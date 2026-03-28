extends Control
## Shop UI — three-column list with keyboard navigation. Left: vendor wares. Center: cart. Right: actions.
## Anchored above the dialogue box. No title bar, no drag handle.
## Keyboard: WS navigate within column, AD switch columns, Enter/Space confirm, X/Backspace remove last.

const ItemDatabase = preload("res://scripts/data/item_database.gd")

signal shop_closed
signal cart_changed(total: int)

var _panel: PanelContainer
var _wares_vbox: VBoxContainer
var _cart_vbox: VBoxContainer
var _total_label: Label
var _cart: Dictionary = {}  # {item_id: count}
var _is_open: bool = false
var _player: Node
var _vendor: Node = null
var _discount: float = 0.0

# Column navigation state
var _active_column: int = 0   # 0=merchant, 1=cart, 2=actions
var _merchant_idx: int = 0
var _cart_idx: int = 0
var _action_idx: int = 0      # 0=Buy, 1=Close
var _merchant_rows: Array = []
var _cart_rows: Array = []
var _merchant_item_ids: Array = []
var _cart_item_ids: Array = []
var _action_buttons: Array = []
var _buy_button: Button
var _close_button: Button


func _ready() -> void:
	visible = false
	_build_ui()
	_position_panel()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	margin.add_child(hbox)

	# --- Left column: Wares ---
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 8)
	hbox.add_child(left_col)

	var wares_header := Label.new()
	wares_header.text = "Merchant Wares"
	wares_header.add_theme_font_override("font", UIHelper.GAME_FONT_DISPLAY)
	wares_header.add_theme_font_size_override("font_size", 13)
	wares_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	left_col.add_child(wares_header)

	var wares_scroll := ScrollContainer.new()
	wares_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wares_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_col.add_child(wares_scroll)

	_wares_vbox = VBoxContainer.new()
	_wares_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wares_vbox.add_theme_constant_override("separation", 4)
	wares_scroll.add_child(_wares_vbox)

	# --- Separator ---
	var sep := VSeparator.new()
	sep.add_theme_constant_override("separation", 12)
	sep.add_theme_color_override("color", Color(0.5, 0.45, 0.3, 0.6))
	hbox.add_child(sep)

	# --- Center column: Cart ---
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 8)
	hbox.add_child(right_col)

	var cart_header := Label.new()
	cart_header.text = "Your Cart"
	cart_header.add_theme_font_override("font", UIHelper.GAME_FONT_DISPLAY)
	cart_header.add_theme_font_size_override("font_size", 13)
	cart_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	right_col.add_child(cart_header)

	var cart_scroll := ScrollContainer.new()
	cart_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cart_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(cart_scroll)

	_cart_vbox = VBoxContainer.new()
	_cart_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cart_vbox.add_theme_constant_override("separation", 4)
	cart_scroll.add_child(_cart_vbox)

	_total_label = Label.new()
	_total_label.text = "Total: 0g"
	_total_label.add_theme_font_override("font", UIHelper.GAME_FONT)
	_total_label.add_theme_font_size_override("font_size", 13)
	_total_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_col.add_child(_total_label)

	# --- Separator ---
	var sep2 := VSeparator.new()
	sep2.add_theme_constant_override("separation", 12)
	sep2.add_theme_color_override("color", Color(0.5, 0.45, 0.3, 0.6))
	hbox.add_child(sep2)

	# --- Right column: Actions ---
	var action_col := VBoxContainer.new()
	action_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_col.custom_minimum_size = Vector2(140, 0)
	action_col.add_theme_constant_override("separation", 12)
	hbox.add_child(action_col)

	var action_header := Label.new()
	action_header.text = "Actions"
	action_header.add_theme_font_override("font", UIHelper.GAME_FONT_DISPLAY)
	action_header.add_theme_font_size_override("font_size", 13)
	action_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	action_col.add_child(action_header)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.09, 0.07, 0.8)
	btn_style.border_color = Color(0.5, 0.45, 0.3, 0.6)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(3)
	btn_style.set_content_margin_all(6)

	_buy_button = Button.new()
	_buy_button.text = "Buy (0g)"
	_buy_button.disabled = true
	_buy_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buy_button.focus_mode = Control.FOCUS_NONE
	_buy_button.add_theme_stylebox_override("normal", btn_style.duplicate())
	_buy_button.add_theme_stylebox_override("disabled", btn_style.duplicate())
	_buy_button.add_theme_stylebox_override("hover", btn_style.duplicate())
	_buy_button.add_theme_stylebox_override("pressed", btn_style.duplicate())
	_buy_button.add_theme_font_override("font", UIHelper.GAME_FONT)
	_buy_button.add_theme_font_size_override("font_size", 13)
	_buy_button.add_theme_color_override("font_color", Color(0.92, 0.89, 0.82))
	_buy_button.add_theme_color_override("font_color_disabled", Color(0.5, 0.48, 0.42))
	action_col.add_child(_buy_button)

	_close_button = Button.new()
	_close_button.text = "Close Shop"
	_close_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.add_theme_stylebox_override("normal", btn_style.duplicate())
	_close_button.add_theme_stylebox_override("disabled", btn_style.duplicate())
	_close_button.add_theme_stylebox_override("hover", btn_style.duplicate())
	_close_button.add_theme_stylebox_override("pressed", btn_style.duplicate())
	_close_button.add_theme_font_override("font", UIHelper.GAME_FONT)
	_close_button.add_theme_font_size_override("font_size", 13)
	_close_button.add_theme_color_override("font_color", Color(0.92, 0.89, 0.82))
	action_col.add_child(_close_button)

	_action_buttons = [_buy_button, _close_button]


func _position_panel() -> void:
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 270
	_panel.offset_right = -40
	_panel.offset_top = -480
	_panel.offset_bottom = -20


# --- Public API ---

func set_player(p: Node) -> void:
	_player = p


func open_shop(vendor: Node) -> void:
	_vendor = vendor
	_cart.clear()
	_active_column = 0
	_merchant_idx = 0
	_cart_idx = 0
	_action_idx = 0
	_is_open = true
	visible = true
	AudioManager.play_ui_sfx("ui_panel_open")
	_cache_discount()
	_refresh_wares()
	_refresh_cart()


func close_shop() -> void:
	_is_open = false
	visible = false
	_vendor = null
	_cart.clear()
	_discount = 0.0
	shop_closed.emit()


func is_open() -> bool:
	return _is_open


func get_cart() -> Dictionary:
	return _cart


func get_cart_total() -> int:
	if not _vendor:
		return 0
	var vending_comp: Node = _vendor.get_node_or_null("VendingComponent")
	if not vending_comp:
		return 0
	var listings: Dictionary = vending_comp.get_listings()
	var total: int = 0
	for item_id: String in _cart:
		var listing: Dictionary = listings.get(item_id, {})
		var base_price: int = listing.get("price", 0)
		var discounted_price: int = maxi(1, ceili(base_price * (1.0 - _discount)))
		total += discounted_price * _cart[item_id]
	return total


func clear_cart() -> void:
	_cart.clear()
	_refresh_cart()
	_update_total()
	cart_changed.emit(0)


func purchase_cart() -> bool:
	if not _vendor or not _player:
		return false
	var vending_comp: Node = _vendor.get_node_or_null("VendingComponent")
	if not vending_comp:
		return false

	var purchased_any: bool = false
	for item_id: String in _cart.duplicate():
		var count: int = _cart[item_id]
		var ok: bool = vending_comp.buy_from(_player, item_id, count)
		if ok:
			purchased_any = true

	if purchased_any:
		AudioManager.play_ui_sfx("ui_buy_sell")
		if _player:
			var prog: Node = _player.get_node_or_null("ProgressionComponent")
			if prog:
				prog.grant_proficiency_xp("persuasion", 3)

	_cart.clear()
	_refresh_wares()
	_refresh_cart()
	return purchased_any


# --- Keyboard navigation ---

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_W:
			if _active_column == 0 and _merchant_idx > 0:
				_merchant_idx -= 1
				_update_highlight()
				get_viewport().set_input_as_handled()
			elif _active_column == 1 and _cart_idx > 0:
				_cart_idx -= 1
				_update_highlight()
				get_viewport().set_input_as_handled()
			elif _active_column == 2 and _action_idx > 0:
				_action_idx -= 1
				_update_action_highlight()
				get_viewport().set_input_as_handled()
		KEY_S:
			if _active_column == 0 and _merchant_idx < _merchant_rows.size() - 1:
				_merchant_idx += 1
				_update_highlight()
				get_viewport().set_input_as_handled()
			elif _active_column == 1 and _cart_idx < _cart_rows.size() - 1:
				_cart_idx += 1
				_update_highlight()
				get_viewport().set_input_as_handled()
			elif _active_column == 2 and _action_idx < _action_buttons.size() - 1:
				_action_idx += 1
				_update_action_highlight()
				get_viewport().set_input_as_handled()
		KEY_A:
			if _active_column > 0:
				_active_column -= 1
				_update_highlight()
			get_viewport().set_input_as_handled()
		KEY_D:
			if _active_column < 2:
				_active_column += 1
				_update_highlight()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _active_column == 0 and _merchant_idx < _merchant_item_ids.size():
				_add_to_cart(_merchant_item_ids[_merchant_idx])
				get_viewport().set_input_as_handled()
			elif _active_column == 1 and _cart_idx < _cart_item_ids.size():
				_remove_from_cart(_cart_item_ids[_cart_idx])
				get_viewport().set_input_as_handled()
			elif _active_column == 2:
				_execute_action(_action_idx)
				get_viewport().set_input_as_handled()
		KEY_X, KEY_BACKSPACE:
			_remove_last_from_cart()
			get_viewport().set_input_as_handled()


func _execute_action(idx: int) -> void:
	if idx == 0:
		# Buy
		if not _buy_button.disabled:
			var ok: bool = purchase_cart()
			if ok:
				close_shop()
	elif idx == 1:
		# Close
		close_shop()


# --- Cart operations ---

func _add_to_cart(item_id: String) -> void:
	if not _vendor:
		return
	var vending_comp: Node = _vendor.get_node_or_null("VendingComponent")
	if not vending_comp:
		return
	var listings: Dictionary = vending_comp.get_listings()
	var listing: Dictionary = listings.get(item_id, {})
	var available_stock: int = listing.get("count", 0)
	var already_in_cart: int = _cart.get(item_id, 0)
	if already_in_cart >= available_stock:
		return
	_cart[item_id] = already_in_cart + 1
	_refresh_cart()
	_update_total()
	cart_changed.emit(get_cart_total())


func _remove_from_cart(item_id: String) -> void:
	if not _cart.has(item_id):
		return
	_cart[item_id] -= 1
	if _cart[item_id] <= 0:
		_cart.erase(item_id)
	_refresh_cart()
	_update_total()
	cart_changed.emit(get_cart_total())


func _remove_last_from_cart() -> void:
	if _cart.is_empty():
		return
	var last_id: String = _cart.keys().back()
	_remove_from_cart(last_id)


# --- Discount helpers ---

func _cache_discount() -> void:
	_discount = 0.0
	if not _vendor or not _player:
		return
	var vending_comp: Node = _vendor.get_node_or_null("VendingComponent")
	if not vending_comp:
		return
	_discount = vending_comp.get_discount_for("player")


# --- Refresh helpers ---

func _refresh_wares() -> void:
	for child in _wares_vbox.get_children():
		child.queue_free()
	_merchant_rows.clear()
	_merchant_item_ids.clear()

	if not _vendor:
		return
	var vending_comp: Node = _vendor.get_node_or_null("VendingComponent")
	if not vending_comp:
		return

	var listings: Dictionary = vending_comp.get_listings()
	for item_id: String in listings:
		var listing: Dictionary = listings[item_id]
		if listing.get("count", 0) <= 0:
			continue
		var base_price: int = listing.get("price", 0)
		var stock: int = listing.get("count", 0)
		var row: PanelContainer = _create_wares_row(item_id, stock, base_price)
		_wares_vbox.add_child(row)
		_merchant_rows.append(row)
		_merchant_item_ids.append(item_id)

	_merchant_idx = clampi(_merchant_idx, 0, maxi(0, _merchant_rows.size() - 1))
	_update_highlight()


func _refresh_cart() -> void:
	for child in _cart_vbox.get_children():
		child.queue_free()
	_cart_rows.clear()
	_cart_item_ids.clear()

	if not _vendor:
		_update_total()
		return
	var vending_comp: Node = _vendor.get_node_or_null("VendingComponent")
	if not vending_comp:
		_update_total()
		return
	var listings: Dictionary = vending_comp.get_listings()

	for item_id: String in _cart:
		var listing: Dictionary = listings.get(item_id, {})
		var base_price: int = listing.get("price", 0)
		var row: PanelContainer = _create_cart_row(item_id, _cart[item_id], base_price)
		_cart_vbox.add_child(row)
		_cart_rows.append(row)
		_cart_item_ids.append(item_id)

	_cart_idx = clampi(_cart_idx, 0, maxi(0, _cart_rows.size() - 1))
	_update_total()
	_update_highlight()


func _update_total() -> void:
	var total: int = get_cart_total()
	_total_label.text = "Total: %dg" % total

	_buy_button.text = "Buy (%dg)" % total
	_buy_button.disabled = total <= 0

	if _player and total > 0:
		var inv: Node = _player.get_node_or_null("InventoryComponent")
		if inv and inv.get_gold_amount() < total:
			_buy_button.disabled = true

	_update_action_highlight()


# --- Row highlight ---

func _update_highlight() -> void:
	for row in _merchant_rows:
		_set_row_style(row, false)
	for row in _cart_rows:
		_set_row_style(row, false)

	if _active_column == 0 and _merchant_idx < _merchant_rows.size():
		_set_row_style(_merchant_rows[_merchant_idx], true)
	elif _active_column == 1 and _cart_idx < _cart_rows.size():
		_set_row_style(_cart_rows[_cart_idx], true)

	_update_action_highlight()


func _update_action_highlight() -> void:
	for i in _action_buttons.size():
		var btn: Button = _action_buttons[i]
		if _active_column == 2 and i == _action_idx:
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			btn.add_theme_color_override("font_color", Color(0.92, 0.89, 0.82))


func _set_row_style(row: PanelContainer, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	if selected:
		style.bg_color = Color(0.2, 0.17, 0.1, 0.9)
		style.border_color = Color(1.0, 0.85, 0.2, 0.8)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0.1, 0.09, 0.07, 0.6)
		style.border_color = Color(0, 0, 0, 0)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4)
	row.add_theme_stylebox_override("panel", style)


# --- Row builders ---

func _create_wares_row(item_id: String, stock: int, price: int) -> PanelContainer:
	var item_data: Dictionary = ItemDatabase.get_item(item_id)
	var item_name: String = item_data.get("name", item_id)
	var discounted_price: int = maxi(1, ceili(price * (1.0 - _discount)))

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 28)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	row.add_child(inner)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", UIHelper.GAME_FONT)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.89, 0.82))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_label)

	var price_label := Label.new()
	price_label.text = "%dg" % discounted_price
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.add_theme_font_override("font", UIHelper.GAME_FONT)
	price_label.add_theme_font_size_override("font_size", 12)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(price_label)

	var stock_label := Label.new()
	stock_label.text = "x%d" % stock
	stock_label.custom_minimum_size = Vector2(30, 0)
	stock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stock_label.add_theme_font_override("font", UIHelper.GAME_FONT)
	stock_label.add_theme_font_size_override("font_size", 11)
	stock_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55, 0.8))
	stock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(stock_label)

	_set_row_style(row, false)
	return row


func _create_cart_row(item_id: String, count: int, price: int) -> PanelContainer:
	var item_data: Dictionary = ItemDatabase.get_item(item_id)
	var item_name: String = item_data.get("name", item_id)
	var discounted_price: int = maxi(1, ceili(price * (1.0 - _discount)))
	var line_total: int = discounted_price * count

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 28)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	row.add_child(inner)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", UIHelper.GAME_FONT)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.89, 0.82))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_label)

	var count_label := Label.new()
	count_label.text = "x%d" % count
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_override("font", UIHelper.GAME_FONT)
	count_label.add_theme_font_size_override("font_size", 11)
	count_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55, 0.8))
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(count_label)

	var total_label := Label.new()
	total_label.text = "%dg" % line_total
	total_label.custom_minimum_size = Vector2(40, 0)
	total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_label.add_theme_font_override("font", UIHelper.GAME_FONT)
	total_label.add_theme_font_size_override("font_size", 12)
	total_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	total_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(total_label)

	_set_row_style(row, false)
	return row
