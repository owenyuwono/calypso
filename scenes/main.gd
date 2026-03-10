extends Node3D
## Main scene — wires up UI panel references to the player.

func _ready() -> void:
	var player := $Player
	var shop_panel := $UILayer/ShopPanel
	var inventory_panel := $UILayer/InventoryPanel

	if player and shop_panel:
		player.shop_panel = shop_panel
	if player and inventory_panel:
		player.inventory_panel = inventory_panel

