extends Control
## Shop UI panel for buying items from a vending entity.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

var _panel: PanelContainer
var _shop_list: VBoxContainer
var _gold_label: Label
var _drag_handle: PanelContainer
var _is_open: bool = false
var _player: Node
var _vendor: Node = null

func _ready() -> void:
	visible = false
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(320, 400)

	var style := UIHelper.create_panel_style()
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var main_vbox := VBoxContainer.new()
	_panel.add_child(main_vbox)

	# Gold label shown on the right of the drag handle
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

	# Buy column header
	var buy_title := Label.new()
	buy_title.text = "Buy"
	buy_title.add_theme_font_size_override("font_size", 16)
	buy_title.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	main_vbox.add_child(buy_title)

	var shop_scroll := ScrollContainer.new()
	shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(shop_scroll)

	_shop_list = VBoxContainer.new()
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_scroll.add_child(_shop_list)

func set_player(p: Node) -> void:
	_player = p

func _input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()

func open_shop(vendor: Node) -> void:
	_vendor = vendor
	var vending_comp: Node = vendor.get_node_or_null("VendingComponent")
	var title: String = "Shop"
	if vending_comp:
		var shop_title: String = vending_comp.get_shop_title()
		if not shop_title.is_empty():
			title = shop_title
	var vendor_data: Dictionary = WorldState.get_entity_data(WorldState.get_entity_id_for_node(vendor))
	var vendor_name: String = vendor_data.get("name", "")
	if not vendor_name.is_empty():
		_drag_handle.set_title("%s — %s" % [vendor_name, title])
	else:
		_drag_handle.set_title(title)
	_is_open = true
	visible = true
	UIHelper.center_panel(_panel)
	_refresh()

func close_shop() -> void:
	_is_open = false
	visible = false
	_vendor = null
	if _player and _player.has_method("stop_vending"):
		_player.stop_vending()

func _refresh() -> void:
	for child in _shop_list.get_children():
		child.queue_free()

	if not _player:
		return
	var inv_comp: Node = _player.get_node_or_null("InventoryComponent")
	if not inv_comp:
		return

	var gold: int = inv_comp.get_gold_amount()
	_gold_label.text = "Gold: %d" % gold

	if not _vendor:
		return
	var vending_comp: Node = _vendor.get_node_or_null("VendingComponent")
	if not vending_comp:
		return

	var listings: Dictionary = vending_comp.get_listings()
	for item_id in listings:
		var listing: Dictionary = listings[item_id]
		var count: int = listing.get("count", 0)
		var price: int = listing.get("price", 0)
		var item_name: String = ItemDatabase.get_item_name(item_id)

		var row := HBoxContainer.new()
		_shop_list.add_child(row)

		var label := Label.new()
		label.text = "%s x%d (%dg)" % [item_name, count, price]
		label.add_theme_font_size_override("font_size", 13)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var btn := Button.new()
		btn.text = "Buy"
		btn.disabled = gold < price or count <= 0
		btn.pressed.connect(_buy_item.bind(item_id))
		row.add_child(btn)

func _buy_item(item_id: String) -> void:
	if not _vendor or not _player:
		return
	var vending_comp: Node = _vendor.get_node_or_null("VendingComponent")
	if not vending_comp:
		return
	vending_comp.buy_from(_player, item_id, 1)
	_refresh()

func is_open() -> bool:
	return _is_open
