# Character Models

Source: `assets/models/characters/`, `scripts/data/npc_loadouts.gd`, `scripts/npcs/npc_generator.gd`

All characters use the toon shader (`assets/shaders/toon.gdshader`) applied via `ModelHelper.apply_toon_to_model()`.

---

## Animation Whitelist

`ModelHelper.ANIM_WHITELIST` — only these 6 animations are kept on load; all others are stripped:

| # | Animation Name |
|---|---|
| 1 | `Idle` |
| 2 | `Walking_A` |
| 3 | `Running_A` |
| 4 | `1H_Melee_Attack_Chop` |
| 5 | `Death_A` |
| 6 | `RESET` |

---

## Character Model Table

All models live in `assets/models/characters/`. Scale is 0.7 for all humanoid characters.

| Model File | Path | Scale | Used By |
|---|---|---|---|
| `Knight.glb` | `res://assets/models/characters/Knight.glb` | 0.7 | Player, Kael, Thane; procedural warrior + ranger archetypes |
| `Barbarian.glb` | `res://assets/models/characters/Barbarian.glb` | 0.7 | Bjorn (weapon shop NPC); procedural warrior + ranger archetypes |
| `Mage.glb` | `res://assets/models/characters/Mage.glb` | 0.7 | Lyra, Mira; procedural mage + merchant archetypes |
| `Rogue.glb` | `res://assets/models/characters/Rogue.glb` | 0.7 | Sera, Dusk (item shop); procedural rogue + merchant archetypes |

---

## Unused Models

| Model File | Status |
|---|---|
| `Skeleton_Rogue.glb` | On disk, not referenced by any monster or NPC definition |

---

## Meshy AI Prompts

Use these prompts to generate replacement character models in Meshy AI. All characters use chibi anime style to match the game's toon aesthetic. Characters require humanoid rigging for animation — Meshy supports this via auto-rig with 500+ animation presets.

### Swordsman / Knight

Replaces: `Knight.glb`

```
Chibi anime fantasy swordsman, big head small body, medieval plate armor, sword and shield, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready model, idle standing pose
```

### Mage

Replaces: `Mage.glb`

```
Chibi anime fantasy mage, big head small body, flowing robes, wizard hat, wooden staff, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready model, idle standing pose
```

### Rogue / Thief

Replaces: `Rogue.glb`

```
Chibi anime fantasy rogue, big head small body, hooded leather armor, dual daggers, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready model, idle standing pose
```

### Barbarian

Replaces: `Barbarian.glb`

```
Chibi anime fantasy barbarian, big head small body, fur armor, large two-handed axe, muscular, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready model, idle standing pose
```

### Merchant

Used by procedural merchant archetype NPCs (currently using `Rogue.glb` and `Mage.glb` as proxies).

```
Chibi anime fantasy merchant, big head small body, traveler robes, backpack, friendly expression, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready model, idle standing pose
```
