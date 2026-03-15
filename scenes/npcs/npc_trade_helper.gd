## Pure utility functions for NPC trade decisions.
## No state — all methods are static.
class_name NpcTradeHelper

const ItemDatabase = preload("res://scripts/data/item_database.gd")

const VENDOR_SEARCH_RADIUS: float = 200.0
const VEND_PRICE_RATIO: float = 0.8

## Returns the entity ID of the nearest vending NPC.
## Pass item_id to require that vendor to stock that item; pass "" to find any vendor.
static func find_vendor(npc_id: String, npc_position: Vector3, item_id: String = "") -> String:
	var all_entries: Array = WorldState.get_nearby_entities(npc_position, VENDOR_SEARCH_RADIUS)
	var best_id: String = ""
	var best_dist: float = INF
	for entry in all_entries:
		var eid: String = entry["id"]
		if eid == npc_id:
			continue
		var edata: Dictionary = WorldState.get_entity_data(eid)
		if not edata.get("vending", false):
			continue
		if not item_id.is_empty():
			var listings: Dictionary = edata.get("listings", {})
			if not listings.has(item_id):
				continue
		var entity_node: Node = WorldState.get_entity(eid)
		if not entity_node or not is_instance_valid(entity_node):
			continue
		var dist: float = npc_position.distance_to(entity_node.global_position)
		if dist < best_dist:
			best_dist = dist
			best_id = eid
	return best_id

## Builds a listings dict from the NPC's non-equipped inventory at 80% of base value.
static func build_vend_listings(inventory: Node, equipment: Node) -> Dictionary:
	var equip_dict: Dictionary = equipment.get_equipment()
	var equipped_ids: Array = equip_dict.values()
	var inv: Dictionary = inventory.get_items()
	var listings: Dictionary = {}
	for item_id in inv:
		if item_id in equipped_ids:
			continue
		var item: Dictionary = ItemDatabase.get_item(item_id)
		if item.is_empty():
			continue
		var base_value: int = item.get("value", 0)
		var price: int = int(base_value * VEND_PRICE_RATIO)
		if price <= 0:
			continue
		listings[item_id] = {"count": inv[item_id], "price": price}
	return listings

## Returns the item ID of the best affordable upgrade for the given slot ("weapon" or "armor"),
## or "" if no upgrade is available.
static func get_best_upgrade(slot: String, equipment: Node, inventory: Node) -> String:
	var equip_dict: Dictionary = equipment.get_equipment()
	var current_id: String = equip_dict.get(slot, "")
	var current_item := ItemDatabase.get_item(current_id)
	var gold: int = inventory.gold

	var bonus_key: String = "atk_bonus" if slot == "weapon" else "def_bonus"
	var current_bonus: int = current_item.get(bonus_key, 0)
	var item_type: String = slot  # "weapon" or "armor"

	var best_id: String = ""
	var best_bonus: int = current_bonus

	for item_id in ItemDatabase.ITEMS:
		var item: Dictionary = ItemDatabase.ITEMS[item_id]
		if item.get("type", "") != item_type:
			continue
		var item_bonus: int = item.get(bonus_key, 0)
		var cost: int = item.get("value", 0)
		if item_bonus > best_bonus and cost <= gold and item_id != current_id:
			best_bonus = item_bonus
			best_id = item_id

	return best_id

## Returns the item ID of the first material item in inventory, or "".
static func get_first_material(inventory: Node) -> String:
	var inv: Dictionary = inventory.get_items()
	for item_id in inv:
		var item := ItemDatabase.get_item(item_id)
		if item.get("type", "") == "material":
			return item_id
	return ""
