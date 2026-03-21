extends BaseComponent
## Component that owns equipment slots for an entity.
## Bridge: _sync() writes back to WorldState.entity_data on every mutation.

const ItemDatabase = preload("res://scripts/data/item_database.gd")

var _slots: Dictionary = {
	"head": "", "torso": "", "legs": "", "gloves": "",
	"feet": "", "back": "", "main_hand": "", "off_hand": "",
}
var _inventory: Node  # InventoryComponent ref

func setup(equipment: Dictionary, inventory_component: Node) -> void:
	_slots = equipment.duplicate()
	_inventory = inventory_component

func equip(item_id: String) -> bool:
	if not _inventory or not _inventory.has_item(item_id):
		return false
	var item: Dictionary = ItemDatabase.get_item(item_id)
	if item.is_empty():
		return false
	# Determine slot from slot_type field, fall back to type field
	var slot: String = item.get("slot_type", "")
	if slot.is_empty():
		match item.get("type", ""):
			"weapon": slot = "main_hand"
			"armor": slot = "off_hand"
			_: return false
	if not _slots.has(slot):
		return false
	# Unequip current item in that slot
	if not _slots[slot].is_empty():
		unequip(slot)
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
	return _slots.get("main_hand", "")

func get_armor() -> String:
	return _slots.get("off_hand", "")

func get_slot(slot_name: String) -> String:
	return _slots.get(slot_name, "")

func get_equipment() -> Dictionary:
	return _slots

func get_atk_bonus() -> int:
	var total: int = 0
	for slot_name in _slots:
		var item_id: String = _slots[slot_name]
		if item_id.is_empty():
			continue
		var item: Dictionary = ItemDatabase.get_item(item_id)
		total += item.get("atk_bonus", 0)
	return total

func get_def_bonus() -> int:
	var total: int = 0
	for slot_name in _slots:
		var item_id: String = _slots[slot_name]
		if item_id.is_empty():
			continue
		var item: Dictionary = ItemDatabase.get_item(item_id)
		total += item.get("def_bonus", 0)
	return total

func get_matk_bonus() -> int:
	var total: int = 0
	for slot_name in _slots:
		var item_id: String = _slots[slot_name]
		if item_id.is_empty():
			continue
		var item: Dictionary = ItemDatabase.get_item(item_id)
		total += item.get("matk_bonus", 0)
	return total

func get_mdef_bonus() -> int:
	var total: int = 0
	for slot_name in _slots:
		var item_id: String = _slots[slot_name]
		if item_id.is_empty():
			continue
		var item: Dictionary = ItemDatabase.get_item(item_id)
		total += item.get("mdef_bonus", 0)
	return total

func get_armor_type() -> String:
	var torso_id: String = _slots.get("torso", "")
	if torso_id.is_empty():
		return "light"
	var item: Dictionary = ItemDatabase.get_item(torso_id)
	return item.get("armor_type", "light")

func _sync() -> void:
	var parent := get_parent()
	if not parent or not ("entity_id" in parent):
		return
	var eid: String = parent.entity_id
	if eid.is_empty():
		return
	WorldState.set_entity_data(eid, "equipment", _slots)
