extends BaseComponent
## Component that owns skill state for an entity.
## Also handles shared skill execution: cooldowns, pending hit timing,
## bleed processing, XP granting, and SkillEffectResolver dispatch.
## Call setup_execution() after setup() and after all components are created.

const SkillDatabase = preload("res://scripts/data/skill_database.gd")
const SkillEffectResolver = preload("res://scripts/skills/skill_effect_resolver.gd")
const ProficiencyDatabase = preload("res://scripts/data/proficiency_database.gd")

var _skills: Dictionary = {}  # skill_id -> level (int)
var _skill_xp: Dictionary = {}  # skill_id -> current xp (int)
var _hotbar: Array = ["", "", "", "", ""]

# Execution refs — populated by setup_execution()
var _combat: Node
var _stats: Node
var _progression: Node
var _visuals: Node
var _perception: Node
var _auto_attack: Node

# Cooldown state
var _cooldowns: Dictionary = {}  # skill_id -> {remaining: float, total: float}
var _global_cooldown: float = 0.0

# Pending hit state
var _pending_skill_hit: bool = false
var _pending_skill_id: String = ""
var _pending_target_id: String = ""
var _pending_skill_anim: String = ""
var _skill_hit_time: float = 0.0

# Active bleed effects: {target_id -> bleed_state dict}
var _active_bleeds: Dictionary = {}

var _execution_ready: bool = false


func setup(skills: Dictionary, hotbar: Array) -> void:
	# Initialize all skills at minimum level 1
	for skill_id in SkillDatabase.SKILLS:
		_skills[skill_id] = maxi(1, skills.get(skill_id, 1))
	_hotbar = hotbar.duplicate()
	for skill_id in SkillDatabase.SKILLS:
		_skill_xp[skill_id] = 0
	_sync()

func get_skill_level(skill_id: String) -> int:
	if not SkillDatabase.SKILLS.has(skill_id):
		return 0
	return maxi(1, _skills.get(skill_id, 1))

func has_skill(skill_id: String) -> bool:
	return SkillDatabase.SKILLS.has(skill_id)

func grant_skill_xp(skill_id: String, amount: int) -> void:
	## Grant XP to an active skill. Levels up using same curve as proficiencies.
	var skill: Dictionary = SkillDatabase.get_skill(skill_id)
	if skill.is_empty():
		return
	var current_level: int = _skills.get(skill_id, 1)
	var max_level: int = skill.get("max_level", 5)
	if current_level >= max_level:
		return

	var xp: int = _skill_xp.get(skill_id, 0) + amount
	var xp_needed: int = current_level * 50  # Same curve as proficiencies

	var parent := get_parent()
	var entity_id: String = parent.entity_id if parent and "entity_id" in parent else ""

	while xp >= xp_needed and current_level < max_level:
		xp -= xp_needed
		current_level += 1
		_skills[skill_id] = current_level
		if not entity_id.is_empty():
			GameEvents.skill_learned.emit(entity_id, skill_id, current_level)
		xp_needed = current_level * 50

	_skill_xp[skill_id] = xp
	_sync()

func get_skill_xp(skill_id: String) -> int:
	return _skill_xp.get(skill_id, 0)

func set_hotbar_slot(index: int, skill_id: String) -> void:
	if index < 0 or index >= _hotbar.size():
		return
	# Remove skill from other slots first
	for i in range(_hotbar.size()):
		if _hotbar[i] == skill_id:
			_hotbar[i] = ""
	_hotbar[index] = skill_id
	_sync()

func get_hotbar() -> Array:
	return _hotbar

func _sync() -> void:
	var parent := get_parent()
	if not parent or not ("entity_id" in parent):
		return
	var eid: String = parent.entity_id
	if eid.is_empty():
		return
	WorldState.set_entity_data(eid, "skills", _skills)
	WorldState.set_entity_data(eid, "hotbar", _hotbar)
	WorldState.set_entity_data(eid, "skill_xp", _skill_xp)


# --- Execution setup ---

func setup_execution(combat: Node, stats: Node, progression: Node, visuals: Node, perception: Node, auto_attack: Node) -> void:
	## Stores component refs needed for skill execution.
	## Call after setup() and after all components are created.
	_combat = combat
	_stats = stats
	_progression = progression
	_visuals = visuals
	_perception = perception
	_auto_attack = auto_attack
	_execution_ready = true


# --- Public execution API ---

func begin_skill_use(skill_id: String, target_id: String) -> bool:
	## Validate, animate, cancel auto-attack, drain stamina, start cooldown, set pending state.
	## Returns true on success, false if validation fails.
	var skill_data: Dictionary = SkillDatabase.get_skill(skill_id)
	if skill_data.is_empty():
		return false

	var skill_level: int = get_skill_level(skill_id)

	if not WorldState.is_alive(target_id):
		return false
	var target_node: Node3D = WorldState.get_entity(target_id)
	if not target_node or not is_instance_valid(target_node):
		return false

	var anim_name: String = skill_data.get("animation", "1H_Melee_Attack_Chop")
	_visuals.play_anim(anim_name, true)
	_skill_hit_time = _visuals.get_hit_delay(anim_name)

	if _auto_attack:
		_auto_attack.cancel()

	var stamina_comp: Node = get_parent().get_node_or_null("StaminaComponent")
	if stamina_comp:
		var cost: int = skill_data.get("stamina_cost", 15)
		stamina_comp.drain_flat(float(cost))

	var cd_bonuses: Dictionary = {}
	if _progression:
		cd_bonuses = SkillDatabase.get_synergy_bonuses(skill_id, _progression)
	var synergy_cdr: float = cd_bonuses.get("cooldown_reduction", 0.0)
	var stats_cdr: float = _stats.cooldown_reduction if _stats else 0.0
	var synergy_cdr_pct: float = synergy_cdr * 100.0  # Convert fraction to percentage
	var total_cdr: float = minf(stats_cdr + synergy_cdr_pct, 40.0)
	var base_cd: float = SkillDatabase.get_effective_cooldown(skill_id, skill_level)
	var final_cd: float = base_cd * (1.0 - total_cdr / 100.0)
	start_cooldown(skill_id, final_cd)

	_pending_skill_hit = true
	_pending_skill_id = skill_id
	_pending_target_id = target_id
	_pending_skill_anim = anim_name

	return true


func tick_pending_hit(delta: float) -> int:
	## Advance pending hit timing. Returns:
	##   0 — nothing pending or target died (cancelled)
	##   1 — hit resolved this frame
	##   2 — still waiting
	if not _pending_skill_hit:
		return 0

	if not WorldState.is_alive(_pending_target_id):
		cancel_pending()
		return 0

	var anim_player: AnimationPlayer = _visuals.get_anim_player()
	if anim_player and anim_player.current_animation == _pending_skill_anim:
		if anim_player.current_animation_position >= _skill_hit_time:
			_execute_skill_hit()
			return 1
	else:
		_skill_hit_time -= delta
		if _skill_hit_time <= 0.0:
			_execute_skill_hit()
			return 1

	return 2


func cancel_pending() -> void:
	_pending_skill_hit = false
	_pending_skill_id = ""
	_pending_target_id = ""
	_pending_skill_anim = ""


func is_skill_pending() -> bool:
	return _pending_skill_hit


# --- Cooldown API ---

func start_cooldown(skill_id: String, duration: float) -> void:
	_cooldowns[skill_id] = {"remaining": duration, "total": duration}


func is_on_cooldown(skill_id: String) -> bool:
	return _cooldowns.get(skill_id, {}).get("remaining", 0.0) > 0.0


func get_cooldown_remaining(skill_id: String) -> float:
	return _cooldowns.get(skill_id, {}).get("remaining", 0.0)


func get_cooldown_total(skill_id: String) -> float:
	return _cooldowns.get(skill_id, {}).get("total", 0.0)


func set_global_cooldown(duration: float) -> void:
	_global_cooldown = duration


func is_global_cooldown_active() -> bool:
	return _global_cooldown > 0.0


# --- _process override ---

func _process(delta: float) -> void:
	if not _execution_ready:
		return

	if _cooldowns.is_empty() and _global_cooldown <= 0.0 and _active_bleeds.is_empty():
		return

	# Tick per-skill cooldowns
	var expired_skills: Array = []
	for skill_id in _cooldowns:
		_cooldowns[skill_id]["remaining"] -= delta
		if _cooldowns[skill_id]["remaining"] <= 0.0:
			expired_skills.append(skill_id)
	for skill_id in expired_skills:
		_cooldowns.erase(skill_id)

	# Tick global cooldown
	if _global_cooldown > 0.0:
		_global_cooldown -= delta
		if _global_cooldown < 0.0:
			_global_cooldown = 0.0

	# Process active bleeds
	if not _active_bleeds.is_empty():
		var bleed_results: Array = SkillEffectResolver.process_bleeds(_active_bleeds, delta)
		for result in bleed_results:
			var target_id: String = result.get("target_id", "")
			var damage: int = result.get("damage", 0)
			var target_entity: Node3D = WorldState.get_entity(target_id)
			if target_entity and is_instance_valid(target_entity):
				_visuals.spawn_styled_damage_number(target_id, damage, "normal", false, target_entity.global_position)
				_visuals.flash_target(target_id)


# --- Private ---

func _execute_skill_hit() -> void:
	_pending_skill_hit = false

	if _pending_target_id.is_empty():
		return
	if not WorldState.is_alive(_pending_target_id):
		return

	var skill_data: Dictionary = SkillDatabase.get_skill(_pending_skill_id)
	if skill_data.is_empty():
		return

	var skill_level: int = get_skill_level(_pending_skill_id)

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

	var entity_id: String = _get_entity_id()
	var results: Array = SkillEffectResolver.resolve_skill_hit(
		_combat, _perception, skill_data, skill_level,
		_pending_target_id, get_parent().global_position, _active_bleeds, entity_id,
		effectiveness_data
	)

	# WIS XP: 2 per skill use, always (regardless of hit/miss)
	if _progression:
		_progression.grant_proficiency_xp("wis", 2)

	var damage_category: String = skill_data.get("damage_category", "physical")

	for result in results:
		if result.get("self_harm", false):
			var self_damage: int = result.get("damage", 0)
			if _stats:
				_stats.take_damage(self_damage)
			_visuals.flash_hit()
			_visuals.spawn_styled_damage_number(entity_id, self_damage, "weak", false, get_parent().global_position)
			GameEvents.skill_backfired.emit(entity_id, _pending_skill_id, self_damage)
			continue

		var hit_target_id: String = result.get("target_id", "")
		var hit_damage: int = result.get("damage", 0)
		var hit_node: Node3D = WorldState.get_entity(hit_target_id)
		var hit_pos: Vector3 = hit_node.global_position if hit_node else get_parent().global_position

		var result_hit_type: String = result.get("hit_type", "normal")
		var result_is_crit: bool = result.get("is_crit", false)

		if result.get("is_miss", false):
			# Red if player's skill misses, white if NPC/monster skill misses us
			var miss_color: Color = Color(1, 0.3, 0.3) if entity_id == "player" else Color.WHITE
			_visuals.spawn_styled_damage_number(hit_target_id, 0, "miss", false, hit_pos, miss_color)
			continue

		_visuals.spawn_styled_damage_number(hit_target_id, hit_damage, result_hit_type, result_is_crit, hit_pos)
		_visuals.flash_target(hit_target_id)

		# DEX XP: 2 per hit landed
		if _progression:
			_progression.grant_proficiency_xp("dex", 2)

		# STR XP: 3 per physical damage hit
		if damage_category == "physical" and _progression:
			_progression.grant_proficiency_xp("str", 3)

		# INT XP: 3 per magical damage hit
		if damage_category == "magical" and _progression:
			_progression.grant_proficiency_xp("int", 3)

		# Element magic XP: 5 per hit with an elemental skill
		var element: String = skill_data.get("element", "")
		if not element.is_empty() and not ProficiencyDatabase.get_skill(element).is_empty() and _progression:
			_progression.grant_proficiency_xp(element, 5)

	grant_skill_xp(_pending_skill_id, 5)

	if _progression:
		var target_data: Dictionary = WorldState.get_entity_data(_pending_target_id)
		var monster_type: String = target_data.get("monster_type", "")
		if not monster_type.is_empty():
			var weapon_type: String = _combat.get_equipped_weapon_type()
			_progression.grant_combat_xp(monster_type, weapon_type)

	GameEvents.skill_used.emit(entity_id, _pending_skill_id)

	_pending_skill_id = ""
	_pending_target_id = ""
