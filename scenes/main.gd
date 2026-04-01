extends Node3D
## Main scene — wires up UI, sets up player, and boots ZoneManager.

var _fps_label: Label

func _ready() -> void:
	_setup_fps_counter()

	# Day/night lighting cycle — persists across zone transitions
	var DayNightCycle: GDScript = preload("res://scripts/world/day_night_cycle.gd")
	var day_night: Node3D = DayNightCycle.new()
	day_night.name = "DayNightCycle"
	add_child(day_night)

	var player := $Player
	var game_menu := $UILayer/GameMenu

	# Wire GameMenu — it creates and owns all panel builders
	if player and game_menu:
		game_menu.set_player(player)
		player.game_menu = game_menu

	# Wire player ref to remaining UI panels
	var player_hud := $UILayer/PlayerHUD
	if player and player_hud:
		player_hud.set_player(player)

	# Boot ZoneManager — creates the LoadingScreen used during transitions
	ZoneManager.setup($ZoneAnchor, player, self)

	ZoneManager.load_zone("zone_suburb", Vector3.ZERO)

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

func _process(_delta: float) -> void:
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
