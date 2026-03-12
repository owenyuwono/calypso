extends Control
## Bottom-center hotbar with 5 skill slots, cooldown overlays, and key labels.

const SkillDatabase = preload("res://scripts/data/skill_database.gd")

const SLOT_COUNT: int = 5
const SLOT_SIZE: float = 64.0
const SLOT_GAP: float = 4.0
const BOTTOM_MARGIN: float = 16.0

var _slots: Array = []  # Array of {panel, name_label, key_label, cooldown_overlay, cooldown_label, skill_id}
var _cooldowns: Dictionary = {}  # skill_id -> {remaining: float, total: float}
var _player: Node

func set_player(p: Node) -> void:
	_player = p
	refresh()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	refresh()
	GameEvents.skill_learned.connect(func(_a, _b, _c): refresh())

func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(SLOT_GAP))
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	# Position bottom-center
	var total_width := SLOT_COUNT * SLOT_SIZE + (SLOT_COUNT - 1) * SLOT_GAP
	hbox.anchor_left = 0.5
	hbox.anchor_right = 0.5
	hbox.anchor_top = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = -total_width * 0.5
	hbox.offset_right = total_width * 0.5
	hbox.offset_top = -(SLOT_SIZE + BOTTOM_MARGIN)
	hbox.offset_bottom = -BOTTOM_MARGIN

	for i in range(SLOT_COUNT):
		var slot_data := _create_slot(i)
		hbox.add_child(slot_data.panel)
		_slots.append(slot_data)

func _create_slot(index: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	style.border_color = Color(0.4, 0.35, 0.2)
	UIHelper.set_border_width(style, 1)
	UIHelper.set_corner_radius(style, 4)
	panel.add_theme_stylebox_override("panel", style)

	# Container for layering
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(container)

	# Skill name label (centered)
	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(name_label)

	# Key number label (bottom-right)
	var key_label := Label.new()
	key_label.text = str(index + 1)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	key_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	key_label.add_theme_font_size_override("font_size", 10)
	key_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(key_label)

	# Cooldown overlay (darkens from top)
	var cooldown_overlay := ColorRect.new()
	cooldown_overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	cooldown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_overlay.visible = false
	container.add_child(cooldown_overlay)

	# Cooldown timer text (centered)
	var cooldown_label := Label.new()
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cooldown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooldown_label.add_theme_font_size_override("font_size", 13)
	cooldown_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_label.visible = false
	container.add_child(cooldown_label)

	return {
		"panel": panel,
		"name_label": name_label,
		"key_label": key_label,
		"cooldown_overlay": cooldown_overlay,
		"cooldown_label": cooldown_label,
		"skill_id": "",
	}

func _process(delta: float) -> void:
	for skill_id in _cooldowns.keys():
		var cd: Dictionary = _cooldowns[skill_id]
		cd.remaining -= delta
		if cd.remaining <= 0.0:
			_cooldowns.erase(skill_id)

	# Update visuals for each slot
	for slot in _slots:
		var skill_id: String = slot.skill_id
		if skill_id.is_empty() or not _cooldowns.has(skill_id):
			slot.cooldown_overlay.visible = false
			slot.cooldown_label.visible = false
			continue
		var cd: Dictionary = _cooldowns[skill_id]
		var ratio: float = cd.remaining / cd.total
		slot.cooldown_overlay.visible = true
		# Dark overlay shrinks top-down (top pinned, bottom rises)
		slot.cooldown_overlay.anchor_top = 1.0 - ratio
		slot.cooldown_overlay.anchor_bottom = 1.0
		slot.cooldown_label.visible = true
		slot.cooldown_label.text = "%.1fs" % cd.remaining

func start_cooldown(skill_id: String, duration: float) -> void:
	_cooldowns[skill_id] = {"remaining": duration, "total": duration}

func is_on_cooldown(skill_id: String) -> bool:
	return _cooldowns.has(skill_id) and _cooldowns[skill_id].remaining > 0.0

func refresh() -> void:
	if not _player:
		return
	var skills_comp = _player.get_node("SkillsComponent")
	if not skills_comp:
		return
	var hotbar: Array = skills_comp.get_hotbar()
	for i in range(SLOT_COUNT):
		var skill_id: String = hotbar[i] if i < hotbar.size() else ""
		_slots[i].skill_id = skill_id
		if skill_id.is_empty():
			_slots[i].name_label.text = ""
		else:
			var skill := SkillDatabase.get_skill(skill_id)
			_slots[i].name_label.text = skill.get("name", skill_id)
