extends Control
## Player inventory panel toggled with Tab.
## Layout: drag handle (full width), attack type + gold row (full width),
## then side-by-side: EQUIPMENT section (left) | ITEMS section (right).

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const ModelHelper = preload("res://scripts/utils/model_helper.gd")
const LootHelper = preload("res://scripts/utils/loot_helper.gd")

const GRID_COLUMNS := 5
const MIN_SLOTS := 35
const CELL_SIZE := 64
const EQUIP_CELL_SIZE := 68

const LEFT_EQUIP: Array = ["head", "torso", "gloves", "feet"]
const RIGHT_EQUIP: Array = ["back", "legs", "main_hand", "off_hand"]

const SLOT_LABELS: Dictionary = {
	"head": "Head", "torso": "Torso", "main_hand": "Main", "off_hand": "Off",
	"gloves": "Gloves", "legs": "Legs", "feet": "Feet", "back": "Back",
}

const SLOT_ICON_DIR := "res://assets/textures/ui/equip_slots/"
var _slot_icons: Dictionary = {}  # slot_name -> Texture2D

const TYPE_ORDER := {"weapon": 0, "armor": 1, "consumable": 2, "material": 3}
const TYPE_COLORS := {
	"consumable": Color(0.18, 0.4, 0.18),
	"weapon":     Color(0.35, 0.32, 0.25),
	"armor":      Color(0.2, 0.25, 0.38),
	"material":   Color(0.4, 0.32, 0.2),
}

const EQUIP_SLOT_COLORS: Dictionary = {
	"main_hand": Color(0.35, 0.3, 0.2),
	"off_hand":  Color(0.2, 0.25, 0.35),
}
const EQUIP_SLOT_COLOR_DEFAULT := Color(0.22, 0.2, 0.28)

const WEAPON_COLORS: Dictionary = {
	"sword":  Color(0.9, 0.85, 0.3),
	"axe":    Color(0.8, 0.4, 0.2),
	"mace":   Color(0.6, 0.6, 0.7),
	"dagger": Color(0.4, 0.8, 0.4),
	"staff":  Color(0.5, 0.4, 0.9),
}

const STAT_ICON_DIR := "res://assets/textures/ui/stats/"
const STAT_ICON_MAP: Dictionary = {
	"ATK":   "stat_atk.png",
	"DEF":   "stat_def.png",
	"Heal":  "stat_hp.png",
	"Value": "gold_coin.png",
}

var _panel: PanelContainer
var _left_equip_vbox: VBoxContainer
var _right_equip_vbox: VBoxContainer
var _grid: GridContainer
var _gold_label: Label
var _gold_icon: TextureRect
var _tooltip: PanelContainer
var _tooltip_label: Label
var _is_open: bool = false
var _preview_model_root: Node3D
var _preview_viewport: SubViewport

var _desc_panel: PanelContainer
var _desc_vbox: VBoxContainer
var _context_menu: PanelContainer
var _context_vbox: VBoxContainer
var _context_item_id: String = ""
var _context_slot_name: String = ""

var _player: Node
var _inventory: Node
var _equipment: Node
var _combat: Node
var _stats: Node

var _cursor_idx: int = 0
var _cursor_cells: Array = []      # all navigable cells (equip + inventory)
var _cursor_item_ids: Array = []   # item_id per cell ("" for empty)
var _cursor_slot_names: Array = [] # slot_name for equip cells ("" for inventory)
var _equip_cell_count: int = 0     # number of equip cells at start of arrays
var _action_menu_open: bool = false
var _action_idx: int = 0
var _action_buttons: Array = []
var _cursor_rect: Panel

func _ready() -> void:
	visible = false
	_load_slot_icons()
	_build_ui()
	GameEvents.item_looted.connect(func(_a, _b, _c): _refresh())

func _load_slot_icons() -> void:
	for slot_name in SLOT_LABELS:
		var path: String = SLOT_ICON_DIR + slot_name + ".png"
		var tex: Texture2D = load(path) as Texture2D
		if tex:
			_slot_icons[slot_name] = tex

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := UIHelper.create_panel_style()
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(vbox)

	# Main body: items (left 2/3) | separator | equipment+mesh (right 1/3)
	var body_hbox := HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 10)
	body_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body_hbox)

	# --- Left column: item grid (2/3 width) ---
	var items_vbox := VBoxContainer.new()
	items_vbox.add_theme_constant_override("separation", 4)
	items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_vbox.size_flags_stretch_ratio = 2.0
	body_hbox.add_child(items_vbox)

	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_vbox.add_child(_grid)

	# Cursor highlight overlay — repositioned over the active cell each frame
	_cursor_rect = Panel.new()
	_cursor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_rect.z_index = 10
	_cursor_rect.visible = false
	var cursor_style := StyleBoxFlat.new()
	cursor_style.bg_color = Color(0, 0, 0, 0)
	cursor_style.border_width_left = 2
	cursor_style.border_width_right = 2
	cursor_style.border_width_top = 2
	cursor_style.border_width_bottom = 2
	cursor_style.border_color = Color(1.0, 0.85, 0.2, 1.0)
	cursor_style.corner_radius_top_left = 5
	cursor_style.corner_radius_top_right = 5
	cursor_style.corner_radius_bottom_left = 5
	cursor_style.corner_radius_bottom_right = 5
	_cursor_rect.add_theme_stylebox_override("panel", cursor_style)
	add_child(_cursor_rect)

	# --- Vertical separator ---
	var vsep := VSeparator.new()
	body_hbox.add_child(vsep)

	# --- Right column: equipment + mesh (1/3 width) ---
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 1.0
	body_hbox.add_child(right_vbox)

	# Equipment row: left slots | mesh preview | right slots
	var equip_hbox := HBoxContainer.new()
	equip_hbox.add_theme_constant_override("separation", 6)
	equip_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(equip_hbox)

	# Left equip VBox: head, torso, gloves, feet
	_left_equip_vbox = VBoxContainer.new()
	_left_equip_vbox.add_theme_constant_override("separation", 8)
	_left_equip_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	equip_hbox.add_child(_left_equip_vbox)

	# Center: player 3D mesh preview
	var viewport_container := SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.custom_minimum_size = Vector2(120, 200)
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equip_hbox.add_child(viewport_container)

	_preview_viewport = SubViewport.new()
	_preview_viewport.own_world_3d = true
	_preview_viewport.transparent_bg = true
	_preview_viewport.size = Vector2i(240, 400)
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport_container.add_child(_preview_viewport)

	var viewport_root := Node3D.new()
	_preview_viewport.add_child(viewport_root)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.5
	camera.position = Vector3(0, 0.8, 3)
	viewport_root.add_child(camera)
	camera.look_at(Vector3(0, 0.8, 0), Vector3.UP)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.0
	viewport_root.add_child(light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-30, 150, 0)
	fill_light.light_energy = 0.4
	viewport_root.add_child(fill_light)

	_preview_model_root = Node3D.new()
	viewport_root.add_child(_preview_model_root)

	# Right equip VBox: back, legs, main_hand, off_hand
	_right_equip_vbox = VBoxContainer.new()
	_right_equip_vbox.add_theme_constant_override("separation", 8)
	_right_equip_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	equip_hbox.add_child(_right_equip_vbox)

	# Gold row below equipment
	var gold_hbox := HBoxContainer.new()
	gold_hbox.add_theme_constant_override("separation", 4)
	gold_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_child(gold_hbox)

	_gold_icon = TextureRect.new()
	var gold_coin_tex: Texture2D = load("res://assets/textures/ui/stats/gold_coin.png") as Texture2D
	_gold_icon.texture = gold_coin_tex
	_gold_icon.custom_minimum_size = Vector2(16, 16)
	_gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gold_icon.texture_filter = TEXTURE_FILTER_NEAREST
	_gold_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_hbox.add_child(_gold_icon)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 13)
	_gold_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	_gold_label.text = "0"
	gold_hbox.add_child(_gold_label)

	# Tooltip — child of root Control so it overlays everything
	_tooltip = PanelContainer.new()
	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.06, 0.05, 0.04, 0.96)
	tooltip_style.border_color = Color(0.55, 0.45, 0.25)
	tooltip_style.set_border_width_all(1)
	tooltip_style.set_corner_radius_all(3)
	tooltip_style.content_margin_left = 6
	tooltip_style.content_margin_right = 6
	tooltip_style.content_margin_top = 2
	tooltip_style.content_margin_bottom = 2
	_tooltip.add_theme_stylebox_override("panel", tooltip_style)
	_tooltip_label = Label.new()
	_tooltip_label.add_theme_font_size_override("font_size", 12)
	_tooltip_label.add_theme_color_override("font_color", Color.WHITE)
	_tooltip.add_child(_tooltip_label)
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tooltip)

	_build_desc_panel()
	_build_context_menu()

func _update_mesh_preview() -> void:
	if not _player or not _preview_model_root:
		return
	for child in _preview_model_root.get_children():
		child.queue_free()
	var visuals: Node = _player.get_node_or_null("EntityVisuals")
	if not visuals:
		return
	var mesh_path: String = visuals.get("_mesh_path")
	if mesh_path.is_empty():
		return
	# Load mesh only (no animations) for the preview — faster and avoids loading all anim FBX files
	var result: Dictionary = ModelHelper.instantiate_model(mesh_path, 1.0)
	var model: Node3D = result.get("model")
	if not model:
		return
	ModelHelper.apply_toon_to_model(model)
	_preview_model_root.add_child(model)
	var anim_player: AnimationPlayer = result.get("anim_player")
	if anim_player and anim_player.has_animation("Idle"):
		anim_player.play("Idle")

func _build_desc_panel() -> void:
	_desc_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.05, 0.97)
	style.border_color = Color(0.55, 0.45, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_desc_panel.add_theme_stylebox_override("panel", style)
	_desc_panel.custom_minimum_size = Vector2(280, 0)
	_desc_panel.visible = false
	_desc_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_desc_panel)

	_desc_vbox = VBoxContainer.new()
	_desc_vbox.add_theme_constant_override("separation", 4)
	_desc_panel.add_child(_desc_vbox)

func _build_context_menu() -> void:
	_context_menu = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.05, 0.97)
	style.border_color = Color(0.55, 0.45, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_context_menu.add_theme_stylebox_override("panel", style)
	_context_menu.visible = false
	_context_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_context_menu)

	_context_vbox = VBoxContainer.new()
	_context_vbox.add_theme_constant_override("separation", 2)
	_context_menu.add_child(_context_vbox)

func build_content(container: Control) -> void:
	if not _panel:
		_load_slot_icons()
		_build_ui()
	if _panel and _panel.get_parent():
		_panel.get_parent().remove_child(_panel)
	container.add_child(_panel)
	if _player:
		_refresh()

func refresh() -> void:
	_refresh()

func get_overlay_nodes() -> Array:
	var overlays: Array = []
	if _tooltip:
		overlays.append(_tooltip)
	if _desc_panel:
		overlays.append(_desc_panel)
	if _context_menu:
		overlays.append(_context_menu)
	return overlays


func set_player(p: Node) -> void:
	_player = p
	if _player:
		_inventory = _player.get_node_or_null("InventoryComponent")
		_equipment = _player.get_node_or_null("EquipmentComponent")
		_combat = _player.get_node_or_null("CombatComponent")
		_stats = _player.get_node_or_null("StatsComponent")
		_update_mesh_preview()


func toggle() -> void:
	_toggle()

func _toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	if _is_open:
		AudioManager.play_ui_sfx("ui_panel_open")
		_refresh()
	else:
		AudioManager.play_ui_sfx("ui_panel_close")
		_tooltip.visible = false
		_hide_desc()
		_hide_context_menu()
		if _cursor_rect:
			_cursor_rect.visible = false

func is_open() -> bool:
	return _is_open

func _refresh() -> void:
	_hide_desc()
	_hide_context_menu()

	if not _player:
		return

	if not _inventory or not _equipment:
		return

	# Gold
	var gold: int = _inventory.get_gold_amount()
	_gold_label.text = "%d" % gold

	# Rebuild left equipment column (head, torso, gloves, feet)
	for child in _left_equip_vbox.get_children():
		child.queue_free()
	for slot_name in LEFT_EQUIP:
		var item_id: String = _equipment.get_slot(slot_name)
		if item_id.is_empty():
			_left_equip_vbox.add_child(_build_equip_cell_empty(slot_name, EQUIP_CELL_SIZE))
		else:
			_left_equip_vbox.add_child(_build_equip_cell_filled(slot_name, item_id, EQUIP_CELL_SIZE))

	# Rebuild right equipment column (back, legs, main_hand, off_hand)
	for child in _right_equip_vbox.get_children():
		child.queue_free()
	for slot_name in RIGHT_EQUIP:
		var item_id: String = _equipment.get_slot(slot_name)
		if item_id.is_empty():
			_right_equip_vbox.add_child(_build_equip_cell_empty(slot_name, EQUIP_CELL_SIZE))
		else:
			_right_equip_vbox.add_child(_build_equip_cell_filled(slot_name, item_id, EQUIP_CELL_SIZE))

	# Rebuild inventory grid
	for child in _grid.get_children():
		child.queue_free()

	var inv: Dictionary = _inventory.get_items()
	var sorted_items: Array = _sort_items(inv)

	var slot_count: int = max(MIN_SLOTS, sorted_items.size())
	for i in range(slot_count):
		if i < sorted_items.size():
			var entry: Array = sorted_items[i]
			var item_id: String = entry[0]
			var count: int = entry[1]
			_grid.add_child(_build_cell(item_id, count))
		else:
			_grid.add_child(_build_empty_cell())

	# Rebuild cursor arrays: equipment cells first, then inventory grid
	_cursor_cells.clear()
	_cursor_item_ids.clear()
	_cursor_slot_names.clear()

	# Equipment cells (left column then right column)
	for slot_name in LEFT_EQUIP:
		var cell: Control = null
		var idx: int = LEFT_EQUIP.find(slot_name)
		if idx >= 0 and idx < _left_equip_vbox.get_child_count():
			cell = _left_equip_vbox.get_child(idx)
		if cell:
			_cursor_cells.append(cell)
			var eid: String = _equipment.get_slot(slot_name) if _equipment else ""
			_cursor_item_ids.append(eid)
			_cursor_slot_names.append(slot_name)
	for slot_name in RIGHT_EQUIP:
		var cell: Control = null
		var idx: int = RIGHT_EQUIP.find(slot_name)
		if idx >= 0 and idx < _right_equip_vbox.get_child_count():
			cell = _right_equip_vbox.get_child(idx)
		if cell:
			_cursor_cells.append(cell)
			var eid: String = _equipment.get_slot(slot_name) if _equipment else ""
			_cursor_item_ids.append(eid)
			_cursor_slot_names.append(slot_name)
	_equip_cell_count = _cursor_cells.size()

	# Inventory grid cells
	for cell in _grid.get_children():
		_cursor_cells.append(cell)
		_cursor_slot_names.append("")
	for i in range(sorted_items.size()):
		_cursor_item_ids.append(sorted_items[i][0])
	# Pad item_ids for empty inventory cells
	while _cursor_item_ids.size() < _cursor_cells.size():
		_cursor_item_ids.append("")
	_cursor_idx = clampi(_cursor_idx, 0, max(0, _cursor_cells.size() - 1))
	# Defer highlight so grid has processed layout and global_position is valid
	call_deferred("_update_cursor_highlight")

func _sort_items(inv: Dictionary) -> Array:
	var entries: Array = []
	for item_id in inv:
		var count: int = inv[item_id]
		var item_data: Dictionary = ItemDatabase.get_item(item_id)
		var type_str: String = item_data.get("type", "")
		var type_priority: int = TYPE_ORDER.get(type_str, 99)
		var item_name: String = item_data.get("name", item_id)
		entries.append([item_id, count, type_priority, item_name])
	entries.sort_custom(func(a: Array, b: Array) -> bool:
		if a[2] != b[2]:
			return a[2] < b[2]
		return a[3] < b[3]
	)
	var result: Array = []
	for entry in entries:
		result.append([entry[0], entry[1]])
	return result

func _build_equip_cell_empty(slot_name: String, cell_size: int) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(cell_size, cell_size)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.07)
	style.border_color = Color(0.25, 0.22, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	cell.add_theme_stylebox_override("panel", style)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.add_child(center)

	# Slot icon (dimmed, centered)
	var icon_tex: Texture2D = _slot_icons.get(slot_name)
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(cell_size - 12, cell_size - 12)
		icon.modulate = Color(1, 1, 1, 0.3)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(icon)

	return cell

func _build_equip_cell_filled(slot_name: String, item_id: String, cell_size: int) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(cell_size, cell_size)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var slot_color: Color = EQUIP_SLOT_COLORS.get(slot_name, EQUIP_SLOT_COLOR_DEFAULT)
	var style := StyleBoxFlat.new()
	style.bg_color = slot_color
	style.border_color = Color(0.6, 0.5, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	cell.add_theme_stylebox_override("panel", style)

	var item_data: Dictionary = ItemDatabase.get_item(item_id)
	var item_name: String = item_data.get("name", item_id)

	# Slot icon at top-left (small, semi-transparent)
	var icon_tex: Texture2D = _slot_icons.get(slot_name)
	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(16, 16)
		icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
		icon.offset_left = 2
		icon.offset_top = 2
		icon.offset_right = 18
		icon.offset_bottom = 18
		icon.modulate = Color(1, 1, 1, 0.5)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)

	# 2-char abbreviation of item name, centered
	var abbrev: String = item_name.substr(0, 2) if item_name.length() >= 2 else item_name
	var letter := Label.new()
	letter.text = abbrev
	letter.add_theme_font_size_override("font_size", 16)
	letter.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.set_anchors_preset(Control.PRESET_FULL_RECT)
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(letter)

	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return cell

func _build_cell(item_id: String, count: int) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var item_data: Dictionary = ItemDatabase.get_item(item_id)
	var type_str: String = item_data.get("type", "")
	var type_color: Color = TYPE_COLORS.get(type_str, Color(0.22, 0.2, 0.18))

	var style := StyleBoxFlat.new()
	style.bg_color = type_color
	style.border_color = Color(0.4, 0.35, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	cell.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	cell.add_child(margin)

	var item_name: String = item_data.get("name", "?")
	var abbrev: String = item_name.substr(0, 2) if item_name.length() >= 2 else item_name
	var letter := Label.new()
	letter.text = abbrev
	letter.add_theme_font_size_override("font_size", 18)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	letter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	letter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(letter)

	if count > 1:
		var badge := PanelContainer.new()
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.offset_left = -28
		badge.offset_top = -18
		badge.offset_right = -2
		badge.offset_bottom = -2
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(0.0, 0.0, 0.0, 0.7)
		badge_style.set_corner_radius_all(3)
		badge_style.content_margin_left = 3
		badge_style.content_margin_right = 3
		badge_style.content_margin_top = 1
		badge_style.content_margin_bottom = 1
		badge.add_theme_stylebox_override("panel", badge_style)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var count_label := Label.new()
		count_label.text = "x%d" % count
		count_label.add_theme_font_size_override("font_size", 10)
		count_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
		badge.add_child(count_label)
		cell.add_child(badge)

	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return cell

func _build_empty_cell() -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.07)
	style.border_color = Color(0.22, 0.2, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	cell.add_theme_stylebox_override("panel", style)
	return cell

func _format_tooltip(item_id: String) -> String:
	var item: Dictionary = ItemDatabase.get_item(item_id)
	var name: String = item.get("name", item_id)
	var type: String = item.get("type", "")
	var extra: String = ""
	if item.has("atk_bonus"):
		extra = " (ATK +%d)" % item["atk_bonus"]
	elif item.has("def_bonus"):
		extra = " (DEF +%d)" % item["def_bonus"]
	elif item.has("heal"):
		extra = " (Heal %d)" % item["heal"]
	elif type == "material":
		extra = " (Material)"
	return name + extra


func _show_desc(item_id: String) -> void:
	_hide_context_menu()
	for child in _desc_vbox.get_children():
		child.queue_free()

	var item: Dictionary = ItemDatabase.get_item(item_id)
	if item.is_empty():
		_desc_panel.visible = false
		return

	var type_str: String = item.get("type", "")
	var type_color: Color = TYPE_COLORS.get(type_str, Color(0.5, 0.5, 0.5))

	# Item name (large, colored)
	var name_label := Label.new()
	name_label.text = item.get("name", item_id)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", type_color.lightened(0.4))
	_desc_vbox.add_child(name_label)

	# Type label
	var type_label := Label.new()
	type_label.text = type_str.capitalize()
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	_desc_vbox.add_child(type_label)

	_desc_vbox.add_child(HSeparator.new())

	# Stats
	if item.has("atk_bonus"):
		_add_desc_stat("ATK", "+%d" % item["atk_bonus"], Color(0.9, 0.5, 0.3))
	if item.has("def_bonus"):
		_add_desc_stat("DEF", "+%d" % item["def_bonus"], Color(0.3, 0.6, 0.9))
	if item.has("heal"):
		_add_desc_stat("Heal", "%d HP" % item["heal"], Color(0.3, 0.8, 0.3))
	if item.has("value"):
		_add_desc_stat("Value", "%dg" % item["value"], Color(0.8, 0.7, 0.3))

	# Weapon type
	if item.has("weapon_type"):
		_add_desc_stat("Type", item["weapon_type"].capitalize(), WEAPON_COLORS.get(item["weapon_type"], Color.WHITE))

	# Proficiency requirement
	if item.has("required_skill") and item.has("required_level"):
		var req_text: String = "%s Lv. %d" % [item["required_skill"].capitalize(), item["required_level"]]
		_add_desc_stat("Requires", req_text, Color(0.7, 0.6, 0.4))

	# Attack speed (daggers)
	if item.has("attack_speed"):
		_add_desc_stat("Speed", "%.1f" % item["attack_speed"], Color(0.6, 0.8, 0.6))

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(_hide_desc)
	_desc_vbox.add_child(close_btn)

	# Position near center of panel
	_desc_panel.position = Vector2(60, 180)
	_desc_panel.visible = true

func _add_desc_stat(label_text: String, value_text: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_desc_vbox.add_child(row)

	var icon_file: String = STAT_ICON_MAP.get(label_text, "")
	if not icon_file.is_empty():
		var icon := TextureRect.new()
		icon.texture = load(STAT_ICON_DIR + icon_file) as Texture2D
		icon.custom_minimum_size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = TEXTURE_FILTER_NEAREST
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

	var lbl := Label.new()
	lbl.text = label_text + ":"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.5, 0.4))
	lbl.custom_minimum_size.x = 60
	row.add_child(lbl)
	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 12)
	val.add_theme_color_override("font_color", color)
	row.add_child(val)

func _hide_desc() -> void:
	_desc_panel.visible = false


func _hide_context_menu() -> void:
	_context_menu.visible = false
	_context_item_id = ""
	_context_slot_name = ""
	_action_menu_open = false
	_action_buttons.clear()

func _ctx_use() -> void:
	if not _context_item_id.is_empty():
		var item_data: Dictionary = ItemDatabase.get_item(_context_item_id)
		_use_item(_context_item_id, item_data)
	_hide_context_menu()

func _ctx_equip() -> void:
	if not _context_item_id.is_empty():
		var item_data: Dictionary = ItemDatabase.get_item(_context_item_id)
		var type_str: String = item_data.get("type", "")
		if type_str == "weapon":
			_equip_to_slot(_context_item_id, "main_hand")
		elif type_str == "armor":
			_equip_to_slot(_context_item_id, "off_hand")
	_hide_context_menu()

func _ctx_unequip() -> void:
	if not _context_slot_name.is_empty():
		_unequip(_context_slot_name)
	_hide_context_menu()

func _ctx_discard() -> void:
	if _context_item_id.is_empty() or not _inventory:
		_hide_context_menu()
		return
	if not _inventory.has_item(_context_item_id):
		_hide_context_menu()
		return
	var discard_id: String = _context_item_id
	_inventory.remove_item(discard_id)
	# Spawn loot drop at player position
	if _player:
		var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		LootHelper.spawn_drop(_player.global_position + offset, discard_id, 1, 0)
	_hide_context_menu()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return

	# --- Keyboard/Gamepad Navigation ---
	if event is InputEventKey and event.pressed and not event.echo:
		if _action_menu_open:
			_handle_action_menu_input(event as InputEventKey)
		else:
			_handle_grid_input(event as InputEventKey)
		get_viewport().set_input_as_handled()
		return


func _handle_grid_input(event: InputEventKey) -> void:
	var key: int = event.keycode
	var old_idx: int = _cursor_idx

	match key:
		KEY_A:
			if _cursor_idx > 0:
				_cursor_idx -= 1
		KEY_D:
			if _cursor_idx + 1 < _cursor_cells.size():
				_cursor_idx += 1
		KEY_W:
			if _cursor_idx >= _equip_cell_count:
				# In inventory grid — go up by GRID_COLUMNS, or jump to last equip cell
				var grid_idx: int = _cursor_idx - _equip_cell_count
				if grid_idx >= GRID_COLUMNS:
					_cursor_idx -= GRID_COLUMNS
				elif _equip_cell_count > 0:
					_cursor_idx = _equip_cell_count - 1
			elif _cursor_idx > 0:
				_cursor_idx -= 1
		KEY_S:
			if _cursor_idx >= _equip_cell_count:
				# In inventory grid — go down by GRID_COLUMNS
				if _cursor_idx + GRID_COLUMNS < _cursor_cells.size():
					_cursor_idx += GRID_COLUMNS
			elif _cursor_idx < _equip_cell_count - 1:
				_cursor_idx += 1
			else:
				# Last equip cell — jump to first inventory cell
				if _equip_cell_count < _cursor_cells.size():
					_cursor_idx = _equip_cell_count
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			var slot_name: String = _cursor_slot_names[_cursor_idx] if _cursor_idx < _cursor_slot_names.size() else ""
			var item_id: String = _cursor_item_ids[_cursor_idx] if _cursor_idx < _cursor_item_ids.size() else ""
			if not slot_name.is_empty() and not item_id.is_empty():
				_open_equip_action_menu(slot_name, item_id)
			elif not item_id.is_empty():
				_open_action_menu(item_id)
			return
		KEY_ESCAPE:
			_toggle()
			return
		_:
			return

	if _cursor_idx != old_idx:
		_update_cursor_highlight()

func _handle_action_menu_input(event: InputEventKey) -> void:
	var key: int = event.keycode

	match key:
		KEY_W:
			_action_idx = maxi(0, _action_idx - 1)
			_update_action_highlight()
		KEY_S:
			_action_idx = mini(_action_buttons.size() - 1, _action_idx + 1)
			_update_action_highlight()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _action_idx >= 0 and _action_idx < _action_buttons.size():
				_action_buttons[_action_idx].emit_signal("pressed")
		KEY_ESCAPE:
			_close_action_menu()

func _update_cursor_highlight() -> void:
	if not _cursor_rect:
		return
	if _cursor_idx < 0 or _cursor_idx >= _cursor_cells.size():
		_cursor_rect.visible = false
		_tooltip.visible = false
		return
	var cell: Control = _cursor_cells[_cursor_idx]
	_cursor_rect.visible = true
	_cursor_rect.global_position = cell.global_position
	_cursor_rect.size = cell.size
	var item_id: String = _cursor_item_ids[_cursor_idx] if _cursor_idx < _cursor_item_ids.size() else ""
	if not item_id.is_empty():
		_tooltip_label.text = _format_tooltip(item_id)
		_tooltip.position = cell.global_position - global_position + Vector2(0, -28)
		_tooltip.visible = true
	else:
		_tooltip.visible = false

func _open_action_menu(item_id: String) -> void:
	_hide_desc()
	_context_item_id = item_id
	_context_slot_name = ""

	for child in _context_vbox.get_children():
		child.queue_free()
	_action_buttons.clear()

	var item: Dictionary = ItemDatabase.get_item(item_id)
	var type_str: String = item.get("type", "")
	if type_str == "consumable" and item.has("heal"):
		_add_action_button("Use", _ctx_use)
	if type_str in ["weapon", "armor"]:
		_add_action_button("Equip", _ctx_equip)
	_add_action_button("Discard", _ctx_discard)
	_add_action_button("Cancel", _close_action_menu)

	# Position next to the selected cell
	if _cursor_idx >= 0 and _cursor_idx < _cursor_cells.size():
		var cell: Control = _cursor_cells[_cursor_idx]
		var cell_pos: Vector2 = cell.global_position - global_position
		_context_menu.position = Vector2(cell_pos.x + CELL_SIZE + 4, cell_pos.y)

	_context_menu.visible = true
	_action_menu_open = true
	_action_idx = 0
	_update_action_highlight()

func _open_equip_action_menu(slot_name: String, item_id: String) -> void:
	_hide_desc()
	_context_item_id = item_id
	_context_slot_name = slot_name

	for child in _context_vbox.get_children():
		child.queue_free()
	_action_buttons.clear()

	_add_action_button("Unequip", _ctx_unequip)
	_add_action_button("Cancel", _close_action_menu)

	if _cursor_idx >= 0 and _cursor_idx < _cursor_cells.size():
		var cell: Control = _cursor_cells[_cursor_idx]
		var cell_pos: Vector2 = cell.global_position - global_position
		_context_menu.position = Vector2(cell_pos.x + EQUIP_CELL_SIZE + 4, cell_pos.y)

	_context_menu.visible = true
	_action_menu_open = true
	_action_idx = 0
	_update_action_highlight()

func _add_action_button(text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 12)
	btn.custom_minimum_size = Vector2(80, 26)
	btn.pressed.connect(callback)
	_context_vbox.add_child(btn)
	_action_buttons.append(btn)

func _update_action_highlight() -> void:
	for i in _action_buttons.size():
		var btn: Button = _action_buttons[i]
		if i == _action_idx:
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.2))
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_color_override("font_hover_color")

func _close_action_menu() -> void:
	_context_menu.visible = false
	_action_menu_open = false
	_action_buttons.clear()
	_context_item_id = ""
	_context_slot_name = ""

func _use_item(item_id: String, item_data: Dictionary) -> void:
	if not _inventory or not _inventory.has_item(item_id):
		return
	var heal_amount: int = item_data.get("heal", 0)
	if heal_amount > 0 and _combat:
		_combat.heal(heal_amount)
	_inventory.remove_item(item_id)
	_refresh()

func _equip_to_slot(item_id: String, _slot_hint: String) -> void:
	if not _equipment:
		return
	if _equipment.equip(item_id):
		AudioManager.play_ui_sfx("ui_item_equip")
		_refresh()

func _unequip(slot_name: String) -> void:
	if not _equipment:
		return
	if _equipment.unequip(slot_name):
		_refresh()
