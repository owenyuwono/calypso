extends BaseComponent
## Harvestable resource component for gathering skills (woodcutting, mining, etc.).
## Add as child to a harvestable entity. Manages chop count, depletion, and respawn.

const TreeDatabase = preload("res://scripts/data/tree_database.gd")

signal depleted()
signal respawned()

var _skill_id: String = "woodcutting"
var _database_lookup: Callable = Callable()

var _tier: String = ""
var _required_level: int = 1
var _xp_per_chop: int = 0
var _drop_item: String = ""
var _bonus_drop: String = ""
var _bonus_chance: float = 0.0
var _respawn_time: float = 60.0

var respawn_mode: String = "in_place"

var _chops_remaining: int = 0
var _chops_min: int = 0
var _chops_max: int = 0
var _depleted: bool = false
var _respawn_timer: float = 0.0


func setup(tier: String, skill_id: String = "woodcutting", database_lookup: Callable = Callable()) -> void:
	_tier = tier
	_skill_id = skill_id
	_database_lookup = database_lookup

	var data: Dictionary
	if _database_lookup.is_valid():
		data = _database_lookup.call(tier)
	else:
		data = TreeDatabase.get_tree(tier)
	if data.is_empty():
		push_error("HarvestableComponent: unknown tier '%s'" % tier)
		return

	var chops_range: Array = data.get("chops", [3, 5])
	_chops_min = chops_range[0]
	_chops_max = chops_range[1]
	_xp_per_chop = data.get("xp_per_chop", 5)
	_required_level = data.get("required_level", 1)
	_drop_item = data.get("drop", "log")
	_bonus_drop = data.get("bonus_drop", "")
	_bonus_chance = data.get("bonus_chance", 0.0)
	_respawn_time = data.get("respawn_time", 60.0)

	_chops_remaining = randi_range(_chops_min, _chops_max)
	_depleted = false


func can_harvest(entity_id: String) -> bool:
	if _depleted:
		return false

	var entity: Node = WorldState.get_entity(entity_id)
	if not is_instance_valid(entity):
		return false

	var progression: Node = entity.get_node_or_null("ProgressionComponent")
	if not progression:
		return false

	var skill_level: int = progression.get_proficiency_level(_skill_id)
	return skill_level >= _required_level


func process_chop(entity_id: String) -> Dictionary:
	if _depleted:
		return {}
	_chops_remaining -= 1

	var bonus_item: String = ""
	if not _bonus_drop.is_empty() and randf() < _bonus_chance:
		bonus_item = _bonus_drop

	var just_depleted: bool = _chops_remaining <= 0
	if just_depleted:
		_depleted = true
		_respawn_timer = _respawn_time
		depleted.emit()

	return {
		"item_id": _drop_item,
		"xp": _xp_per_chop,
		"bonus_item": bonus_item,
		"depleted": just_depleted,
	}


func is_depleted() -> bool:
	return _depleted


func get_respawn_time() -> float:
	return _respawn_time


func get_required_level() -> int:
	return _required_level


func get_skill_id() -> String:
	return _skill_id


func get_tier() -> String:
	return _tier


func _process(delta: float) -> void:
	if not _depleted:
		return
	if respawn_mode != "in_place":
		return  # External manager handles respawn

	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		_chops_remaining = randi_range(_chops_min, _chops_max)
		_depleted = false
		respawned.emit()
