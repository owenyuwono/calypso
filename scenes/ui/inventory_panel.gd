extends Control
## Player inventory panel toggled with Tab.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const DragHandle = preload("res://scripts/utils/drag_handle.gd")

var _panel: PanelContainer
var _item_list: VBoxContainer
var _gold_label: Label
var _equipment_label: Label
var _is_open: bool = false

func _ready() -> void:
	visible = false
	_build_ui()
	GameEvents.item_looted.connect(func(_a, _b, _c): _refresh())

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(300, 400)

	var style := UIHelper.create_panel_style()
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)

	# Draggable title bar
	var drag_handle := DragHandle.new()
	drag_handle.setup(_panel, "Inventory")
	drag_handle.close_pressed.connect(_toggle)
	vbox.add_child(drag_handle)

	# Equipment section
	_equipment_label = Label.new()
	_equipment_label.add_theme_font_size_override("font_size", 14)
	_equipment_label.add_theme_color_override("font_color", UIHelper.COLOR_EQUIPMENT)
	vbox.add_child(_equipment_label)

	# Gold
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	vbox.add_child(_gold_label)

	# Separator
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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle()

func _toggle() -> void:
	_is_open = not _is_open
	visible = _is_open
	if _is_open:
		UIHelper.center_panel(_panel)
		_refresh()

func _refresh() -> void:
	if not _is_open:
		return

	# Clear old items
	for child in _item_list.get_children():
		child.queue_free()

	var data := WorldState.get_entity_data("player")
	var gold: int = data.get("gold", 0)
	_gold_label.text = "Gold: %d" % gold

	# Equipment info
	var equipment: Dictionary = data.get("equipment", {})
	var weapon: String = equipment.get("weapon", "")
	var armor: String = equipment.get("armor", "")
	var weapon_name := ItemDatabase.get_item_name(weapon) if not weapon.is_empty() else "(none)"
	var armor_name := ItemDatabase.get_item_name(armor) if not armor.is_empty() else "(none)"
	_equipment_label.text = "Weapon: %s | Armor: %s" % [weapon_name, armor_name]

	# Items
	var inv: Dictionary = WorldState.get_inventory("player")
	if inv.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No items"
		empty_label.add_theme_color_override("font_color", UIHelper.COLOR_DISABLED)
		_item_list.add_child(empty_label)
		return

	for item_id in inv:
		var count: int = inv[item_id]
		var item_data := ItemDatabase.get_item(item_id)
		var item_name: String = item_data.get("name", item_id)
		var item_type: String = item_data.get("type", "")

		var row := HBoxContainer.new()
		_item_list.add_child(row)

		var name_label := Label.new()
		name_label.text = "%s x%d" % [item_name, count]
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		# Use/Equip button
		if item_type == "consumable":
			var use_btn := Button.new()
			use_btn.text = "Use"
			use_btn.pressed.connect(_use_item.bind(item_id))
			row.add_child(use_btn)
		elif item_type in ["weapon", "armor"]:
			var equip_btn := Button.new()
			equip_btn.text = "Equip"
			equip_btn.pressed.connect(_equip_item.bind(item_id))
			row.add_child(equip_btn)

func _use_item(item_id: String) -> void:
	var item := ItemDatabase.get_item(item_id)
	if item.get("type", "") == "consumable" and WorldState.has_item("player", item_id):
		var heal_amount: int = item.get("heal", 0)
		if heal_amount > 0:
			WorldState.heal_entity("player", heal_amount)
		WorldState.remove_from_inventory("player", item_id)
		_refresh()

func _equip_item(item_id: String) -> void:
	if WorldState.equip_item("player", item_id):
		_refresh()

func is_open() -> bool:
	return _is_open
