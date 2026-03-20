extends Control
## Crafting panel — two-column layout (recipe list | detail + craft button).
## Opened by the player when they interact with a crafting station.

const RecipeDatabase = preload("res://scripts/data/recipe_database.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

var _panel: PanelContainer
var _is_open: bool = false

var _player: Node
var _inventory: Node
var _progression: Node

# Current station context.
var _skill_id: String = ""
var _station_name: String = ""

# All recipe IDs for the active skill_id.
var _recipe_ids: Array = []
var _selected_recipe_id: String = ""

# Left sidebar widgets (rebuilt each open/refresh).
var _sidebar: VBoxContainer

# Right detail widgets.
var _detail_vbox: VBoxContainer
var _craft_btn: Button
var _craft_feedback_tween: Tween


func _ready() -> void:
	visible = false
	_build_ui()


func set_player(p: Node) -> void:
	_player = p
	if _player:
		_inventory = _player.get_node_or_null("InventoryComponent")
		_progression = _player.get_node_or_null("ProgressionComponent")


func open(skill_id: String, sname: String) -> void:
	_skill_id = skill_id
	_station_name = sname
	_recipe_ids = RecipeDatabase.get_recipes_for_skill(skill_id)
	_selected_recipe_id = _recipe_ids[0] if not _recipe_ids.is_empty() else ""

	_is_open = true
	visible = true
	AudioManager.play_ui_sfx("ui_panel_open")
	UIHelper.center_panel(_panel)
	_refresh_title()
	_refresh_sidebar()
	_refresh_detail()


func close() -> void:
	_is_open = false
	visible = false
	AudioManager.play_ui_sfx("ui_panel_close")


func is_open() -> bool:
	return _is_open


# --- UI construction ---

func _build_ui() -> void:
	var ui: Dictionary = UIHelper.create_titled_panel("Crafting", Vector2(420, 350), close)
	_panel = ui["panel"]
	add_child(_panel)

	var vbox: VBoxContainer = ui["vbox"]
	vbox.add_child(HSeparator.new())

	# Main body: left sidebar + separator + right detail.
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 0)
	vbox.add_child(hbox)

	# Left sidebar in a scroll container.
	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.custom_minimum_size = Vector2(150, 0)
	sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(sidebar_scroll)

	var sidebar_margin := MarginContainer.new()
	sidebar_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_margin.add_theme_constant_override("margin_left", 4)
	sidebar_margin.add_theme_constant_override("margin_right", 4)
	sidebar_margin.add_theme_constant_override("margin_top", 4)
	sidebar_margin.add_theme_constant_override("margin_bottom", 4)
	sidebar_scroll.add_child(sidebar_margin)

	_sidebar = VBoxContainer.new()
	_sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar.add_theme_constant_override("separation", 3)
	sidebar_margin.add_child(_sidebar)

	hbox.add_child(VSeparator.new())

	# Right detail area.
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(right_scroll)

	var right_margin := MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 12)
	right_margin.add_theme_constant_override("margin_right", 12)
	right_margin.add_theme_constant_override("margin_top", 10)
	right_margin.add_theme_constant_override("margin_bottom", 10)
	right_scroll.add_child(right_margin)

	_detail_vbox = VBoxContainer.new()
	_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_theme_constant_override("separation", 6)
	right_margin.add_child(_detail_vbox)


func _refresh_title() -> void:
	var vbox: VBoxContainer = _panel.get_child(0) as VBoxContainer
	if not vbox:
		return
	for child in vbox.get_children():
		if child is DragHandle:
			child.set_title(_station_name)
			return


func _refresh_sidebar() -> void:
	for child in _sidebar.get_children():
		child.queue_free()

	for recipe_id in _recipe_ids:
		_sidebar.add_child(_build_sidebar_entry(recipe_id))


func _build_sidebar_entry(recipe_id: String) -> Control:
	var recipe: Dictionary = RecipeDatabase.get_recipe(recipe_id)
	var name_text: String = recipe.get("name", recipe_id)
	var required_level: int = recipe.get("required_level", 1)
	var is_selected: bool = recipe_id == _selected_recipe_id

	var player_level: int = 1
	if _progression:
		player_level = _progression.get_proficiency_level(_skill_id)

	var level_locked: bool = player_level < required_level

	# Wrapper as a clickable row.
	var wrapper := PanelContainer.new()
	wrapper.custom_minimum_size = Vector2(0, 28)
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg_style := StyleBoxFlat.new()
	if is_selected:
		bg_style.bg_color = Color(0.18, 0.15, 0.08, 0.9)
		bg_style.set_border_width_all(1)
		bg_style.border_color = UIHelper.COLOR_GOLD
	else:
		bg_style.bg_color = Color(0.12, 0.11, 0.09, 0.7)
		bg_style.set_border_width_all(1)
		bg_style.border_color = Color(0.3, 0.28, 0.22, 0.5)
	UIHelper.set_corner_radius(bg_style, 3)
	wrapper.add_theme_stylebox_override("panel", bg_style)
	wrapper.set_meta("bg_style", bg_style)
	wrapper.set_meta("is_selected", is_selected)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	wrapper.add_child(margin)

	var name_label := Label.new()
	name_label.text = name_text
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if level_locked:
		name_label.add_theme_color_override("font_color", UIHelper.COLOR_DISABLED)
	elif is_selected:
		name_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	else:
		name_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	row.add_child(name_label)

	wrapper.mouse_entered.connect(_on_sidebar_hover.bind(wrapper, true))
	wrapper.mouse_exited.connect(_on_sidebar_hover.bind(wrapper, false))
	wrapper.gui_input.connect(_on_sidebar_click.bind(recipe_id))

	return wrapper


func _on_sidebar_hover(wrapper: PanelContainer, hovered: bool) -> void:
	var bg_style: StyleBoxFlat = wrapper.get_meta("bg_style") as StyleBoxFlat
	var is_selected: bool = wrapper.get_meta("is_selected") as bool
	if not bg_style or is_selected:
		return
	if hovered:
		bg_style.bg_color = Color(0.18, 0.16, 0.1, 0.85)
		bg_style.border_color = Color(0.5, 0.45, 0.3, 0.7)
	else:
		bg_style.bg_color = Color(0.12, 0.11, 0.09, 0.7)
		bg_style.border_color = Color(0.3, 0.28, 0.22, 0.5)


func _on_sidebar_click(event: InputEvent, recipe_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected_recipe_id = recipe_id
		_refresh_sidebar()
		_refresh_detail()


# --- Detail panel ---

func _refresh_detail() -> void:
	for child in _detail_vbox.get_children():
		child.queue_free()
	_craft_btn = null

	if _selected_recipe_id.is_empty():
		var placeholder := Label.new()
		placeholder.text = "Select a recipe."
		placeholder.add_theme_font_size_override("font_size", 12)
		placeholder.add_theme_color_override("font_color", UIHelper.COLOR_DISABLED)
		_detail_vbox.add_child(placeholder)
		return

	var recipe: Dictionary = RecipeDatabase.get_recipe(_selected_recipe_id)
	if recipe.is_empty():
		return

	var required_level: int = recipe.get("required_level", 1)
	var player_level: int = 1
	if _progression:
		player_level = _progression.get_proficiency_level(_skill_id)
	var level_met: bool = player_level >= required_level

	# Recipe name header.
	var name_label := Label.new()
	name_label.text = recipe.get("name", _selected_recipe_id)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", UIHelper.COLOR_HEADER)
	_detail_vbox.add_child(name_label)

	_detail_vbox.add_child(HSeparator.new())

	# Requires section.
	var req_header := Label.new()
	req_header.text = "Requires:"
	req_header.add_theme_font_size_override("font_size", 12)
	req_header.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	_detail_vbox.add_child(req_header)

	var inputs: Dictionary = recipe.get("inputs", {})
	var all_inputs_met: bool = true
	for item_id in inputs:
		var needed: int = inputs[item_id]
		var have: int = 0
		if _inventory:
			have = _inventory.get_item_count(item_id)
		var has_enough: bool = have >= needed

		if not has_enough:
			all_inputs_met = false

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_detail_vbox.add_child(row)

		var indent := Label.new()
		indent.text = "  "
		indent.add_theme_font_size_override("font_size", 12)
		row.add_child(indent)

		var item_label := Label.new()
		if has_enough:
			item_label.text = "%s x%d  v" % [item_id.capitalize().replace("_", " "), needed]
			item_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		else:
			item_label.text = "%s x%d  (have %d)  x" % [item_id.capitalize().replace("_", " "), needed, have]
			item_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		item_label.add_theme_font_size_override("font_size", 12)
		row.add_child(item_label)

	_detail_vbox.add_child(HSeparator.new())

	# Produces section.
	var prod_header := Label.new()
	prod_header.text = "Produces:"
	prod_header.add_theme_font_size_override("font_size", 12)
	prod_header.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	_detail_vbox.add_child(prod_header)

	var outputs: Dictionary = recipe.get("outputs", {})
	for item_id in outputs:
		var count: int = outputs[item_id]
		var out_row := HBoxContainer.new()
		out_row.add_theme_constant_override("separation", 4)
		_detail_vbox.add_child(out_row)

		var indent := Label.new()
		indent.text = "  "
		indent.add_theme_font_size_override("font_size", 12)
		out_row.add_child(indent)

		var out_label := Label.new()
		out_label.text = "%s x%d" % [item_id.capitalize().replace("_", " "), count]
		out_label.add_theme_font_size_override("font_size", 12)
		out_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
		out_row.add_child(out_label)

	_detail_vbox.add_child(HSeparator.new())

	# XP and skill level row.
	var xp_label := Label.new()
	var xp_amount: int = recipe.get("xp", 0)
	xp_label.text = "XP: %d" % xp_amount
	xp_label.add_theme_font_size_override("font_size", 12)
	xp_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	_detail_vbox.add_child(xp_label)

	var skill_row := HBoxContainer.new()
	skill_row.add_theme_constant_override("separation", 4)
	_detail_vbox.add_child(skill_row)

	var skill_label := Label.new()
	skill_label.text = "Skill Level: %d / %d" % [player_level, required_level]
	skill_label.add_theme_font_size_override("font_size", 12)
	if level_met:
		skill_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	else:
		skill_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	skill_row.add_child(skill_label)

	# Spacer to push craft button to bottom.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_child(spacer)

	# Craft button.
	_craft_btn = Button.new()
	_craft_btn.text = "Craft"
	_craft_btn.custom_minimum_size = Vector2(0, 32)
	_craft_btn.add_theme_font_size_override("font_size", 14)

	var can_craft: bool = level_met and all_inputs_met
	_craft_btn.disabled = not can_craft
	_apply_craft_btn_style(can_craft)
	_craft_btn.pressed.connect(_on_craft_pressed)
	_detail_vbox.add_child(_craft_btn)


func _apply_craft_btn_style(enabled: bool) -> void:
	if not _craft_btn:
		return
	if enabled:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.6, 0.45, 0.05)
		style.border_color = UIHelper.COLOR_GOLD
		style.set_border_width_all(1)
		UIHelper.set_corner_radius(style, 4)
		_craft_btn.add_theme_stylebox_override("normal", style)
		_craft_btn.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	else:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.18, 0.18)
		style.border_color = Color(0.3, 0.3, 0.3)
		style.set_border_width_all(1)
		UIHelper.set_corner_radius(style, 4)
		_craft_btn.add_theme_stylebox_override("normal", style)
		_craft_btn.add_theme_color_override("font_color", UIHelper.COLOR_DISABLED)


# --- Crafting logic ---

func _on_craft_pressed() -> void:
	if not _player or not _inventory or not _progression:
		return

	var recipe: Dictionary = RecipeDatabase.get_recipe(_selected_recipe_id)
	if recipe.is_empty():
		return

	# Double-check requirements before consuming items.
	var required_level: int = recipe.get("required_level", 1)
	var player_level: int = _progression.get_proficiency_level(_skill_id)
	if player_level < required_level:
		return

	var inputs: Dictionary = recipe.get("inputs", {})
	for item_id in inputs:
		var needed: int = inputs[item_id]
		if not _inventory.has_item(item_id, needed):
			return

	# Consume inputs.
	for item_id in inputs:
		_inventory.remove_item(item_id, inputs[item_id])

	# Add outputs.
	var outputs: Dictionary = recipe.get("outputs", {})
	for item_id in outputs:
		_inventory.add_item(item_id, outputs[item_id])

	# Grant XP.
	var xp: int = recipe.get("xp", 0)
	_progression.grant_proficiency_xp(_skill_id, xp)

	AudioManager.play_ui_sfx("ui_craft_complete")

	# Visual feedback: brief flash on the craft button.
	_flash_craft_btn()

	# Refresh so input counts update.
	_refresh_detail()


func _flash_craft_btn() -> void:
	if not _craft_btn:
		return
	if _craft_feedback_tween and _craft_feedback_tween.is_valid():
		_craft_feedback_tween.kill()

	var flash_style := StyleBoxFlat.new()
	flash_style.bg_color = Color(0.2, 0.8, 0.3)
	flash_style.border_color = Color(0.4, 1.0, 0.5)
	flash_style.set_border_width_all(1)
	UIHelper.set_corner_radius(flash_style, 4)
	_craft_btn.add_theme_stylebox_override("normal", flash_style)

	_craft_feedback_tween = get_tree().create_tween()
	_craft_feedback_tween.tween_interval(0.3)
	_craft_feedback_tween.tween_callback(func() -> void:
		if _craft_btn and is_instance_valid(_craft_btn):
			_apply_craft_btn_style(not _craft_btn.disabled)
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _is_open:
		close()
		get_viewport().set_input_as_handled()
