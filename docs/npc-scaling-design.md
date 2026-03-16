# NPC Scaling Design: 50-100 Agents with Social Dynamics

## Context

Arcadia has 7 LLM-capable adventurer NPCs with goal-driven behavior. Scripted behavior handles ~95% of decisions; LLM is optional fallback/social layer. We're scaling to 50-100 NPCs with emergent social dynamics — relationships, gossip propagation, faction emergence, and self-balancing economy.

**Hardware**: 5070 Ti 16GB VRAM, local inference only.
**Throughput budget**: ~2-4 LLM decisions/sec sustained (qwen3.5:4b).
**Approach**: Pure event-driven LLM triggers, high density in current world size.

---

## 1. Inference Backend: llama-server

Switch from Ollama to llama-server for continuous batching and prompt caching.

**LLMClient changes** (`autoloads/llm_client.gd`):
- OpenAI-compatible API (`/v1/chat/completions`) instead of Ollama `/api/chat`
- `MAX_CONCURRENT_REQUESTS`: 2 → 10
- Request deduplication: drop new request if NPC already has pending request of same type
- Stale request dropping: cancel if NPC state changed significantly since queueing (died, entered combat)
- Keep existing 5-tier priority queue

**llama-server config**:
```bash
./llama-server -m qwen3.5-4b.gguf --host 0.0.0.0 --port 8080 \
  -cb -np 12 --cache-prompt -c 8192 -ngl 99
```

---

## 2. Event-Driven LLM Triggers

Replace timer-based NPC decision loop with event-driven triggers. NPCs only consult the LLM when something worth thinking about happens.

**Event types and priorities**:

| Event | Priority | Trigger | Cooldown |
|-------|----------|---------|----------|
| `player_chat` | 1 | Player speaks to NPC | 2s |
| `npc_chat` | 2 | NPC-to-NPC conversation | 5s |
| `goal_completed` | 3 | Current goal finished | 10s |
| `significant_discovery` | 3 | Rare loot, new area | 15s |
| `combat_outcome` | 3 | Fight won/lost/fled | 10s |
| `low_resources` | 3 | HP < 30%, no potions | 30s |
| `social_trigger` | 4 | Met NPC with shared history | 20s |
| `memory_extraction` | 4 | After conversation ends | 10s |
| `idle_timeout` | 5 | Nothing happened for 60s | 60s |

**Not LLM-triggered** (handled by scripted behavior): routine combat, movement, auto-equip, buying from shops, taking damage.

**NpcBrain changes**: Remove 5s decision timer. Add `_event_cooldowns` dictionary, `on_significant_event(event_type, context)` method, `_pending_events` buffer.

**NpcBehavior changes**: Emit events at appropriate points (goal completion, survival critical, combat outcome, idle detection). All scripted behavior unchanged.

---

## 3. Prompt Optimization

Reduce prompt sizes to double effective throughput.

**Compact formats**:

| Data | Before | After |
|------|--------|-------|
| Perception | ~80 tokens/entity | ~20 tokens/entity |
| Memory | ~30 tokens/memory | ~12 tokens/memory |
| Stats | ~25 tokens | ~12 tokens |

**Examples**:
```
# Perception: "Kael(knight,hp:full,fighting:slime,8m)"
# Memory: "fought w/ Lyra vs goblins @east_gate, won"
# Stats: "lv5 hp:80/100 atk:15+4 def:8+3 gold:150"
```

**Target sizes**: Decision 400-600 tokens, Chat 200-400 tokens.

---

## 4. NPC Generator

Procedural NPC creation via `scripts/npcs/npc_generator.gd`.

**5 archetypes** (weighted): warrior 30%, mage 25%, rogue 20%, ranger 15%, merchant 10%.

Each archetype defines: weapon preference, trait ranges (boldness, generosity, sociability, curiosity), default goal.

**Generation**: Pick archetype → randomize traits → draw unique name from ~200 pool → tier roll (poor 40% / average 40% / wealthy 20%) → assign equipment and gold → map to KayKit model.

**Model mapping**: warrior→Knight/Barbarian, mage→Mage, rogue→Rogue, ranger→Knight/Barbarian, merchant→Rogue/Mage.

---

## 5. Gossip & Social Dynamics

Emergent information propagation through NPC conversations.

**Memory gossip metadata**:
```gdscript
{
    "fact": "Kael defeated the goblin chief",
    "importance": 2.0,
    "source": "witnessed",        # witnessed | told_by | rumor
    "spread_count": 0,
    "original_source": "Kael",
    "timestamp": 12345
}
```

**Propagation rules**:
- During NPC-NPC chat, each NPC shares 1-2 high-importance facts
- Each retelling: 15% distortion chance
- `spread_count >= 4` → becomes "rumor" (less trusted)
- Sociability trait affects sharing threshold
- NPCs track who told them what (prevents echo)

**Relationship effects**: Hearing "X helped me" → +relationship with X. Hearing "X stole from Y" → -relationship with X (modulated by traits). Creates emergent faction clustering.

**Economy**: NPCs share merchant/price gossip during conversations. Supply/demand emerges naturally.

---

## 6. Spawning & World Integration

**Spawn distribution**: 40-60% city, 40-60% field. Random positions within zone bounds.

**Performance at 100 entities**:
- EntityVisuals: skip animation updates > 50m from camera
- HP bars: render within 30m only
- PerceptionComponent: O(n) with overlaps, not total entities
- Scripted `_process()`: cheap state checks, no concern

---

## 7. Implementation Order

```
Group A (parallel):  Step 1 (backend) + Step 3 (prompts) + Step 4 (generator)
Group B (sequential): Step 2 (events, needs Step 1) → Step 5 (gossip, needs Step 2)
Group C:             Step 6 (spawning, needs Step 4)
Final:               Step 7 (integration testing, needs all)
```
