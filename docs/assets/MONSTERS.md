# Monster Models

Source: `scripts/data/monster_database.gd`

All monsters use the toon shader (`assets/shaders/toon.gdshader`) applied via `ModelHelper.apply_toon_to_model()`. The `color` field is the entity's minimap/UI indicator color; `model_tint` is an overlay applied on the model mesh.

---

## Monster Table

| Monster | ID | Model | Scale | Color (RGB) | Tint (RGBA) | HP | ATK | DEF | Speed | Aggro Range | Attack Range | XP | Gold | Prof XP | Drops |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Slime | `slime` | `Slime.glb` | 0.7 | (0.2, 0.8, 0.2) | none | 20 | 3 | 1 | 1.2 | 6.0 | 2.0 | 15 | 5 | 3 | jelly (50%) |
| Wolf | `wolf` | `Rogue_Hooded.glb` | 0.5 | (0.5, 0.5, 0.5) | (0.4, 0.35, 0.3, 0.2) | 40 | 7 | 3 | 1.0 | 10.0 | 2.0 | 30 | 10 | 6 | fur (40%) |
| Goblin | `goblin` | `Skeleton_Minion.glb` | 0.5 | (0.2, 0.4, 0.1) | (0.1, 0.3, 0.05, 0.25) | 60 | 10 | 5 | 0.8 | 8.0 | 2.5 | 50 | 20 | 10 | goblin_tooth (30%) |
| Skeleton | `skeleton` | `Skeleton_Warrior.glb` | 0.7 | (0.9, 0.9, 0.85) | none | 80 | 14 | 8 | 0.8 | 10.0 | 2.5 | 80 | 30 | 16 | bone (40%) |
| Dark Mage | `dark_mage` | `Skeleton_Mage.glb` | 0.7 | (0.3, 0.1, 0.4) | (0.2, 0.05, 0.3, 0.15) | 60 | 18 | 4 | 1.6 | 12.0 | 3.0 | 100 | 40 | 20 | dark_crystal (25%) |

Speed column is `attack_speed`. Gold values are fixed drops, not ranges. Wander radius: slime 5.0, wolf 8.0, goblin 6.0, skeleton 5.0, dark_mage 4.0.

---

## Proxy Models

Two monsters currently use placeholder character models with color tints because no dedicated models exist:

| Monster | Proxy Model | Tint | Priority |
|---|---|---|---|
| Wolf | `Rogue_Hooded.glb` (humanoid character) | `Color(0.4, 0.35, 0.3, 0.2)` grey | High — needs quadruped model |
| Goblin | `Skeleton_Minion.glb` (skeleton minion) | `Color(0.1, 0.3, 0.05, 0.25)` green | High — needs goblin model |

Replacing these is listed as high priority in `docs/ASSETS.md` section 15.

---

## Meshy AI Prompts

Use these prompts to generate dedicated monster models in Meshy AI. Monsters use realistic proportions (not chibi) to distinguish them visually from player characters.

Wolf and goblin need non-humanoid or quadruped rigging. Meshy supports quadruped auto-rigging with 500+ animation presets.

### Wolf

Replaces proxy `Rogue_Hooded.glb`. Needs quadruped rigging.

```
Fantasy wolf, realistic proportions, fierce stance, grey-brown fur, muscular build, sharp fangs, alert ears, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready model, idle standing pose
```

### Goblin

Replaces proxy `Skeleton_Minion.glb`. Needs non-humanoid or short-biped rigging.

```
Fantasy goblin, short but realistic proportions, green skin, pointy ears, hunched aggressive posture, ragged loincloth, wooden club, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready model, idle standing pose
```

### Slime

Replaces `Slime.glb`. No rigging required — animate via shader or morph targets.

```
Round translucent slime creature, jelly body, simple cute face, soft green, smooth surface, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready model
```

### Skeleton Warrior

Replaces `Skeleton_Warrior.glb`. Needs humanoid rigging.

```
Fantasy skeleton warrior, bone armor remnants, tattered cloth, rusted sword, undead, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready model, idle standing pose
```

### Dark Mage

Replaces `Skeleton_Mage.glb`. Needs humanoid rigging.

```
Fantasy undead dark mage, skeletal figure, dark purple robes, glowing staff, menacing hood, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready model, idle standing pose
```
