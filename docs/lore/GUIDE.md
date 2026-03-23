# Arcadia Lore — Writing Guide

## Setting
Classic medieval fantasy. Swords, magic, guilds, monsters. Tone is warm but not childish — the world has real danger but also real community. Think Ragnarok Online meets early Final Fantasy.

## Folder Structure

```
docs/lore/
├── GUIDE.md                        ← you are here
├── world.md                        ← world overview, history, cosmology
│
├── cities/
│   └── {city_name}/
│       ├── {city_name}.md          ← city overview
│       └── people/
│           └── {npc_name}.md       ← character profile
│
├── fields/
│   └── {field_name}/
│       ├── {field_name}.md         ← zone overview
│       └── creatures/
│           └── {creature_name}.md  ← creature/monster lore
│
└── dungeons/
    └── {dungeon_name}/
        ├── {dungeon_name}.md       ← dungeon overview
        └── monsters/
            └── {monster_name}.md   ← boss/monster lore
```

Use lowercase_snake_case for all folder and file names. Match the in-game IDs where possible.

---

## Templates

### world.md
```markdown
# {World Name}

## History
Brief timeline — founding, major events, current era.

## Geography
Continents, regions, climate. How zones connect.

## Magic & Technology
How magic works, who can use it, what limits it.

## Factions
Major groups, their goals, their conflicts.

## Economy
What people trade, what's valuable, currency system.
```

### City — `cities/{city_name}/{city_name}.md`
```markdown
# {City Name}

## Overview
One paragraph — what this city is, why it matters.

## Districts
List each district with 1-2 sentences: purpose, atmosphere, notable buildings.

## Culture
What do people value? Festivals, customs, daily life.

## Economy
What the city produces, trades, needs. Key industries.

## Notable Locations
Specific buildings/landmarks with brief descriptions.

## Threats & Problems
What challenges does this city face? External and internal.
```

### Character — `cities/{city_name}/people/{npc_name}.md`
```markdown
# {Character Name}

## Basics
- **Role**: (merchant, guard, blacksmith, adventurer)
- **Age**:
- **Personality**: 1-2 sentences
- **Appearance**: brief visual description

## Backstory
2-3 paragraphs — where they came from, what shaped them.

## Motivations
What do they want? What are they afraid of?

## Relationships
Key connections to other NPCs. Who do they trust, avoid, admire?

## Dialogue Notes
How they speak — formal, casual, gruff, cheerful. Verbal tics or patterns.
Useful for writing their dialogue tree entries.

## Quests
What quests they give, why, what they need.
```

### Field Zone — `fields/{field_name}/{field_name}.md`
```markdown
# {Field Name}

## Overview
One paragraph — what this zone looks like and feels like.

## Geography
Terrain, landmarks, paths, water features.

## Ecology
What grows here, what lives here naturally.

## Dangers
What monsters spawn here, how aggressive, patrol routes.

## Resources
Gatherable resources (ore, trees, fish spots) and their tiers.

## Connections
How this zone connects to adjacent zones (portals, roads, paths).
```

### Creature — `fields/{field_name}/creatures/{creature_name}.md`
```markdown
# {Creature Name}

## Overview
What it is, how common, how dangerous.

## Appearance
Brief visual description.

## Behavior
Passive or aggressive? Pack or solo? Day or night?

## Combat
Attack patterns, resistances, weaknesses. What it drops.

## Lore
Why it exists here. Origin, ecology, relationship to the world.
```

### Dungeon — `dungeons/{dungeon_name}/{dungeon_name}.md`
```markdown
# {Dungeon Name}

## Overview
What this place was, what it is now, why adventurers go there.

## History
Who built it, what happened, why it's dangerous.

## Floors / Areas
Each floor or section with: theme, monsters, hazards, loot.

## Boss
Name, lore, combat style, what it guards.
```

### Dungeon Monster — `dungeons/{dungeon_name}/monsters/{monster_name}.md`
Same template as field creature, but add:
```markdown
## Floor
Which floor/area this monster appears on.

## Mechanic
Any special dungeon mechanic (key drops, gate guards, traps).
```

---

## Writing Guidelines

1. **Write for the game, not for a novel.** Lore should be usable — it informs dialogue, quest design, zone building, and monster behavior. If it doesn't affect gameplay, it's flavor text (still valuable, but secondary).

2. **Keep it short.** Each file should be scannable in 30 seconds. Use headers, bullet points, short paragraphs. No walls of text.

3. **Be specific, not vague.** "Bjorn lost his brother in the eastern mines" is better than "Bjorn has a tragic past."

4. **Connect everything.** Characters should reference other characters. Zones should reference adjacent zones. Quests should grow from character motivations. The lore is a web, not a list.

5. **Leave room for mystery.** Not everything needs an explanation. Unanswered questions create intrigue. "No one knows what lies below the third floor" is more compelling than a full explanation.

6. **Match the tone.** Warm but not saccharine. Dangerous but not grimdark. Characters are people — they joke, worry, bicker, help each other. The world has problems but also hope.

7. **Name things deliberately.** Names should feel consistent within the world. Avoid mixing Norse, Japanese, and Latin names randomly. Pick a linguistic palette and stick to it.
