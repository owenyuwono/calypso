extends Control
## Shop UI — simple item list panel. No title bar, no drag, no gold display.
## Buy/Close actions are handled by dialogue panel choices, not shop buttons.

const ItemDatabase = preload("res://scripts/data/item_database.gd")

signal shop_closed

var _panel: PanelContainer
var _shop_list: VBoxContainer
var _is_open: bool = false
var _player: Node
var _vendor: Node = null


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(300, 280)

	var style := UIHelper.create_panel_style()
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var shop_scroll := ScrollContainer.new()
	shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(shop_scroll)

	_shop_list = VBoxContainer.new()
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_list.add_theme_constant_override("separation", 4)
	shop_scroll.add_child(_shop_list)


func set_player(p: Node) -> void:
	_player = p


func open_shop(vendor: Node) -> void:
	_vendor = vendor
	_is_open = true
	visible = true
	AudioManager.play_ui_sfx("ui_panel_open")
	UIHelper.center_panel(_panel)
	_refresh()


func close_shop() -> void:
	_is_open = false
	visible = false
	_vendor = null
	shop_closed.emit()


func is_open() -> bool:
	return _is_open


func _refresh() -> void:
	for child in _shop_list.get_children():
		child.queue_free()

	if not _player or not _vendor:
		return

	var inv_comp: Node = _player.get_node_or_null("InventoryComponent")
	if not inv_comp:
		return

	var vending_comp: Node = _vendor.get_node_or_null("VendingComponent")
	if not vending_comp:
		return

	var listings: Dictionary = vending_comp.get_listings()
	var player_gold: int = inv_comp.get_gold_amount()

	for item_id: String in listings:
		var listing: Dictionary = listings[item_id]
		var count: int = listing.get("count", 0)
		var price: int = listing.get("price", 0)
		if count <= 0:
			continue

		var item_data: Dictionary = ItemDatabase.get_item(item_id)
		var item_name: String = item_data.get("name", item_id)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_shop_list.add_child(row)

		# Item name
		var name_label := Label.new()
		name_label.text = item_name
		name_label.add_theme_font_override("font", UIHelper.GAME_FONT)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.87, 0.8))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		# Stock count
		var count_label := Label.new()
		count_label.text = "x%d" % count
		count_label.add_theme_font_override("font", UIHelper.GAME_FONT)
		count_label.add_theme_font_size_override("font_size", 13)
		count_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
		count_label.custom_minimum_size = Vector2(35, 0)
		row.add_child(count_label)

		# Price
		var price_label := Label.new()
		price_label.text = "%dg" % price
		price_label.add_theme_font_override("font", UIHelper.GAME_FONT)
		price_label.add_theme_font_size_override("font_size", 13)
		price_label.custom_minimum_size = Vector2(40, 0)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if player_gold >= price:
			price_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
		else:
			price_label.add_theme_color_override("font_color", Color(0.5, 0.4, 0.3))
		row.add_child(price_label)

		# Buy button
		var btn := Button.new()
		btn.text = "Buy"
		btn.disabled = player_gold < price or count <= 0
		btn.add_theme_font_override("font", UIHelper.GAME_FONT)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_buy_item.bind(item_id))
		row.add_child(btn)

	if listings.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No items available."
		empty_label.add_theme_font_override("font", UIHelper.GAME_FONT)
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
		_shop_list.add_child(empty_label)


func _buy_item(item_id: String) -> void:
	if not _vendor or not _player:
		return
	var vending_comp: Node = _vendor.get_node_or_null("VendingComponent")
	if not vending_comp:
		return
	vending_comp.buy_from(_player, item_id, 1)
	AudioManager.play_ui_sfx("ui_buy_sell")
	_refresh()
