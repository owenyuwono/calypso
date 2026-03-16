extends Control
## Player inventory panel toggled with Tab.
## Layout (top to bottom): drag handle, attack type + gold row,
## 4x2 equipment grid, separator, 5-column inventory grid with scroll.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

const GRID_COLUMNS := 5
const MIN_SLOTS := 20
const CELL_SIZE := 64
const EQUIP_CELL_SIZE := 56

const EQUIP_LAYOUT: Array = [
	["head", "torso", "main_hand", "off_hand"],
	["gloves", "legs", "feet", "back"],
]

const SLOT_LABELS: Dictionary = {
	"head": "Head", "torso": "Torso", "main_hand": "Main", "off_hand": "Off",
	"gloves": "Gloves", "legs": "Legs", "feet": "Feet", "back": "Back",
}

const TYPE_ORDER := {"weapon": 0, "armor": 1, "consumable": 2, "material": 3}
const TYPE_COLORS := {
	"consumable": Color(0.2, 0.5, 0.2),
	"weapon":     Color(0.4, 0.4, 0.5),
	"armor":      Color(0.2, 0.3, 0.5),
	"material":   Color(0.5, 0.4, 0.25),
}

const EQUIP_SLOT_COLORS: Dictionary = {
	"main_hand": Color(0.4, 0.4, 0.5),
	"off_hand":  Color(0.2, 0.3, 0.5),
}
const EQUIP_SLOT_COLOR_DEFAULT := Color(0.25, 0.3, 0.45)

const WEAPON_COLORS: Dictionary = {
	"sword":  Color(0.9, 0.85, 0.3),
	"axe":    Color(0.8, 0.4, 0.2),
	"mace":   Color(0.6, 0.6, 0.7),
	"dagger": Color(0.4, 0.8, 0.4),
	"staff":  Color(0.5, 0.4, 0.9),
}

var _panel: PanelContainer
var _equip_grid: GridContainer
var _grid: GridContainer
var _attack_type_label: Label
var _gold_label: Label
var _tooltip: PanelContainer
var _tooltip_label: Label
var _is_open: bool = false

var _player: Node
var _inventory: Node
var _equipment: Node
var _combat: Node
var _stats: Node

func _ready() -> void:
	visible = false
	_build_ui()
	GameEvents.item_looted.connect(func(_a, _b, _c): _refresh())

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(380, 580)
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
	_attack_type_label.add_theme_font_size_override("font_size", 14)
	_attack_type_label.add_theme_color_override("font_color", UIHelper.COLOR_DISABLED)
	_attack_type_label.text = "Unarmed"
	_attack_type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(_attack_type_label)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 14)
	_gold_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	_gold_label.text = "Gold: 0"
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_row.add_child(_gold_label)

	# Equipment grid (4 columns x 2 rows)
	_equip_grid = GridContainer.new()
	_equip_grid.columns = 4
	_equip_grid.add_theme_constant_override("h_separation", 6)
	_equip_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(_equip_grid)

	# Separator
	vbox.add_child(HSeparator.new())

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

	# Tooltip — child of root Control so it overlays everything
	_tooltip = PanelContainer.new()
	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	tooltip_style.border_color = Color(0.5, 0.5, 0.5)
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

func set_player(p: Node) -> void:
	_player = p
	if _player:
		_inventory = _player.get_node_or_null("InventoryComponent")
		_equipment = _player.get_node_or_null("EquipmentComponent")
		_combat = _player.get_node_or_null("CombatComponent")
		_stats = _player.get_node_or_null("StatsComponent")

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

func is_open() -> bool:
	return _is_open

func _refresh() -> void:
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
			_attack_type_label.text = wtype_cap
			var wcolor: Color = WEAPON_COLORS.get(weapon_type, UIHelper.COLOR_DISABLED)
			_attack_type_label.add_theme_color_override("font_color", wcolor)
	else:
		_attack_type_label.text = "Unarmed"
		_attack_type_label.add_theme_color_override("font_color", UIHelper.COLOR_DISABLED)

	# Gold
	var gold: int = _inventory.get_gold_amount()
	_gold_label.text = "Gold: %d" % gold

	# Rebuild equipment grid
	for child in _equip_grid.get_children():
		child.queue_free()

	for row in EQUIP_LAYOUT:
		for slot_name in row:
			var item_id: String = _equipment.get_slot(slot_name)
			if item_id.is_empty():
				_equip_grid.add_child(_build_equip_cell_empty(slot_name))
			else:
				_equip_grid.add_child(_build_equip_cell_filled(slot_name, item_id))

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

func _build_equip_cell_empty(slot_name: String) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(EQUIP_CELL_SIZE, EQUIP_CELL_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12)
	style.border_color = Color(0.25, 0.25, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	cell.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = SLOT_LABELS.get(slot_name, slot_name)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.add_child(label)

	return cell

func _build_equip_cell_filled(slot_name: String, item_id: String) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(EQUIP_CELL_SIZE, EQUIP_CELL_SIZE)

	var slot_color: Color = EQUIP_SLOT_COLORS.get(slot_name, EQUIP_SLOT_COLOR_DEFAULT)
	var style := StyleBoxFlat.new()
	style.bg_color = slot_color
	style.border_color = Color(0.5, 0.5, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	cell.add_theme_stylebox_override("panel", style)

	var item_data: Dictionary = ItemDatabase.get_item(item_id)
	var item_name: String = item_data.get("name", item_id)

	# Slot label tiny at top
	var slot_label := Label.new()
	slot_label.text = SLOT_LABELS.get(slot_name, slot_name)
	slot_label.add_theme_font_size_override("font_size", 9)
	slot_label.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0, 0.75))
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	slot_label.offset_top = 3
	slot_label.offset_bottom = 16
	slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(slot_label)

	# First letter of item name, centered
	var letter := Label.new()
	letter.text = item_name.substr(0, 1).to_upper()
	letter.add_theme_font_size_override("font_size", 20)
	letter.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.set_anchors_preset(Control.PRESET_FULL_RECT)
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(letter)

	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.mouse_entered.connect(_on_equip_cell_hover.bind(item_name, cell))
	cell.mouse_exited.connect(_on_cell_unhover)
	cell.gui_input.connect(_on_equip_cell_input.bind(slot_name))

	return cell

func _build_cell(item_id: String, count: int) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)

	var item_data: Dictionary = ItemDatabase.get_item(item_id)
	var type_str: String = item_data.get("type", "")
	var type_color: Color = TYPE_COLORS.get(type_str, Color(0.25, 0.25, 0.3))

	var style := StyleBoxFlat.new()
	style.bg_color = type_color
	style.border_color = Color(0.4, 0.4, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	cell.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	cell.add_child(margin)

	var letter := Label.new()
	letter.text = item_data.get("name", "?").substr(0, 1).to_upper()
	letter.add_theme_font_size_override("font_size", 22)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	letter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	letter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(letter)

	if count > 1:
		var count_label := Label.new()
		count_label.text = "x%d" % count
		count_label.add_theme_font_size_override("font_size", 10)
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count_label.offset_left = -24
		count_label.offset_top = -16
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(count_label)

	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.mouse_entered.connect(_on_cell_hover.bind(item_id, cell))
	cell.mouse_exited.connect(_on_cell_unhover)
	cell.gui_input.connect(_on_cell_input.bind(item_id))

	return cell

func _build_empty_cell() -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12)
	style.border_color = Color(0.2, 0.2, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	cell.add_theme_stylebox_override("panel", style)
	return cell

func _on_equip_cell_hover(item_name: String, cell: Control) -> void:
	_tooltip_label.text = item_name
	var cell_pos: Vector2 = cell.global_position - _panel.global_position
	_tooltip.position = Vector2(cell_pos.x, cell_pos.y - 28)
	_tooltip.visible = true

func _on_cell_hover(item_id: String, cell: Control) -> void:
	var item_data: Dictionary = ItemDatabase.get_item(item_id)
	_tooltip_label.text = item_data.get("name", item_id)
	var cell_pos: Vector2 = cell.global_position - _panel.global_position
	_tooltip.position = Vector2(cell_pos.x, cell_pos.y - 28)
	_tooltip.visible = true

func _on_cell_unhover() -> void:
	_tooltip.visible = false

func _on_equip_cell_input(event: InputEvent, slot_name: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_unequip(slot_name)

func _on_cell_input(event: InputEvent, item_id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var item_data: Dictionary = ItemDatabase.get_item(item_id)
	var type_str: String = item_data.get("type", "")
	match type_str:
		"consumable":
			_use_item(item_id, item_data)
		"weapon":
			_equip_to_slot(item_id, "main_hand")
		"armor":
			_equip_to_slot(item_id, "off_hand")

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
