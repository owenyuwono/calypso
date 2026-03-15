extends Node
## Handles skill execution: hotbar routing, skill activation, pending hit timing,
## and hit resolution.
## Call setup(player) from player._ready() after adding as child.

const SkillDatabase = preload("res://scripts/data/skill_database.gd")

var _player: Node3D
var _combat: Node
var _stats: Node
var _skills_comp: Node
var _progression: Node
var _visuals: Node
var _skill_hotbar: Control

# Pending skill hit state
var pending_skill_hit: bool = false
var _pending_skill_damage: int = 0
var _pending_skill_id: String = ""
var _pending_skill_anim: String = ""
var _skill_hit_time: float = 0.0

const STAMINA_DRAIN_SKILL: float = 5.0


func setup(player: Node3D, combat: Node, stats: Node, skills_comp: Node, progression: Node, visuals: Node) -> void:
	_player = player
	_combat = combat
	_stats = stats
	_skills_comp = skills_comp
	_progression = progression
	_visuals = visuals


## Set the skill hotbar UI reference (needed for cooldown display).
func set_skill_hotbar(hotbar: Control) -> void:
	_skill_hotbar = hotbar


## Clear all pending skill state (called by player when cancelling attack).
func cancel_pending() -> void:
	pending_skill_hit = false
	_pending_skill_damage = 0
	_pending_skill_id = ""
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
	var skill := SkillDatabase.get_skill(skill_id)
	if skill.is_empty():
		return
	var skill_level: int = _skills_comp.get_skill_level(skill_id)
	if skill_level <= 0:
		return
	var skill_type: String = skill.get("type", "")
	if skill_type == "melee_attack":
		var attack_target: String = _player._attack_target
		if attack_target.is_empty():
			return
		var target_node := WorldState.get_entity(attack_target)
		if not target_node or not is_instance_valid(target_node) or not WorldState.is_alive(attack_target):
			return
		var dist := _player.global_position.distance_to(target_node.global_position)
		var attack_range: float = _stats.attack_range
		if dist > attack_range:
			return
		var multiplier := SkillDatabase.get_effective_multiplier(skill_id, skill_level)
		var raw_damage := floori(_combat.get_effective_atk() * multiplier)
		var anim_name: String = skill.get("animation", "1H_Melee_Attack_Chop")
		pending_skill_hit = true
		_pending_skill_damage = raw_damage
		_pending_skill_id = skill_id
		_pending_skill_anim = anim_name
		_visuals.play_anim(anim_name, true)
		_skill_hit_time = _visuals.get_hit_delay(anim_name)
		_player._auto_attack.cancel()
		# Drain stamina for skill use
		var stamina_comp_node = _player.get_node_or_null("StaminaComponent")
		if stamina_comp_node:
			stamina_comp_node.drain_flat(STAMINA_DRAIN_SKILL)
		# Start cooldown
		var cooldown := SkillDatabase.get_effective_cooldown(skill_id, skill_level)
		if _skill_hotbar:
			_skill_hotbar.start_cooldown(skill_id, cooldown)


## Handles the pending skill hit timing while suppressing auto-attack.
## Returns true if the player is moving (chasing out-of-range target).
## Call from player._process_combat() when pending_skill_hit is true.
func process_skill_hit(delta: float, attack_range: float) -> bool:
	var attack_target: String = _player._attack_target
	# Validate target first
	var target_node := WorldState.get_entity(attack_target)
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
	var to_target := (target_node.global_position - _player.global_position)
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
	var attack_target: String = _player._attack_target
	if attack_target.is_empty():
		return
	if not WorldState.is_alive(attack_target):
		return
	var target_node := WorldState.get_entity(attack_target)
	var target_pos := target_node.global_position if target_node else _player.global_position
	var actual_damage: int = _combat.deal_damage_amount_to(attack_target, _pending_skill_damage)
	_visuals.spawn_damage_number(attack_target, actual_damage, Color(1, 1, 1), target_pos)
	_visuals.flash_target(attack_target)
	GameEvents.skill_used.emit("player", _pending_skill_id)
	# Grant skill XP for use-based leveling
	_skills_comp.grant_skill_xp(_pending_skill_id, 5)
	# Grant weapon XP for skill hits too
	var target_data := WorldState.get_entity_data(attack_target)
	var monster_type: String = target_data.get("monster_type", "")
	if not monster_type.is_empty():
		var weapon_type: String = _combat.get_equipped_weapon_type()
		_progression.grant_combat_xp(monster_type, weapon_type)
	_pending_skill_damage = 0
	_pending_skill_id = ""
