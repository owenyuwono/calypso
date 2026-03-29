extends Control
## Player inventory panel toggled with Tab.
## Layout: drag handle (full width), attack type + gold row (full width),
## then side-by-side: EQUIPMENT section (left) | ITEMS section (right).

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const ModelHelper = preload("res://scripts/utils/model_helper.gd")
const LootHelper = preload("res://scripts/utils/loot_helper.gd")

const GRID_COLUMNS := 5
const MIN_SLOTS := 20
const CELL_SIZE := 96
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
var _preview_model_root: Node3D
var _preview_viewport: SubViewport

var _detail_container: VBoxContainer
var _context_menu: PanelContainer
var _context_vbox: VBoxContainer
var _context_item_id: String = ""
var _context_slot_name: String = ""

var _player: Node
var _inventory: Node
var _equipment: Node
var _combat: Node
var _stats: Node

var _nav_zone: String = "inventory"  # "inventory" or "equipment"
var _grid_idx: int = 0               # index into inventory grid cells
var _equip_col: int = 0              # 0=left, 1=right
var _equip_row: int = 0              # 0..3
var _cursor_cells: Array = []        # inventory grid cells only
var _cursor_item_ids: Array = []     # item_id per inventory grid cell ("" for empty)
var _active: bool = false
var _action_menu_open: bool = false
var _action_idx: int = 0
var _action_buttons: Array = []
var _cursor_hand: TextureRect

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
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_vbox.add_child(_grid)

	# --- Item detail section below grid ---
	var detail_sep := HSeparator.new()
	detail_sep.add_theme_color_override("separator", Color(0.4, 0.35, 0.25, 0.5))
	items_vbox.add_child(detail_sep)

	_detail_container = VBoxContainer.new()
	_detail_container.add_theme_constant_override("separation", 4)
	_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items_vbox.add_child(_detail_container)

	# Cursor hand — hand icon that floats left of the active cell
	_cursor_hand = TextureRect.new()
	var cursor_tex: Texture2D = load("res://assets/textures/ui/dialogue/cursor_hand.png") as Texture2D
	if cursor_tex:
		_cursor_hand.texture = cursor_tex
	_cursor_hand.custom_minimum_size = Vector2(24, 24)
	_cursor_hand.size = Vector2(24, 24)
	_cursor_hand.visible = false
	_cursor_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_hand.z_index = 10
	add_child(_cursor_hand)

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
	var result: Dictionary = ModelHelper.instantiate_model(mesh_path, 1.0)
	var model: Node3D = result.get("model")
	if not model:
		return
	ModelHelper.apply_toon_to_model(model)
	_preview_model_root.add_child(model)
	var anim_player: AnimationPlayer = result.get("anim_player")
	if anim_player and anim_player.has_animation("Idle"):
		anim_player.play("Idle")
	# Show equipped weapon on preview model
	if _equipment and not _equipment.get_weapon().is_empty():
		var skeleton: Skeleton3D = ModelHelper.find_skeleton_3d(model)
		if skeleton:
			var bone_name: String = ""
			for candidate in ["RightHand", "Right_Hand", "right_hand", "Hand_R"]:
				if skeleton.find_bone(candidate) != -1:
					bone_name = candidate
					break
			if bone_name.is_empty():
				for i in skeleton.get_bone_count():
					var bname: String = skeleton.get_bone_name(i).to_lower()
					if "hand" in bname and "right" in bname:
						bone_name = skeleton.get_bone_name(i)
						break
			if not bone_name.is_empty():
				var attachment := BoneAttachment3D.new()
				attachment.bone_name = bone_name
				skeleton.add_child(attachment)
				attachment.add_child(ModelHelper.create_procedural_sword())

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

func set_active(active: bool) -> void:
	_active = active
	if not active:
		if _cursor_hand:
			_cursor_hand.visible = false
		if _tooltip:
			_tooltip.visible = false
		_hide_context_menu()
	else:
		_nav_zone = "inventory"
		_grid_idx = 0
		_equip_col = 0
		_equip_row = 0
		call_deferred("_update_cursor_highlight")

func refresh() -> void:
	_nav_zone = "inventory"
	_grid_idx = 0
	_equip_col = 0
	_equip_row = 0
	_refresh()

func get_overlay_nodes() -> Array:
	var overlays: Array = []
	if _cursor_hand:
		overlays.append(_cursor_hand)
	if _tooltip:
		overlays.append(_tooltip)
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
	var opening: bool = not visible
	visible = opening
	if opening:
		AudioManager.play_ui_sfx("ui_panel_open")
		_nav_zone = "inventory"
		_grid_idx = 0
		_equip_col = 0
		_equip_row = 0
		_refresh()
	else:
		AudioManager.play_ui_sfx("ui_panel_close")
		_tooltip.visible = false
		_clear_detail()
		_hide_context_menu()
		if _cursor_hand:
			_cursor_hand.visible = false

func is_open() -> bool:
	return _panel and _panel.is_visible_in_tree()

func _refresh() -> void:
	_clear_detail()
	_hide_context_menu()
	_update_mesh_preview()

	if not _player:
		return

	if not _inventory or not _equipment:
		return

	# Gold
	var gold: int = _inventory.get_gold_amount()
	_gold_label.text = "%d" % gold

	# Rebuild left equipment column (head, torso, gloves, feet)
	for child in _left_equip_vbox.get_children():
		_left_equip_vbox.remove_child(child)
		child.queue_free()
	for slot_name in LEFT_EQUIP:
		var item_id: String = _equipment.get_slot(slot_name)
		if item_id.is_empty():
			_left_equip_vbox.add_child(_build_equip_cell_empty(slot_name, EQUIP_CELL_SIZE))
		else:
			_left_equip_vbox.add_child(_build_equip_cell_filled(slot_name, item_id, EQUIP_CELL_SIZE))

	# Rebuild right equipment column (back, legs, main_hand, off_hand)
	for child in _right_equip_vbox.get_children():
		_right_equip_vbox.remove_child(child)
		child.queue_free()
	for slot_name in RIGHT_EQUIP:
		var item_id: String = _equipment.get_slot(slot_name)
		if item_id.is_empty():
			_right_equip_vbox.add_child(_build_equip_cell_empty(slot_name, EQUIP_CELL_SIZE))
		else:
			_right_equip_vbox.add_child(_build_equip_cell_filled(slot_name, item_id, EQUIP_CELL_SIZE))

	# Rebuild inventory grid
	for child in _grid.get_children():
		_grid.remove_child(child)
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

	# Rebuild inventory cursor arrays (inventory grid cells only)
	_cursor_cells.clear()
	_cursor_item_ids.clear()

	for cell in _grid.get_children():
		_cursor_cells.append(cell)
	for i in range(sorted_items.size()):
		_cursor_item_ids.append(sorted_items[i][0])
	# Pad item_ids for empty inventory cells
	while _cursor_item_ids.size() < _cursor_cells.size():
		_cursor_item_ids.append("")

	_grid_idx = clampi(_grid_idx, 0, max(0, _cursor_cells.size() - 1))
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
	cell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

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

	# Try icon texture, fall back to 2-letter abbreviation
	var icon_path: String = item_data.get("icon", "")
	var icon_tex: Texture2D = null
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon_tex = load(icon_path) as Texture2D

	if icon_tex:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.texture_filter = TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(icon)
	else:
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
	cell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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


func _update_detail(item_id: String) -> void:
	if not _detail_container:
		return
	for child in _detail_container.get_children():
		_detail_container.remove_child(child)
		child.queue_free()

	if item_id.is_empty():
		return

	var item: Dictionary = ItemDatabase.get_item(item_id)
	if item.is_empty():
		return

	var type_str: String = item.get("type", "")
	var type_color: Color = TYPE_COLORS.get(type_str, Color(0.5, 0.5, 0.5))

	# Header row: name + type
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_detail_container.add_child(header)

	var name_label := Label.new()
	name_label.text = item.get("name", item_id)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", type_color.lightened(0.4))
	header.add_child(name_label)

	var type_label := Label.new()
	type_label.text = type_str.capitalize()
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	type_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(type_label)

	# Description
	var desc_text: String = item.get("description", "")
	if not desc_text.is_empty():
		var desc_label := Label.new()
		desc_label.text = desc_text
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.5))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_container.add_child(desc_label)

	# Stats row
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 16)
	_detail_container.add_child(stats_row)

	if item.has("atk_bonus"):
		_add_detail_stat(stats_row, "ATK", "+%d" % item["atk_bonus"], Color(0.9, 0.5, 0.3))
	if item.has("def_bonus"):
		_add_detail_stat(stats_row, "DEF", "+%d" % item["def_bonus"], Color(0.3, 0.6, 0.9))
	if item.has("matk_bonus"):
		_add_detail_stat(stats_row, "MATK", "+%d" % item["matk_bonus"], Color(0.6, 0.4, 0.9))
	if item.has("mdef_bonus"):
		_add_detail_stat(stats_row, "MDEF", "+%d" % item["mdef_bonus"], Color(0.4, 0.5, 0.9))
	if item.has("heal"):
		_add_detail_stat(stats_row, "Heal", "%d HP" % item["heal"], Color(0.3, 0.8, 0.3))
	if item.has("weapon_type"):
		_add_detail_stat(stats_row, "Type", item["weapon_type"].capitalize(), WEAPON_COLORS.get(item["weapon_type"], Color.WHITE))
	if item.has("attack_speed"):
		_add_detail_stat(stats_row, "Speed", "%.1f" % item["attack_speed"], Color(0.6, 0.8, 0.6))
	if item.has("required_skill") and item.has("required_level"):
		var req_text: String = "%s Lv. %d" % [item["required_skill"].capitalize(), item["required_level"]]
		_add_detail_stat(stats_row, "Requires", req_text, Color(0.7, 0.6, 0.4))
	if item.has("value"):
		_add_detail_stat(stats_row, "Value", "%dg" % item["value"], Color(0.8, 0.7, 0.3))

func _add_detail_stat(parent: HBoxContainer, label_text: String, value_text: String, color: Color) -> void:
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 4)
	parent.add_child(pair)

	var icon_file: String = STAT_ICON_MAP.get(label_text, "")
	if not icon_file.is_empty():
		var icon := TextureRect.new()
		icon.texture = load(STAT_ICON_DIR + icon_file) as Texture2D
		icon.custom_minimum_size = Vector2(14, 14)
		icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = TEXTURE_FILTER_NEAREST
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_child(icon)

	var lbl := Label.new()
	lbl.text = label_text + ":"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.5, 0.4))
	pair.add_child(lbl)
	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 11)
	val.add_theme_color_override("font_color", color)
	pair.add_child(val)

func _clear_detail() -> void:
	if not _detail_container:
		return
	for child in _detail_container.get_children():
		_detail_container.remove_child(child)
		child.queue_free()


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
	if not _active:
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
	var changed: bool = false

	match key:
		KEY_W:
			if _nav_zone == "inventory":
				var row: int = _grid_idx / GRID_COLUMNS
				if row > 0:
					_grid_idx -= GRID_COLUMNS
					changed = true
			else:
				if _equip_row > 0:
					_equip_row -= 1
					changed = true
		KEY_S:
			if _nav_zone == "inventory":
				if _grid_idx + GRID_COLUMNS < _cursor_cells.size():
					_grid_idx += GRID_COLUMNS
					changed = true
			else:
				var max_row: int = (LEFT_EQUIP.size() if _equip_col == 0 else RIGHT_EQUIP.size()) - 1
				if _equip_row < max_row:
					_equip_row += 1
					changed = true
		KEY_A:
			if _nav_zone == "inventory":
				var col: int = _grid_idx % GRID_COLUMNS
				if col > 0:
					_grid_idx -= 1
					changed = true
			else:
				if _equip_col == 1:
					_equip_col = 0
					changed = true
				else:
					# Switch back to inventory — rightmost column of closest row
					_nav_zone = "inventory"
					var target_row: int = clampi(_equip_row, 0, (_cursor_cells.size() - 1) / GRID_COLUMNS)
					_grid_idx = target_row * GRID_COLUMNS + (GRID_COLUMNS - 1)
					_grid_idx = clampi(_grid_idx, 0, max(0, _cursor_cells.size() - 1))
					changed = true
		KEY_D:
			if _nav_zone == "inventory":
				var col: int = _grid_idx % GRID_COLUMNS
				if col < GRID_COLUMNS - 1 and _grid_idx + 1 < _cursor_cells.size():
					_grid_idx += 1
					changed = true
				else:
					# Switch to equipment zone — left column, closest row
					var current_row: int = _grid_idx / GRID_COLUMNS
					_nav_zone = "equipment"
					_equip_col = 0
					_equip_row = clampi(current_row, 0, LEFT_EQUIP.size() - 1)
					changed = true
			else:
				if _equip_col == 0:
					_equip_col = 1
					changed = true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _nav_zone == "inventory":
				var item_id: String = _cursor_item_ids[_grid_idx] if _grid_idx < _cursor_item_ids.size() else ""
				if not item_id.is_empty():
					_open_action_menu(item_id)
			else:
				var slot_array: Array = LEFT_EQUIP if _equip_col == 0 else RIGHT_EQUIP
				var slot_name: String = slot_array[_equip_row] if _equip_row < slot_array.size() else ""
				if not slot_name.is_empty() and _equipment:
					var item_id: String = _equipment.get_slot(slot_name)
					if not item_id.is_empty():
						_open_equip_action_menu(slot_name, item_id)
			return
		_:
			return

	if changed:
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
	if not _cursor_hand:
		return

	var cell: Control = null
	var item_id: String = ""

	if _nav_zone == "inventory":
		if _grid_idx < 0 or _grid_idx >= _cursor_cells.size():
			_cursor_hand.visible = false
			_tooltip.visible = false
			return
		cell = _cursor_cells[_grid_idx]
		item_id = _cursor_item_ids[_grid_idx] if _grid_idx < _cursor_item_ids.size() else ""
	else:
		var equip_vbox: VBoxContainer = _left_equip_vbox if _equip_col == 0 else _right_equip_vbox
		if _equip_row < 0 or _equip_row >= equip_vbox.get_child_count():
			_cursor_hand.visible = false
			_tooltip.visible = false
			return
		cell = equip_vbox.get_child(_equip_row)
		var slot_array: Array = LEFT_EQUIP if _equip_col == 0 else RIGHT_EQUIP
		var slot_name: String = slot_array[_equip_row] if _equip_row < slot_array.size() else ""
		item_id = _equipment.get_slot(slot_name) if _equipment and not slot_name.is_empty() else ""

	if not cell:
		_cursor_hand.visible = false
		_tooltip.visible = false
		return

	_cursor_hand.visible = true
	_cursor_hand.global_position = Vector2(
		cell.global_position.x - 24,
		cell.global_position.y + cell.size.y / 2.0 - 12.0
	)

	if not item_id.is_empty():
		_tooltip_label.text = _format_tooltip(item_id)
		_tooltip.position = cell.global_position - global_position + Vector2(0, -28)
		_tooltip.visible = true
		_update_detail(item_id)
	else:
		_tooltip.visible = false
		_clear_detail()

func _open_action_menu(item_id: String) -> void:
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
	if _grid_idx >= 0 and _grid_idx < _cursor_cells.size():
		var cell: Control = _cursor_cells[_grid_idx]
		var cell_pos: Vector2 = cell.global_position - global_position
		_context_menu.position = Vector2(cell_pos.x + CELL_SIZE + 4, cell_pos.y)

	_context_menu.visible = true
	_action_menu_open = true
	_action_idx = 0
	_update_action_highlight()

func _open_equip_action_menu(slot_name: String, item_id: String) -> void:
	_clear_detail()
	_context_item_id = item_id
	_context_slot_name = slot_name

	for child in _context_vbox.get_children():
		child.queue_free()
	_action_buttons.clear()

	_add_action_button("Unequip", _ctx_unequip)
	_add_action_button("Cancel", _close_action_menu)

	var equip_vbox: VBoxContainer = _left_equip_vbox if _equip_col == 0 else _right_equip_vbox
	if _equip_row >= 0 and _equip_row < equip_vbox.get_child_count():
		var cell: Control = equip_vbox.get_child(_equip_row)
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
