extends BaseComponent
## Harvestable resource component for trees (woodcutting).
## Add as child to a tree entity. Manages chop count, depletion, and respawn.

const TreeDatabase = preload("res://scripts/data/tree_database.gd")

signal depleted()
signal respawned()

var _tier: String = ""
var _required_level: int = 1
var _xp_per_chop: int = 0
var _drop_item: String = ""
var _bonus_drop: String = ""
var _bonus_chance: float = 0.0
var _respawn_time: float = 60.0

var _chops_remaining: int = 0
var _chops_min: int = 0
var _chops_max: int = 0
var _depleted: bool = false
var _respawn_timer: float = 0.0


func setup(tier: String) -> void:
	_tier = tier
	var data: Dictionary = TreeDatabase.get_tree(tier)
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

	var woodcutting_level: int = progression.get_proficiency_level("woodcutting")
	return woodcutting_level >= _required_level


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


func get_required_level() -> int:
	return _required_level


func get_tier() -> String:
	return _tier


func _process(delta: float) -> void:
	if not _depleted:
		return

	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		_chops_remaining = randi_range(_chops_min, _chops_max)
		_depleted = false
		respawned.emit()
