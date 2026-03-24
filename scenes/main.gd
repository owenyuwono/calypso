extends Node3D
## Main scene — wires up UI panel references to the player, spawns the merchant NPC, and boots ZoneManager.

var _fps_label: Label
var interior_manager: InteriorManager

func _ready() -> void:
	_setup_fps_counter()

	# Day/night lighting cycle — persists across zone transitions
	var DayNightCycle: GDScript = preload("res://scripts/world/day_night_cycle.gd")
	var day_night: Node3D = DayNightCycle.new()
	day_night.name = "DayNightCycle"
	add_child(day_night)

	var player := $Player
	var shop_panel := $UILayer/ShopPanel
	var skill_hotbar := $UILayer/SkillHotbar
	var game_menu := $UILayer/GameMenu

	if player and shop_panel:
		player.shop_panel = shop_panel
	if player and skill_hotbar:
		player.skill_hotbar = skill_hotbar

	var npc_info_panel := $UILayer/NpcInfoPanel
	if player and npc_info_panel:
		player.npc_info_panel = npc_info_panel

	# Wire GameMenu — it creates and owns all panel builders
	if player and game_menu:
		game_menu.set_player(player)
		player.game_menu = game_menu

	var dialogue_panel: PanelContainer = PanelContainer.new()
	dialogue_panel.set_script(preload("res://scenes/ui/dialogue_panel.gd"))
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.visible = false
	$UILayer.add_child(dialogue_panel)
	if player:
		dialogue_panel.set_player(player)
		dialogue_panel.set_shop_panel(shop_panel)
		dialogue_panel.set_hud_elements([
			$UILayer/PlayerHUD,
			$UILayer/Minimap,
		])
		player.dialogue_panel = dialogue_panel
	dialogue_panel.trade_requested.connect(func(npc_node: Node) -> void:
		if npc_node and is_instance_valid(npc_node):
			shop_panel.open_shop(npc_node)
	)

	var crafting_panel := $UILayer/CraftingPanel
	if player and crafting_panel:
		crafting_panel.set_player(player)
		player.crafting_panel = crafting_panel

	# Wire player ref to remaining UI panels
	var player_hud := $UILayer/PlayerHUD
	if player and player_hud:
		player_hud.set_player(player)
	if player and shop_panel:
		shop_panel.set_player(player)
	if player and skill_hotbar:
		skill_hotbar.set_player(player)

	# Boot ZoneManager first — it creates the LoadingScreen we share with InteriorManager.
	ZoneManager.setup($ZoneAnchor, player, self)

	# InteriorManager — handles enter/exit lifecycle for in-zone interior rooms.
	interior_manager = InteriorManager.new()
	interior_manager.name = "InteriorManager"
	add_child(interior_manager)
	interior_manager.setup(player, $ZoneAnchor, ZoneManager.get_loading_screen())
	player.interior_manager = interior_manager

	# Spawn merchant once the first zone's navmesh is ready
	ZoneManager.zone_load_completed.connect(_on_first_zone_ready, CONNECT_ONE_SHOT)

	ZoneManager.load_zone("city", Vector3(8, 1, 3))

func _on_first_zone_ready(zone_id: String) -> void:
	_spawn_merchant()
	_assign_npc_nav_map()
	_evaluate_npc_zones(zone_id)

func _assign_npc_nav_map() -> void:
	var loaded_zone: Node3D = ZoneManager.get_loaded_zone()
	if not loaded_zone:
		return
	var nav_region: NavigationRegion3D = loaded_zone.get_node_or_null("NavigationRegion3D")
	if not nav_region:
		return
	var map_rid: RID = nav_region.get_navigation_map()
	for npc in $NPCs.get_children():
		var agent: NavigationAgent3D = npc.get_node_or_null("NavigationAgent3D")
		if agent:
			agent.set_navigation_map(map_rid)

func _evaluate_npc_zones(current_zone_id: String) -> void:
	for npc in $NPCs.get_children():
		if npc.has_method("_on_zone_changed"):
			npc._on_zone_changed("", current_zone_id)

func _spawn_merchant() -> void:
	var npc_scene: PackedScene = preload("res://scenes/npcs/npc_base.tscn")
	var npc: Node3D = npc_scene.instantiate()
	npc.npc_id = "celine"
	npc.npc_name = "Celine"
	npc.npc_color = Color(0.5, 0.6, 0.45)
	npc.model_path = "res://assets/models/characters/Barbarian.glb"
	npc.model_scale = 0.7
	npc.trait_profile = "merchant"
	$NPCs.add_child(npc)
	npc.global_position = Vector3(5, 1, 5)

	npc.initialize_from_loadout({
		"default_goal": "idle",
		"items": {
			"healing_potion": 20,
			"bandage": 15,
		},
		"gold": 500,
	})

func _setup_fps_counter() -> void:
	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.add_theme_color_override("font_color", Color(1, 1, 0.3))
	_fps_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_fps_label.add_theme_constant_override("shadow_offset_x", 1)
	_fps_label.add_theme_constant_override("shadow_offset_y", 1)
	_fps_label.position = Vector2(10, 10)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UILayer.add_child(_fps_label)

func _process(delta: float) -> void:
	if _fps_label:
		var fps: int = Engine.get_frames_per_second()
		var tris: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		var draws: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		var objs: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		var phys_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		var script_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_fps_label.text = "FPS: %d | Tris: %s | Draw: %d | Obj: %d\nPhysics: %.1fms | Script: %.1fms" % [fps, _format_number(tris), draws, objs, phys_ms, script_ms]

static func _format_number(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 1000:
		return "%.1fK" % (n / 1000.0)
	return str(n)
