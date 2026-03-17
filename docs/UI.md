# Arcadia — UI Icon Asset Spec

**Purpose**: This document is the authoritative spec for generating UI icons with Gemini AI. Every icon required by the game is catalogued here with exact IDs, colors, sizes, and visual prompts.

## Art Style

- **Style**: Fantasy RPG — stylized flat with a hand-painted feel. Bold readable silhouettes. No photorealism. No pixel art.
- **Palette**: Warm, slightly desaturated tones. Deep shadows, subtle highlights. Medieval/fantasy aesthetic.
- **Consistency**: All icons share the same light source (top-left), line weight, and border treatment.
- **Backgrounds**: Transparent PNG. No drop shadows baked in.
- **Rendering**: Clean vector-style edges, 2px inner stroke, slight inner glow matching the item color.

## Default Sizes

| Context | Size |
|---|---|
| Inventory grid cells | 64×64 px |
| Skill hotbar slots | 64×64 px |
| Equipment slot icons | 32×32 px |
| Proficiency icons | 32×32 px |
| Inline / stat icons | 16×16 px |
| Monster portraits | 64×64 px |

## File Path Conventions

| Category | Directory |
|---|---|
| Weapon items | `assets/textures/ui/items/weapons/` |
| Shield items | `assets/textures/ui/items/shields/` |
| Consumable items | `assets/textures/ui/items/consumables/` |
| Material items | `assets/textures/ui/items/materials/` |
| Active skills | `assets/textures/ui/skills/` |
| Proficiency icons | `assets/textures/ui/proficiencies/` |
| Equipment slot placeholders | `assets/textures/ui/equip_slots/` |
| Monster portraits | `assets/textures/ui/monsters/` |
| Stat / inline icons | `assets/textures/ui/stats/` |
| Panel toggle buttons | `assets/textures/ui/buttons/` |

---

## 1. Item Icons

**Size**: 64×64 px
**File naming**: `{item_id}.png`

### Tier Color Progression

Tiers represent material quality. The tier color should tint the entire icon — blade, haft, pommel — to unify the set.

| Tier | Material | Color Character |
|---|---|---|
| 1 (basic) | Wood / crude iron | Dull grey-brown, rough edges |
| 3 (iron) | Forged iron | Cool mid-grey, simple crossguard |
| 5 (steel) | Polished steel | Bright silver-blue, refined shape |
| 7 (mithril) | Mithril | Pale cyan-silver, faint arcane shimmer |
| 9 (dragon) | Dragon-forged | Deep crimson-gold, etched runes, subtle glow |

---

### 1.1 Swords

Category: `weapon` | Weapon type: `sword` | Slot: `main_hand`
Shape: Straight double-edged blade, simple crossguard, round pommel.

| id | name | tier (req_level) | atk_bonus | value | color hint (from inventory_panel.gd WEAPON_COLORS) | notes |
|---|---|---|---|---|---|---|
| `basic_sword` | Basic Sword | 1 | +5 | 50g | RGB(0.9, 0.85, 0.3) — warm gold-yellow | Rough wooden grip, crude iron blade |
| `iron_sword` | Iron Sword | 3 | +10 | 150g | RGB(0.9, 0.85, 0.3) — warm gold-yellow | Simple iron blade, leather-wrapped hilt |
| `steel_sword` | Steel Sword | 5 | +15 | 400g | RGB(0.9, 0.85, 0.3) — warm gold-yellow | Polished double-edged blade, fuller groove |
| `mithril_sword` | Mithril Sword | 7 | +20 | 800g | RGB(0.9, 0.85, 0.3) — warm gold-yellow | Pale silver blade, faint cyan edge glow |
| `dragon_sword` | Dragon Sword | 9 | +25 | 1500g | RGB(0.9, 0.85, 0.3) — warm gold-yellow | Dark crimson blade, etched dragon scale pattern, ember glow |

---

### 1.2 Axes

Category: `weapon` | Weapon type: `axe` | Slot: `main_hand`
Shape: Single-bitted axe head, medium haft, curved blade.

| id | name | tier (req_level) | atk_bonus | value | color hint (from inventory_panel.gd WEAPON_COLORS) | notes |
|---|---|---|---|---|---|---|
| `basic_axe` | Basic Axe | 1 | +5 | 50g | RGB(0.8, 0.4, 0.2) — burnt orange | Crude stone/iron head, splintered haft |
| `iron_axe` | Iron Axe | 3 | +10 | 150g | RGB(0.8, 0.4, 0.2) — burnt orange | Forged iron head, wrapped grip |
| `steel_axe` | Steel Axe | 5 | +15 | 400g | RGB(0.8, 0.4, 0.2) — burnt orange | Polished axe head with engraved line detail |
| `mithril_axe` | Mithril Axe | 7 | +20 | 800g | RGB(0.8, 0.4, 0.2) — burnt orange | Glinting mithril head, arcane blue edge |
| `dragon_axe` | Dragon Axe | 9 | +25 | 1500g | RGB(0.8, 0.4, 0.2) — burnt orange | Dragon-fang shaped blade, smoldering orange runes |

---

### 1.3 Maces

Category: `weapon` | Weapon type: `mace` | Slot: `main_hand`
Shape: Flanged head or spiked ball, thick haft.

| id | name | tier (req_level) | atk_bonus | value | color hint (from inventory_panel.gd WEAPON_COLORS) | notes |
|---|---|---|---|---|---|---|
| `basic_mace` | Basic Mace | 1 | +5 | 50g | RGB(0.6, 0.6, 0.7) — slate blue-grey | Club-like blunt head, rough wooden haft |
| `iron_mace` | Iron Mace | 3 | +10 | 150g | RGB(0.6, 0.6, 0.7) — slate blue-grey | 4 flanged iron head, basic grip |
| `steel_mace` | Steel Mace | 5 | +15 | 400g | RGB(0.6, 0.6, 0.7) — slate blue-grey | 6-flanged polished head, reinforced haft |
| `mithril_mace` | Mithril Mace | 7 | +20 | 800g | RGB(0.6, 0.6, 0.7) — slate blue-grey | Pale spiked ball head, blue-tinged sheen |
| `dragon_mace` | Dragon Mace | 9 | +25 | 1500g | RGB(0.6, 0.6, 0.7) — slate blue-grey | Spiked dragon-scale head, deep purple shadow glow |

---

### 1.4 Daggers

Category: `weapon` | Weapon type: `dagger` | Slot: `main_hand`
Attack speed: 0.7 (fast). Shape: Short narrow blade, small crossguard, compact profile.

| id | name | tier (req_level) | atk_bonus | value | color hint (from inventory_panel.gd WEAPON_COLORS) | notes |
|---|---|---|---|---|---|---|
| `basic_dagger` | Basic Dagger | 1 | +4 | 50g | RGB(0.4, 0.8, 0.4) — muted green | Plain iron shiv, simple wrap |
| `iron_dagger` | Iron Dagger | 3 | +8 | 150g | RGB(0.4, 0.8, 0.4) — muted green | Forged thin blade, small guard |
| `steel_dagger` | Steel Dagger | 5 | +12 | 400g | RGB(0.4, 0.8, 0.4) — muted green | Polished stiletto, grooved blade |
| `mithril_dagger` | Mithril Dagger | 7 | +16 | 800g | RGB(0.4, 0.8, 0.4) — muted green | Near-transparent blade, cyan glint at tip |
| `dragon_dagger` | Dragon Dagger | 9 | +20 | 1500g | RGB(0.4, 0.8, 0.4) — muted green | Serrated black blade, green venom shimmer |

---

### 1.5 Staves

Category: `weapon` | Weapon type: `staff` | Slot: `main_hand`
Shape: Long two-handed staff, ornamental top piece (crystal, orb, or carved finial).

| id | name | tier (req_level) | atk_bonus | value | color hint (from inventory_panel.gd WEAPON_COLORS) | notes |
|---|---|---|---|---|---|---|
| `basic_staff` | Basic Staff | 1 | +5 | 50g | RGB(0.5, 0.4, 0.9) — medium purple | Simple wooden rod, no topper |
| `iron_staff` | Iron Staff | 3 | +10 | 150g | RGB(0.5, 0.4, 0.9) — medium purple | Iron-capped staff, small crystal orb |
| `steel_staff` | Steel Staff | 5 | +15 | 400g | RGB(0.5, 0.4, 0.9) — medium purple | Carved steel haft, glowing purple gem topper |
| `mithril_staff` | Mithril Staff | 7 | +20 | 800g | RGB(0.5, 0.4, 0.9) — medium purple | Mithril-veined shaft, levitating arcane orb |
| `dragon_staff` | Dragon Staff | 9 | +25 | 1500g | RGB(0.5, 0.4, 0.9) — medium purple | Dragon claw grip, swirling dark-energy core at tip |

---

### 1.6 Shields

Category: `armor` | Type: `armor` | Slot: `off_hand` | Required skill: `constitution`
Shape: Kite/heater shield, slightly angled to the left.

| id | name | tier (req_level) | def_bonus | value | color notes | notes |
|---|---|---|---|---|---|---|
| `basic_shield` | Basic Shield | 1 | +3 | 50g | Weathered brown wood with iron boss | Simple round wooden buckler |
| `iron_shield` | Iron Shield | 3 | +6 | 150g | Dark iron-grey with rivets | Heater shield, riveted iron face |
| `steel_shield` | Steel Shield | 5 | +9 | 400g | Bright steel-silver, embossed chevron | Polished steel with geometric emboss |
| `mithril_shield` | Mithril Shield | 7 | +12 | 800g | Pale silver-blue, faint arcane sigil | Thin lightweight form, glowing edge |
| `dragon_shield` | Dragon Shield | 9 | +15 | 1500g | Dark crimson scales with gold trim | Dragon-scale surface, fire-ember center boss |

---

### 1.7 Consumables

Category: `consumable` | Background tint: RGB(0.18, 0.4, 0.18) — deep forest green

| id | name | effect | value | size | description |
|---|---|---|---|---|---|
| `healing_potion` | Healing Potion | Heal 30 HP | 20g | 64×64 | Round glass flask with red liquid, cork stopper, faint inner glow. Classic RPG potion shape. |

---

### 1.8 Materials (Monster Drops)

Category: `material` | Background tint: RGB(0.4, 0.32, 0.2) — warm ochre-brown
These are loot drops, sell-only. Icons should look natural/organic.

| id | name | value | source monster | size | description |
|---|---|---|---|---|---|
| `jelly` | Jelly | 8g | Slime | 64×64 | Translucent green blob, wobbly droplet shape. Color from monster: RGB(0.2, 0.8, 0.2). |
| `fur` | Fur | 15g | Wolf | 64×64 | Brown/grey tuft of fur, slightly matted. Color hint from wolf: RGB(0.5, 0.5, 0.5). |
| `goblin_tooth` | Goblin Tooth | 25g | Goblin | 64×64 | Yellowed pointed fang, slightly chipped. Green tint from goblin: RGB(0.2, 0.4, 0.1). |
| `bone` | Bone | 20g | Skeleton | 64×64 | Single femur bone, cream-white. Color from skeleton: RGB(0.9, 0.9, 0.85). |
| `dark_crystal` | Dark Crystal | 50g | Dark Mage | 64×64 | Jagged hexagonal crystal shard, deep violet-purple glow. Color from dark_mage: RGB(0.3, 0.1, 0.4). |

---

## 2. Skill Icons

**Size**: 64×64 px
**File naming**: `{skill_id}.png`
**Directory**: `assets/textures/ui/skills/`

All skill icons should convey the action type immediately. Use the color field as the dominant hue of the icon (glow, energy, or material color).

### Skill Type Visual Guide

| Type | Visual language |
|---|---|
| `melee_attack` | Single concentrated impact — bright burst at point of strike |
| `aoe_melee` | Radiating arcs or ring explosion — energy spreading outward |
| `bleed` | Red droplets or dripping cuts — crimson/dark tones |
| `armor_pierce` | Penetrating arrow or spike through a shield fragment |

---

### 2.1 Sword Skills

| id | name | type | color (exact from code) | cooldown | visual description |
|---|---|---|---|---|---|
| `bash` | Bash | `melee_attack` | RGB(0.9, 0.4, 0.2) — vivid orange-red | 3.0s | Sword angled downward mid-swing, orange impact burst radiating from blade tip |
| `cleave` | Cleave | `aoe_melee` | RGB(0.9, 0.6, 0.2) — amber-orange | 5.0s | Wide horizontal slash arc, three fanning lines emanating right, warm amber energy |
| `rend` | Rend | `bleed` | RGB(0.8, 0.2, 0.2) — deep red | 6.0s | Jagged diagonal cut with crimson blood droplets trailing behind the blade |

### 2.2 Axe Skills

| id | name | type | color (exact from code) | cooldown | visual description |
|---|---|---|---|---|---|
| `chop` | Chop | `melee_attack` | RGB(0.7, 0.5, 0.2) — dark amber | 3.0s | Axe descending vertically, amber impact shockwave at bottom, wood-chip effect |
| `whirlwind` | Whirlwind | `aoe_melee` | RGB(0.7, 0.7, 0.3) — yellow-green | 5.0s | Circular spin trail, axe head at center of outward spiraling yellow arc |
| `execute` | Execute | `armor_pierce` | RGB(0.6, 0.1, 0.1) — very dark red | 7.0s | Axe blade piercing through a cracked shield fragment, dark red glow along blade edge |

### 2.3 Mace Skills

| id | name | type | color (exact from code) | cooldown | visual description |
|---|---|---|---|---|---|
| `crush` | Crush | `melee_attack` | RGB(0.5, 0.5, 0.7) — medium blue-slate | 3.0s | Mace head striking downward, blue-slate shockwave rings on impact |
| `shatter` | Shatter | `armor_pierce` | RGB(0.4, 0.4, 0.8) — medium-bright blue | 5.0s | Mace striking armor that explodes outward in fragments, blue energy burst |
| `quake` | Quake | `aoe_melee` | RGB(0.6, 0.4, 0.3) — dusty brown-red | 6.0s | Mace slammed into ground, concentric shockwave rings spreading outward in earthy tones |

### 2.4 Dagger Skills

| id | name | type | color (exact from code) | cooldown | visual description |
|---|---|---|---|---|---|
| `stab` | Stab | `melee_attack` | RGB(0.3, 0.7, 0.3) — medium green | 2.0s | Dagger thrusting forward, sharp green speed lines, fast motion blur |
| `lacerate` | Lacerate | `bleed` | RGB(0.7, 0.2, 0.3) — dark rose-red | 4.0s | Two crossing slash marks leaving four crimson drip lines, dark red tones |
| `backstab` | Backstab | `armor_pierce` | RGB(0.2, 0.2, 0.2) — near-black | 5.0s | Shadow silhouette of dagger striking from behind, black with dark grey energy, no color glow |

### 2.5 Staff Skills

| id | name | type | color (exact from code) | cooldown | visual description |
|---|---|---|---|---|---|
| `arcane_bolt` | Arcane Bolt | `melee_attack` | RGB(0.5, 0.3, 0.9) — deep purple | 2.5s | Compact orb of purple arcane energy with a spark trail, concentrated single-point impact |
| `flame_burst` | Flame Burst | `aoe_melee` | RGB(0.9, 0.3, 0.1) — bright orange-red | 5.0s | Expanding fireball explosion at center, radiating flame petals outward, hot orange-red |
| `drain` | Drain | `bleed` | RGB(0.4, 0.1, 0.5) — dark violet | 6.0s | Tendrils of dark violet energy spiraling inward toward a center point, life-drain visual |

---

## 3. Proficiency Icons

**Size**: 32×32 px
**File naming**: `{proficiency_id}.png`
**Directory**: `assets/textures/ui/proficiencies/`

Proficiency icons are small, clear silhouettes used in the skill grid overview. Each should be immediately recognizable at 32px. Use the category color for the icon tint.

### Category Colors (for icon tinting)

| Category | Color |
|---|---|
| Weapon | Warm gold — RGB(0.85, 0.75, 0.3) |
| Attribute | Teal-white — RGB(0.6, 0.9, 0.85) |
| Gathering | Earthy green — RGB(0.4, 0.65, 0.3) |
| Production | Warm amber — RGB(0.8, 0.55, 0.2) |

---

### 3.1 Weapon Proficiencies (5 total)

| id | name | category | size | icon description |
|---|---|---|---|---|
| `sword` | Sword | weapon | 32×32 | Upright sword silhouette, straight blade, simple crossguard, warm gold tint |
| `axe` | Axe | weapon | 32×32 | Side-facing axe head with short haft, single-bitted, warm gold tint |
| `mace` | Mace | weapon | 32×32 | Flanged mace head and haft, top-facing, warm gold tint |
| `dagger` | Dagger | weapon | 32×32 | Short diagonal dagger, point facing upper-right, warm gold tint |
| `staff` | Staff | weapon | 32×32 | Tall staff with small orb at top, centered vertically, warm gold tint |

### 3.2 Attribute Proficiencies (2 total)

| id | name | category | size | icon description |
|---|---|---|---|---|
| `constitution` | Constitution | attribute | 32×32 | Rounded shield with a heart or HP bar motif inside. Teal-white tint. |
| `agility` | Agility | attribute | 32×32 | Running figure silhouette or speed chevron. Teal-white tint. |

### 3.3 Gathering Proficiencies (3 total)

| id | name | category | size | icon description |
|---|---|---|---|---|
| `mining` | Mining | gathering | 32×32 | Pickaxe silhouette, angled diagonally. Earthy green tint. |
| `woodcutting` | Woodcutting | gathering | 32×32 | Hatchet or handaxe with wood grain at base. Earthy green tint. |
| `fishing` | Fishing | gathering | 32×32 | Fishing rod arcing over water ripple. Earthy green tint. |

### 3.4 Production Proficiencies (3 total)

| id | name | category | size | icon description |
|---|---|---|---|---|
| `smithing` | Smithing | production | 32×32 | Blacksmith hammer over an anvil silhouette. Warm amber tint. |
| `cooking` | Cooking | production | 32×32 | Steaming bowl or cooking pot with rising steam curl. Warm amber tint. |
| `crafting` | Crafting | production | 32×32 | Thread spool and needle, or wrench and gear. Warm amber tint. |

---

## 4. Equipment Slot Icons

**Size**: 32×32 px (displayed at 32×28 in empty slots, 16×16 as overlay in filled slots)
**File naming**: `{slot_name}.png`
**Directory**: `assets/textures/ui/equip_slots/`
**Style**: Outline / silhouette only. White line-art on transparent background. Should read clearly at low opacity (30% for empty slot hint).

These are the 8 equipment slots as defined in `inventory_panel.gd` `SLOT_LABELS`.

| slot_name | label | size | icon description |
|---|---|---|---|
| `head` | Head | 32×32 | Side-profile helmet silhouette — simple knight bascinet or open helm |
| `torso` | Torso | 32×32 | Front-facing chest armor / cuirass silhouette |
| `gloves` | Gloves | 32×32 | Open hand with gauntlet or finger-less glove silhouette, palm facing forward |
| `legs` | Legs | 32×32 | Two leg greaves / cuisses, straight-on view |
| `feet` | Feet | 32×32 | Side-profile armored boot or sabatons |
| `back` | Back | 32×32 | Folded cloak or cape silhouette |
| `main_hand` | Main | 32×32 | Upright sword (matching the sword proficiency icon) — slot color: RGB(0.35, 0.3, 0.2) |
| `off_hand` | Off | 32×32 | Kite shield (matching basic shield silhouette) — slot color: RGB(0.2, 0.25, 0.35) |

---

## 5. UI Element Icons

### 5.1 Panel Toggle Buttons

**Size**: 16×16 px
**Directory**: `assets/textures/ui/buttons/`
**Style**: Flat monochrome line-art on transparent background. White or light grey.

| id | label | key | description |
|---|---|---|---|
| `btn_status` | Status | C | Person silhouette or portrait frame |
| `btn_inventory` | Inventory | I | Open bag or chest |
| `btn_skills` | Skills | S | Star or lightning bolt |
| `btn_map` | Map | W | Folded parchment or compass rose |

---

### 5.2 Gold Coin

**Size**: 16×16 px
**File**: `assets/textures/ui/stats/gold_coin.png`
**Description**: Small circular gold coin, face-on. Central dot or engraved symbol. Color: RGB(0.8, 0.7, 0.3) — warm gold.

---

### 5.3 Monster Portraits

**Size**: 64×64 px
**Directory**: `assets/textures/ui/monsters/`
**Style**: Head-and-shoulders portrait, slightly stylized, matching the in-game entity color. Dark background with faint color vignette matching the monster color.

| id | name | hp | atk | def | color (exact from code) | model used in-game | portrait description |
|---|---|---|---|---|---|---|---|
| `slime` | Slime | 20 | 3 | 1 | RGB(0.2, 0.8, 0.2) — bright green | Slime.glb | Round gelatinous blob face, bright green, simple black dot eyes |
| `wolf` | Wolf | 40 | 7 | 3 | RGB(0.5, 0.5, 0.5) — neutral grey | Rogue_Hooded.glb (grey tint) | Snarling wolf head, grey-brown fur, yellow eyes |
| `goblin` | Goblin | 60 | 10 | 5 | RGB(0.2, 0.4, 0.1) — dark olive green | Skeleton_Minion.glb (green tint) | Small goblin face, green skin, oversized ears, beady eyes |
| `skeleton` | Skeleton | 80 | 14 | 8 | RGB(0.9, 0.9, 0.85) — off-white bone | Skeleton_Warrior.glb | Skull face, bone-white, hollow eye sockets with faint inner glow |
| `dark_mage` | Dark Mage | 60 | 18 | 4 | RGB(0.3, 0.1, 0.4) — deep violet | Skeleton_Mage.glb (violet tint) | Hooded skeletal mage, deep purple cloak shadows, glowing violet eyes |

---

### 5.4 Stat Icons

**Size**: 16×16 px
**Directory**: `assets/textures/ui/stats/`
**Style**: Flat monochrome line-art, tinted with the stat color used in the inventory item description panel.

| id | label | color (from inventory_panel.gd _add_desc_stat calls) | description |
|---|---|---|---|
| `stat_hp` | HP | RGB(0.3, 0.8, 0.3) — green | Heart or shield-with-cross silhouette |
| `stat_atk` | ATK | RGB(0.9, 0.5, 0.3) — orange | Sword pointing upward silhouette |
| `stat_def` | DEF | RGB(0.3, 0.6, 0.9) — sky blue | Shield front-facing silhouette |
| `gold_coin` | Gold | RGB(0.8, 0.7, 0.3) — warm gold | Coin silhouette (same as gold coin above) |
