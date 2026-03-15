# NPC System Design

## Model Strategy
- **Qwen 3.5 4B** for all generation (~4GB VRAM, consumer-friendly)
- Prompt engineering first, fine-tuning only if we hit a wall prompting can't solve
- Fine-tuning later using conversations we're happy with as training data

## Conversation Architecture
- **One speaker per inference call.** Never generate a full group conversation at once
- Each call: model plays one NPC, sees conversation history, generates one line
- **Turn selection is code, not LLM:** interest scoring based on topic relevance + personality determines who speaks next
- NPCs can join mid-conversation: inject `[NPC walks over, having overheard]` as context cue
- NPCs can leave conversations naturally
- Valid outputs include silence, one-word answers, changing subject, or walking away
- Conversation state object tracks: participants, location, topic, turns, nearby NPCs, mood

## NPC Data Structure

```json
{
  "id": "tom",
  "name": "Old Tom",
  "age": 58,
  "occupation": "retired town guard",

  "personality": {
    "traits": ["paranoid", "gossip-lover", "secretly caring"],
    "speech_style": "Short blunt sentences. Calls everyone under 40 'kid'...",
    "likes": ["ale", "war stories", "routine"],
    "dislikes": ["change", "magic users", "being called old"]
  },

  "desires": [
    { "want": "feel useful and respected", "intensity": "high" },
    { "want": "keep Willowmere safe", "intensity": "medium" },
    { "want": "not be seen as a useless old man", "intensity": "high" }
  ],

  "opinions": [
    {
      "topic": "wolf attacks",
      "take": "guard captain is slacking, wouldn't have happened in my day",
      "strength": "strong",
      "will_share_with": "anyone"
    }
  ],

  "secrets": [
    { "fact": "let a prisoner escape years ago out of pity", "known_by": ["gareth"] }
  ],

  "tendencies": {
    "exaggerates": true,
    "withholds_from_strangers": true,
    "lies_when": "protecting pride",
    "avoids_topic": ["his late wife"]
  },

  "mood": {
    "emotion": "content",
    "energy": "tired",
    "baseline_emotion": "content",
    "baseline_energy": "tired"
  },

  "schedule_type": "routine | goal | periodic",

  "relationships": {
    "gareth": {
      "tier": "close",
      "impression": "Best mate since guard days.",
      "tension": "annoyed he didn't warn me sooner about wolves",
      "history": [
        { "event": "served together in guard 30 years", "timestamp": 0 }
      ]
    },
    "player": {
      "tier": "recognized",
      "impression": "New face. Seems capable.",
      "tension": null,
      "history": [
        { "event": "first met at tavern", "timestamp": 1000 }
      ]
    }
  },

  "memories": [
    {
      "fact": "wolves attacked east gate, three of them",
      "source": "heard_from:gareth",
      "importance": "high",
      "emotional": false,
      "times_reinforced": 1,
      "timestamp": 1200,
      "fuzzy": false
    }
  ],

  "conversation_logs": {}
}
```

## Schedule Types

**Routine** (baker, guard): fixed daily pattern
```json
"routine": [
  { "time": "dawn", "location": "bakery", "activity": "baking" },
  { "time": "morning", "location": "market", "activity": "selling bread" },
  { "time": "evening", "location": "tavern", "activity": "eating" }
]
```

**Goal-driven** (assassin, quest NPCs): behavior follows current objective
```json
"current_goal": {
  "objective": "gather info on merchant guild leader",
  "steps": [
    { "status": "done", "action": "scout merchant district" },
    { "status": "active", "action": "befriend tavern barkeep for intel" },
    { "status": "pending", "action": "find entry point to guild hall" }
  ],
  "fallback_location": "inn_room"
}
```

**Periodic** (traveling merchant): visits on a pattern
```json
"pattern": {
  "visits": "every 3 days",
  "duration": "1 day",
  "location_when_present": "market",
  "location_when_absent": null
}
```

## No World Facts
- Information lives in people's memories, not a global pool
- NPC witnesses event → tells others in conversation → spreads with distortion
- Ignorance is natural: if nobody told you, you don't know
- Player is an information vector: telling the hermit about wolves is a meaningful interaction
- NPCs distort deliberately too: exaggeration (attention), downplaying (self-interest), lying (secrets)

## Memory System

### Extraction
- After each conversation, LLM call extracts facts NPC would remember
- Personality filters what they care about (guard remembers threats, baker remembers "it's dangerous")
- Each memory tagged: fact, source (witnessed/heard_from:X/overheard), importance, emotional flag, timestamp

### Opinions (post-extraction)
- After learning new facts, NPCs can form opinions
- Opinions = personality + fact: same event, different takes per NPC
- Opinions drive conversation more than facts do (people share takes, not information)
- Opinions have strength and sharing preference (anyone / close only / keeps to self)

### Forgetting (Sleep = Garbage Collector)
- Memory score = importance_weight + recency_bonus + repetition_bonus
  - importance: high=10, medium=5, low=2
  - recency: same day=10, yesterday=6, 2-3 days=3, 4-7 days=1, older=0
  - repetition: +3 per additional source confirming same fact
  - emotional: +5 permanent bonus, never goes fuzzy
- Each in-game night, recalculate scores and cleanup:
  - Cap at ~20 memories per NPC
  - Drop lowest scores when over cap
  - Memories below threshold go "fuzzy" (lose specifics)
  - Below lower threshold: dropped entirely

### Fuzzy Degradation
- Sharp: "wolves attacked east gate, three of them"
- Fuzzy: "wolves attacked east gate recently"
- Almost gone: "some trouble at the east gate a while back"

## Relationship System

### Tiers
```
stranger → recognized → acquaintance → friendly → close → bonded
```
- Event-triggered, not point-based
- Each tier unlocks behavior (strangers = generic, close = confide/defend/worry)

### Per-relationship data
- **Tier**: overall closeness level
- **Impression**: LLM-generated one-sentence summary, updated after meaningful interactions
- **Tension**: current friction independent of tier (close friends can be furious at each other)
- **History**: key events in the relationship

### Between NPCs too
- NPCs have relationships with each other, not just with the player
- Drives who talks to whom, who sits together, who gossips about whom

## Behavioral Tendencies
- **Exaggeration**: some NPCs inflate stories for attention
- **Withholding**: NPCs share less with strangers, more with trusted people
- **Lying**: when protecting pride, secrets, or self-interest
- **Topic avoidance**: sensitive subjects NPCs refuse to discuss or deflect from
- **Secrets**: facts only known to specific people, creates tension and depth

## Desires & Proactive Behavior
- NPCs have wants that drive behavior beyond reacting to others
- Desires make NPCs initiate: Tom seeks out the player because he wants to feel relevant
- Desires create internal conflict: the assassin likes the barkeep they're manipulating
- Each desire has intensity (high/medium/low) affecting how much it drives behavior

## Mood System
- Two axes: emotion (content/worried/angry/sad/excited/afraid) + energy (tired/normal/energetic)
- Mood shifts from events (monster attack → worried, festival → excited)
- Decays toward NPC's personal baseline over time
- Feeds directly into prompt, LLM handles the tone

## Prompt Structure
Three assembled blocks per generation call:

**Block 1 - World (constant):**
Setting, technology constraints, no modern stuff

**Block 2 - Character (per NPC):**
Personality, speech style, desires, tendencies, mood, location, secrets (what they know/hide)

**Block 3 - Context (dynamic):**
Relevant relationships + tensions, active memories, current opinions, conversation so far

**Instruction:**
1-2 sentences max (or silence/deflection/walking away). Stay in character. No narration. No modern language. Only reference known memories. Can share opinions, exaggerate, withhold, or lie per tendencies.

## Three-Layer Architecture
- **Code/rules:** conversation management, turn order, mood decay, relationship changes, memory scoring, schedule resolution, event propagation
- **4B model:** dialogue generation, opinion formation, impression updates, memory degradation
- **Smaller model (optional later):** memory extraction (structured, constrained task)
