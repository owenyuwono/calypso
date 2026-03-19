extends Node
## NPC skill execution node. AI-driven skill selection, cooldown management,
## pending hit timing, bleed tracking, and SkillEffectResolver dispatch.
## Call setup() from npc_base._ready() after all components are initialised.

const SkillDatabase = preload("res://scripts/data/skill_database.gd")
const SkillEffectResolver = preload("res://scripts/skills/skill_effect_resolver.gd")

var _entity: Node
var _combat: Node
var _skills: Node
var _perception: Node
var _visuals: Node
var _auto_attack: Node

var _active_bleeds: Dictionary = {}
var _cooldowns: Dictionary = {}
var _global_cooldown: float = 0.0

var _pending_skill_hit: bool = false
var _pending_skill_id: String = ""
var _pending_target_id: String = ""
var _skill_hit_timer: float = 0.0

const GLOBAL_COOLDOWN: float = 4.0
const SKILL_XP_PER_HIT: int = 5


func setup(entity: Node, combat: Node, skills: Node, perception: Node, visuals: Node, auto_attack: Node) -> void:
	_entity = entity
	_combat = combat
	_skills = skills
	_perception = perception
	_visuals = visuals
	_auto_attack = auto_attack


func _process(delta: float) -> void:
	# Tick individual skill cooldowns
	for skill_id in _cooldowns.keys():
		_cooldowns[skill_id] = _cooldowns[skill_id] - delta
		if _cooldowns[skill_id] <= 0.0:
			_cooldowns.erase(skill_id)

	# Tick global cooldown
	if _global_cooldown > 0.0:
		_global_cooldown -= delta

	# Process active bleeds and spawn damage numbers for each tick
	var bleed_results: Array = SkillEffectResolver.process_bleeds(_active_bleeds, delta)
	for result in bleed_results:
		var target_id: String = result.get("target_id", "")
		var damage: int = result.get("damage", 0)
		_spawn_damage_number(target_id, damage)

	# Tick pending skill hit timer
	if _pending_skill_hit:
		_skill_hit_timer -= delta
		if _skill_hit_timer <= 0.0:
			_execute_skill_hit()


func try_use_skill(target_id: String) -> bool:
	if _pending_skill_hit:
		return false
	if _global_cooldown > 0.0:
		return false

	var skill_id: String = _pick_best_skill(target_id)
	if skill_id.is_empty():
		return false

	var skill_data: Dictionary = SkillDatabase.get_skill(skill_id)
	if skill_data.is_empty():
		return false

	var skill_level: int = _skills.get_skill_level(skill_id)
	if skill_level <= 0:
		return false

	_pending_skill_hit = true
	_pending_skill_id = skill_id
	_pending_target_id = target_id

	var anim_name: String = skill_data.get("animation", "1H_Melee_Attack_Chop")
	_visuals.play_anim(anim_name, true)
	_skill_hit_timer = _visuals.get_hit_delay(anim_name)

	_auto_attack.cancel()

	_cooldowns[skill_id] = SkillDatabase.get_effective_cooldown(skill_id, skill_level)
	_global_cooldown = GLOBAL_COOLDOWN

	return true


func _pick_best_skill(target_id: String) -> String:
	# Determine equipped weapon type for matching skills to proficiency
	var weapon_type: String = _combat.get_equipped_weapon_type()

	# Count alive enemies nearby to decide if AoE is preferred
	var nearby: Array = _perception.get_nearby(8.0)
	var nearby_enemy_count: int = 0
	for entry in nearby:
		var eid: String = entry.get("id", "")
		if eid.begins_with("monster_") and WorldState.is_alive(eid):
			nearby_enemy_count += 1

	var best_aoe_id: String = ""
	var best_aoe_multiplier: float = -1.0
	var best_single_id: String = ""
	var best_single_multiplier: float = -1.0

	for skill_id in SkillDatabase.SKILLS:
		var skill_data: Dictionary = SkillDatabase.SKILLS[skill_id]

		# Must be unlocked and have skill level > 0
		if not _skills.has_skill(skill_id):
			continue

		var skill_level: int = _skills.get_skill_level(skill_id)
		if skill_level <= 0:
			continue

		# Must not be on cooldown
		if _cooldowns.get(skill_id, 0.0) > 0.0:
			continue

		# Must require the NPC's current weapon proficiency
		if not skill_data.has("synergy"):
			continue
		if skill_data.synergy.primary.get("skill", "") != weapon_type:
			continue

		var skill_type: String = skill_data.get("type", "")
		var multiplier: float = SkillDatabase.get_effective_multiplier(skill_id, skill_level)

		if skill_type == "aoe_melee":
			if multiplier > best_aoe_multiplier:
				best_aoe_multiplier = multiplier
				best_aoe_id = skill_id
		else:
			if multiplier > best_single_multiplier:
				best_single_multiplier = multiplier
				best_single_id = skill_id

	# Prefer AoE when multiple enemies are nearby
	if nearby_enemy_count >= 2 and not best_aoe_id.is_empty():
		return best_aoe_id

	if not best_single_id.is_empty():
		return best_single_id

	# Fall back to AoE even with a single target if it's the only option
	return best_aoe_id


func _execute_skill_hit() -> void:
	_pending_skill_hit = false

	if not WorldState.is_alive(_pending_target_id):
		return

	var skill_data: Dictionary = SkillDatabase.get_skill(_pending_skill_id)
	if skill_data.is_empty():
		return

	var skill_level: int = _skills.get_skill_level(_pending_skill_id)
	var skill_color: Color = skill_data.get("color", Color(1, 1, 1))
	var skill_name: String = skill_data.get("name", _pending_skill_id)

	var entity_id: String = WorldState.get_entity_id_for_node(_entity)
	var results: Array = SkillEffectResolver.resolve_skill_hit(
		_combat,
		_perception,
		skill_data,
		skill_level,
		_pending_target_id,
		_entity.global_position,
		_active_bleeds,
		entity_id
	)

	for result in results:
		var target_id: String = result.get("target_id", "")
		var damage: int = result.get("damage", 0)
		_spawn_damage_number(target_id, damage, skill_color)

	_skills.grant_skill_xp(_pending_skill_id, SKILL_XP_PER_HIT)

	GameEvents.skill_used.emit(entity_id, _pending_skill_id)
	GameEvents.npc_spoke.emit(entity_id, "%s!" % skill_name, _pending_target_id)


func is_skill_active() -> bool:
	return _pending_skill_hit


# --- Private helpers ---

func _spawn_damage_number(target_id: String, damage: int, color: Color = Color(1, 1, 1)) -> void:
	if target_id.is_empty() or damage <= 0:
		return
	var target_node: Node3D = WorldState.get_entity(target_id)
	if not target_node or not is_instance_valid(target_node):
		return
	_visuals.spawn_damage_number(target_id, damage, color, target_node.global_position)
	_visuals.flash_target(target_id)
