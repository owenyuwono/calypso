extends Node3D
## Main scene — wires up UI panel references to the player.

func _ready() -> void:
	var player := $Player
	var shop_panel := $UILayer/ShopPanel
	var inventory_panel := $UILayer/InventoryPanel
	var status_panel := $UILayer/StatusPanel
	var chat_input := $UILayer/ChatInput
	var skill_hotbar := $UILayer/SkillHotbar
	var skill_panel := $UILayer/SkillPanel

	if player and shop_panel:
		player.shop_panel = shop_panel
	if player and inventory_panel:
		player.inventory_panel = inventory_panel
	if player and status_panel:
		player.status_panel = status_panel
	if player and chat_input:
		player.chat_input = chat_input
		chat_input.message_sent.connect(player.show_chat)
	if player and skill_hotbar:
		player.skill_hotbar = skill_hotbar
	if player and skill_panel:
		player.skill_panel = skill_panel

