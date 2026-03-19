extends Node3D
## Main scene — wires up UI panel references to the player, spawns NPCs, and boots ZoneManager.

const NpcScene: PackedScene = preload("res://scenes/npcs/npc_base.tscn")

const GENERATED_NPC_COUNT: int = 25

# Maps NpcGenerator archetype IDs to NpcTraits profile strings.
const ARCHETYPE_TO_PROFILE: Dictionary = {
	"warrior":  "bold_warrior",
	"mage":     "cautious_mage",
	"rogue":    "sly_rogue",
	"ranger":   "stoic_knight",
	"merchant": "merchant",
}

# Character model paths by model name token.
const MODEL_PATHS: Dictionary = {
	"Knight":    "res://assets/models/characters/Knight.glb",
	"Barbarian": "res://assets/models/characters/Barbarian.glb",
	"Mage":      "res://assets/models/characters/Mage.glb",
	"Rogue":     "res://assets/models/characters/Rogue.glb",
}

# Distinct npc_color per archetype so NPCs are visually distinguishable in bulk.
const ARCHETYPE_COLORS: Dictionary = {
	"warrior":  Color(0.2, 0.3, 0.7, 1.0),
	"mage":     Color(0.5, 0.1, 0.6, 1.0),
	"rogue":    Color(0.1, 0.5, 0.4, 1.0),
	"ranger":   Color(0.2, 0.5, 0.2, 1.0),
	"merchant": Color(0.7, 0.5, 0.1, 1.0),
}

var _fps_label: Label

func _ready() -> void:
	_setup_fps_counter()

	# Instantiate ConversationManager — NPCBehavior/NPCBrain find it via group "conversation_manager"
	var conversation_manager: Node = ConversationManager.new()
	conversation_manager.name = "ConversationManager"
	add_child(conversation_manager)

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

	# Boot ZoneManager — loads first zone and bakes navmesh
	ZoneManager.setup($ZoneAnchor, player, self)

	# Spawn NPCs + apply loadouts once the first zone's navmesh is ready
	# (matches original game_world.gd flow where NPCs spawned inside _on_navmesh_baked)
	ZoneManager.zone_load_completed.connect(_on_first_zone_ready, CONNECT_ONE_SHOT)

	ZoneManager.load_zone("city", Vector3(8, 1, 3))

func _on_first_zone_ready(zone_id: String) -> void:
	_spawn_generated_npcs()
	_setup_adventurer_npcs()
	# Assign nav map to all NPCs so their NavigationAgent3D uses the zone's navmesh
	# (NPCs are under Main/NPCs, not under the zone's NavigationRegion3D)
	_assign_npc_nav_map()
	# NPCs missed the initial zone_changed signal (they didn't exist yet).
	# Evaluate zone status now so out-of-zone NPCs go dormant immediately.
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

func _setup_adventurer_npcs() -> void:
	for npc_id in NpcLoadouts.LOADOUTS:
		var loadout: Dictionary = NpcLoadouts.LOADOUTS[npc_id]
		var npc_name: String = npc_id.capitalize()
		var npc: Node3D = $NPCs.get_node_or_null(npc_name)
		if not npc:
			continue

		npc.trait_profile = loadout["trait_profile"]

		var inventory: Node = npc.get_node("InventoryComponent")
		for item_id in loadout["items"]:
			inventory.add_item(item_id, loadout["items"][item_id])

		var equipment: Node = npc.get_node("EquipmentComponent")
		for item_id in loadout["equip"]:
			equipment.equip(item_id)

		var gold: int = loadout["gold"]
		if gold != -1:
			inventory.set_gold_amount(gold)

		var brain: Node = npc.get_node_or_null("NPCBrain")
		if brain:
			brain.set_use_llm(false)
			brain.set_use_llm_chat(true)

		var goal: String = loadout["default_goal"]
		var behavior: Node = npc.get_node_or_null("NPCBehavior")
		if behavior:
			behavior.default_goal = goal
		npc.set_goal(goal)

		# Re-init proficiencies + skills (trait_profile was empty during _ready)
		npc.late_init_skills()

func _spawn_generated_npcs() -> void:
	var loadouts: Array = NpcGenerator.generate_npcs(GENERATED_NPC_COUNT)
	for loadout in loadouts:
		_spawn_generated_npc(loadout)

func _spawn_generated_npc(loadout: Dictionary) -> void:
	var npc_name: String = loadout.get("name", "Adventurer")
	var npc_id: String = "gen_" + npc_name.to_lower()
	var archetype: String = loadout.get("archetype", "warrior")
	var model_token: String = loadout.get("model", "Knight")

	var npc: CharacterBody3D = NpcScene.instantiate()
	# Set export vars before add_child so _ready() uses them for visuals/components.
	# trait_profile is intentionally left empty here (as with hardcoded NPCs) so _ready()
	# does not pre-equip a weapon — initialize_from_loadout applies the real loadout after.
	npc.npc_id = npc_id
	npc.npc_name = npc_name
	npc.model_path = MODEL_PATHS.get(model_token, "res://assets/models/characters/Knight.glb")
	npc.model_scale = 0.7
	npc.npc_color = ARCHETYPE_COLORS.get(archetype, Color(0.5, 0.5, 0.5, 1.0))
	npc.starting_goal = loadout.get("default_goal", "idle")
	npc.personality = ""

	$NPCs.add_child(npc)
	# Set trait_profile after _ready() so npc_behavior reads it correctly at runtime.
	npc.trait_profile = ARCHETYPE_TO_PROFILE.get(archetype, "bold_warrior")
	npc.global_position = _pick_generated_npc_spawn_pos(loadout.get("default_goal", "idle"))

	npc.initialize_from_loadout(loadout)

	var brain: Node = npc.get_node_or_null("NPCBrain")
	if brain:
		brain.set_use_llm(true)
		brain.set_use_llm_chat(true)

func _pick_generated_npc_spawn_pos(goal: String) -> Vector3:
	# Merchants stay in the city. Others split 50/50 between city and east field.
	if goal == "vend":
		var x: float = randf_range(-60.0, 60.0)
		var z: float = randf_range(-40.0, 40.0)
		return Vector3(x, 1.0, z)
	var roll: float = randf()
	if roll < 0.5:
		# City
		var x: float = randf_range(-60.0, 60.0)
		var z: float = randf_range(-40.0, 40.0)
		return Vector3(x, 1.0, z)
	else:
		# East field
		var x: float = randf_range(80.0, 140.0)
		var z: float = randf_range(-30.0, 30.0)
		return Vector3(x, 1.0, z)

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
	NpcTradeHelper.tick_vendor_cache(delta)
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
