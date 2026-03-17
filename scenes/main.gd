extends Node3D
## Main scene — wires up UI panel references to the player.

var _fps_label: Label

func _ready() -> void:
	_setup_fps_counter()

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
		panel_toggles.inventory_panel = inventory_panel
		panel_toggles.skill_panel = skill_panel
		panel_toggles.proficiency_panel = proficiency_panel
		panel_toggles.chat_input = chat_input
		panel_toggles.world_map_panel = $UILayer/WorldMapPanel

func _setup_fps_counter() -> void:
	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.add_theme_color_override("font_color", Color(1, 1, 0.3))
	_fps_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_fps_label.add_theme_constant_override("shadow_offset_x", 1)
	_fps_label.add_theme_constant_override("shadow_offset_y", 1)
	_fps_label.position = Vector2(10, 10)
	$UILayer.add_child(_fps_label)

func _process(_delta: float) -> void:
	if _fps_label:
		var fps: int = Engine.get_frames_per_second()
		var tris: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		_fps_label.text = "FPS: %d | Tris: %s" % [fps, _format_number(tris)]

static func _format_number(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 1000:
		return "%.1fK" % (n / 1000.0)
	return str(n)

