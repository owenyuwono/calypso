extends BaseComponent
## Component that owns equipment slots for an entity.
## Bridge: _sync() writes back to WorldState.entity_data on every mutation.

const ItemDatabase = preload("res://scripts/data/item_database.gd")

var _slots: Dictionary = {"weapon": "", "armor": ""}
var _inventory: Node  # InventoryComponent ref

func setup(equipment: Dictionary, inventory_component: Node) -> void:
	_slots = equipment.duplicate()
	_inventory = inventory_component

func equip(item_id: String) -> bool:
	var item := ItemDatabase.get_item(item_id)
	if item.is_empty():
		return false
	if not _inventory.has_item(item_id):
		return false

	var slot: String = ""
	match item.get("type", ""):
		"weapon": slot = "weapon"
		"armor": slot = "armor"
		_: return false

	# Unequip current item in that slot
	var current: String = _slots.get(slot, "")
	if not current.is_empty():
		_inventory.add_item(current)

	# Equip new item
	_inventory.remove_item(item_id)
	_slots[slot] = item_id
	_sync()
	return true

func unequip(slot: String) -> bool:
	var item_id: String = _slots.get(slot, "")
	if item_id.is_empty():
		return false
	_slots[slot] = ""
	_inventory.add_item(item_id)
	_sync()
	return true

func get_weapon() -> String:
	return _slots.get("weapon", "")

func get_armor() -> String:
	return _slots.get("armor", "")

func get_equipment() -> Dictionary:
	return _slots

func get_atk_bonus() -> int:
	var weapon_id: String = _slots.get("weapon", "")
	if not weapon_id.is_empty():
		var item := ItemDatabase.get_item(weapon_id)
		return item.get("atk_bonus", 0)
	return 0

func get_def_bonus() -> int:
	var armor_id: String = _slots.get("armor", "")
	if not armor_id.is_empty():
		var item := ItemDatabase.get_item(armor_id)
		return item.get("def_bonus", 0)
	return 0

func _sync() -> void:
	var parent := get_parent()
	if not parent or not ("entity_id" in parent):
		return
	var eid: String = parent.entity_id
	if eid.is_empty():
		return
	WorldState.set_entity_data(eid, "equipment", _slots)
