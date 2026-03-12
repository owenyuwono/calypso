extends Node
## Component that owns inventory and gold for an entity.
## Bridge: _sync() writes back to WorldState.entity_data on every mutation.

var _items: Dictionary = {}
var gold: int = 0

func setup(items: Dictionary, initial_gold: int) -> void:
	_items = items.duplicate()
	gold = initial_gold

func add_item(item_id: String, count: int = 1) -> void:
	_items[item_id] = _items.get(item_id, 0) + count
	_sync()

func remove_item(item_id: String, count: int = 1) -> bool:
	var current: int = _items.get(item_id, 0)
	if current < count:
		return false
	current -= count
	if current <= 0:
		_items.erase(item_id)
	else:
		_items[item_id] = current
	_sync()
	return true

func has_item(item_id: String, count: int = 1) -> bool:
	return _items.get(item_id, 0) >= count

func get_item_count(item_id: String) -> int:
	return _items.get(item_id, 0)

func get_items() -> Dictionary:
	return _items

func add_gold_amount(amount: int) -> void:
	gold += amount
	_sync()

func remove_gold_amount(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	_sync()
	return true

func get_gold_amount() -> int:
	return gold

func set_gold_amount(amount: int) -> void:
	gold = amount
	_sync()

func _sync() -> void:
	var parent := get_parent()
	if not parent or not ("entity_id" in parent):
		return
	var eid: String = parent.entity_id
	if eid.is_empty():
		return
	WorldState.set_entity_data(eid, "inventory", _items)
	WorldState.set_entity_data(eid, "gold", gold)
