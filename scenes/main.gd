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

	var npc_info_panel := $UILayer/NpcInfoPanel
	if player and npc_info_panel:
		player.npc_info_panel = npc_info_panel

	var proficiency_panel := $UILayer/ProficiencyPanel
	if player and proficiency_panel:
		proficiency_panel.set_player(player)

	var vend_setup_panel := $UILayer/VendSetupPanel
	if player and vend_setup_panel:
		vend_setup_panel.set_player(player)
		player.vend_setup_panel = vend_setup_panel

	# Wire player ref to UI panels
	var player_hud := $UILayer/PlayerHUD
	if player and player_hud:
		player_hud.set_player(player)
	if player and inventory_panel:
		inventory_panel.set_player(player)
	if player and status_panel:
		status_panel.set_player(player)
	if player and shop_panel:
		shop_panel.set_player(player)
	if player and skill_hotbar:
		skill_hotbar.set_player(player)
	if player and skill_panel:
		skill_panel.set_player(player)

	var chat_log := $UILayer/ChatLog
	if player and chat_log:
		chat_log.set_player(player)

	var panel_toggles := $UILayer/PanelToggles
	if panel_toggles:
		panel_toggles.status_panel = status_panel
		panel_toggles.skill_panel = skill_panel
		panel_toggles.proficiency_panel = proficiency_panel
		panel_toggles.chat_input = chat_input
		panel_toggles.world_map_panel = $UILayer/WorldMapPanel

