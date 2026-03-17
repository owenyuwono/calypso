# Arcadia — Asset Reference

Complete inventory of all assets referenced by code, organized by type. All values are taken directly from source files — nothing is approximated.

---

## Table of Contents

1. [Character Models](#1-character-models)
2. [Monster Database](#2-monster-database)
3. [Item Database](#3-item-database)
4. [Skill Database](#4-skill-database)
5. [Proficiency System](#5-proficiency-system)
6. [Equipment Slots & UI Icons](#6-equipment-slots--ui-icons)
7. [Environment — Dungeon Props](#7-environment--dungeon-props)
8. [Environment — Nature: Trees](#8-environment--nature-trees)
9. [Environment — Nature: Foliage](#9-environment--nature-foliage)
10. [Terrain Textures](#10-terrain-textures)
11. [Shaders](#11-shaders)
12. [Audio](#12-audio)
13. [City Districts & Buildings](#13-city-districts--buildings)
14. [Procedural NPC Generation](#14-procedural-npc-generation)
15. [Needed Assets (Missing)](#15-needed-assets-missing)
16. [Unused Assets Summary](#16-unused-assets-summary)

---

## 1. Character Models

All character models live in `assets/models/characters/`. All characters (player, NPC, monsters) use the toon shader (`assets/shaders/toon.gdshader`) applied via `ModelHelper.apply_toon_to_model()`.

### Animation Whitelist

`ModelHelper.ANIM_WHITELIST` — only these 6 animations are kept on load; all others are stripped:

| # | Animation Name |
|---|----------------|
| 1 | `Idle` |
| 2 | `Walking_A` |
| 3 | `Running_A` |
| 4 | `1H_Melee_Attack_Chop` |
| 5 | `Death_A` |
| 6 | `RESET` |

### Playable / NPC Character Models

| Model File | Path | Scale | Used By |
|---|---|---|---|
| `Knight.glb` | `res://assets/models/characters/Knight.glb` | 0.7 | Player, Kael, Thane; procedural warrior/ranger archetypes |
| `Barbarian.glb` | `res://assets/models/characters/Barbarian.glb` | 0.7 | Bjorn (weapon shop NPC); procedural warrior/ranger archetypes |
| `Mage.glb` | `res://assets/models/characters/Mage.glb` | 0.7 | Lyra, Mira; procedural mage/merchant archetypes |
| `Rogue.glb` | `res://assets/models/characters/Rogue.glb` | 0.7 | Sera, Dusk (item shop); procedural rogue/merchant archetypes |

### Monster Models

| Model File | Used For | Scale | Notes |
|---|---|---|---|
| `Slime.glb` | Slime monster | 0.7 (0.7 from monster_database) | Dedicated model |
| `Rogue_Hooded.glb` | Wolf monster | 0.5 | Proxy — no wolf model. Tinted `Color(0.4, 0.35, 0.3, 0.2)` |
| `Skeleton_Minion.glb` | Goblin monster | 0.5 | Proxy — no goblin model. Tinted `Color(0.1, 0.3, 0.05, 0.25)` |
| `Skeleton_Warrior.glb` | Skeleton monster | 0.7 | Dedicated model |
| `Skeleton_Mage.glb` | Dark Mage monster | 0.7 | Tinted `Color(0.2, 0.05, 0.3, 0.15)` |

### Unused Character Models on Disk

| Model File | Status |
|---|---|
| `Skeleton_Rogue.glb` | On disk, not referenced by any monster or NPC definition |

---

## 2. Monster Database

Source: `scripts/data/monster_database.gd`

| Monster | Monster ID | Model | Scale | Color (RGB) | Tint (RGBA) | HP | ATK | DEF | Speed (attack_speed) | Aggro Range | Attack Range | XP | Gold | Prof XP | Wander Radius | Drops |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Slime | `slime` | `Slime.glb` | 0.7 | (0.2, 0.8, 0.2) | none | 20 | 3 | 1 | 1.2 | 6.0 | 2.0 | 15 | 5 | 3 | 5.0 | jelly (50%) |
| Wolf | `wolf` | `Rogue_Hooded.glb` | 0.5 | (0.5, 0.5, 0.5) | (0.4, 0.35, 0.3, 0.2) | 40 | 7 | 3 | 1.0 | 10.0 | 2.0 | 30 | 10 | 6 | 8.0 | fur (40%) |
| Goblin | `goblin` | `Skeleton_Minion.glb` | 0.5 | (0.2, 0.4, 0.1) | (0.1, 0.3, 0.05, 0.25) | 60 | 10 | 5 | 0.8 | 8.0 | 2.5 | 50 | 20 | 10 | 6.0 | goblin_tooth (30%) |
| Skeleton | `skeleton` | `Skeleton_Warrior.glb` | 0.7 | (0.9, 0.9, 0.85) | none | 80 | 14 | 8 | 0.8 | 10.0 | 2.5 | 80 | 30 | 16 | 5.0 | bone (40%) |
| Dark Mage | `dark_mage` | `Skeleton_Mage.glb` | 0.7 | (0.3, 0.1, 0.4) | (0.2, 0.05, 0.3, 0.15) | 60 | 18 | 4 | 1.6 | 12.0 | 3.0 | 100 | 40 | 20 | 4.0 | dark_crystal (25%) |

Gold values in `monster_database.gd` represent fixed gold drops (not ranges). The `color` field is the entity's minimap/UI indicator color; `model_tint` is an overlay applied on the model mesh.

---

## 3. Item Database

Source: `scripts/data/item_database.gd`

### Consumables

| Item ID | Name | Type | Heal | Buy/Sell Value |
|---|---|---|---|---|
| `healing_potion` | Healing Potion | consumable | 30 HP | 20 |

### Weapons

All weapons use `slot_type: "main_hand"`. Dagger has `attack_speed: 0.7`; all others have no explicit attack_speed override.

#### Swords (`weapon_type: "sword"`, `required_skill: "sword"`)

| Item ID | Name | Tier | ATK Bonus | Required Level | Value |
|---|---|---|---|---|---|
| `basic_sword` | Basic Sword | 1 | +5 | 1 | 50 |
| `iron_sword` | Iron Sword | 2 | +10 | 3 | 150 |
| `steel_sword` | Steel Sword | 3 | +15 | 5 | 400 |
| `mithril_sword` | Mithril Sword | 4 | +20 | 7 | 800 |
| `dragon_sword` | Dragon Sword | 5 | +25 | 9 | 1500 |

#### Axes (`weapon_type: "axe"`, `required_skill: "axe"`)

| Item ID | Name | Tier | ATK Bonus | Required Level | Value |
|---|---|---|---|---|---|
| `basic_axe` | Basic Axe | 1 | +5 | 1 | 50 |
| `iron_axe` | Iron Axe | 2 | +10 | 3 | 150 |
| `steel_axe` | Steel Axe | 3 | +15 | 5 | 400 |
| `mithril_axe` | Mithril Axe | 4 | +20 | 7 | 800 |
| `dragon_axe` | Dragon Axe | 5 | +25 | 9 | 1500 |

#### Maces (`weapon_type: "mace"`, `required_skill: "mace"`)

| Item ID | Name | Tier | ATK Bonus | Required Level | Value |
|---|---|---|---|---|---|
| `basic_mace` | Basic Mace | 1 | +5 | 1 | 50 |
| `iron_mace` | Iron Mace | 2 | +10 | 3 | 150 |
| `steel_mace` | Steel Mace | 3 | +15 | 5 | 400 |
| `mithril_mace` | Mithril Mace | 4 | +20 | 7 | 800 |
| `dragon_mace` | Dragon Mace | 5 | +25 | 9 | 1500 |

#### Daggers (`weapon_type: "dagger"`, `required_skill: "dagger"`, `attack_speed: 0.7`)

| Item ID | Name | Tier | ATK Bonus | Required Level | Value |
|---|---|---|---|---|---|
| `basic_dagger` | Basic Dagger | 1 | +4 | 1 | 50 |
| `iron_dagger` | Iron Dagger | 2 | +8 | 3 | 150 |
| `steel_dagger` | Steel Dagger | 3 | +12 | 5 | 400 |
| `mithril_dagger` | Mithril Dagger | 4 | +16 | 7 | 800 |
| `dragon_dagger` | Dragon Dagger | 5 | +20 | 9 | 1500 |

#### Staves (`weapon_type: "staff"`, `required_skill: "staff"`)

| Item ID | Name | Tier | ATK Bonus | Required Level | Value |
|---|---|---|---|---|---|
| `basic_staff` | Basic Staff | 1 | +5 | 1 | 50 |
| `iron_staff` | Iron Staff | 2 | +10 | 3 | 150 |
| `steel_staff` | Steel Staff | 3 | +15 | 5 | 400 |
| `mithril_staff` | Mithril Staff | 4 | +20 | 7 | 800 |
| `dragon_staff` | Dragon Staff | 5 | +25 | 9 | 1500 |

### Shields (`type: "armor"`, `slot_type: "off_hand"`, `required_skill: "constitution"`)

| Item ID | Name | Tier | DEF Bonus | Required Level | Value |
|---|---|---|---|---|---|
| `basic_shield` | Basic Shield | 1 | +3 | 1 | 50 |
| `iron_shield` | Iron Shield | 2 | +6 | 3 | 150 |
| `steel_shield` | Steel Shield | 3 | +9 | 5 | 400 |
| `mithril_shield` | Mithril Shield | 4 | +12 | 7 | 800 |
| `dragon_shield` | Dragon Shield | 5 | +15 | 9 | 1500 |

### Monster Drops (`type: "material"`, sell only)

| Item ID | Name | Sell Value | Source |
|---|---|---|---|
| `jelly` | Jelly | 8 | Slime (50%) |
| `fur` | Fur | 15 | Wolf (40%) |
| `goblin_tooth` | Goblin Tooth | 25 | Goblin (30%) |
| `bone` | Bone | 20 | Skeleton (40%) |
| `dark_crystal` | Dark Crystal | 50 | Dark Mage (25%) |

---

## 4. Skill Database

Source: `scripts/data/skill_database.gd`

All 16 active skills. All skills have `max_level: 5` and use animation `1H_Melee_Attack_Chop`.

### Per-Level Scaling Formulas

```
effective_multiplier(skill_id, level) = damage_multiplier + (level - 1) * damage_multiplier_per_level
effective_cooldown(skill_id, level)   = max(0.5, cooldown - (level - 1) * cooldown_reduction_per_level)
```

### Sword Skills

| Skill | ID | Type | Req. Prof Level | Cooldown (s) | Damage Mult | Mult/Level | CD Reduction/Level | Color (RGB) | AoE Radius | AoE Center | Special |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Bash | `bash` | `melee_attack` | sword 2 | 3.0 | 1.5 | +0.1 | -0.2 | (0.9, 0.4, 0.2) | — | — | — |
| Cleave | `cleave` | `aoe_melee` | sword 4 | 5.0 | 1.0 | +0.08 | -0.2 | (0.9, 0.6, 0.2) | 3.0 | target | — |
| Rend | `rend` | `bleed` | sword 6 | 6.0 | 0.6 | +0.06 | -0.2 | (0.8, 0.2, 0.2) | — | — | 3 ticks, 3.0s duration, 0.3× per tick |

### Axe Skills

| Skill | ID | Type | Req. Prof Level | Cooldown (s) | Damage Mult | Mult/Level | CD Reduction/Level | Color (RGB) | AoE Radius | AoE Center | Special |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Chop | `chop` | `melee_attack` | axe 2 | 3.0 | 1.6 | +0.1 | -0.2 | (0.7, 0.5, 0.2) | — | — | — |
| Whirlwind | `whirlwind` | `aoe_melee` | axe 4 | 5.0 | 1.1 | +0.08 | -0.2 | (0.7, 0.7, 0.3) | 3.5 | self | — |
| Execute | `execute` | `armor_pierce` | axe 6 | 7.0 | 1.8 | +0.1 | -0.2 | (0.6, 0.1, 0.1) | — | — | Ignores 75% DEF |

### Mace Skills

| Skill | ID | Type | Req. Prof Level | Cooldown (s) | Damage Mult | Mult/Level | CD Reduction/Level | Color (RGB) | AoE Radius | AoE Center | Special |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Crush | `crush` | `melee_attack` | mace 2 | 3.0 | 1.5 | +0.1 | -0.2 | (0.5, 0.5, 0.7) | — | — | — |
| Shatter | `shatter` | `armor_pierce` | mace 4 | 5.0 | 1.3 | +0.08 | -0.2 | (0.4, 0.4, 0.8) | — | — | Ignores 50% DEF |
| Quake | `quake` | `aoe_melee` | mace 6 | 6.0 | 0.9 | +0.07 | -0.2 | (0.6, 0.4, 0.3) | 4.0 | self | — |

### Dagger Skills

| Skill | ID | Type | Req. Prof Level | Cooldown (s) | Damage Mult | Mult/Level | CD Reduction/Level | Color (RGB) | AoE Radius | AoE Center | Special |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Stab | `stab` | `melee_attack` | dagger 2 | 2.0 | 1.3 | +0.1 | -0.15 | (0.3, 0.7, 0.3) | — | — | — |
| Lacerate | `lacerate` | `bleed` | dagger 4 | 4.0 | 0.5 | +0.05 | -0.15 | (0.7, 0.2, 0.3) | — | — | 4 ticks, 4.0s duration, 0.25× per tick |
| Backstab | `backstab` | `armor_pierce` | dagger 6 | 5.0 | 2.0 | +0.12 | -0.15 | (0.2, 0.2, 0.2) | — | — | Ignores 100% DEF |

### Staff Skills

| Skill | ID | Type | Req. Prof Level | Cooldown (s) | Damage Mult | Mult/Level | CD Reduction/Level | Color (RGB) | AoE Radius | AoE Center | Special |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Arcane Bolt | `arcane_bolt` | `melee_attack` | staff 2 | 2.5 | 1.4 | +0.1 | -0.2 | (0.5, 0.3, 0.9) | — | — | — |
| Flame Burst | `flame_burst` | `aoe_melee` | staff 4 | 5.0 | 0.8 | +0.06 | -0.2 | (0.9, 0.3, 0.1) | 3.5 | target | — |
| Drain | `drain` | `bleed` | staff 6 | 6.0 | 0.5 | +0.05 | -0.2 | (0.4, 0.1, 0.5) | — | — | 3 ticks, 3.0s duration, 0.35× per tick |

### Skill Type Definitions

| Type | Behavior |
|---|---|
| `melee_attack` | Single-target hit against primary target |
| `aoe_melee` | Hits all entities within `aoe_radius` of `aoe_center` (self or target) via PerceptionComponent |
| `armor_pierce` | Ignores `def_ignore_percent` of target's DEF |
| `bleed` | Initial hit at `damage_multiplier`, then `bleed_ticks` ticks of `bleed_multiplier_per_tick × ATK` over `bleed_duration` seconds |

---

## 5. Proficiency System

Source: `scripts/data/proficiency_database.gd`

Global constants: `MAX_LEVEL = 10`, XP formula: `get_xp_to_next_level(current_level) = current_level * 50`

| Skill ID | Name | Category | XP Source | Stat Derivation |
|---|---|---|---|---|
| `sword` | Sword | weapon | XP per hit dealt with a sword | ATK = 5 + sword_level × 2 |
| `axe` | Axe | weapon | XP per hit dealt with an axe | ATK = 5 + axe_level × 2 |
| `mace` | Mace | weapon | XP per hit dealt with a mace | ATK = 5 + mace_level × 2 |
| `dagger` | Dagger | weapon | XP per hit dealt with a dagger | ATK = 5 + dagger_level × 2 |
| `staff` | Staff | weapon | XP per hit dealt with a staff | ATK = 5 + staff_level × 2 |
| `constitution` | Constitution | attribute | XP per hit taken in combat | DEF = 3 + constitution_level; Max HP = 40 + constitution_level × 10 |
| `agility` | Agility | attribute | XP per distance traveled (placeholder) | Not yet derived |
| `mining` | Mining | gathering | XP per mine action (not yet implemented) | Placeholder |
| `woodcutting` | Woodcutting | gathering | XP per chop action (not yet implemented) | Placeholder |
| `fishing` | Fishing | gathering | XP per fish action (not yet implemented) | Placeholder |
| `smithing` | Smithing | production | XP per smith action (not yet implemented) | Placeholder |
| `cooking` | Cooking | production | XP per cook action (not yet implemented) | Placeholder |
| `crafting` | Crafting | production | XP per craft action (not yet implemented) | Placeholder |

Player total level = sum of all 13 proficiency levels. Default starting level for every proficiency is 1 with 0 XP.

---

## 6. Equipment Slots & UI Icons

Source: `assets/textures/ui/equip_slots/`, referenced by `scenes/ui/inventory_panel.gd`

All 8 equipment slots have placeholder sprite icons. No actual item icons exist yet.

| Slot Name | Icon Path | Description |
|---|---|---|
| `head` | `assets/textures/ui/equip_slots/head.png` | Helmet/headgear |
| `torso` | `assets/textures/ui/equip_slots/torso.png` | Body armor / chest |
| `legs` | `assets/textures/ui/equip_slots/legs.png` | Leg armor |
| `gloves` | `assets/textures/ui/equip_slots/gloves.png` | Gloves / gauntlets |
| `feet` | `assets/textures/ui/equip_slots/feet.png` | Boots / footwear |
| `back` | `assets/textures/ui/equip_slots/back.png` | Cape / back slot |
| `main_hand` | `assets/textures/ui/equip_slots/main_hand.png` | Primary weapon |
| `off_hand` | `assets/textures/ui/equip_slots/off_hand.png` | Shield / off-hand |

Note: Only `main_hand` (weapons) and `off_hand` (shields) slots are populated by current item data. Head, torso, legs, gloves, feet, and back slots exist in `EquipmentComponent` but no items in `ItemDatabase` target them.

---

## 7. Environment — Dungeon Props

Source: KayKit Dungeon Remastered (CC0)
Path: `assets/models/environment/dungeon/`

Spawned via `AssetSpawner.spawn_dungeon_model(ctx, filename, pos)`.

| File | Actively Used | Where / How Many Instances |
|---|---|---|
| `torch_lit.gltf.glb` | Yes | City: east gate (4), west gate (4), market shops (4), temple quarter (1), craft (1), garrison (3), library (1), chapel annex (1), guard tower (2), armory (1), gazebo (1), gatehouse (1), commerce row (3), artisan quarter (2), civic district (2), craft row (1), military compound (2), gate district (2); city wall interior: north (8), south (8), west (5), east (4). Total ~60+ instances |
| `torch_mounted.gltf.glb` | Yes | City wall interior: north wall (8), south wall (8), west wall (5), east wall (4). Total 25 instances |
| `banner_red.gltf.glb` | Yes | East gate road (8 banners), temple/noble quarter (2), garrison (1). Total ~11 instances |
| `barrel_large.gltf.glb` | Yes | Market district (6+), craft district (2), residential (1), house props (2), garrison (4), bakery (1), commerce row (1), artisan quarter (1), craft row (2), military compound (2). Total ~25 instances |
| `barrel_small.gltf.glb` | Yes | Market district (1 at Vector3(-53, 0, 28)) |
| `crates_stacked.gltf.glb` | Yes | Market district (2+), craft district (2), residential stalls (1), bakery (1), storage shed (2), garrison (2), gatehouse (1), all cluster districts. Total ~20+ instances |
| `pillar_decorated.gltf.glb` | Yes | Temple/noble quarter (2), central plaza corners (4). Total 6 instances |
| `chest.glb` | No | On disk, no spawn call found |
| `pillar.gltf.glb` | No | On disk, no spawn call found |
| `wall.gltf.glb` | No | On disk, no spawn call found |
| `wall_arched.gltf.glb` | No | On disk, no spawn call found |
| `wall_broken.gltf.glb` | No | On disk, no spawn call found |
| `wall_corner.gltf.glb` | No | On disk, no spawn call found |
| `wall_doorway.glb` | No | On disk, no spawn call found |
| `wall_endcap.gltf.glb` | No | On disk, no spawn call found |
| `wall_half.gltf.glb` | No | On disk, no spawn call found |
| `wall_pillar.gltf.glb` | No | On disk, no spawn call found |
| `stairs.gltf.glb` | No | On disk, no spawn call found |
| `floor_dirt_large.gltf.glb` | No | On disk, no spawn call found |
| `floor_dirt_small_A.gltf.glb` | No | On disk, no spawn call found |
| `floor_tile_large.gltf.glb` | No | On disk, no spawn call found |
| `floor_tile_small.gltf.glb` | No | On disk, no spawn call found |

Each `.gltf.glb` file has a corresponding `_dungeon_texture.png` sidecar used by the model's built-in material.

---

## 8. Environment — Nature: Trees

Source: FBX nature pack (pre-textured via bark/leaf textures)
Path: `assets/models/environment/nature/trees/fir/`

`AssetSpawner.spawn_tree()` applies bark and leaf materials from `trees/textures/` and adds trunk collision (CylinderShape3D, radius 0.3, height 3.0).

### Tree Models

| File | Actively Used | Notes |
|---|---|---|
| `SM_FirTree1.FBX` | Yes | City biomes (park, residential, noble gardens) + field biomes (dense forest, transitional areas) |
| `SM_FirTree2.FBX` | Yes | Same biomes as SM_FirTree1 |
| `SM_FirTree3.FBX` | Yes | Same biomes as SM_FirTree1 |
| `SM_FirTree4.FBX` | Yes | Same biomes as SM_FirTree1 |
| `SM_FirTree5.FBX` | Yes | Same biomes as SM_FirTree1 |
| `SM_FirSapling1.FBX` | Yes | Field path-edge scatter and city-field border transition |
| `SM_FirSapling2.FBX` | Yes | Field path-edge scatter and city-field border transition |
| `SM_FirStump1.FBX` | Yes | Rocky clearing biome (field), transitional SW biome (1 stump each) |
| `SM_FirFallen1.FBX` | Yes | Rocky clearing biome (east + west field, 2 instances each) |
| `SM_FirFallen2.FBX` | Yes | Rocky clearing biome (east + west field, 2 instances each) |
| `SM_FirFallen3.FBX` | No | On disk, not referenced in any biome recipe |
| `SM_FirBranch1.FBX` | No | On disk, not referenced in any biome recipe |
| `SM_FirBranch2.FBX` | No | On disk, not referenced in any biome recipe |

### Tree Textures (Used by AssetSpawner)

| File | Used In |
|---|---|
| `T_FirBark_BC.PNG` | `create_bark_material()` — bark albedo for fir trees |
| `T_FirBarkMisc_BC.PNG` | `create_bark_material(misc=true)` — stump/fallen bark albedo |
| `T_Leaf_Fir_Filled.PNG` | `create_leaf_material()` — leaf albedo for fir trees |

### Tree Texture Files on Disk (Unused by Code)

The `trees/textures/` directory contains textures for many additional tree species whose models are not in the project:

Unused texture sets: Bamboo (BC/N/R), Banana, Birch, ChinaPina, CoconutPalm, DesertCoconutPalm, DesertPalm, Knotwood, Oak, PalmWood, PineBark, RedMaple, WindsweptBark, and all their leaf variants. Also unused fir normal/roughness maps: `T_FirBark_N.PNG`, `T_FirBark_R.PNG`, `T_FirBarkMisc_N.PNG`, `T_FirBarkMisc_R.PNG`.

---

## 9. Environment — Nature: Foliage

Source: FBX nature pack (CC0)
Path: `assets/models/environment/nature/foliage/`

`AssetSpawner.spawn_foliage()` applies a flat color material. Scale is 0.25 for all foliage instances.

### Actively Used

| File | Used In (Biome) |
|---|---|
| `SM_Bush1.FBX` | City residential gardens; field transitional SW, border transition, dense forest |
| `SM_Bush2.FBX` | City residential gardens; field transitional SW, border transition, dense forest |
| `SM_Bush3.FBX` | City residential gardens; field transitional SW, border transition, dense forest |
| `SM_BushLeafy01.FBX` | City park/gardens, noble garden; field transitional SW, border transition, dense forest |
| `SM_BushLeafy02.FBX` | City park/gardens, noble garden; field transitional SW, border transition, dense forest |
| `SM_Fern1.FBX` | City park/gardens; field dense forest, rocky clearing, transitional NE, path-edge, border transition |
| `SM_Fern2.FBX` | City park/gardens; field dense forest, rocky clearing, transitional NE, path-edge, border transition |
| `SM_Fern3.FBX` | City park/gardens; field dense forest, rocky clearing, transitional NE, path-edge, border transition |
| `SM_FlowerBush01.FBX` | City park/gardens, noble garden, central plaza; field open meadow |
| `SM_FlowerBush02.FBX` | City park/gardens |
| `SM_Flower_Daisies1.FBX` | City park/gardens, central plaza |
| `SM_Flower_TulipsRed.FBX` | City park/gardens |
| `SM_Flower_TulipsYellow.FBX` | City park/gardens, central plaza |
| `SM_FlowerCrocus01.FBX` | Field open meadow |
| `SM_Flower_Allium.FBX` | Field open meadow |
| `SM_Flower_Foxtails1.FBX` | Field open meadow |
| `SM_Flower_DaffodilsYellow.FBX` | Field open meadow |
| `SM_Flower_Sunflower1.FBX` | Field open meadow |
| `SM_Flower_Sunflower2.FBX` | Field open meadow |
| `SM_Flower_Sunflower3.FBX` | Field open meadow |
| `SM_Flower_TulipsOrange.FBX` | (referenced via flower_orange color in field meadow) — note: `SM_Flower_TulipsOrange.FBX` is on disk but field meadow uses `flower_files` array which includes Foxtails not TulipsOrange |
| `SM_Grass1.FBX` | Field open meadow, dense forest, rocky clearing, transitional NE/SW, path-edge, border transition |
| `SM_Grass2.FBX` | Field open meadow, dense forest, rocky clearing, transitional NE/SW, path-edge, border transition |

### Available (Unused)

All files below are on disk in `assets/models/environment/nature/foliage/` but are not referenced in any biome recipe:

`SM_BambooBush01.FBX`, `SM_BushChina01.FBX`, `SM_BushChina02.FBX`, `SM_BushChina03.FBX`, `SM_BushSnowDead01.FBX`, `SM_BushSnowDead02.FBX`, `SM_BushTropical01.FBX`, `SM_BushTropical02.FBX`, `SM_BushTropical03.FBX`, all `SM_Cactus*.FBX` (8 variants), all `SM_CactusBulb*.FBX` (2), all `SM_CactusPricklyPear*.FBX` (4), all `SM_DesertBush*.FBX` (6), all `SM_DesertTwigRoots*.FBX` (3), all `SM_DesertWeed*.FBX` (3), all `SM_ElephantEars*.FBX` (3), `SM_FlowerCrocus02.FBX`, all `SM_FlowerDesertBulb*.FBX` (5), all `SM_FlowerDesertPink*.FBX` (3), `SM_Flower_DaffodilsOrange.FBX`, `SM_Flower_DaffodilsPink.FBX`, `SM_Flower_FoxtailsLight1.FBX`, `SM_Flower_TulipsPink.FBX`, `SM_Flower_TulipsOrange.FBX`, all `SM_FlowersIce*.FBX` (3), all `SM_IvyCoastal*.FBX` (5), all `SM_IvyCoastalCurved*.FBX` (3), all `SM_IvyCoastalVine*.FBX` (8), `SM_LilyPad1.FBX`, `SM_LilyPad2.FBX`, `SM_LilyPad3.FBX`, `SM_LilyPadClump2.FBX`, `SM_Marshtail01.FBX`, `SM_Marshtail02.FBX`, `SM_Marshtail03.FBX`, and more.

---

## 10. Terrain Textures

Source: `scenes/game_world/game_world.gd`, shader: `assets/shaders/terrain_blend.gdshader`

The terrain shader blends up to 5 texture channels per zone using vertex colors painted by terrain rules.

### Shader Channel Mapping

| Channel | Shader Param | Texture Role | UV Scale Param | UV Scale Value |
|---|---|---|---|---|
| Default (no paint) | `texture_grass` | Base ground / grass / pavement | `uv_scale_pavement` | 0.5 |
| R (channel 0) | `texture_dirt` | Dirt paths, market district | `uv_scale_dirt` | 0.25 |
| G (channel 1) | `texture_stone` | Stone roads, rocky clearings | `uv_scale_stone` | 0.2 |
| B (channel 2) | `texture_cobble` | Cobblestone roads (city roads, central plaza) | `uv_scale_cobble` | 0.5 |
| A inverted (channel 3) | `texture_packed_earth` | Packed earth / brick pavement (district grounds) | `uv_scale_earth` | 0.5 |

Additional shader parameter: `blend_sharpness = 1.5`

### Per-Zone Texture Assignments

| Zone | `texture_grass` (default) | `texture_dirt` (ch 0) | `texture_stone` (ch 1) | `texture_cobble` (ch 2) | `texture_packed_earth` (ch 3) |
|---|---|---|---|---|---|
| City | `Bricks/Bricks_23-512x512.png` | `dirt_albedo.png` | `stone_albedo.png` | `Bricks/Bricks_17-512x512.png` | `Bricks/Bricks_23-512x512.png` |
| East Field | `grass_town.png` | `dirt_albedo.png` | `stone_albedo.png` | (null — not used) | (null — not used) |
| West Field | `grass_town.png` | `dirt_albedo.png` | `stone_albedo.png` | (null — not used) | (null — not used) |

Full texture paths are under `assets/textures/terrain/`:
- `dirt_albedo.png`
- `stone_albedo.png`
- `grass_town.png`
- `Bricks/Bricks_17-512x512.png` — cobblestone roads (shader param `texture_cobble`)
- `Bricks/Bricks_23-512x512.png` — packed earth pavement and city grass base (shader param `texture_packed_earth` and `texture_grass` in city)

### Terrain Textures on Disk but Unused

The `assets/textures/terrain/` directory contains large texture libraries that are not referenced by code:

- `Bricks/` — 25 brick variants (Bricks_01 through Bricks_25); only Bricks_17 and Bricks_23 are used
- `Roofs/` — 25 roof texture variants (Roofs_01 through Roofs_25); none used (buildings are procedural colored BoxMesh)
- `Wood/` — 25 wood texture variants (Wood_01 through Wood_25); none used
- `Tile/` — 25 tile texture variants (Tile_01 through Tile_25); none used

---

## 11. Shaders

Source: `assets/shaders/`

| File | Type | Purpose | Used By |
|---|---|---|---|
| `toon.gdshader` | Vertex/Fragment | Toon shading with hard shadow bands; supports `albedo_color`, `albedo_texture`, `use_texture`, `alpha_multiplier` params | All characters (player, NPCs, monsters) via `ModelHelper.apply_toon_to_model()` and `ModelHelper.create_toon_material()` |
| `toon_cutout.gdshader` | Vertex/Fragment | Toon shading variant with alpha-cutout transparency | On disk; not confirmed to be actively referenced in current codebase |
| `terrain_blend.gdshader` | Vertex/Fragment | Vertex-color-based texture blending for terrain meshes; 5-channel blend with configurable UV scales and `blend_sharpness` | All terrain meshes (city, east field, west field) via `game_world.gd` |
| `outline.gdshader` | Vertex/Fragment | Object outline pass | On disk; not confirmed to be actively referenced in current codebase |

---

## 12. Audio

No audio assets exist on the `master` branch.

An audio system (zone-based BGM crossfade + signal-driven SFX) was implemented on the `main` branch but has not been merged. When that work is merged, this section should be updated with:
- BGM track files and zone assignments
- SFX files and the GameEvents signals that trigger them

---

## 13. City Districts & Buildings

Source: `scripts/world/city_builder.gd`, `scripts/world/districts/`, `scripts/world/town_builder.gd`

### City Zone Layout

City terrain: center (0, 0, 0), 140×100 units, x: −70..70, z: −50..50.

| District | Class | X Range | Z Range |
|---|---|---|---|
| Central Plaza | `DistrictPlaza` | −15..20 | −10..10 |
| Market District | `DistrictMarket` | −70..−20 | −10..50 |
| Residential Quarter | `DistrictResidential` | −70..−20 | −50..−10 |
| Noble/Temple Quarter | `DistrictNoble` | −20..25 | −50..−10 |
| Park/Gardens | `DistrictPark` | 25..70 | −50..−10 |
| Craft/Workshop | `DistrictCraft` | −20..25 | 10..50 |
| Garrison/Training | `DistrictGarrison` | 25..70 | 10..50 |
| City Gate Area | `DistrictGate` | 55..70 | −10..10 |

### City Wall

Color: `Color(0.45, 0.42, 0.38)` (warm grey stone)
Wall height: 4.0 units, thickness: 1.0 unit
Corner towers: height 5.5, width 3.0
Gate towers: height 6.0, width 3.0
Gate gaps: x=−70 and x=70, z=−5..5 (10-unit gap)
Gatehouse archway: BoxMesh 1.0×1.5×10.0, placed at y = 4.75 (above walking height)
Crenellations: 4 per tower, 0.4×0.6×0.4 units at tower corners

### Buildings by District

All buildings are procedural BoxMesh geometry built via `BuildingHelper.create_building()`. Roof types: `"peaked"` or `"flat"`. Color values are wall/facade colors; roof colors are separate.

#### Central Plaza (DistrictPlaza)

| Structure | Position | Notes |
|---|---|---|
| Fountain | (0, y, 0) | Procedural CylinderMesh, basin radius 1.5/height 0.4, upper basin radius 1.2/height 0.8 |
| Benches (4) | (±3, y, 0), (0, y, ±3) | Procedural plank + legs |
| Street Lamps (4) | (±8, y, ±8) | CylinderMesh post + SphereMesh glow, emission `Color(1.0, 0.85, 0.5)`, energy 0.5 |

#### Market District (DistrictMarket)

| Building | Position | Size (W×H×D) | Wall Color | Roof Type | Roof Color |
|---|---|---|---|---|---|
| Weapon Shop | (−45, y, 20) | 6×3.5×5 | (0.55, 0.38, 0.22) | peaked | (0.5, 0.18, 0.1) |
| Item Shop | (−55, y, 30) | 5×3×4 | (0.55, 0.48, 0.35) | peaked | (0.2, 0.4, 0.15) |
| Bakery | (−30, y, 30) | 4×3×4 | (0.62, 0.52, 0.38) | peaked | (0.45, 0.25, 0.15) |
| Storage Shed | (−65, y, 15) | 3.5×2.5×3 | (0.42, 0.35, 0.28) | flat | (0.35, 0.3, 0.25) |
| A1 Merchant Office | (−36, y, 5) | 4×3×3.5 | (0.58, 0.50, 0.40) | peaked | (0.40, 0.25, 0.15) |
| A2 Tax Office | (−30, y, 5) | 3.5×3×3 | (0.55, 0.48, 0.38) | peaked | (0.38, 0.22, 0.14) |
| A3 Courier Post | (−24, y, 5) | 3.5×3×3 | (0.52, 0.46, 0.36) | flat | (0.35, 0.30, 0.25) |
| Market Stalls (5) | Various | 3.0×2.5×2.0 | (0.45, 0.35, 0.22) | canopy | Red/Green/Yellow/Blue/Brown |

#### Residential Quarter (DistrictResidential)

| Building | Position | Size (W×H×D) | Wall Color | Roof Color |
|---|---|---|---|---|
| House 6 | (−62, y, −20) | 4×3×4 | (0.6, 0.53, 0.42) | (0.38, 0.22, 0.14) |
| House 7 | (−38, y, −40) | 4.5×3×4 | (0.57, 0.5, 0.38) | (0.42, 0.24, 0.16) |
| House 3 | (−53, y, −21) | 4×3×4 | (0.65, 0.58, 0.45) | (0.45, 0.25, 0.15) |
| House 4 | (−62, y, −33) | 5×3.5×5 | (0.6, 0.55, 0.42) | (0.35, 0.2, 0.15) |
| House 5 | (−46, y, −42) | 4.5×3×4 | (0.62, 0.56, 0.48) | (0.4, 0.22, 0.12) |
| House 8 | (−34, y, −21) | 4×3×4.5 | (0.58, 0.52, 0.4) | (0.3, 0.3, 0.3) |
| House 9 | (−51, y, −43) | 5×3×4 | (0.55, 0.5, 0.4) | (0.42, 0.2, 0.12) |
| Inn (ground) | (−45, y, −30) | 7×3×6 | (0.5, 0.38, 0.25) | flat — (0.35, 0.28, 0.2) |
| Inn (upper) | (−45, y+4.25, −30) | 6.5×2.5×5.5 | (0.52, 0.4, 0.28) | peaked — (0.4, 0.18, 0.1) |
| Well | (−42, y, −35) | Procedural cylinder basin | (0.5, 0.47, 0.42) | — |
| B1 Boarding House | (−47, y, −14) | 3.5×3×3 | (0.60, 0.52, 0.40) | peaked — (0.40, 0.24, 0.16) |
| B2 Tailor Shop | (−41, y, −14) | 3.5×3×3 | (0.56, 0.48, 0.36) | peaked — (0.36, 0.22, 0.14) |
| B3 Cobbler | (−36, y, −14) | 3×3×3 | (0.54, 0.46, 0.34) | peaked — (0.38, 0.24, 0.16) |

#### Noble/Temple Quarter (DistrictNoble)

| Building | Position | Size (W×H×D) | Wall Color | Roof Type | Roof Color |
|---|---|---|---|---|---|
| Temple | (10, y, −35) | 8×5×10 | (0.6, 0.58, 0.55) | peaked | (0.35, 0.3, 0.28) |
| Guild Hall | (15, y, −25) | 10×4×7 | (0.5, 0.45, 0.4) | flat | (0.3, 0.28, 0.25) |
| Manor (main) | (−10, y, −40) | 6×3.5×5 | (0.62, 0.58, 0.52) | peaked | (0.38, 0.3, 0.25) |
| Manor (annex) | (−6, y, −41) | 4×3×3 | (0.62, 0.58, 0.52) | peaked | (0.38, 0.3, 0.25) |
| Library | (0, y, −20) | 6×4×5 | (0.55, 0.52, 0.48) | peaked | (0.3, 0.25, 0.2) |
| C1 Scriptorium | (6, y, −26) | 4×3×3.5 | (0.56, 0.53, 0.48) | peaked | (0.32, 0.26, 0.20) |
| C2 Records Hall | (18, y, −35) | 3.5×3×3.5 | (0.58, 0.55, 0.50) | peaked | (0.30, 0.25, 0.20) |
| Chapel Annex | (18, y, −40) | 3.5×3×3 | (0.6, 0.58, 0.55) | peaked | (0.35, 0.28, 0.22) |
| Statue | (5, y, −30) | Procedural: pedestal 1×1×1 + figure cylinder | (0.5, 0.48, 0.45) | — | — |

#### Park/Gardens (DistrictPark)

| Structure | Position | Notes |
|---|---|---|
| Fountain | (45, y, −30) | basin radius 2.0/h 0.5, upper basin radius 1.5/h 1.0 |
| Benches (6) | Around fountain | At (40/50, y, −25), (40/50, y, −35), (35/55, y, −30) |
| Gardener Cottage | (40, y, −38) | 3.5×3×3.5, peaked, wall (0.52,0.48,0.40), roof (0.38,0.24,0.16) |
| Gazebo | (35, y, −20) | 6-post CylinderMesh + BoxMesh flat roof 3.6×0.15×3.6 |

#### Craft/Workshop (DistrictCraft)

| Building | Position | Size | Wall Color | Roof Type | Roof Color |
|---|---|---|---|---|---|
| Forge | (8, y, 30) | 6×3.5×5 | (0.4, 0.38, 0.35) | flat | (0.3, 0.28, 0.25) |
| Workshop 1 | (−10, y, 35) | Open shed: back wall 4×2.5×0.2, lean-to roof | (0.45, 0.35, 0.22) | lean-to | (0.35, 0.28, 0.2) |
| Workshop 2 | (12, y, 42) | 4×3×4 | (0.48, 0.42, 0.35) | peaked | (0.35, 0.25, 0.18) |
| Stables | (−15, y, 20) | 6×3×5 | (0.5, 0.42, 0.32) | flat | (0.38, 0.32, 0.25) |
| D1 Tannery | (−4, y, 26) | 4×3×3.5 | (0.48, 0.40, 0.30) | flat | (0.36, 0.30, 0.24) |
| D2 Potter Shop | (−4, y, 33) | 3.5×3×3 | (0.50, 0.42, 0.32) | flat | (0.38, 0.32, 0.26) |
| D3 Weaver Hut | (−4, y, 38) | 3×3×3 | (0.46, 0.38, 0.28) | flat | (0.34, 0.28, 0.22) |
| Storage Hut | (20, y, 38) | 3×2.5×3 | (0.45, 0.38, 0.3) | flat | (0.35, 0.3, 0.25) |

#### Garrison/Training (DistrictGarrison)

| Building | Position | Size | Wall Color | Roof Type | Roof Color |
|---|---|---|---|---|---|
| Barracks | (45, y, 35) | 12×3.5×5 | (0.42, 0.4, 0.38) | flat | (0.3, 0.28, 0.25) |
| Guard Tower | (30, y, 40) | 3×5×3 | (0.45, 0.42, 0.38) | flat | (0.35, 0.32, 0.28) |
| E1 Quartermaster | (38, y, 30) | 4×3×3.5 | (0.46, 0.42, 0.36) | flat | (0.34, 0.30, 0.26) |
| E2 Mess Hall | (52, y, 32) | 3.5×3×3 | (0.48, 0.44, 0.38) | flat | (0.36, 0.32, 0.28) |
| Armory | (55, y, 25) | 5×3.5×4 | (0.48, 0.44, 0.38) | flat | (0.32, 0.28, 0.24) |
| Training dummies (6) | (35..48, y, 15..22) | Procedural post+crossbar+head | (0.45, 0.35, 0.22) | — | — |
| Weapon racks (3) | (40/44/48, y, 32) | Procedural bar + 2 legs | (0.4, 0.3, 0.2) | — | — |
| Archery targets (2) | (55/58, y, 15..20) | Procedural post + disc face | (0.8, 0.3, 0.2) | — | — |

#### City Gate Area (DistrictGate)

| Building | Position | Size | Wall Color | Roof Type | Roof Color |
|---|---|---|---|---|---|
| F1 Waystation | (49, y, −4) | 3.5×3×3 | (0.50, 0.46, 0.40) | flat | (0.36, 0.32, 0.28) |
| F2 Gatehouse Office | (55, y, −4) | 3.5×3×3 | (0.48, 0.44, 0.38) | flat | (0.34, 0.30, 0.26) |
| Guard Post North | (65, y, −7) | 2×2.5×2 | (0.45, 0.42, 0.38) | flat | (0.35, 0.32, 0.28) |
| Guard Post South | (65, y, 7) | 2×2.5×2 | (0.45, 0.42, 0.38) | flat | (0.35, 0.32, 0.28) |
| Gatehouse Storage | (60, y, −7) | 3×2.5×3 | (0.45, 0.42, 0.38) | flat | (0.35, 0.32, 0.28) |

### Named NPC Loadouts

Source: `scripts/data/npc_loadouts.gd`

| NPC ID | Trait Profile | Starting Items | Equipped | Gold | Default Goal |
|---|---|---|---|---|---|
| `kael` | bold_warrior | basic_sword ×1, healing_potion ×3 | basic_sword | default | hunt_field |
| `lyra` | cautious_mage | healing_potion ×5 | — | 60 | idle |
| `bjorn` | boisterous_brawler | healing_potion ×3 | — | 80 | hunt_field |
| `sera` | sly_rogue | healing_potion ×2 | — | 100 | patrol |
| `thane` | stoic_knight | healing_potion ×2 | — | 70 | hunt_field |
| `mira` | cheerful_scholar | healing_potion ×3 | — | 60 | idle |
| `dusk` | mysterious_loner | healing_potion ×2 | — | 50 | hunt_field |
| `garen` | stern_guardian | basic_sword ×1, healing_potion ×2 | basic_sword | 90 | patrol |
| `garrick` | merchant | basic_sword ×5, iron_sword ×3, steel_sword ×2, basic_axe ×3, iron_axe ×2, basic_mace ×3, iron_mace ×2, basic_dagger ×3, iron_dagger ×2, basic_staff ×3, iron_staff ×2 | iron_sword | 500 | vend |
| `elara` | merchant | healing_potion ×20 | — | 300 | vend |
| `finn` | charming_bard | healing_potion ×2 | — | 30 | idle |
| `rook` | earnest_apprentice | healing_potion ×3 | — | 25 | idle |

`gold: -1` means the NPC's gold is not overridden (keeps whatever default was set).

---

## 14. Procedural NPC Generation

Source: `scripts/npcs/npc_generator.gd`, `scripts/data/npc_traits.gd`

`GENERATED_NPC_COUNT = 25` in `game_world.gd`.

### Archetypes

| Archetype | Weight | Weapon Pref | Default Goal | Model Pool | Boldness | Generosity | Sociability | Curiosity |
|---|---|---|---|---|---|---|---|---|
| warrior | 30 | sword | hunt | Knight, Barbarian | 0.6–1.0 | 0.2–0.8 | 0.3–0.7 | 0.2–0.6 |
| mage | 25 | staff | hunt | Mage | 0.3–0.7 | 0.3–0.9 | 0.4–0.8 | 0.5–0.9 |
| rogue | 20 | dagger | hunt | Rogue | 0.5–0.9 | 0.1–0.5 | 0.2–0.6 | 0.4–0.8 |
| ranger | 15 | axe | hunt | Knight, Barbarian | 0.4–0.8 | 0.3–0.7 | 0.3–0.6 | 0.6–1.0 |
| merchant | 10 | mace | vend | Rogue, Mage | 0.2–0.5 | 0.4–0.9 | 0.6–1.0 | 0.3–0.6 |

Total weight: 100. Archetype-to-profile mapping in `game_world.gd`:
- warrior → `bold_warrior`
- mage → `cautious_mage`
- rogue → `sly_rogue`
- ranger → `stoic_knight`
- merchant → `merchant`

### Archetype Overlay Colors

| Archetype | NPC Color (RGBA) |
|---|---|
| warrior | (0.2, 0.3, 0.7, 1.0) — blue |
| mage | (0.5, 0.1, 0.6, 1.0) — purple |
| rogue | (0.1, 0.5, 0.4, 1.0) — teal |
| ranger | (0.2, 0.5, 0.2, 1.0) — green |
| merchant | (0.7, 0.5, 0.1, 1.0) — amber |

### Wealth Tiers

| Tier | Probability | Gold Range | Potions | Weapon Tier | Shield | Merchant Bonus |
|---|---|---|---|---|---|---|
| poor | 40% (roll < 40) | 20–50 | 1–2 | basic_ (tier 1) | none | basic weapons (1–3 each) + potions |
| average | 40% (40 ≤ roll < 80) | 50–150 | 2–4 | iron_ (tier 2) | iron_shield (warriors/rangers) | + iron_ weapons (1–2 each) |
| wealthy | 20% (roll ≥ 80) | 150–300 | 4–6 | steel_ (tier 3) | steel_shield (warriors/rangers) | + steel_sword/axe/mace (1 each) |

Merchants receive sell inventory instead of a shield.

### Name Pool

Pool size: ~200 names across 3 cultural themes (Nordic, Celtic, Generic Fantasy), with 7 named NPC names excluded (Kael, Lyra, Bjorn, Sera, Thane, Mira, Dusk). If pool is exhausted, fallback is `Adventurer_NNNN` (random 4-digit suffix).

### Trait Profiles

Source: `scripts/data/npc_traits.gd`

| Profile ID | Boldness | Sociability | Generosity | Curiosity | Weapon Type | Starting Proficiencies |
|---|---|---|---|---|---|---|
| `bold_warrior` | 0.85 | 0.70 | 0.50 | 0.30 | sword | sword 3, constitution 2, agility 1 |
| `cautious_mage` | 0.20 | 0.40 | 0.60 | 0.70 | staff | staff 3, constitution 1, agility 1 |
| `boisterous_brawler` | 0.75 | 0.90 | 0.60 | 0.40 | sword | sword 3, constitution 2, agility 1 |
| `sly_rogue` | 0.50 | 0.80 | 0.20 | 0.60 | dagger | dagger 3, agility 2, constitution 1 |
| `stoic_knight` | 0.60 | 0.25 | 0.70 | 0.20 | sword | sword 3, constitution 2, agility 1 |
| `cheerful_scholar` | 0.40 | 0.85 | 0.80 | 0.90 | staff | staff 3, constitution 1, agility 1 |
| `mysterious_loner` | 0.55 | 0.15 | 0.30 | 0.50 | dagger | dagger 3, agility 2, constitution 1 |
| `stern_guardian` | 0.70 | 0.20 | 0.75 | 0.15 | sword | sword 4, constitution 3, agility 1 |
| `gentle_healer` | 0.15 | 0.75 | 0.95 | 0.50 | staff | staff 2, constitution 3, agility 1 |
| `charming_bard` | 0.45 | 0.95 | 0.55 | 0.80 | dagger | dagger 2, agility 2, constitution 1 |
| `earnest_apprentice` | 0.50 | 0.60 | 0.70 | 0.55 | mace | mace 2, constitution 2, smithing 2 |
| `merchant` | 0.30 | 0.85 | 0.60 | 0.40 | sword | sword 2, constitution 2, agility 1 |

Trait axis ranges: 0.0 (minimum) to 1.0 (maximum)
- `boldness`: 0 = cautious (high retreat threshold), 1 = reckless
- `sociability`: 0 = introverted (long chat cooldown), 1 = extroverted
- `generosity`: 0 = selfish (trade unwilling), 1 = generous
- `curiosity`: 0 = focused (rare goal switching), 1 = exploratory

---

## 15. Needed Assets (Missing)

### High Priority

| Asset | Count | Current Workaround |
|---|---|---|
| Item icons | 52 items total (1 consumable, 25 weapons, 5 shields, 5 materials) | No sprites — inventory shows text-only item names |
| Skill icons | 16 active skills | No sprites — skill panel is text-only buttons |
| Proficiency icons | 13 proficiencies | No sprites — proficiency panel uses text labels |
| Dedicated wolf model | 1 | `Rogue_Hooded.glb` proxy with grey tint `(0.4, 0.35, 0.3, 0.2)` |
| Dedicated goblin model | 1 | `Skeleton_Minion.glb` proxy with green tint `(0.1, 0.3, 0.05, 0.25)` |

### Medium Priority

| Asset | Notes |
|---|---|
| Gathering resource nodes | Mining rocks, choppable trees, fishing spots — gathering proficiencies exist in code but no interactable nodes placed in world |
| Rock models | Currently `SphereMesh` procedural geometry with `Color(0.4, 0.38, 0.36)`, created by `BiomeScatter.create_rock_cluster()` |
| Building facade models | All city buildings are procedural `BoxMesh` geometry; no architectural mesh assets |
| Medieval font | UI uses default Godot font throughout |

### Low Priority

| Asset | Notes |
|---|---|
| Audio assets | BGM tracks for city/field zones; SFX for combat hits, UI interactions, skill effects. System exists on `main` branch awaiting assets |
| Additional tree species models | Bark and leaf textures exist for Birch, Oak, Pine, Maple, Knotwood, and others; no corresponding FBX models present |
| Interior decoration props | Buildings have no interiors; dungeon wall/floor tiles are on disk but unused |
| Particle effects for skills/combat | All skill effects use flash/color overlays only; no particle systems |
| Weather/environment effects | No rain, wind, fog, or ambient particles |

---

## 16. Unused Assets Summary

Assets present on disk but not referenced by any code.

### Character Models

| File | Reason Unused |
|---|---|
| `Skeleton_Rogue.glb` | No monster or NPC type uses this model |

### Dungeon Props (Models)

The following 14 `.gltf.glb` model files are in `assets/models/environment/dungeon/` but not spawned anywhere:

`chest.glb`, `pillar.gltf.glb`, `wall.gltf.glb`, `wall_arched.gltf.glb`, `wall_broken.gltf.glb`, `wall_corner.gltf.glb`, `wall_doorway.glb`, `wall_endcap.gltf.glb`, `wall_half.gltf.glb`, `wall_pillar.gltf.glb`, `stairs.gltf.glb`, `floor_dirt_large.gltf.glb`, `floor_dirt_small_A.gltf.glb`, `floor_tile_large.gltf.glb`, `floor_tile_small.gltf.glb`

These were likely intended for a dungeon zone that was removed. They remain as a ready-to-use interior/dungeon building kit.

### Tree Models

`SM_FirFallen3.FBX`, `SM_FirBranch1.FBX`, `SM_FirBranch2.FBX` — on disk, not in any biome recipe.

### Tree Textures

All non-fir bark and leaf textures: Bamboo, Banana, Birch, ChinaPina, CoconutPalm, DesertCoconutPalm, DesertPalm, Knotwood, Oak, PalmWood, PineBark, RedMaple, Windswept sets, plus fir normal/roughness channels (`T_FirBark_N.PNG`, `T_FirBark_R.PNG`, `T_FirBarkMisc_N.PNG`, `T_FirBarkMisc_R.PNG`). These would be used if additional tree species models were added.

### Foliage Models

~100+ foliage FBX files covering desert, tropical, arctic, aquatic, and coastal plant types. None are used in current temperate-biome world. See Section 9 for the full unused list.

### Terrain Textures

- `Bricks/Bricks_01` through `Bricks_25` — only Bricks_17 and Bricks_23 are used
- Entire `Roofs/` directory — 25 roof texture variants, none used
- Entire `Wood/` directory — 25 wood texture variants, none used
- Entire `Tile/` directory — 25 tile texture variants, none used

### Shaders

`toon_cutout.gdshader` and `outline.gdshader` — present in `assets/shaders/` but no confirmed active references in current scripts.
