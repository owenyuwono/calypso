extends Control
class_name ToastNotification
## Toast notification manager — slides in/out from the top-right of the screen.
## Handles a queue of toasts and stacks up to 3 visible at once.

const MAX_VISIBLE: int = 3
const TOAST_WIDTH: float = 250.0
const TOAST_HEIGHT: float = 60.0
const TOAST_GAP: float = 8.0
const SLIDE_DURATION: float = 0.3
const HOLD_DURATION: float = 3.0
const ANCHOR_Y: float = 270.0
const SCREEN_MARGIN: float = 10.0

const TIER_COLORS: Dictionary = {
	"stranger": Color("#888888"),
	"recognized": Color("#bbbbbb"),
	"acquaintance": Color("#ffdd66"),
	"friendly": Color("#66cc66"),
	"close": Color("#6688ff"),
	"bonded": Color("#cc66ff"),
}

const PROMOTION_PHRASES: Dictionary = {
	"recognized": "They've noticed you.",
	"acquaintance": "A familiar face now.",
	"friendly": "You've earned their trust.",
	"close": "A true companion.",
	"bonded": "An unbreakable bond.",
}

const DEMOTION_PHRASE_GENERAL: String = "Your relationship has cooled."
const DEMOTION_PHRASE_ATTACK: String = "Trust has been broken."

# Each entry: { title, subtitle, color }
var _queue: Array[Dictionary] = []
# Each entry: { panel, tween }
var _active_toasts: Array[Dictionary] = []


func _ready() -> void:
	# Control fills the whole screen passively — mouse passthrough
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	GameEvents.relationship_tier_changed.connect(_on_relationship_tier_changed)


# --- Public API ---

func show_toast(title: String, subtitle: String, color: Color = Color("#ffdd66")) -> void:
	_queue.append({"title": title, "subtitle": subtitle, "color": color})
	_flush_queue()


# --- Queue management ---

func _flush_queue() -> void:
	while _queue.size() > 0 and _active_toasts.size() < MAX_VISIBLE:
		var data: Dictionary = _queue.pop_front()
		_spawn_toast(data)


func _spawn_toast(data: Dictionary) -> void:
	var panel: PanelContainer = _build_toast_panel(data)
	add_child(panel)

	var slot: int = _active_toasts.size()
	_active_toasts.append({"panel": panel, "tween": null})

	_position_at_slot(panel, slot)

	# Slide in from off-screen right
	var visible_x: float = _toast_visible_x()
	var hidden_x: float = get_viewport_rect().size.x
	panel.position.x = hidden_x

	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "position:x", visible_x, SLIDE_DURATION)
	tween.tween_interval(HOLD_DURATION)
	tween.tween_callback(_slide_out.bind(panel))
	_active_toasts[slot]["tween"] = tween


func _slide_out(panel: PanelContainer) -> void:
	if not is_instance_valid(panel):
		_remove_toast_by_panel(null)
		return

	var hidden_x: float = get_viewport_rect().size.x
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "position:x", hidden_x, SLIDE_DURATION)
	tween.tween_callback(_remove_toast_by_panel.bind(panel))


func _remove_toast_by_panel(panel) -> void:
	var idx: int = -1
	for i in _active_toasts.size():
		if _active_toasts[i]["panel"] == panel:
			idx = i
			break

	if idx >= 0:
		if is_instance_valid(_active_toasts[idx]["panel"]):
			_active_toasts[idx]["panel"].queue_free()
		_active_toasts.remove_at(idx)

	# Shift remaining toasts up to fill the gap
	_restack_toasts()

	# Try to show queued toasts now that a slot is free
	_flush_queue()


func _restack_toasts() -> void:
	for i in _active_toasts.size():
		var panel: PanelContainer = _active_toasts[i]["panel"]
		if not is_instance_valid(panel):
			continue
		var target_x: float = _toast_visible_x()
		var target_y: float = _slot_y(i)
		var tween: Tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(panel, "position", Vector2(target_x, target_y), SLIDE_DURATION * 0.5)


# --- Positioning helpers ---

func _toast_visible_x() -> float:
	return get_viewport_rect().size.x - TOAST_WIDTH - SCREEN_MARGIN


func _slot_y(slot: int) -> float:
	return ANCHOR_Y + slot * (TOAST_HEIGHT + TOAST_GAP)


func _position_at_slot(panel: PanelContainer, slot: int) -> void:
	panel.position = Vector2(_toast_visible_x(), _slot_y(slot))


# --- Toast panel construction ---

func _build_toast_panel(data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(TOAST_WIDTH, TOAST_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UIHelper.create_panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var title_label := Label.new()
	title_label.text = data["title"]
	title_label.add_theme_font_override("font", UIHelper.GAME_FONT_DISPLAY)
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", data["color"])
	title_label.clip_text = true
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = data["subtitle"]
	subtitle_label.add_theme_font_override("font", UIHelper.GAME_FONT)
	subtitle_label.add_theme_font_size_override("font_size", 12)
	subtitle_label.add_theme_color_override("font_color", Color("#ccbbaa"))
	subtitle_label.clip_text = true
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(subtitle_label)

	return panel


# --- Relationship signal handler ---

func _on_relationship_tier_changed(entity_id: String, partner_id: String, old_tier: String, new_tier: String) -> void:
	if partner_id != "player":
		return

	var npc_name: String = _get_npc_name(entity_id)
	var old_idx: int = _tier_index(old_tier)
	var new_idx: int = _tier_index(new_tier)
	var is_promotion: bool = new_idx > old_idx

	var subtitle: String
	var color: Color

	if is_promotion:
		subtitle = PROMOTION_PHRASES.get(new_tier, "Your bond has grown.")
		color = TIER_COLORS.get(new_tier, Color("#ffdd66"))
		AudioManager.play_ui_sfx("ui_panel_open")
	else:
		if new_tier == "recognized" and old_idx > _tier_index("recognized"):
			subtitle = DEMOTION_PHRASE_ATTACK
		else:
			subtitle = DEMOTION_PHRASE_GENERAL
		color = TIER_COLORS.get(new_tier, Color("#888888"))

	show_toast(npc_name, subtitle, color)


func _get_npc_name(entity_id: String) -> String:
	var entity: Node = WorldState.get_entity(entity_id)
	if entity and "npc_name" in entity:
		return entity.npc_name
	return entity_id


func _tier_index(tier: String) -> int:
	const TIERS: Array = ["stranger", "recognized", "acquaintance", "friendly", "close", "bonded"]
	return TIERS.find(tier)
