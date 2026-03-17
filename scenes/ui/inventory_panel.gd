extends Control
## Player inventory panel toggled with Tab.
## Layout (top to bottom): drag handle, attack type + gold row,
## EQUIPMENT header, semantic equipment layout (armor left / weapons right),
## separator, ITEMS header, 5-column inventory grid with scroll.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

const GRID_COLUMNS := 5
const MIN_SLOTS := 20
const CELL_SIZE := 64
const EQUIP_CELL_SIZE := 56
const EQUIP_WEAPON_CELL_SIZE := 62

# Armor slots: 2 columns × 3 rows (left group)
const ARMOR_LAYOUT: Array = [
	["head",   "torso"],
	["gloves", "legs"],
	["feet",   "back"],
]

# Weapon slots: single column (right group)
const WEAPON_LAYOUT: Array = ["main_hand", "off_hand"]

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
var _equip_armor_grid: GridContainer
var _equip_weapon_vbox: VBoxContainer
var _grid: GridContainer
var _attack_type_label: Label
var _gold_label: Label
var _gold_icon: TextureRect
var _tooltip: PanelContainer
var _tooltip_label: Label
var _is_open: bool = false

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
	_panel.custom_minimum_size = Vector2(400, 580)
	var style := UIHelper.create_panel_style()
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	# Title bar
	var drag_handle := DragHandle.new()
	drag_handle.setup(_panel, "Inventory")
	drag_handle.close_pressed.connect(_toggle)
	vbox.add_child(drag_handle)

	# Attack type + gold row
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 8)
	vbox.add_child(info_row)

	_attack_type_label = Label.new()
	_attack_type_label.add_theme_font_size_override("font_size", 15)
	_attack_type_label.add_theme_color_override("font_color", UIHelper.COLOR_DISABLED)
	_attack_type_label.text = "Unarmed"
	_attack_type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(_attack_type_label)

	var gold_hbox := HBoxContainer.new()
	gold_hbox.add_theme_constant_override("separation", 4)
	gold_hbox.alignment = BoxContainer.ALIGNMENT_END
	info_row.add_child(gold_hbox)

	_gold_icon = TextureRect.new()
	var gold_coin_tex: Texture2D = load("res://assets/textures/ui/stats/gold_coin.png") as Texture2D
	_gold_icon.texture = gold_coin_tex
	_gold_icon.custom_minimum_size = Vector2(16, 16)
	_gold_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gold_icon.texture_filter = TEXTURE_FILTER_NEAREST
	_gold_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_hbox.add_child(_gold_icon)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 14)
	_gold_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	_gold_label.text = "0"
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_hbox.add_child(_gold_label)

	# EQUIPMENT section header
	var equip_header := Label.new()
	equip_header.text = "EQUIPMENT"
	equip_header.add_theme_font_size_override("font_size", 11)
	equip_header.add_theme_color_override("font_color", Color(0.7, 0.6, 0.35))
	equip_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(equip_header)

	# Equipment layout: armor grid (left) + weapon column (right)
	var equip_row := HBoxContainer.new()
	equip_row.add_theme_constant_override("separation", 10)
	vbox.add_child(equip_row)

	# Left: armor grid 2×3
	_equip_armor_grid = GridContainer.new()
	_equip_armor_grid.columns = 2
	_equip_armor_grid.add_theme_constant_override("h_separation", 6)
	_equip_armor_grid.add_theme_constant_override("v_separation", 6)
	equip_row.add_child(_equip_armor_grid)

	# Spacer between groups
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(4, 0)
	equip_row.add_child(spacer)

	# Right: weapon vbox
	_equip_weapon_vbox = VBoxContainer.new()
	_equip_weapon_vbox.add_theme_constant_override("separation", 6)
	equip_row.add_child(_equip_weapon_vbox)

	# Separator
	vbox.add_child(HSeparator.new())

	# ITEMS section header
	var items_header := Label.new()
	items_header.text = "ITEMS"
	items_header.add_theme_font_size_override("font_size", 11)
	items_header.add_theme_color_override("font_color", Color(0.7, 0.6, 0.35))
	items_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(items_header)

	# Scroll + inventory grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 280)
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	# Vend button
	var vend_btn := Button.new()
	vend_btn.text = "Set Up Shop [V]"
	vend_btn.add_theme_font_size_override("font_size", 13)
	vend_btn.custom_minimum_size = Vector2(0, 32)
	vend_btn.pressed.connect(_on_vend_button_pressed)
	vbox.add_child(vend_btn)

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

func set_player(p: Node) -> void:
	_player = p
	if _player:
		_inventory = _player.get_node_or_null("InventoryComponent")
		_equipment = _player.get_node_or_null("EquipmentComponent")
		_combat = _player.get_node_or_null("CombatComponent")
		_stats = _player.get_node_or_null("StatsComponent")

func _on_vend_button_pressed() -> void:
	if _player and _player.vend_setup_panel:
		_player.vend_setup_panel._toggle()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle()

func toggle() -> void:
	_toggle()

func _toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	if _is_open:
		UIHelper.center_panel(_panel)
		_refresh()
	else:
		_tooltip.visible = false
		_hide_desc()
		_hide_context_menu()

func is_open() -> bool:
	return _is_open

func _refresh() -> void:
	_hide_desc()
	_hide_context_menu()

	if not _is_open or not _player:
		return

	if not _inventory or not _equipment:
		return

	# Attack type label
	if _combat:
		var weapon_type: String = _combat.get_equipped_weapon_type()
		var weapon_id: String = _equipment.get_slot("main_hand")
		if weapon_id.is_empty():
			_attack_type_label.text = "Unarmed"
			_attack_type_label.add_theme_color_override("font_color", UIHelper.COLOR_DISABLED)
		else:
			var wtype_cap: String = weapon_type.substr(0, 1).to_upper() + weapon_type.substr(1)
			_attack_type_label.text = "◆ " + wtype_cap
			var wcolor: Color = WEAPON_COLORS.get(weapon_type, UIHelper.COLOR_DISABLED)
			_attack_type_label.add_theme_color_override("font_color", wcolor)
	else:
		_attack_type_label.text = "Unarmed"
		_attack_type_label.add_theme_color_override("font_color", UIHelper.COLOR_DISABLED)

	# Gold
	var gold: int = _inventory.get_gold_amount()
	_gold_label.text = "%d" % gold

	# Rebuild armor grid (left)
	for child in _equip_armor_grid.get_children():
		child.queue_free()

	for row in ARMOR_LAYOUT:
		for slot_name in row:
			var item_id: String = _equipment.get_slot(slot_name)
			if item_id.is_empty():
				_equip_armor_grid.add_child(_build_equip_cell_empty(slot_name, EQUIP_CELL_SIZE))
			else:
				_equip_armor_grid.add_child(_build_equip_cell_filled(slot_name, item_id, EQUIP_CELL_SIZE))

	# Rebuild weapon column (right)
	for child in _equip_weapon_vbox.get_children():
		child.queue_free()

	for slot_name in WEAPON_LAYOUT:
		var item_id: String = _equipment.get_slot(slot_name)
		if item_id.is_empty():
			_equip_weapon_vbox.add_child(_build_equip_cell_empty(slot_name, EQUIP_WEAPON_CELL_SIZE))
		else:
			_equip_weapon_vbox.add_child(_build_equip_cell_filled(slot_name, item_id, EQUIP_WEAPON_CELL_SIZE))

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

	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.mouse_entered.connect(_on_equip_cell_hover.bind(item_id, cell))
	cell.mouse_exited.connect(_on_cell_unhover)
	cell.gui_input.connect(_on_equip_cell_input.bind(slot_name))

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

	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.mouse_entered.connect(_on_cell_hover.bind(item_id, cell))
	cell.mouse_exited.connect(_on_cell_unhover)
	cell.gui_input.connect(_on_cell_input.bind(item_id))

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

func _on_equip_cell_hover(item_id: String, cell: Control) -> void:
	_tooltip_label.text = _format_tooltip(item_id)
	var cell_pos: Vector2 = cell.global_position - _panel.global_position
	_tooltip.position = Vector2(cell_pos.x, cell_pos.y - 28)
	_tooltip.visible = true

func _on_cell_hover(item_id: String, cell: Control) -> void:
	_tooltip_label.text = _format_tooltip(item_id)
	var cell_pos: Vector2 = cell.global_position - _panel.global_position
	_tooltip.position = Vector2(cell_pos.x, cell_pos.y - 28)
	_tooltip.visible = true

func _on_cell_unhover() -> void:
	_tooltip.visible = false

func _on_equip_cell_input(event: InputEvent, slot_name: String) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	var item_id: String = _equipment.get_slot(slot_name)
	if item_id.is_empty():
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_show_desc(item_id)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_show_context_menu("", slot_name, mb.global_position)

func _on_cell_input(event: InputEvent, item_id: String) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_show_desc(item_id)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_show_context_menu(item_id, "", mb.global_position)

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

func _show_context_menu(item_id: String, slot_name: String, global_pos: Vector2) -> void:
	_hide_desc()
	_context_item_id = item_id
	_context_slot_name = slot_name

	for child in _context_vbox.get_children():
		child.queue_free()

	if not slot_name.is_empty():
		# Equipment slot right-click — just Unequip
		_add_context_button("Unequip", _ctx_unequip)
	else:
		# Inventory item right-click
		var item: Dictionary = ItemDatabase.get_item(item_id)
		var type_str: String = item.get("type", "")
		if type_str == "consumable" and item.has("heal"):
			_add_context_button("Use", _ctx_use)
		elif type_str in ["weapon", "armor"]:
			_add_context_button("Equip", _ctx_equip)
		_add_context_button("Discard", _ctx_discard)

	# Position near mouse, relative to this Control
	var local_pos: Vector2 = global_pos - global_position
	_context_menu.position = local_pos
	_context_menu.visible = true

func _add_context_button(text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 12)
	btn.custom_minimum_size = Vector2(80, 26)
	btn.pressed.connect(callback)
	_context_vbox.add_child(btn)

func _hide_context_menu() -> void:
	_context_menu.visible = false
	_context_item_id = ""
	_context_slot_name = ""

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
		var loot_script := preload("res://scenes/objects/loot_drop.gd")
		var loot := Area3D.new()
		loot.set_script(loot_script)
		loot.item_id = discard_id
		loot.item_count = 1
		loot.gold_amount = 0
		var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		loot.position = _player.global_position + offset
		get_tree().current_scene.call_deferred("add_child", loot)
	_hide_context_menu()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	if _context_menu.visible:
		_hide_context_menu()
	if _desc_panel.visible:
		var local: Vector2 = mb.global_position - _desc_panel.global_position
		var rect: Vector2 = _desc_panel.size
		if local.x < 0 or local.y < 0 or local.x > rect.x or local.y > rect.y:
			_hide_desc()

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
		_refresh()

func _unequip(slot_name: String) -> void:
	if not _equipment:
		return
	if _equipment.unequip(slot_name):
		_refresh()
