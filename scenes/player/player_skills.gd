extends Node
## Handles skill execution: hotbar routing, skill activation, pending hit timing,
## and hit resolution.
## Call setup(player) from player._ready() after adding as child.

const SkillDatabase = preload("res://scripts/data/skill_database.gd")
const SkillEffectResolver = preload("res://scripts/skills/skill_effect_resolver.gd")

var _player: Node3D
var _combat: Node
var _stats: Node
var _skills_comp: Node
var _progression: Node
var _visuals: Node
var _perception: Node
var _skill_hotbar: Control

# Pending skill hit state
var pending_skill_hit: bool = false
var _pending_skill_id: String = ""
var _pending_target_id: String = ""
var _pending_skill_anim: String = ""
var _skill_hit_time: float = 0.0

# Active bleed effects: {target_id -> bleed_state dict}
var _active_bleeds: Dictionary = {}

const STAMINA_DRAIN_SKILL: float = 5.0


func setup(player: Node3D, combat: Node, stats: Node, skills_comp: Node, progression: Node, visuals: Node, perception: Node) -> void:
	_player = player
	_combat = combat
	_stats = stats
	_skills_comp = skills_comp
	_progression = progression
	_visuals = visuals
	_perception = perception


## Set the skill hotbar UI reference (needed for cooldown display).
func set_skill_hotbar(hotbar: Control) -> void:
	_skill_hotbar = hotbar


## Clear all pending skill state (called by player when cancelling attack).
func cancel_pending() -> void:
	pending_skill_hit = false
	_pending_skill_id = ""
	_pending_target_id = ""
	_pending_skill_anim = ""


## Try to use the skill assigned to the given hotbar slot index (0-based).
func try_use_hotbar_slot(slot: int) -> void:
	var hotbar: Array = _skills_comp.get_hotbar()
	if slot < 0 or slot >= hotbar.size():
		return
	var skill_id: String = hotbar[slot]
	if skill_id.is_empty():
		return
	if _skill_hotbar and _skill_hotbar.is_on_cooldown(skill_id):
		return
	use_skill(skill_id)


func use_skill(skill_id: String) -> void:
	var skill: Dictionary = SkillDatabase.get_skill(skill_id)
	if skill.is_empty():
		return
	var skill_level: int = _skills_comp.get_skill_level(skill_id)

	# All skill types require a valid, in-range, alive target
	var attack_target: String = _player._attack_target
	if attack_target.is_empty():
		return
	var target_node: Node3D = WorldState.get_entity(attack_target)
	if not target_node or not is_instance_valid(target_node) or not WorldState.is_alive(attack_target):
		return
	var dist: float = _player.global_position.distance_to(target_node.global_position)
	var attack_range: float = _stats.attack_range
	if dist > attack_range:
		return

	var anim_name: String = skill.get("animation", "1H_Melee_Attack_Chop")
	pending_skill_hit = true
	_pending_skill_id = skill_id
	_pending_target_id = attack_target
	_pending_skill_anim = anim_name
	_visuals.play_anim(anim_name, true)
	_skill_hit_time = _visuals.get_hit_delay(anim_name)
	_player._auto_attack.cancel()
	# Drain stamina for skill use
	var stamina_comp_node: Node = _player.get_node_or_null("StaminaComponent")
	if stamina_comp_node:
		stamina_comp_node.drain_flat(STAMINA_DRAIN_SKILL)
	# Start cooldown with synergy reduction applied
	var cd_bonuses: Dictionary = {}
	if _progression:
		cd_bonuses = SkillDatabase.get_synergy_bonuses(skill_id, _progression)
	var cd_reduction: float = cd_bonuses.get("cooldown_reduction", 0.0)
	var base_cd: float = SkillDatabase.get_effective_cooldown(skill_id, skill_level)
	var final_cd: float = base_cd * (1.0 - cd_reduction)
	if _skill_hotbar:
		_skill_hotbar.start_cooldown(skill_id, final_cd)


## Handles the pending skill hit timing while suppressing auto-attack.
## Returns true if the player is moving (chasing out-of-range target).
## Call from player._process_combat() when pending_skill_hit is true.
func process_skill_hit(delta: float, attack_range: float) -> bool:
	var attack_target: String = _player._attack_target
	# Validate target first
	var target_node: Node3D = WorldState.get_entity(attack_target)
	if not target_node or not is_instance_valid(target_node) or not WorldState.is_alive(attack_target):
		_player._cancel_attack()
		return false

	# If out of range, chase the target (without auto-attack accumulating)
	var dist: float = _player.global_position.distance_to(target_node.global_position)
	if dist > attack_range:
		var nav_agent: Node = _player.nav_agent
		nav_agent.target_position = target_node.global_position
		if not nav_agent.is_navigation_finished():
			var next_pos: Vector3 = nav_agent.get_next_path_position()
			var dir: Vector3 = (next_pos - _player.global_position)
			dir.y = 0.0
			if dir.length_squared() > 0.01:
				dir = dir.normalized()
				_player.velocity.x = dir.x * _player.SPEED
				_player.velocity.z = dir.z * _player.SPEED
				_visuals.face_direction(dir)
				_visuals.play_anim("Running_A")
		return true

	# In range — resolve skill hit timing
	_player.velocity.x = 0.0
	_player.velocity.z = 0.0
	var to_target: Vector3 = (target_node.global_position - _player.global_position)
	to_target.y = 0.0
	if to_target.length_squared() > 0.01:
		_visuals.face_direction(to_target.normalized())

	var anim_player: AnimationPlayer = _visuals.get_anim_player()
	if anim_player and anim_player.current_animation == _pending_skill_anim:
		if anim_player.current_animation_position >= _skill_hit_time:
			pending_skill_hit = false
			_execute_skill_hit()
	else:
		# Fallback countdown when skill animation isn't playing
		_skill_hit_time -= delta
		if _skill_hit_time <= 0.0:
			pending_skill_hit = false
			_execute_skill_hit()
	return false


func _execute_skill_hit() -> void:
	if _pending_target_id.is_empty():
		return
	if not WorldState.is_alive(_pending_target_id):
		return

	var skill_data: Dictionary = SkillDatabase.get_skill(_pending_skill_id)
	var skill_level: int = _skills_comp.get_skill_level(_pending_skill_id)
	var skill_color: Color = skill_data.get("color", Color(1, 1, 1))

	var effectiveness_data: Dictionary = {}
	if _progression:
		var primary: Dictionary = SkillDatabase.get_primary_proficiency(_pending_skill_id)
		var prof_level: int = _progression.get_proficiency_level(primary.skill)
		var eff_data: Dictionary = SkillDatabase.get_primary_effectiveness(_pending_skill_id, prof_level)
		var bonuses: Dictionary = SkillDatabase.get_synergy_bonuses(_pending_skill_id, _progression)
		effectiveness_data = {
			"effectiveness": eff_data.effectiveness,
			"synergy_bonuses": bonuses,
			"self_harm_chance": eff_data.self_harm_chance,
			"self_harm_percent": eff_data.self_harm_percent,
		}

	var results: Array = SkillEffectResolver.resolve_skill_hit(
		_combat, _perception, skill_data, skill_level,
		_pending_target_id, _player.global_position, _active_bleeds, "player",
		effectiveness_data
	)

	# Spawn damage numbers and visual feedback for every hit in results
	for i in range(results.size()):
		var result: Dictionary = results[i]
		if result.get("self_harm", false):
			var self_damage: int = result.get("damage", 0)
			_stats.take_damage(self_damage)
			_visuals.flash_hit()
			_visuals.spawn_damage_number("player", self_damage, Color.RED, _player.global_position)
			GameEvents.skill_backfired.emit("player", _pending_skill_id, self_damage)
			continue
		var hit_target_id: String = result.get("target_id", "")
		var hit_damage: int = result.get("damage", 0)
		var hit_node: Node3D = WorldState.get_entity(hit_target_id)
		var hit_pos: Vector3 = hit_node.global_position if hit_node else _player.global_position
		_visuals.spawn_damage_number(hit_target_id, hit_damage, skill_color, hit_pos)
		_visuals.flash_target(hit_target_id)

	GameEvents.skill_used.emit("player", _pending_skill_id)

	# Grant XP once for the primary target hit
	_skills_comp.grant_skill_xp(_pending_skill_id, 5)
	var target_data: Dictionary = WorldState.get_entity_data(_pending_target_id)
	var monster_type: String = target_data.get("monster_type", "")
	if not monster_type.is_empty():
		var weapon_type: String = _combat.get_equipped_weapon_type()
		_progression.grant_combat_xp(monster_type, weapon_type)

	_pending_skill_id = ""
	_pending_target_id = ""


func _process(delta: float) -> void:
	if _active_bleeds.is_empty():
		return
	var bleed_results: Array = SkillEffectResolver.process_bleeds(_active_bleeds, delta)
	for result in bleed_results:
		var target_id: String = result.get("target_id", "")
		var damage: int = result.get("damage", 0)
		var target_entity: Node3D = WorldState.get_entity(target_id)
		if target_entity and is_instance_valid(target_entity):
			_visuals.spawn_damage_number(target_id, damage, Color(1, 0.3, 0.3), target_entity.global_position)
			_visuals.flash_target(target_id)
