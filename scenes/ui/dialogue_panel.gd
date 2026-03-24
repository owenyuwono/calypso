extends PanelContainer
## Dialogue panel — bottom-of-screen JRPG-style dialogue box.
## Full width, fixed height, anchored to bottom. NPC name + text only.
## Choices float as a sibling VBoxContainer on the right, above the dialogue box (Stardew Valley style).

const DialogueDatabase = preload("res://scripts/data/dialogue_database.gd")
const GiftDatabase = preload("res://scripts/data/gift_database.gd")
const ItemDatabase = preload("res://scripts/data/item_database.gd")

const DIALOGUE_ICON_SHOP: String = "res://assets/textures/ui/dialogue/shop.png"
const DIALOGUE_ICON_QUEST: String = "res://assets/textures/ui/dialogue/quest.png"
const DIALOGUE_ICON_CHARISMA: String = "res://assets/textures/ui/dialogue/charisma.png"
const DIALOGUE_ICON_PERSUASION: String = "res://assets/textures/ui/dialogue/persuasion.png"
const DIALOGUE_ICON_INTIMIDATION: String = "res://assets/textures/ui/dialogue/intimidation.png"

signal trade_requested(npc_node: Node)

var _player: Node
var _npc_id: String = ""
var _npc_node: Node = null
var _current_node_id: String = ""

var _npc_name_label: Label
var _dialogue_text: Label
var _portrait: TextureRect
var _choices_container: VBoxContainer

# Relationship indicator widgets (created in _build_ui, updated in open_dialogue)
var _rel_tier_label: Label = null

# Whether we are currently in gift-selection mode
var _in_gift_mode: bool = false
# Node id / context to return to after gift reaction
var _gift_return_node_id: String = ""
var _gift_return_is_generic: bool = false

const TIER_COLORS: Dictionary = {
	"stranger":     Color("888888"),
	"recognized":   Color("bbbbbb"),
	"acquaintance": Color("ffdd66"),
	"friendly":     Color("66cc66"),
	"close":        Color("6688ff"),
	"bonded":        Color("cc66ff"),
}

const PROFILE_TO_ARCHETYPE: Dictionary = {
	"bold_warrior": "warrior",
	"stern_guardian": "warrior",
	"wild_berserker": "warrior",
	"stoic_knight": "warrior",
	"cautious_mage": "mage",
	"devout_cleric": "mage",
	"gentle_healer": "mage",
	"earnest_apprentice": "mage",
	"sly_rogue": "rogue",
	"charming_bard": "rogue",
	"shadow_stalker": "rogue",
	"keen_archer": "ranger",
	"merchant": "merchant",
}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Anchor to bottom, full width, fixed height
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 40
	offset_right = -40
	offset_top = -180
	offset_bottom = -20

	add_theme_stylebox_override("panel", UIHelper.create_panel_style())
	_build_ui()
	_build_portrait()
	_build_choices_container()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(main_vbox)

	# Name row: NPC name + relationship indicator (tier + progress)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(name_row)

	# NPC name — gold, display font
	_npc_name_label = Label.new()
	_npc_name_label.add_theme_font_override("font", UIHelper.GAME_FONT_DISPLAY)
	_npc_name_label.add_theme_font_size_override("font_size", 18)
	_npc_name_label.add_theme_color_override("font_color", UIHelper.COLOR_GOLD)
	name_row.add_child(_npc_name_label)

	# Separator "▸"
	var sep_label := Label.new()
	sep_label.text = "▸"
	sep_label.add_theme_font_override("font", UIHelper.GAME_FONT)
	sep_label.add_theme_font_size_override("font_size", 13)
	sep_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	sep_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(sep_label)

	# Tier name label — color set at open time
	_rel_tier_label = Label.new()
	_rel_tier_label.add_theme_font_override("font", UIHelper.GAME_FONT)
	_rel_tier_label.add_theme_font_size_override("font_size", 13)
	_rel_tier_label.add_theme_color_override("font_color", Color("888888"))
	_rel_tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(_rel_tier_label)

	# Dialogue text — body font, word-wrapped, fills available space
	_dialogue_text = Label.new()
	_dialogue_text.add_theme_font_override("font", UIHelper.GAME_FONT)
	_dialogue_text.add_theme_font_size_override("font_size", 14)
	_dialogue_text.add_theme_color_override("font_color", Color(0.92, 0.89, 0.82))
	_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_dialogue_text)


func _build_portrait() -> void:
	# Sibling floating above the dialogue box, left side
	_portrait = TextureRect.new()
	_portrait.name = "DialoguePortrait"
	_portrait.visible = false
	_portrait.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# Position: left side, above dialogue box
	_portrait.anchor_left = 0.0
	_portrait.anchor_right = 0.0
	_portrait.anchor_top = 1.0
	_portrait.anchor_bottom = 1.0
	_portrait.offset_left = 40       # match dialogue panel left margin
	_portrait.offset_right = 320     # ~280px wide (2x bigger)
	_portrait.offset_bottom = -180   # bottom touches dialogue box top
	_portrait.offset_top = -650      # ~470px tall for portrait (2x bigger)

	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(_portrait)


func _build_choices_container() -> void:
	# Sibling of the dialogue panel in UILayer — floats right, above the dialogue box
	_choices_container = VBoxContainer.new()
	_choices_container.name = "DialogueChoices"
	_choices_container.visible = false
	_choices_container.add_theme_constant_override("separation", 6)

	# Anchor to bottom-right, growing upward
	_choices_container.anchor_left = 1.0
	_choices_container.anchor_right = 1.0
	_choices_container.anchor_top = 1.0
	_choices_container.anchor_bottom = 1.0

	# Right side, above the dialogue box (dialogue box top is at offset_top = -180)
	_choices_container.offset_right = -40    # match dialogue panel right margin
	_choices_container.offset_left = -220    # ~180px wide
	_choices_container.offset_bottom = -185  # 5px gap above dialogue box top
	_choices_container.offset_top = -400     # enough room for several choices

	_choices_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_choices_container.grow_vertical = Control.GROW_DIRECTION_BEGIN  # grow upward

	get_parent().add_child(_choices_container)


var _shop_panel: Node
var _buy_button: Button = null
var _hud_elements: Array = []  # nodes to hide when dialogue is open
var _charisma_xp_granted: bool = false

func set_player(player: Node) -> void:
	_player = player

func set_hud_elements(elements: Array) -> void:
	_hud_elements = elements

func set_shop_panel(shop: Node) -> void:
	_shop_panel = shop
	if _shop_panel and _shop_panel.has_signal("shop_closed"):
		_shop_panel.shop_closed.connect(_on_shop_closed)
	if _shop_panel and _shop_panel.has_signal("cart_changed"):
		_shop_panel.cart_changed.connect(_on_cart_changed)


func open_dialogue(npc_id: String, npc_node: Node) -> void:
	_npc_id = npc_id
	_npc_node = npc_node
	_in_gift_mode = false
	_gift_return_node_id = ""
	_gift_return_is_generic = false
	_charisma_xp_granted = false

	var npc_name: String = npc_node.npc_name if "npc_name" in npc_node else npc_id
	_npc_name_label.text = npc_name

	var prog: Node = _player.get_node_or_null("ProgressionComponent") if _player else null
	var charisma_level: int = 0
	if prog:
		charisma_level = prog.get_proficiency_level("charisma")

	# Record conversation event on NPC's RelationshipComponent
	var rel: Node = npc_node.get_node_or_null("RelationshipComponent")
	if rel:
		rel.record_event("player", "conversation", TimeManager.get_day(), charisma_level)

	# Grant charisma XP once per dialogue session
	if prog and not _charisma_xp_granted:
		prog.grant_proficiency_xp("charisma", 3)
		_charisma_xp_granted = true

	# Load portrait if it exists
	var portrait_path: String = "res://assets/textures/ui/portraits/%s.png" % npc_id
	if ResourceLoader.exists(portrait_path):
		_portrait.texture = load(portrait_path)
		_portrait.visible = true
	else:
		_portrait.texture = null
		_portrait.visible = false

	# Update relationship indicator
	_update_relationship_indicator(npc_node)

	# Record conversation event
	_record_conversation_event(npc_node)

	var entry_node_id: String = DialogueDatabase.get_dialogue_entry(npc_id)
	if not entry_node_id.is_empty():
		_show_node(entry_node_id)
	else:
		_show_generic_greeting(npc_node)

	visible = true
	_choices_container.visible = true
	for elem in _hud_elements:
		if elem and is_instance_valid(elem):
			elem.visible = false
	AudioManager.play_ui_sfx("ui_panel_open")


func _update_relationship_indicator(npc_node: Node) -> void:
	if _rel_tier_label == null:
		return

	var rel_comp: Node = npc_node.get_node_or_null("RelationshipComponent")
	if rel_comp == null:
		_rel_tier_label.text = "Stranger"
		_rel_tier_label.add_theme_color_override("font_color", Color("888888"))
		return

	var tier: String = rel_comp.get_tier("player")
	var tier_color: Color = TIER_COLORS.get(tier, Color("888888"))
	_rel_tier_label.text = tier.capitalize()
	_rel_tier_label.add_theme_color_override("font_color", tier_color)


func _record_conversation_event(npc_node: Node) -> void:
	# Canonical path for player-initiated conversation events.
	# NPC-NPC conversations are recorded separately in npc_memory.gd via the npc_spoke signal.
	var rel_comp: Node = npc_node.get_node_or_null("RelationshipComponent")
	if rel_comp == null:
		return
	var game_day: int = TimeManager.get_day() if TimeManager.has_method("get_day") else 0
	rel_comp.record_event("player", "conversation", game_day)


func close_dialogue() -> void:
	if _shop_panel and _shop_panel.has_signal("cart_changed") and _shop_panel.cart_changed.is_connected(_on_cart_changed):
		_shop_panel.cart_changed.disconnect(_on_cart_changed)
	_buy_button = null
	_in_gift_mode = false
	visible = false
	_choices_container.visible = false
	_portrait.visible = false
	_clear_choices()
	for elem in _hud_elements:
		if elem and is_instance_valid(elem):
			elem.visible = true
	AudioManager.play_ui_sfx("ui_panel_close")
	_npc_id = ""
	_npc_node = null
	_current_node_id = ""
	_charisma_xp_granted = false


func _show_node(node_id: String) -> void:
	_current_node_id = node_id
	var dialogue_node: Dictionary = DialogueDatabase.get_node(_npc_id, node_id)
	if dialogue_node.is_empty():
		close_dialogue()
		return

	_dialogue_text.text = dialogue_node.get("text", "...")

	_clear_choices()

	var choices: Array = dialogue_node.get("choices", [])
	for choice in choices:
		var condition: String = choice.get("condition", "")
		if not condition.is_empty():
			if not DialogueDatabase.evaluate_condition(condition, _player, _npc_node):
				continue

		var icon_path: String = _get_choice_icon(choice)
		var btn := _create_choice_button(choice.get("text", "..."), icon_path)
		var next_node = choice.get("next", null)
		var action: String = choice.get("action", "")
		btn.pressed.connect(_on_choice_pressed.bind(next_node, action))
		_choices_container.add_child(btn)

	# Inject gift choice if eligible
	_maybe_inject_gift_choice(node_id, false)

	if _choices_container.get_child_count() == 0:
		var btn := _create_choice_button("Goodbye.")
		btn.pressed.connect(close_dialogue)
		_choices_container.add_child(btn)


func _show_generic_greeting(npc_node: Node) -> void:
	var archetype: String = _get_archetype(npc_node)
	var mood: String = _get_mood(npc_node)
	var node: Dictionary = DialogueDatabase.get_generic_greeting(archetype, mood)

	_dialogue_text.text = node.get("text", "...")

	_clear_choices()

	var choices: Array = node.get("choices", [])
	for choice in choices:
		var btn := _create_choice_button(choice.get("text", "Goodbye."))
		btn.pressed.connect(close_dialogue)
		_choices_container.add_child(btn)

	# Inject gift choice if eligible
	_maybe_inject_gift_choice("", true)

	if _choices_container.get_child_count() == 0:
		var btn := _create_choice_button("Goodbye.")
		btn.pressed.connect(close_dialogue)
		_choices_container.add_child(btn)


func _maybe_inject_gift_choice(node_id: String, is_generic: bool) -> void:
	if _player == null:
		return

	# Only show gift if NPC has a RelationshipComponent and is not already bonded
	var rel_comp: Node = _npc_node.get_node_or_null("RelationshipComponent") if _npc_node else null
	if rel_comp == null:
		return
	var tier: String = rel_comp.get_tier("player")
	if tier == "bonded":
		return

	# Only show gift if player has items
	var inv: Node = _player.get_node_or_null("InventoryComponent")
	if inv == null:
		return
	var items: Dictionary = inv.get_items()
	if items.is_empty():
		return

	var gift_btn := _create_choice_button("Give a Gift")
	gift_btn.pressed.connect(_on_gift_choice_pressed.bind(node_id, is_generic))
	_choices_container.add_child(gift_btn)


func _on_gift_choice_pressed(node_id: String, is_generic: bool) -> void:
	_in_gift_mode = true
	_gift_return_node_id = node_id
	_gift_return_is_generic = is_generic
	_show_gift_items()


func _show_gift_items() -> void:
	_dialogue_text.text = "What would you like to give?"
	_clear_choices()

	var inv: Node = _player.get_node_or_null("InventoryComponent")
	if inv == null:
		_in_gift_mode = false
		_restore_after_gift()
		return

	var items: Dictionary = inv.get_items()
	for item_id: String in items:
		var count: int = items[item_id]
		if count <= 0:
			continue
		var item_data: Dictionary = ItemDatabase.get_item(item_id)
		var item_name: String = item_data.get("name", item_id)
		var btn_text: String = item_name if count <= 1 else "%s (%d)" % [item_name, count]
		var gift_item_btn := _create_choice_button(btn_text)
		gift_item_btn.pressed.connect(_on_gift_item_selected.bind(item_id))
		_choices_container.add_child(gift_item_btn)

	var cancel_btn := _create_choice_button("Cancel")
	cancel_btn.pressed.connect(_on_gift_cancelled)
	_choices_container.add_child(cancel_btn)


func _on_gift_item_selected(item_id: String) -> void:
	_in_gift_mode = false

	# Remove 1 of the item from inventory
	var inv: Node = _player.get_node_or_null("InventoryComponent")
	if inv:
		inv.remove_item(item_id, 1)

	# Determine preference
	var archetype: String = _get_archetype(_npc_node) if _npc_node else ""
	var preference: String = GiftDatabase.get_preference(_npc_id, archetype, item_id)

	# Record events on the NPC's RelationshipComponent
	var rel_comp: Node = _npc_node.get_node_or_null("RelationshipComponent") if _npc_node else null
	if rel_comp != null:
		var game_day: int = TimeManager.get_day() if TimeManager.has_method("get_day") else 0
		match preference:
			"loved":
				rel_comp.record_event("player", "helped", game_day)
				rel_comp.record_event("player", "helped", game_day)
			"liked":
				rel_comp.record_event("player", "helped", game_day)
			"neutral":
				rel_comp.record_event("player", "conversation", game_day)
			"disliked":
				pass  # No relationship event for disliked gifts

	# Refresh relationship indicator
	if _npc_node:
		_update_relationship_indicator(_npc_node)

	# Show reaction
	var reaction: String = GiftDatabase.get_reaction(preference)
	_dialogue_text.text = reaction

	# Return to normal choices after reaction
	_clear_choices()
	var ok_btn := _create_choice_button("You're welcome.")
	ok_btn.pressed.connect(_restore_after_gift)
	_choices_container.add_child(ok_btn)


func _on_gift_cancelled() -> void:
	_in_gift_mode = false
	_restore_after_gift()


func _restore_after_gift() -> void:
	if _gift_return_is_generic:
		_show_generic_greeting(_npc_node)
	elif not _gift_return_node_id.is_empty():
		_show_node(_gift_return_node_id)
	else:
		_show_generic_greeting(_npc_node)


func _on_choice_pressed(next_node, action: String) -> void:
	if not action.is_empty():
		_execute_action(action)
		return

	if next_node == null:
		close_dialogue()
		return

	_show_node(next_node)


func _execute_action(action: String) -> void:
	if action.begins_with("quest_accept:"):
		var quest_id: String = action.substr(13)
		var quest_comp: Node = _player.get_node_or_null("QuestComponent")
		if quest_comp:
			quest_comp.accept_quest(quest_id)
		close_dialogue()
		return

	if action.begins_with("quest_complete:"):
		var quest_id: String = action.substr(15)
		var quest_comp: Node = _player.get_node_or_null("QuestComponent")
		if quest_comp:
			var rewards: Dictionary = quest_comp.try_complete_quest(quest_id)
			_apply_rewards(rewards)
		close_dialogue()
		return

	if action == "persuasion_attempt":
		var prog: Node = _player.get_node_or_null("ProgressionComponent") if _player else null
		if prog:
			prog.grant_proficiency_xp("persuasion", 5)
		close_dialogue()
		return

	if action == "intimidation_attempt":
		var prog: Node = _player.get_node_or_null("ProgressionComponent") if _player else null
		if prog:
			prog.grant_proficiency_xp("intimidation", 5)
		close_dialogue()
		return

	match action:
		"trade":
			_dialogue_text.text = "Take your time browsing..."
			_show_trade_choices()
			if _npc_node and is_instance_valid(_npc_node):
				trade_requested.emit(_npc_node)
		"follow":
			if _npc_node and is_instance_valid(_npc_node) and _npc_node.has_method("set_goal"):
				_npc_node.set_goal("follow_player")
			close_dialogue()
		"info":
			close_dialogue()
		_:
			close_dialogue()


func _apply_rewards(rewards: Dictionary) -> void:
	if rewards.is_empty():
		return
	var inv: Node = _player.get_node_or_null("InventoryComponent")
	if inv:
		var gold: int = rewards.get("gold", 0)
		if gold > 0:
			inv.add_gold_amount(gold)
		var items: Dictionary = rewards.get("items", {})
		for item_id: String in items:
			inv.add_item(item_id, items[item_id])
	var prog: Node = _player.get_node_or_null("ProgressionComponent")
	if prog:
		var xp: Dictionary = rewards.get("proficiency_xp", {})
		for prof_id: String in xp:
			prog.grant_proficiency_xp(prof_id, xp[prof_id])


func _clear_choices() -> void:
	for child in _choices_container.get_children():
		_choices_container.remove_child(child)
		child.queue_free()


func _get_choice_icon(choice: Dictionary) -> String:
	var action: String = choice.get("action", "")
	var condition: String = choice.get("condition", "")

	if action == "trade" or action.begins_with("trade"):
		return DIALOGUE_ICON_SHOP
	if action.begins_with("quest_accept") or action.begins_with("quest_complete"):
		return DIALOGUE_ICON_QUEST
	if action == "persuasion_attempt" or condition.begins_with("proficiency:persuasion"):
		return DIALOGUE_ICON_PERSUASION
	if action == "intimidation_attempt" or condition.begins_with("proficiency:intimidation"):
		return DIALOGUE_ICON_INTIMIDATION
	if condition.begins_with("proficiency:charisma"):
		return DIALOGUE_ICON_CHARISMA
	return ""


func _create_choice_button(label_text: String, icon_path: String = "") -> Button:
	var btn := Button.new()
	# When an icon is present the Button node adds its own gap; no leading spaces needed
	if icon_path.is_empty():
		btn.text = "  " + label_text + "  "
	else:
		btn.text = label_text + "  "
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 32)
	btn.add_theme_font_override("font", UIHelper.GAME_FONT)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	btn.add_theme_color_override("font_hover_color", UIHelper.COLOR_GOLD)
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.7))

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.12, 0.08, 0.85)
	normal_style.border_color = Color(0.6, 0.5, 0.3, 0.5)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(3)
	normal_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.25, 0.2, 0.12, 0.95)
	hover_style.border_color = UIHelper.COLOR_GOLD
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.3, 0.25, 0.15, 0.9)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var tex: Texture2D = load(icon_path)
		btn.icon = tex
		btn.icon_max_width = 18
		btn.expand_icon = false

	return btn


func _get_archetype(npc_node: Node) -> String:
	var profile: String = npc_node.trait_profile if "trait_profile" in npc_node else ""
	return PROFILE_TO_ARCHETYPE.get(profile, "warrior")


func _get_mood(npc_node: Node) -> String:
	var emotion: String = ""
	if "current_mood" in npc_node:
		emotion = npc_node.current_mood
	elif npc_node.has_node("NpcIdentity"):
		var identity: Node = npc_node.get_node("NpcIdentity")
		emotion = identity.emotion if "emotion" in identity else ""

	match emotion:
		"excited", "content", "energetic": return "happy"
		"sad", "afraid", "tired": return "sad"
		"angry": return "angry"
	return "neutral"


func _show_trade_choices() -> void:
	_clear_choices()

	var total: int = _shop_panel.get_cart_total() if _shop_panel else 0
	_buy_button = _create_choice_button("Buy (%dg)" % total)
	_buy_button.disabled = total <= 0
	_buy_button.pressed.connect(_on_buy_pressed)
	_choices_container.add_child(_buy_button)

	var close_btn := _create_choice_button("Close Shop")
	close_btn.pressed.connect(_close_shop)
	_choices_container.add_child(close_btn)

	_choices_container.visible = true


func _on_buy_pressed() -> void:
	if _shop_panel and _shop_panel.purchase_cart():
		AudioManager.play_ui_sfx("ui_buy_sell")
		# Grant persuasion XP for completing a trade
		if _player:
			var prog: Node = _player.get_node_or_null("ProgressionComponent")
			if prog:
				prog.grant_proficiency_xp("persuasion", 3)
		_show_trade_choices()


func _on_cart_changed(total: int) -> void:
	if not (_buy_button and is_instance_valid(_buy_button)):
		return
	_buy_button.text = "  Buy (%dg)  " % total
	_buy_button.disabled = total <= 0
	if total > 0 and _player:
		var inv: Node = _player.get_node_or_null("InventoryComponent")
		if inv and inv.get_gold_amount() < total:
			_buy_button.disabled = true


func _close_shop() -> void:
	if _shop_panel and _shop_panel.is_open():
		_shop_panel.close_shop()


const PARTING_WORDS: Array = [
	"Thanks for your business! Stay safe out there.",
	"Come back anytime you need supplies!",
	"Good luck on your adventures, friend!",
	"May your travels be prosperous!",
	"Safe journeys, traveler!",
]

func _on_shop_closed() -> void:
	if not visible or _npc_id.is_empty():
		return
	# Show parting words with a goodbye choice
	_dialogue_text.text = PARTING_WORDS[randi() % PARTING_WORDS.size()]
	_clear_choices()
	var btn := _create_choice_button("Farewell.")
	btn.pressed.connect(close_dialogue)
	_choices_container.add_child(btn)
	_choices_container.visible = true


func _exit_tree() -> void:
	if is_instance_valid(_choices_container):
		_choices_container.queue_free()
	if is_instance_valid(_portrait):
		_portrait.queue_free()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		# Don't close dialogue while shop is open — shop handles its own Escape
		if _shop_panel and _shop_panel.is_open():
			return
		close_dialogue()
		get_viewport().set_input_as_handled()
