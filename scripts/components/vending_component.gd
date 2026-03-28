extends BaseComponent
## Component that owns vending state for an entity (player-run shop).
## Bridge: _sync() writes back to WorldState.entity_data on every mutation.

const ItemDatabase = preload("res://scripts/data/item_database.gd")

var _shop_title: String = ""
var _listings: Dictionary = {}  # {item_id: {count: int, price: int}}

func setup_shop(title: String) -> void:
	_shop_title = title

func get_listings() -> Dictionary:
	return _listings

func get_shop_title() -> String:
	return _shop_title

func get_discount_for(buyer_id: String) -> float:
	var rel_comp: Node = get_parent().get_node_or_null("RelationshipComponent")
	if not rel_comp:
		return 0.0
	return rel_comp.get_discount_for(buyer_id)


func buy_from(buyer: Node, item_id: String, count: int) -> bool:
	if not _listings.has(item_id):
		return false

	var listing: Dictionary = _listings[item_id]
	var available_count: int = listing.get("count", 0)
	var price_each: int = listing.get("price", 0)

	if available_count < count:
		return false

	var buyer_id: String = WorldState.get_entity_id_for_node(buyer)
	var discount: float = get_discount_for(buyer_id)
	var discounted_price: int = maxi(1, ceili(price_each * (1.0 - discount)))
	var total_cost: int = discounted_price * count

	var buyer_inv: Node = buyer.get_node_or_null("InventoryComponent")
	if not buyer_inv:
		return false
	if buyer_inv.get_gold_amount() < total_cost:
		return false

	var seller_inv: Node = get_parent().get_node_or_null("InventoryComponent")
	if not seller_inv:
		return false
	if not seller_inv.has_item(item_id, count):
		return false

	buyer_inv.remove_gold_amount(total_cost)
	seller_inv.add_gold_amount(total_cost)
	seller_inv.remove_item(item_id, count)
	buyer_inv.add_item(item_id, count)

	var new_count: int = available_count - count
	if new_count <= 0:
		_listings.erase(item_id)
	else:
		_listings[item_id]["count"] = new_count

	_sync()

	return true

func refresh_listings(inventory: Node, equipment: Node) -> void:
	_listings.clear()
	if not inventory:
		return
	var items: Dictionary = inventory.get_items()
	for item_id: String in items:
		var count: int = items[item_id]
		if count <= 0:
			continue
		var item_data: Dictionary = ItemDatabase.get_item(item_id)
		var base_value: int = item_data.get("value", 10)
		var price: int = int(base_value * 0.8)
		_listings[item_id] = {"count": count, "price": maxi(1, price)}
	_sync()

func add_listing(item_id: String, count: int, price: int) -> void:
	if _listings.has(item_id):
		_listings[item_id]["count"] += count
	else:
		_listings[item_id] = {"count": count, "price": price}
	_sync()

func _sync() -> void:
	var eid: String = _get_entity_id()
	if eid.is_empty():
		return
	WorldState.set_entity_data(eid, "shop_title", _shop_title)
	WorldState.set_entity_data(eid, "listings", _listings)
