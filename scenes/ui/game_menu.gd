extends Control
## BotW-style full-screen menu with a horizontal tab bar.
## Builds its entire scene tree in code.

enum Tab { STATUS, INVENTORY, SYSTEM }

const TAB_NAMES: Array = ["Status", "Inventory", "System"]

# Panel builder scripts — one per Tab enum value
const StatusPanel = preload("res://scenes/ui/status_panel.gd")
const InventoryPanel = preload("res://scenes/ui/inventory_panel.gd")
const SettingsPanel = preload("res://scenes/ui/settings_panel.gd")

# Styling constants
const _COLOR_TAB_BG_INACTIVE := Color(0.12, 0.1, 0.08, 0.9)
const _COLOR_TAB_BG_ACTIVE := Color(0.25, 0.2, 0.1, 0.95)
const _COLOR_BORDER_INACTIVE := Color(0.4, 0.35, 0.2)
const _COLOR_BORDER_ACTIVE := Color(1.0, 0.85, 0.3)
const _TAB_BUTTON_MIN_SIZE := Vector2(120, 40)

var _player: Node
var _last_active_tab: int = Tab.STATUS
var _builders_ready: bool = false

# Indexed by Tab enum
var _content_containers: Array[Control] = []
# Content builder nodes (one per tab, indexed by Tab enum)
var _builders: Array[Control] = []
# For tooltips/popups that need to render on top
var _overlay_container: Control

var _tab_buttons: Array[Button] = []
var _tab_bar: HBoxContainer
var _content_area: Control

# Cached tab button StyleBoxes to avoid per-frame allocation
var _tab_style_inactive: StyleBoxFlat
var _tab_style_active: StyleBoxFlat


func _ready() -> void:
	_build_tab_styles()
	_build_ui()
	visible = false


func _build_tab_styles() -> void:
	_tab_style_inactive = StyleBoxFlat.new()
	_tab_style_inactive.bg_color = _COLOR_TAB_BG_INACTIVE
	_tab_style_inactive.border_color = _COLOR_BORDER_INACTIVE
	UIHelper.set_border_width(_tab_style_inactive, 1)
	UIHelper.set_corner_radius(_tab_style_inactive, 4)

	_tab_style_active = StyleBoxFlat.new()
	_tab_style_active.bg_color = _COLOR_TAB_BG_ACTIVE
	_tab_style_active.border_color = _COLOR_BORDER_ACTIVE
	UIHelper.set_border_width(_tab_style_active, 2)
	UIHelper.set_corner_radius(_tab_style_active, 4)


func _build_ui() -> void:
	# Full-screen anchor
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	# --- Background overlay ---
	var bg_overlay := ColorRect.new()
	bg_overlay.name = "BGOverlay"
	bg_overlay.color = Color(0, 0, 0, 0.6)
	bg_overlay.anchor_left = 0.0
	bg_overlay.anchor_top = 0.0
	bg_overlay.anchor_right = 1.0
	bg_overlay.anchor_bottom = 1.0
	bg_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	bg_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg_overlay)

	# --- Main panel ---
	var main_panel := PanelContainer.new()
	main_panel.name = "MainPanel"
	main_panel.anchor_left = 0.0
	main_panel.anchor_top = 0.0
	main_panel.anchor_right = 1.0
	main_panel.anchor_bottom = 1.0
	main_panel.add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	add_child(main_panel)

	# --- VBox inside panel ---
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 0)
	main_panel.add_child(vbox)

	# --- Tab bar wrapper (adds vertical padding) ---
	var tab_bar_margin := MarginContainer.new()
	tab_bar_margin.name = "TabBarMargin"
	tab_bar_margin.add_theme_constant_override("margin_top", 8)
	tab_bar_margin.add_theme_constant_override("margin_bottom", 8)
	tab_bar_margin.add_theme_constant_override("margin_left", 0)
	tab_bar_margin.add_theme_constant_override("margin_right", 0)
	vbox.add_child(tab_bar_margin)

	# --- Tab bar ---
	_tab_bar = HBoxContainer.new()
	_tab_bar.name = "TabBar"
	_tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_bar.add_theme_constant_override("separation", 24)
	tab_bar_margin.add_child(_tab_bar)

	for i in TAB_NAMES.size():
		var btn := _create_tab_button(TAB_NAMES[i], i)
		_tab_bar.add_child(btn)
		_tab_buttons.append(btn)

	# --- Divider between tab bar and content ---
	var divider: ColorRect = ColorRect.new()
	divider.name = "TabDivider"
	divider.color = Color(0.6, 0.5, 0.2, 0.6)
	divider.custom_minimum_size = Vector2(0, 2)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(divider)

	# --- Content area ---
	_content_area = Control.new()
	_content_area.name = "ContentArea"
	_content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_content_area)

	# --- Content containers (one per tab) ---
	_content_containers.clear()
	for i in TAB_NAMES.size():
		var container := VBoxContainer.new()
		container.name = TAB_NAMES[i] + "Content"
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.anchor_left = 0.0
		container.anchor_top = 0.0
		container.anchor_right = 1.0
		container.anchor_bottom = 1.0
		container.grow_horizontal = Control.GROW_DIRECTION_BOTH
		container.grow_vertical = Control.GROW_DIRECTION_BOTH
		container.visible = (i == Tab.STATUS)
		_content_area.add_child(container)
		_content_containers.append(container)

	# --- Overlay container (for tooltips/popups on top) ---
	_overlay_container = Control.new()
	_overlay_container.name = "OverlayContainer"
	_overlay_container.anchor_left = 0.0
	_overlay_container.anchor_top = 0.0
	_overlay_container.anchor_right = 1.0
	_overlay_container.anchor_bottom = 1.0
	_overlay_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_overlay_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	_overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay_container)

	# Apply initial tab highlight
	_apply_tab_styles(_last_active_tab)


func _create_tab_button(label_text: String, index: int) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = _TAB_BUTTON_MIN_SIZE
	btn.add_theme_font_override("font", UIHelper.GAME_FONT_DISPLAY)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_stylebox_override("normal", _tab_style_inactive)
	btn.add_theme_stylebox_override("hover", _tab_style_inactive)
	btn.add_theme_stylebox_override("pressed", _tab_style_active)
	btn.add_theme_stylebox_override("focus", _tab_style_inactive)
	return btn


func set_player(player: Node) -> void:
	_player = player
	_setup_builders()


func _setup_builders() -> void:
	# Map Tab enum index to builder script
	var builder_scripts: Array = [
		StatusPanel,
		InventoryPanel,
		SettingsPanel,
	]

	for i in builder_scripts.size():
		var script: GDScript = builder_scripts[i]
		var builder: Control = Control.new()
		builder.set_script(script)
		builder.name = TAB_NAMES[i] + "Builder"
		add_child(builder)
		_builders.append(builder)

		if builder.has_method("set_player"):
			builder.set_player(_player)

	for i in _builders.size():
		var builder: Control = _builders[i]
		var container: Control = _content_containers[i]
		builder.build_content(container)

		# Wire overlay nodes (tooltips, popups, cursors) to the overlay container
		if builder.has_method("get_overlay_nodes"):
			var overlays: Array = builder.get_overlay_nodes()
			for overlay in overlays:
				if overlay:
					if overlay.get_parent():
						overlay.get_parent().remove_child(overlay)
					_overlay_container.add_child(overlay)

	_builders_ready = true


func open(tab_index: int = -1) -> void:
	visible = true
	var active_tab: int = tab_index if (tab_index >= 0 and tab_index < TAB_NAMES.size()) else _last_active_tab
	_last_active_tab = active_tab
	_show_tab_content(active_tab)
	_apply_tab_styles(active_tab)
	_refresh_active_builder(active_tab)
	_notify_builders_active(active_tab)
	AudioManager.play_ui_sfx("ui_panel_open")
	get_viewport().set_input_as_handled()


func close() -> void:
	_notify_builders_active(-1)
	visible = false
	AudioManager.play_ui_sfx("ui_panel_close")


func switch_tab(index: int) -> void:
	_last_active_tab = index
	_show_tab_content(index)
	_apply_tab_styles(index)
	_refresh_active_builder(index)
	_notify_builders_active(index)
	AudioManager.play_ui_sfx("ui_panel_open")


func is_open() -> bool:
	return visible


func _refresh_active_builder(index: int) -> void:
	if not _builders_ready:
		return
	if index < _builders.size() and _builders[index] and _builders[index].has_method("refresh"):
		_builders[index].refresh()


func _notify_builders_active(active_index: int) -> void:
	if not _builders_ready:
		return
	for i in _builders.size():
		if _builders[i] and _builders[i].has_method("set_active"):
			_builders[i].set_active(i == active_index)


func _show_tab_content(index: int) -> void:
	for i in _content_containers.size():
		_content_containers[i].visible = (i == index)


func _apply_tab_styles(active_index: int) -> void:
	for i in _tab_buttons.size():
		var btn: Button = _tab_buttons[i]
		if i == active_index:
			btn.add_theme_stylebox_override("normal", _tab_style_active)
			btn.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
		else:
			btn.add_theme_stylebox_override("normal", _tab_style_inactive)
			btn.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6))


func _input(event: InputEvent) -> void:
	# toggle_menu — always handle (open or close)
	if InputMap.has_action("toggle_menu") and event.is_action_pressed("toggle_menu"):
		if visible:
			close()
		else:
			# Don't open menu while dialogue is active
			var dialogue: Control = get_parent().get_node_or_null("DialoguePanel") if get_parent() else null
			if dialogue and dialogue.visible:
				return
			open()
		get_viewport().set_input_as_handled()
		return

	# Actions only processed when menu is open
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return

	# Tab navigation via Q/E keys
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			var next: int = (_last_active_tab + 1) % TAB_NAMES.size()
			switch_tab(next)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Q:
			var prev: int = (_last_active_tab - 1 + TAB_NAMES.size()) % TAB_NAMES.size()
			switch_tab(prev)
			get_viewport().set_input_as_handled()
