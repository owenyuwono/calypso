extends Control
## Shop UI — two-column grid with cart. Left: vendor wares. Right: cart with total.
## No title bar, no drag handle. Buy/Close driven by dialogue panel choices.

const ItemDatabase = preload("res://scripts/data/item_database.gd")

signal shop_closed
signal cart_changed(total: int)

const CELL_SIZE := 52
const GRID_COLUMNS := 4

# Type → background color for item cells
const TYPE_COLORS := {
	"consumable": Color(0.3, 0.55, 0.3),
	"material":   Color(0.5, 0.4, 0.25),
	"weapon":     Color(0.55, 0.3, 0.3),
	"armor":      Color(0.3, 0.35, 0.55),
}
const TYPE_COLOR_DEFAULT := Color(0.4, 0.4, 0.4)

var _panel: PanelContainer
var _wares_grid: GridContainer
var _cart_grid: GridContainer
var _total_label: Label
var _cart: Dictionary = {}  # {item_id: count}
var _is_open: bool = false
var _player: Node
var _vendor: Node = null


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(480, 300)
	_panel.add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	margin.add_child(hbox)

	# --- Left column: Wares ---
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 6)
	hbox.add_child(left_col)

	var wares_label := Label.new()
	wares_label.text = "Wares"
	wares_label.add_theme_font_override("font", UIHelper.GAME_FONT)
	wares_label.add_theme_font_size_override("font_size", 12)
	wares_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	left_col.add_child(wares_label)

	_wares_grid = GridContainer.new()
	_wares_grid.columns = GRID_COLUMNS
	_wares_grid.add_theme_constant_override("h_separation", 4)
	_wares_grid.add_theme_constant_override("v_separation", 4)
	left_col.add_child(_wares_grid)

	# --- Separator ---
	var sep := VSeparator.new()
	sep.add_theme_constant_override("separation", 12)
	sep.add_theme_color_override("color", Color(0.5, 0.45, 0.3, 0.6))
	hbox.add_child(sep)

	# --- Right column: Cart ---
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 6)
	hbox.add_child(right_col)

	var cart_label := Label.new()
	cart_label.text = "Your Cart"
	cart_label.add_theme_font_override("font", UIHelper.GAME_FONT)
	cart_label.add_theme_font_size_override("font_size", 12)
	cart_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	right_col.add_child(cart_label)

	_cart_grid = GridContainer.new()
	_cart_grid.columns = GRID_COLUMNS
	_cart_grid.add_theme_constant_override("h_separation", 4)
	_cart_grid.add_theme_constant_override("v_separation", 4)
	right_col.add_child(_cart_grid)

	_total_label = Label.new()
	_total_label.text = "Total: 0g"
	_total_label.add_theme_font_override("font", UIHelper.GAME_FONT)
	_total_label.add_theme_font_size_override("font_size", 13)
	_total_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_col.add_child(_total_label)


# --- Public API ---

func set_player(p: Node) -> void:
	_player = p


func open_shop(vendor: Node) -> void:
	_vendor = vendor
	_cart.clear()
	_is_open = true
	visible = true
	AudioManager.play_ui_sfx("ui_panel_open")
	UIHelper.center_panel(_panel)
	_refresh_wares()
	_refresh_cart()


func close_shop() -> void:
	_is_open = false
	visible = false
	_vendor = null
	_cart.clear()
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
		var price: int = listing.get("price", 0)
		total += price * _cart[item_id]
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

	_cart.clear()
	_refresh_wares()
	_refresh_cart()
	return purchased_any


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


# --- Refresh helpers ---

func _refresh_wares() -> void:
	for child in _wares_grid.get_children():
		child.queue_free()

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
		var cell: Control = _create_item_cell(item_id, listing.get("count", 0), listing.get("price", 0), false)
		_wares_grid.add_child(cell)


func _refresh_cart() -> void:
	for child in _cart_grid.get_children():
		child.queue_free()

	if not _vendor:
		return
	var vending_comp: Node = _vendor.get_node_or_null("VendingComponent")
	if not vending_comp:
		return
	var listings: Dictionary = vending_comp.get_listings()

	for item_id: String in _cart:
		var listing: Dictionary = listings.get(item_id, {})
		var price: int = listing.get("price", 0)
		var cell: Control = _create_item_cell(item_id, _cart[item_id], price, true)
		_cart_grid.add_child(cell)


func _update_total() -> void:
	_total_label.text = "Total: %dg" % get_cart_total()


# --- Cell builder ---

func _create_item_cell(item_id: String, count: int, price: int, is_cart: bool) -> Control:
	var item_data: Dictionary = ItemDatabase.get_item(item_id)
	var item_name: String = item_data.get("name", item_id)
	var item_type: String = item_data.get("type", "")

	var bg_color: Color = TYPE_COLORS.get(item_type, TYPE_COLOR_DEFAULT)

	# Outer container sized to CELL_SIZE
	var container := Panel.new()
	container.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)

	var bg_style := UIHelper.create_style_box(bg_color, Color(0.8, 0.7, 0.5, 0.5), 3, 1)
	container.add_theme_stylebox_override("panel", bg_style)

	container.tooltip_text = "%s\n%dg each" % [item_name, price]
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Letter label centered
	var letter_label := Label.new()
	letter_label.text = item_name.left(1).to_upper()
	letter_label.add_theme_font_override("font", UIHelper.GAME_FONT_BOLD)
	letter_label.add_theme_font_size_override("font_size", 18)
	letter_label.add_theme_color_override("font_color", Color.WHITE)
	letter_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	letter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(letter_label)

	# Count label bottom-right
	var count_label := Label.new()
	count_label.text = "x%d" % count
	count_label.add_theme_font_override("font", UIHelper.GAME_FONT)
	count_label.add_theme_font_size_override("font_size", 11)
	count_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	count_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.offset_left = -28
	count_label.offset_top = -16
	count_label.offset_right = -2
	count_label.offset_bottom = -2
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(count_label)

	# Click handler
	if is_cart:
		container.gui_input.connect(_on_cell_input.bind(item_id, true))
	else:
		container.gui_input.connect(_on_cell_input.bind(item_id, false))

	return container


func _on_cell_input(event: InputEvent, item_id: String, is_cart: bool) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_cart:
			_remove_from_cart(item_id)
		else:
			_add_to_cart(item_id)
