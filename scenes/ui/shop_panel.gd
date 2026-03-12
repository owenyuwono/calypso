extends Control
## Shop UI panel for buying and selling items.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

var _panel: PanelContainer
var _shop_list: VBoxContainer
var _player_list: VBoxContainer
var _gold_label: Label
var _drag_handle: PanelContainer
var _is_open: bool = false
var _player: Node
var _current_shop_id: String = ""
var _current_shop_items: Array = []

func _ready() -> void:
	visible = false
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(500, 400)

	var style := UIHelper.create_panel_style()
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var main_vbox := VBoxContainer.new()
	_panel.add_child(main_vbox)

	# Gold label (will be reparented into drag handle as extra_right)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	main_vbox.add_child(_gold_label)

	# Draggable title bar with gold label on the right
	_drag_handle = DragHandle.new()
	_drag_handle.setup(_panel, "Shop", _gold_label)
	_drag_handle.close_pressed.connect(close_shop)
	main_vbox.add_child(_drag_handle)
	main_vbox.move_child(_drag_handle, 0)

	# Two columns
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(columns)

	# Shop column
	var shop_col := VBoxContainer.new()
	shop_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(shop_col)

	var shop_title := Label.new()
	shop_title.text = "Buy"
	shop_title.add_theme_font_size_override("font_size", 16)
	shop_title.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	shop_col.add_child(shop_title)

	var shop_scroll := ScrollContainer.new()
	shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_col.add_child(shop_scroll)

	_shop_list = VBoxContainer.new()
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_scroll.add_child(_shop_list)

	# Separator
	var vsep := VSeparator.new()
	columns.add_child(vsep)

	# Player column (sell)
	var player_col := VBoxContainer.new()
	player_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(player_col)

	var sell_title := Label.new()
	sell_title.text = "Sell"
	sell_title.add_theme_font_size_override("font_size", 16)
	sell_title.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
	player_col.add_child(sell_title)

	var player_scroll := ScrollContainer.new()
	player_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player_col.add_child(player_scroll)

	_player_list = VBoxContainer.new()
	_player_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_scroll.add_child(_player_list)

func set_player(p: Node) -> void:
	_player = p

func _input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()

func open_shop(shop_id: String) -> void:
	_current_shop_id = shop_id
	var shop_data := WorldState.get_entity_data(shop_id)
	_current_shop_items = shop_data.get("shop_items", [])
	_drag_handle.set_title(shop_data.get("name", "Shop"))
	_is_open = true
	visible = true
	UIHelper.center_panel(_panel)
	_refresh()

func close_shop() -> void:
	_is_open = false
	visible = false
	_current_shop_id = ""

func _refresh() -> void:
	for child in _shop_list.get_children():
		child.queue_free()
	for child in _player_list.get_children():
		child.queue_free()

	if not _player:
		return
	var inv_comp = _player.get_node("InventoryComponent")
	if not inv_comp:
		return

	var gold: int = inv_comp.gold
	_gold_label.text = "Gold: %d" % gold

	# Shop items (buy)
	for item_id in _current_shop_items:
		var item := ItemDatabase.get_item(item_id)
		if item.is_empty():
			continue
		var cost: int = item.get("value", 0)
		var row := HBoxContainer.new()
		_shop_list.add_child(row)

		var label := Label.new()
		label.text = "%s (%dg)" % [item.get("name", item_id), cost]
		label.add_theme_font_size_override("font_size", 13)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var btn := Button.new()
		btn.text = "Buy"
		btn.disabled = gold < cost
		btn.pressed.connect(_buy_item.bind(item_id, cost))
		row.add_child(btn)

	# Player items (sell)
	var inv: Dictionary = inv_comp.get_items()
	for item_id in inv:
		var count: int = inv[item_id]
		var item := ItemDatabase.get_item(item_id)
		var sell_price: int = int(item.get("value", 0) * 0.5)
		var row := HBoxContainer.new()
		_player_list.add_child(row)

		var label := Label.new()
		label.text = "%s x%d (%dg)" % [item.get("name", item_id), count, sell_price]
		label.add_theme_font_size_override("font_size", 13)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var btn := Button.new()
		btn.text = "Sell"
		btn.disabled = sell_price <= 0
		btn.pressed.connect(_sell_item.bind(item_id, sell_price))
		row.add_child(btn)

func _buy_item(item_id: String, cost: int) -> void:
	if not _player:
		return
	var inv_comp = _player.get_node("InventoryComponent")
	if inv_comp and inv_comp.remove_gold_amount(cost):
		inv_comp.add_item(item_id)
		GameEvents.item_purchased.emit("player", item_id, cost)
		_refresh()

func _sell_item(item_id: String, price: int) -> void:
	if not _player:
		return
	var inv_comp = _player.get_node("InventoryComponent")
	if inv_comp and inv_comp.remove_item(item_id):
		inv_comp.add_gold_amount(price)
		GameEvents.item_sold.emit("player", item_id, price)
		_refresh()

func is_open() -> bool:
	return _is_open
