extends Control
## Player inventory panel toggled with Tab.
## Grid-based layout: equipment row, gold display, 5-column item grid with hover tooltips.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

const GRID_COLUMNS := 5
const MIN_SLOTS := 20
const CELL_SIZE := 64

const TYPE_ORDER := {"weapon": 0, "armor": 1, "consumable": 2, "material": 3}
const TYPE_COLORS := {
	"consumable": Color(0.2, 0.5, 0.2),
	"weapon":     Color(0.4, 0.4, 0.5),
	"armor":      Color(0.2, 0.3, 0.5),
	"material":   Color(0.5, 0.4, 0.25),
}

var _panel: PanelContainer
var _grid: GridContainer
var _gold_label: Label
var _weapon_cell_label: Label
var _armor_cell_label: Label
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
	_panel.custom_minimum_size = Vector2(380, 480)
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

	# Gold display
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	_gold_label.text = "Gold: 0"
	vbox.add_child(_gold_label)

	# Equipment row
	var equip_row := HBoxContainer.new()
	equip_row.add_theme_constant_override("separation", 8)
	vbox.add_child(equip_row)

	var weapon_panel := _build_equip_slot("Weapon")
	equip_row.add_child(weapon_panel)
	_weapon_cell_label = weapon_panel.get_node("MarginContainer/VBoxContainer/ValueLabel")

	var armor_panel := _build_equip_slot("Armor")
	equip_row.add_child(armor_panel)
	_armor_cell_label = armor_panel.get_node("MarginContainer/VBoxContainer/ValueLabel")

	# Separator
	vbox.add_child(HSeparator.new())

	# Scroll + grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
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

func _build_equip_slot(slot_label: String) -> PanelContainer:
	var slot_panel := PanelContainer.new()
	slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(0.12, 0.12, 0.18)
	slot_style.border_color = Color(0.35, 0.35, 0.45)
	slot_style.set_border_width_all(1)
	slot_style.set_corner_radius_all(4)
	slot_panel.add_theme_stylebox_override("panel", slot_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	slot_panel.add_child(margin)
	margin.name = "MarginContainer"

	var inner_vbox := VBoxContainer.new()
	margin.add_child(inner_vbox)
	inner_vbox.name = "VBoxContainer"

	var header := Label.new()
	header.name = "HeaderLabel"
	header.text = slot_label
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", UIHelper.COLOR_DISABLED)
	inner_vbox.add_child(header)

	var value := Label.new()
	value.name = "ValueLabel"
	value.text = "(none)"
	value.add_theme_font_size_override("font_size", 13)
	value.add_theme_color_override("font_color", UIHelper.COLOR_EQUIPMENT)
	value.clip_text = true
	inner_vbox.add_child(value)

	return slot_panel

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

	# Clear grid
	for child in _grid.get_children():
		child.queue_free()

	if not _inventory or not _equipment:
		return

	# Gold
	var gold: int = _inventory.get_gold_amount()
	_gold_label.text = "Gold: %d" % gold

	# Equipment row
	var equipment: Dictionary = _equipment.get_equipment()
	var weapon_id: String = equipment.get("weapon", "")
	var armor_id: String = equipment.get("armor", "")
	_weapon_cell_label.text = ItemDatabase.get_item_name(weapon_id) if not weapon_id.is_empty() else "(none)"
	_armor_cell_label.text = ItemDatabase.get_item_name(armor_id) if not armor_id.is_empty() else "(none)"

	# Build sorted item list
	var inv: Dictionary = _inventory.get_items()
	var sorted_items: Array = _sort_items(inv)

	# Populate grid cells
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
	# Strip sort keys, return [item_id, count] pairs
	var result: Array = []
	for entry in entries:
		result.append([entry[0], entry[1]])
	return result

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

func _on_cell_hover(item_id: String, cell: Control) -> void:
	var item_data: Dictionary = ItemDatabase.get_item(item_id)
	_tooltip_label.text = item_data.get("name", item_id)
	var cell_pos: Vector2 = cell.global_position - _panel.global_position
	_tooltip.position = Vector2(cell_pos.x, cell_pos.y - 28)
	_tooltip.visible = true

func _on_cell_unhover() -> void:
	_tooltip.visible = false

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
		"weapon", "armor":
			_equip_item(item_id)

func _use_item(item_id: String, item_data: Dictionary) -> void:
	if not _inventory or not _inventory.has_item(item_id):
		return
	var heal_amount: int = item_data.get("heal", 0)
	if heal_amount > 0 and _combat:
		_combat.heal(heal_amount)
	_inventory.remove_item(item_id)
	_refresh()

func _equip_item(item_id: String) -> void:
	if not _equipment:
		return
	if _equipment.equip(item_id):
		_refresh()
