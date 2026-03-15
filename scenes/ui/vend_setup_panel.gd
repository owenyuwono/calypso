extends Control
## Panel for the player to configure and open their own vending shop.
## Toggled with V key.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

var _panel: PanelContainer
var _item_list: VBoxContainer
var _title_input: LineEdit
var _open_shop_btn: Button
var _close_shop_btn: Button
var _is_open: bool = false
var _player: Node

func _ready() -> void:
	visible = false
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(360, 460)

	var style := UIHelper.create_panel_style()
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)

	# Draggable title bar
	var drag_handle := DragHandle.new()
	drag_handle.setup(_panel, "Set Up Shop")
	drag_handle.close_pressed.connect(_toggle)
	vbox.add_child(drag_handle)

	# Shop title input row
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)

	var title_label := Label.new()
	title_label.text = "Shop Name:"
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	title_row.add_child(title_label)

	_title_input = LineEdit.new()
	_title_input.text = "Player's Shop"
	_title_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_input.add_theme_font_size_override("font_size", 14)
	title_row.add_child(_title_input)

	# Column header row
	var header_row := HBoxContainer.new()
	vbox.add_child(header_row)

	var header_name := Label.new()
	header_name.text = "Item"
	header_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_name.add_theme_font_size_override("font_size", 13)
	header_name.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	header_row.add_child(header_name)

	var header_qty := Label.new()
	header_qty.text = "Qty"
	header_qty.custom_minimum_size = Vector2(60, 0)
	header_qty.add_theme_font_size_override("font_size", 13)
	header_qty.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	header_row.add_child(header_qty)

	var header_price := Label.new()
	header_price.text = "Price"
	header_price.custom_minimum_size = Vector2(70, 0)
	header_price.add_theme_font_size_override("font_size", 13)
	header_price.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	header_row.add_child(header_price)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Scrollable item list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 280)
	vbox.add_child(scroll)

	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_item_list)

	var btn_sep := HSeparator.new()
	vbox.add_child(btn_sep)

	# Buttons row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	_open_shop_btn = Button.new()
	_open_shop_btn.text = "Open Shop"
	_open_shop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_open_shop_btn.pressed.connect(_on_open_shop_pressed)
	btn_row.add_child(_open_shop_btn)

	_close_shop_btn = Button.new()
	_close_shop_btn.text = "Close Shop"
	_close_shop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_shop_btn.pressed.connect(_on_close_shop_pressed)
	btn_row.add_child(_close_shop_btn)

func set_player(p: Node) -> void:
	_player = p

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_vend"):
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	if _is_open:
		UIHelper.center_panel(_panel)
		_refresh()

func _on_visibility_changed() -> void:
	if visible:
		_refresh()

func _refresh() -> void:
	for child in _item_list.get_children():
		child.queue_free()

	if not _player:
		return

	var inv_comp: Node = _player.get_node_or_null("InventoryComponent")
	if not inv_comp:
		return

	var vending_comp: Node = _player.get_node_or_null("VendingComponent")
	var currently_vending: bool = vending_comp != null and vending_comp.is_vending()

	_open_shop_btn.visible = not currently_vending
	_close_shop_btn.visible = currently_vending

	var inv: Dictionary = inv_comp.get_items()
	if inv.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No items to sell"
		empty_label.add_theme_color_override("font_color", UIHelper.COLOR_DISABLED)
		_item_list.add_child(empty_label)
		return

	for item_id in inv:
		var count: int = inv[item_id]
		if count <= 0:
			continue

		var item_data := ItemDatabase.get_item(item_id)
		var item_name: String = item_data.get("name", item_id)
		var base_value: int = item_data.get("value", 1)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_item_list.add_child(row)

		var name_label := Label.new()
		name_label.text = "%s x%d" % [item_name, count]
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var qty_spin := SpinBox.new()
		qty_spin.min_value = 0
		qty_spin.max_value = count
		qty_spin.value = 0
		qty_spin.custom_minimum_size = Vector2(60, 0)
		qty_spin.add_theme_font_size_override("font_size", 13)
		qty_spin.name = "qty_%s" % item_id
		row.add_child(qty_spin)

		var price_spin := SpinBox.new()
		price_spin.min_value = 1
		price_spin.max_value = 999999
		price_spin.value = base_value
		price_spin.custom_minimum_size = Vector2(70, 0)
		price_spin.add_theme_font_size_override("font_size", 13)
		price_spin.name = "price_%s" % item_id
		row.add_child(price_spin)

func _on_open_shop_pressed() -> void:
	if not _player:
		return
	var vending_comp: Node = _player.get_node_or_null("VendingComponent")
	if not vending_comp:
		return

	var listings: Dictionary = {}
	for row in _item_list.get_children():
		if not row is HBoxContainer:
			continue
		# Row structure: name_label, qty_spin, price_spin
		var children := row.get_children()
		if children.size() < 3:
			continue
		var qty_spin: SpinBox = children[1]
		var price_spin: SpinBox = children[2]
		var qty: int = int(qty_spin.value)
		if qty <= 0:
			continue
		# Recover item_id from spinbox name convention "qty_{item_id}"
		var spin_name: String = qty_spin.name
		if not spin_name.begins_with("qty_"):
			continue
		var item_id: String = spin_name.substr(4)
		listings[item_id] = {"count": qty, "price": int(price_spin.value)}

	if listings.is_empty():
		return

	var shop_title: String = _title_input.text.strip_edges()
	if shop_title.is_empty():
		shop_title = "Player's Shop"

	# Enter vending state via public method (cancels attack, stops navigation)
	_player.enter_vending_state()

	vending_comp.start_vending(shop_title, listings)
	_refresh()

func _on_close_shop_pressed() -> void:
	if not _player:
		return
	var vending_comp: Node = _player.get_node_or_null("VendingComponent")
	# stop_vending() clears _is_vending and stops the VendingComponent
	_player.stop_vending()
	_refresh()

func is_open() -> bool:
	return _is_open
