# Pivot: LLM NPCs → Scripted NPCs

## Why
Remove Ollama/LLM dependency. Game becomes fully offline, simpler stack, deterministic NPC behavior. Replace free-text LLM chat with branching dialogue trees for richer authored content.

## Decisions
- **Dialogue**: Full dialogue tree system (branching conversations per NPC)
- **Chat log**: Remove entirely (combat feedback via floating damage numbers)
- **Player vending**: Remove (no V key shop setup)

---

## Files to DELETE

| File | What it was |
|------|-------------|
| `autoloads/llm_client.gd` | HTTP pool to Ollama API |
| `scenes/npcs/npc_brain.gd` | Event-driven LLM decision loop |
| `scripts/llm/prompt_builder.gd` | Compact prompt construction |
| `scripts/llm/response_parser.gd` | LLM JSON response validation |
| `scripts/llm/action_schema.gd` | Ollama output schema |
| `scenes/ui/chat_log.gd` | Chat log panel |
| `scenes/ui/chat_input.gd` | Free-text chat input |
| `scenes/ui/vend_setup_panel.gd` | Player vending config (V key) |
| `scenes/npcs/npc_economy_helper.gd` | Dynamic economic need assessment |
| `scenes/npcs/npc_trade_helper.gd` | Vendor discovery / pricing / upgrades |
| `scripts/conversation/conversation_manager.gd` | Multi-party LLM conversations |
| `scripts/conversation/conversation_state.gd` | Conversation data class |

## Files to DELETE (also)

| File | What it was |
|------|-------------|
| `docs/npc-system-spec.md` | LLM NPC system spec |
| `docs/npc-system-design.md` | LLM NPC architecture |
| `docs/npc-scaling-design.md` | LLM decision trees + economy |

## Files to MODIFY

### `main.gd` — Remove all LLM wiring
- ConversationManager.new() instantiation
- ChatInput wiring (`player.chat_input`, `message_sent.connect(player.show_chat)`)
- ChatLog wiring (`chat_log.set_player()`)
- VendSetupPanel wiring (`vend_setup_panel.set_player()`, `player.vend_setup_panel`)
- `panel_toggles.chat_input` assignment
- `brain.set_use_llm()` / `brain.set_use_llm_chat()` calls on hardcoded + generated NPCs
- `NpcTradeHelper.tick_vendor_cache(delta)` in `_process()`

### `npc_behavior.gd` — Strip LLM + economic goals
- `LLMClient.request_completed` signal connection (shop title generation)
- All `brain.is_busy()` checks
- 15× `_emit_npc_event()` calls (orphaned — only NpcBrain consumed these)
- 12+ calls to `NpcEconomyHelper` + `NpcTradeHelper` (deleted)
- Remove goals: vend, buy_potions, sell_loot, buy_weapon, buy_armor, buy_from_vendor, tend_shop, restock_shop
- Remove functions: `_execute_vend()`, `_execute_buy_potions()`, `_execute_sell_loot()`, `_execute_buy_equipment()`, `_check_economic_needs()`, `_on_shop_title_response()`
- Keep: hunt_field, patrol, rest, idle, craft_items, chop_wood, return_to_town

### `npc_base.gd` — Remove NpcBrain
- NpcBrain child creation
- `_use_llm` / `_use_llm_chat` flags
- LLM-related signal connections

### `npc_social.gd` — Remove brain dependency
- `_brain: Node` field and `brain.is_busy()` check (will crash)
- `setup()` signature — remove brain param
- `brain.initiate_social_chat()` call → use canned greetings only

### `npc_memory.gd` — Remove LLM context builders
- `get_memories_for_prompt()`, `gather_chat_facts()` weight logic
- Keep: fact storage, gossip tracking, event log

### `player.gd` — Remove chat routing
- `show_chat()` → `_send_to_nearby_npc()` path
- Chat input toggle keybinding
- `chat_input` property

### `player_hover.gd` — Dead import
- Line 9: `const PromptBuilder = preload(...)` — remove

### `npc_info_panel.gd` — Dead import
- Line 7: `const PromptBuilder = preload(...)` — remove

### `relationship_component.gd` — Remove LLM impressions
- LLM impression update calls
- Keep: tier ladder, event recording, tension

### `vending_component.gd` — Remove LLM shop titles
- LLM shop title generation
- Keep: buy/sell mechanics for fixed shops

### `game_events.gd` — Remove orphaned signals
- `conversation_started`, `conversation_ended`, `conversation_participant_joined`, `conversation_participant_left`, `conversation_turn_added` (5 signals)
- `npc_event_triggered` (1 signal)

### `project.godot` — Remove autoload + input actions
- `LLMClient` autoload entry
- `toggle_vend` input action (V key)
- `chat_submit` input action (Enter)

### `panel_toggles.gd` — Remove chat_input toggle
- Chat input toggle logic

### `CLAUDE.md` — Comprehensive rewrite
- Remove LLMClient autoload reference
- Remove "Event-driven LLM" section
- Remove "NPC AI Systems" section (NpcBrain, NpcMemory docs)
- Remove "NPC Economy System" section
- Remove "Conversation System" section
- Remove "ChatLog" and "ChatInput" UI entries
- Remove "V vend setup" from Input section
- Add dialogue tree system documentation

## Files UNCHANGED

- `npc_traits.gd`, `npc_identity_database.gd`, `npc_identity.gd` — personality/mood
- `npc_action_executor.gd` — action execution (agnostic to decision source)
- `gossip_system.gd` — pure fact propagation
- `dialogue_bubble.gd` — speech bubble UI
- `shop_panel.gd` — shop UI (reads VendingComponent)
- `npc_loadouts.gd`, `npc_generator.gd` — NPC data/creation
- All combat, skill, proficiency, gathering, crafting, audio systems
- Interior NPC system (already static shops)

---

## New Systems

### 1. Dialogue Tree System

**DialogueDatabase** (`scripts/data/dialogue_database.gd`) — static data:
```
"kael": {
    "greeting": {
        text: "Ho there, traveler. The fields are dangerous today.",
        choices: [
            {text: "What's out there?", next: "kael_field_info"},
            {text: "Can you train me?", next: "kael_training", condition: "relationship >= friendly"},
            {text: "Farewell.", next: null},
        ]
    },
    "kael_field_info": {
        text: "Slimes and wolves mostly. The wolves have been bold lately.",
        choices: [
            {text: "I'll be careful.", next: null},
            {text: "Want to hunt together?", next: "kael_hunt_offer"},
        ]
    },
}
```

**Conditions** on choices:
- `relationship >= friendly` — relationship tier gate
- `time == night` — time of day
- `mood == happy` — NPC mood
- `has_item:iron_sword` — player inventory
- `flag:quest_started` — quest/flag state (future)

**DialoguePanel** (`scenes/ui/dialogue_panel.gd`) — UI:
- Click NPC → opens dialogue panel
- NPC name + dialogue text + choice buttons
- Special choices: `"action:trade"` opens ShopPanel, `"action:info"` opens NpcInfoPanel
- Procedural NPCs without trees get generic lines by archetype + mood

### 2. Fixed Shop NPCs
- Merchants have permanent inventories (VendingComponent + ShopPanel, already works)
- Dialogue tree includes "Buy/Sell" choice → opens shop
- Interior NPCs already follow this pattern

### 3. Simplified NPC Goals
**Remove**: vend, buy_from_vendor, sell_loot, buy_weapon, buy_armor, restock_shop, tend_shop
**Keep**: hunt_field, patrol, rest, idle, craft_items, chop_wood, return_to_town
**Add**: guard (stand at post), wander (random movement within district)

---

## Implementation Order

1. **Strip LLM** — Delete files, strip hooks. Game runs without Ollama, canned greetings.
2. **Remove UI** — Delete chat log/input/vend setup. Clean main.gd wiring.
3. **Dialogue Trees** — DialogueDatabase + DialoguePanel + NPC content.
4. **Polish** — Simplify goals, fix shops, test full flow, update CLAUDE.md.
