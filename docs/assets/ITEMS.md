# Arcadia — Items, Equipment & Proficiency Reference

Source: `scripts/data/item_database.gd`, `scripts/data/proficiency_database.gd`, `scenes/ui/inventory_panel.gd`

---

## Consumables

| Item ID | Name | Type | Heal | Buy/Sell Value |
|---|---|---|---|---|
| `healing_potion` | Healing Potion | consumable | 30 HP | 20 |

---

## Weapons

All weapons use `slot_type: "main_hand"`. Dagger has `attack_speed: 0.7`; all others have no explicit attack_speed override.

### Swords (`weapon_type: "sword"`, `required_skill: "sword"`)

| Item ID | Name | Tier | ATK Bonus | Required Level | Value |
|---|---|---|---|---|---|
| `basic_sword` | Basic Sword | 1 | +5 | 1 | 50 |
| `iron_sword` | Iron Sword | 2 | +10 | 3 | 150 |
| `steel_sword` | Steel Sword | 3 | +15 | 5 | 400 |
| `mithril_sword` | Mithril Sword | 4 | +20 | 7 | 800 |
| `dragon_sword` | Dragon Sword | 5 | +25 | 9 | 1500 |

### Axes (`weapon_type: "axe"`, `required_skill: "axe"`)

| Item ID | Name | Tier | ATK Bonus | Required Level | Value |
|---|---|---|---|---|---|
| `basic_axe` | Basic Axe | 1 | +5 | 1 | 50 |
| `iron_axe` | Iron Axe | 2 | +10 | 3 | 150 |
| `steel_axe` | Steel Axe | 3 | +15 | 5 | 400 |
| `mithril_axe` | Mithril Axe | 4 | +20 | 7 | 800 |
| `dragon_axe` | Dragon Axe | 5 | +25 | 9 | 1500 |

### Maces (`weapon_type: "mace"`, `required_skill: "mace"`)

| Item ID | Name | Tier | ATK Bonus | Required Level | Value |
|---|---|---|---|---|---|
| `basic_mace` | Basic Mace | 1 | +5 | 1 | 50 |
| `iron_mace` | Iron Mace | 2 | +10 | 3 | 150 |
| `steel_mace` | Steel Mace | 3 | +15 | 5 | 400 |
| `mithril_mace` | Mithril Mace | 4 | +20 | 7 | 800 |
| `dragon_mace` | Dragon Mace | 5 | +25 | 9 | 1500 |

### Daggers (`weapon_type: "dagger"`, `required_skill: "dagger"`, `attack_speed: 0.7`)

| Item ID | Name | Tier | ATK Bonus | Required Level | Value |
|---|---|---|---|---|---|
| `basic_dagger` | Basic Dagger | 1 | +4 | 1 | 50 |
| `iron_dagger` | Iron Dagger | 2 | +8 | 3 | 150 |
| `steel_dagger` | Steel Dagger | 3 | +12 | 5 | 400 |
| `mithril_dagger` | Mithril Dagger | 4 | +16 | 7 | 800 |
| `dragon_dagger` | Dragon Dagger | 5 | +20 | 9 | 1500 |

### Staves (`weapon_type: "staff"`, `required_skill: "staff"`)

| Item ID | Name | Tier | ATK Bonus | Required Level | Value |
|---|---|---|---|---|---|
| `basic_staff` | Basic Staff | 1 | +5 | 1 | 50 |
| `iron_staff` | Iron Staff | 2 | +10 | 3 | 150 |
| `steel_staff` | Steel Staff | 3 | +15 | 5 | 400 |
| `mithril_staff` | Mithril Staff | 4 | +20 | 7 | 800 |
| `dragon_staff` | Dragon Staff | 5 | +25 | 9 | 1500 |

---

## Shields (`type: "armor"`, `slot_type: "off_hand"`, `required_skill: "constitution"`)

| Item ID | Name | Tier | DEF Bonus | Required Level | Value |
|---|---|---|---|---|---|
| `basic_shield` | Basic Shield | 1 | +3 | 1 | 50 |
| `iron_shield` | Iron Shield | 2 | +6 | 3 | 150 |
| `steel_shield` | Steel Shield | 3 | +9 | 5 | 400 |
| `mithril_shield` | Mithril Shield | 4 | +12 | 7 | 800 |
| `dragon_shield` | Dragon Shield | 5 | +15 | 9 | 1500 |

---

## Monster Drops (`type: "material"`, sell only)

| Item ID | Name | Sell Value | Source |
|---|---|---|---|
| `jelly` | Jelly | 8 | Slime (50%) |
| `fur` | Fur | 15 | Wolf (40%) |
| `goblin_tooth` | Goblin Tooth | 25 | Goblin (30%) |
| `bone` | Bone | 20 | Skeleton (40%) |
| `dark_crystal` | Dark Crystal | 50 | Dark Mage (25%) |

---

## Equipment Slots & Icon Paths

Source: `assets/textures/ui/equip_slots/`, referenced by `scenes/ui/inventory_panel.gd`

All 8 slots have placeholder sprite icons. No actual item icons exist yet.

| Slot Name | Icon Path | Description |
|---|---|---|
| `head` | `assets/textures/ui/equip_slots/head.png` | Helmet / headgear |
| `torso` | `assets/textures/ui/equip_slots/torso.png` | Body armor / chest |
| `legs` | `assets/textures/ui/equip_slots/legs.png` | Leg armor |
| `gloves` | `assets/textures/ui/equip_slots/gloves.png` | Gloves / gauntlets |
| `feet` | `assets/textures/ui/equip_slots/feet.png` | Boots / footwear |
| `back` | `assets/textures/ui/equip_slots/back.png` | Cape / back slot |
| `main_hand` | `assets/textures/ui/equip_slots/main_hand.png` | Primary weapon |
| `off_hand` | `assets/textures/ui/equip_slots/off_hand.png` | Shield / off-hand |

Note: Only `main_hand` (weapons) and `off_hand` (shields) slots are populated by current item data. Head, torso, legs, gloves, feet, and back slots exist in `EquipmentComponent` but no items in `ItemDatabase` target them.

---

## Proficiency System

Source: `scripts/data/proficiency_database.gd`

Global constants: `MAX_LEVEL = 10`. XP formula: `get_xp_to_next_level(current_level) = current_level * 50`.

Player total level = sum of all 13 proficiency levels. Default starting level for every proficiency is 1 with 0 XP.

### 13 Proficiencies

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

### Categories

| Category | Skills |
|---|---|
| weapon (5) | sword, axe, mace, dagger, staff |
| attribute (2) | constitution, agility |
| gathering (3) | mining, woodcutting, fishing |
| production (3) | smithing, cooking, crafting |
