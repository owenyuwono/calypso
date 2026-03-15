extends Control
## Chat log panel — displays combat, dialogue, loot, and system messages.
## Auto-scrolls, click-through, batches combat hits.

const ItemDatabase = preload("res://scripts/data/item_database.gd")
const MAX_MESSAGES := 50

const COLOR_PLAYER_SPEECH := Color("ffffff")
const COLOR_NPC_SPEECH := Color("88ee88")
const COLOR_COMBAT := Color("ff8866")
const COLOR_LOOT := Color("ffdd44")
const COLOR_GOLD := Color("ffcc33")
const COLOR_SYSTEM := Color("66ddff")
const COLOR_CONVERSATION_PLAYER := Color("aaddff")
const COLOR_CONVERSATION_NPC := Color("bbffcc")

var _rich_label: RichTextLabel
var _message_count: int = 0

# Combat hit batching: "attacker->target" -> {damage: int, count: int, timer: float}
var _pending_hits: Dictionary = {}
const HIT_BATCH_WINDOW := 0.3

func _ready() -> void:
	# Anchor bottom-left, above chat input
	anchors_preset = PRESET_BOTTOM_LEFT
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 10
	offset_right = 410
	offset_top = -310
	offset_bottom = -60
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Background panel
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.6)
	UIHelper.set_corner_radius(style, 4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_rich_label = RichTextLabel.new()
	_rich_label.bbcode_enabled = true
	_rich_label.scroll_following = true
	_rich_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rich_label.add_theme_font_size_override("normal_font_size", 13)
	panel.add_child(_rich_label)

	# Connect signals
	GameEvents.npc_spoke.connect(_on_npc_spoke)
	GameEvents.entity_damaged.connect(_on_entity_damaged)
	GameEvents.entity_died.connect(_on_entity_died)
	GameEvents.entity_healed.connect(_on_entity_healed)
	GameEvents.item_looted.connect(_on_item_looted)
	GameEvents.proficiency_level_up.connect(_on_proficiency_level_up)
	GameEvents.conversation_turn_added.connect(_on_conversation_turn_added)

func _process(delta: float) -> void:
	# Flush expired hit batches
	var to_flush: Array = []
	for key in _pending_hits:
		_pending_hits[key].timer -= delta
		if _pending_hits[key].timer <= 0.0:
			to_flush.append(key)
	for key in to_flush:
		_flush_hit(key)

func _add_message(text: String, color: Color) -> void:
	if _message_count >= MAX_MESSAGES:
		_rich_label.remove_paragraph(0)
	else:
		_message_count += 1
	_rich_label.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])

func _get_entity_name(entity_id: String) -> String:
	var data := WorldState.get_entity_data(entity_id)
	var n: String = data.get("name", "")
	if not n.is_empty():
		return n
	return entity_id.capitalize()

# --- Signal handlers ---

func _on_npc_spoke(npc_id: String, dialogue: String, target_id: String) -> void:
	var speaker := _get_entity_name(npc_id)
	var color := COLOR_NPC_SPEECH
	if npc_id == "player":
		color = COLOR_PLAYER_SPEECH
	if not target_id.is_empty():
		var target := _get_entity_name(target_id)
		_add_message("%s → %s: %s" % [speaker, target, dialogue], color)
	else:
		_add_message("%s: %s" % [speaker, dialogue], color)

func _on_entity_damaged(target_id: String, attacker_id: String, damage: int, _remaining_hp: int) -> void:
	var key := "%s->%s" % [attacker_id, target_id]
	if _pending_hits.has(key):
		_pending_hits[key].damage += damage
		_pending_hits[key].count += 1
		_pending_hits[key].timer = HIT_BATCH_WINDOW
	else:
		_pending_hits[key] = {"damage": damage, "count": 1, "timer": HIT_BATCH_WINDOW, "attacker": attacker_id, "target": target_id}

func _flush_hit(key: String) -> void:
	var hit: Dictionary = _pending_hits[key]
	_pending_hits.erase(key)
	var attacker := _get_entity_name(hit.attacker)
	var target := _get_entity_name(hit.target)
	var msg: String
	if hit.count > 1:
		msg = "%s hits %s for %d damage (x%d)" % [attacker, target, hit.damage, hit.count]
	else:
		msg = "%s hits %s for %d damage" % [attacker, target, hit.damage]
	_add_message(msg, COLOR_COMBAT)

func _on_entity_died(entity_id: String, killer_id: String) -> void:
	# Flush pending hits involving this entity first
	var to_flush: Array = []
	for key in _pending_hits:
		if key.ends_with("->%s" % entity_id) or key.begins_with("%s->" % entity_id):
			to_flush.append(key)
	for key in to_flush:
		_flush_hit(key)

	var victim := _get_entity_name(entity_id)
	var killer := _get_entity_name(killer_id)
	_add_message("%s was defeated by %s" % [victim, killer], COLOR_COMBAT)

func _on_entity_healed(entity_id: String, amount: int, _current_hp: int) -> void:
	var name := _get_entity_name(entity_id)
	_add_message("%s recovered %d HP" % [name, amount], COLOR_SYSTEM)

func _on_item_looted(entity_id: String, item_id: String, count: int) -> void:
	var looter := _get_entity_name(entity_id)
	if item_id == "gold":
		_add_message("%s picked up %d Gold" % [looter, count], COLOR_GOLD)
	else:
		var item_name := ItemDatabase.get_item_name(item_id)
		if count > 1:
			_add_message("%s obtained %s x%d" % [looter, item_name, count], COLOR_LOOT)
		else:
			_add_message("%s obtained %s" % [looter, item_name], COLOR_LOOT)

func _on_proficiency_level_up(entity_id: String, skill_id: String, new_level: int) -> void:
	var ProficiencyDatabase = preload("res://scripts/data/proficiency_database.gd")
	var skill_data: Dictionary = ProficiencyDatabase.get_skill(skill_id)
	var skill_name: String = skill_data.get("name", skill_id)
	var name := _get_entity_name(entity_id)
	_add_message("%s reached %s Level %d!" % [name, skill_name, new_level], COLOR_SYSTEM)

func _on_conversation_turn_added(_conversation_id: String, speaker_id: String, dialogue: String, action: String) -> void:
	# Only display "speak" actions; skip join/walk_away/silence meta-turns
	if action != ConversationState.ACTION_SPEAK:
		return
	if dialogue.is_empty():
		return
	var speaker := _get_entity_name(speaker_id)
	var color: Color
	if speaker_id == "player":
		color = COLOR_CONVERSATION_PLAYER
	else:
		color = COLOR_CONVERSATION_NPC
	_add_message("[%s]: %s" % [speaker, dialogue], color)
