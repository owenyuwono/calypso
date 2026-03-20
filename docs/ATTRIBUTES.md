# Combat & Attribute System Spec

## Overview

A three-layer combat system: **base stats** (the numbers), **proficiencies** (use-based progression that drives stats), and **damage types** (physical/magical with resistances). Designed for depth that rewards learning — every stat matters, every build has meaningful choices.

**This spec supersedes** the existing stat derivation system documented in CLAUDE.md:
- Old: `ATK = 5 + weapon_level * 2`, `DEF = 3 + constitution_level`, `Max HP = 40 + constitution_level * 10`
- New: Multi-attribute formulas defined below (e.g., `ATK = 5 + STR × 3 + weapon_prof × 2 + equip`)

---

## Migration from Current System

### Proficiency Changes (13 → 19)

**Kept (renamed):**
- `constitution` → `con` (Constitution) — `con` is the canonical ID everywhere, no compat layer. Same XP source (taking damage), expanded stat impact.
- `agility` → `agi` (Agility) — `agi` is the canonical ID everywhere, no compat layer. New XP source (dodging), new stat impact (was dormant).

**New attributes (4) — canonical IDs:**
- `str` (Strength), `int` (Intelligence), `dex` (Dexterity), `wis` (Wisdom)

**New weapons (2):**
- `bow`, `spear` — proficiencies exist in database but skills/items/mechanics are deferred to future work

**Unchanged (11):**
- Weapons: `sword`, `axe`, `mace`, `dagger`, `staff`
- Gathering: `mining`, `woodcutting`, `fishing`
- Production: `smithing`, `cooking`, `crafting`

### Stat Architecture

All 16 base stats live in **StatsComponent** as properties. ProgressionComponent's `_recalculate_stats()` computes them from proficiency levels and writes them to StatsComponent. CombatComponent reads stats from StatsComponent for damage calculations.

New StatsComponent fields: `matk`, `mdef`, `accuracy`, `evasion`, `crit_rate`, `crit_damage`, `move_speed`, `cast_speed`, `max_stamina`, `stamina_regen`, `hp_regen`, `cooldown_reduction`. Existing fields (`hp`, `max_hp`, `atk`, `def`, `level`, `attack_speed`, `attack_range`) are kept.

### Balance Shift (intentional)

| Stat | Old (level 1 / level 10) | New (level 1 / level 10) |
|------|--------------------------|--------------------------|
| ATK | 7 / 25 | 10 / 55 |
| DEF | 4 / 13 | 5 / 23 |
| Max HP | 50 / 140 | 65 / 200 |

Higher ceilings create more room for build differentiation. Monster stats will need rebalancing to match.

---

## Layer 1: Base Stats

16 derived stats organized by function. No stat exists in isolation — each is driven by one or more attribute proficiencies plus equipment bonuses.

### Offensive Stats

| Stat | Description | Driven By |
|------|-------------|-----------|
| **ATK** | Physical attack power (melee max hit) | STR + weapon proficiency + equipment |
| **MATK** | Magical attack power (spell damage) | INT + staff proficiency + equipment |
| **Accuracy** | Hit chance vs target's evasion (%) | DEX |
| **Crit Rate** | Critical hit chance (%) | DEX |
| **Crit Damage** | Critical hit multiplier (base 1.5×) | STR |

### Defensive Stats

| Stat | Description | Driven By |
|------|-------------|-----------|
| **Max HP** | Health pool | CON |
| **DEF** | Physical damage reduction | CON + equipment |
| **MDEF** | Magical damage reduction | INT + equipment |
| **Evasion** | Dodge chance vs attacker's accuracy (%) | AGI |

### Speed Stats

| Stat | Description | Driven By |
|------|-------------|-----------|
| **Attack Speed** | Auto-attack speed multiplier (higher = faster). Applied to base cooldown: `effective_cooldown = base_interval / attack_speed_mult` | AGI |
| **Move Speed** | Navigation speed multiplier | AGI |
| **Cast Speed** | Skill/spell cast time multiplier (higher = faster) | WIS |

### Resource Stats

| Stat | Description | Driven By |
|------|-------------|-----------|
| **Max Stamina** | Resource pool for skills and actions | CON |
| **Stamina Regen** | Stamina recovery rate multiplier | WIS |
| **HP Regen** | Passive HP recovery per second (out of combat only) | CON |
| **Cooldown Reduction** | Flat % reduction on skill cooldowns (capped 30%). CDR stacks additively with skill synergy `cooldown_reduction` bonuses. Combined cap: 40%. | WIS |

### Stat Derivation Formulas

All formulas use proficiency level (1–10). Equipment bonuses are additive on top.

```
ATK       = 5 + STR × 3 + weapon_prof × 2 + equip_atk
MATK      = 5 + INT × 3 + staff_prof × 2 + equip_matk
DEF       = 3 + CON × 2 + equip_def
MDEF      = 3 + INT × 1 + equip_mdef
Max HP    = 50 + CON × 15
Accuracy  = 80 + DEX × 5
Evasion   = AGI × 3
Crit Rate = 5 + DEX × 2
Crit Dmg  = 150 + STR × 5
ASPD Mult  = 1.0 + AGI × 0.05
Move Spd  = 1.0 + AGI × 0.03
Cast Spd  = 1.0 + WIS × 0.05
Max Stam  = 100 + CON × 10
Stam Regn = base_rate × (1.0 + WIS × 0.1)
HP Regen  = CON × 0.5 per second (out of combat only)
CDR       = WIS × 3 (%, capped at 30%)
```

**Stat ranges at level 1 vs level 10 (no equipment):**

| Stat | Level 1 | Level 10 | Notes |
|------|---------|----------|-------|
| ATK | 10 (5+3+2) | 55 (5+30+20) | With max weapon prof |
| MATK | 10 | 55 | With max staff prof |
| DEF | 5 | 23 | |
| MDEF | 4 | 13 | |
| Max HP | 65 | 200 | |
| Accuracy | 85% | 130% | Overcap offsets evasion |
| Evasion | 3% | 30% | |
| Crit Rate | 7% | 25% | |
| Crit Dmg | 155% | 200% | |
| ASPD Mult | 1.05× | 1.5× | |
| Move Spd | 1.03× | 1.3× | |
| Cast Spd | 1.05× | 1.5× | |
| Max Stam | 110 | 200 | |
| HP Regen | 0.5/s | 5.0/s | Out of combat |
| CDR | 3% | 30% | |

### Hit/Evasion Formula

```
hit_chance = clamp(attacker.accuracy - target.evasion, 5, 100)
```

- Minimum 5% hit chance (never completely unhittable)
- Maximum 100% (no overcap benefit beyond negating evasion)

**Example matchups:**
- Low DEX warrior (85% acc) vs max AGI rogue (30% eva) = 55% hit — significant miss chance
- Max DEX archer (130% acc) vs max AGI rogue (30% eva) = 100% — always hits
- Average DEX (95%) vs average AGI (15%) = 80% — reasonable miss rate

### Critical Hit Formula

Crit Damage is stored as an integer percentage (150 = 1.5× multiplier).

```
is_crit = randf() < (crit_rate / 100.0)
crit_multiplier = crit_damage / 100.0  # e.g. 150 → 1.5×
```

**Integration with synergies:** The existing SkillDatabase synergy `crit_chance` bonuses add to the DEX-based `crit_rate`. The `crit_damage` stat from STR replaces the old hardcoded 1.5× multiplier. There is no separate synergy crit system — it's unified into the global crit.

### Damage Formula

```
# Physical
raw_damage = ATK × skill_multiplier
physical_damage = max(1, raw_damage - target.DEF) × element_modifier × phys_type_modifier

# Magical
raw_damage = MATK × skill_multiplier
magical_damage = max(1, raw_damage - target.MDEF) × element_modifier

# Critical applies after all modifiers
if is_crit:
    final_damage *= crit_multiplier
```

Minimum 1 damage — attacks always deal at least 1.

---

## Layer 2: Proficiencies

Use-based progression — you improve by doing. 19 total proficiencies across 4 categories.

**Global rules:**
- Max level: 10 per proficiency
- XP to next level: `current_level × 50`
- All proficiencies start at level 1, 0 XP
- Total level = sum of all proficiency levels (max 190)
- Player and NPC progression is identical

### Attribute Proficiencies (6)

| Attribute | Description | XP Source | Amount | Stats Driven |
|-----------|-------------|-----------|--------|--------------|
| **Strength (STR)** | Raw physical power. Muscles trained through combat | Deal physical damage | 3 XP per hit | ATK, Crit Damage |
| **Constitution (CON)** | Toughness. Bodies hardened by punishment | Take damage | 3 XP per hit taken | Max HP, DEF, HP Regen, Max Stamina |
| **Agility (AGI)** | Reflexes. Trained by surviving danger | Evade an attack (5 XP) / Travel 10m in combat (1 XP) | 5 XP per dodge / 1 XP per 10m | Evasion, Attack Speed, Move Speed |
| **Intelligence (INT)** | Arcane knowledge. Power through understanding | Deal magical damage | 3 XP per magic hit | MATK, MDEF |
| **Dexterity (DEX)** | Precision. Eyes and hands trained by practice | Land a hit | 2 XP per hit landed | Accuracy, Crit Rate |
| **Wisdom (WIS)** | Mental discipline. Focus sharpened through practice | Use any skill | 2 XP per skill use | Cast Speed, CDR, Stamina Regen |

**Design notes:**
- AGI has two XP sources: 5 XP per successful dodge (requires hit/miss system implementation) and 1 XP per 10m traveled while in combat (always available). Both sources active simultaneously.
- DEX gives 2 XP per hit (frequent but scaled to not outpace other attributes)
- WIS is universal — every build uses skills, so every build levels WIS
- STR only triggers on physical damage, INT only on magical — creates natural specialization

### Weapon Proficiencies (7)

| Weapon | Physical Type | Style | Identity | XP Source |
|--------|--------------|-------|----------|-----------|
| **Sword** | Slash | Melee | Balanced — moderate speed and damage | Deal damage with sword |
| **Axe** | Slash | Melee | Heavy hitter — slow, good AoE | Deal damage with axe |
| **Mace** | Blunt | Melee | Armor crusher — slow, anti-heavy | Deal damage with mace |
| **Dagger** | Pierce | Melee | Fast — crit focused, low base damage | Deal damage with dagger |
| **Staff** | Blunt / Magic | Melee + Magic | Primary magic weapon, weak melee | Deal damage with staff |
| **Bow** | Pierce | Ranged | Ranged physical, DEX-scaling | Deal damage with bow |
| **Spear** | Pierce | Melee | Extended melee range, line attacks | Deal damage with spear |

**Attack type coverage:**
- Slash: Sword, Axe (2 weapons)
- Pierce: Dagger, Bow, Spear (3 weapons)
- Blunt: Mace, Staff (2 weapons)

**Bow special rule:** Bow ATK scales with DEX instead of STR for ranged attacks:
```
bow_ATK = 5 + DEX × 3 + bow_prof × 2 + equip_atk
```

### Gathering Proficiencies (3) — unchanged

| Proficiency | XP Source |
|-------------|-----------|
| Mining | Mine ore nodes |
| Woodcutting | Chop trees |
| Fishing | Fish at fishing spots |

### Production Proficiencies (3) — unchanged

| Proficiency | XP Source |
|-------------|-----------|
| Smithing | Smith items at forge |
| Cooking | Cook food at kitchen |
| Crafting | Craft items at workbench |

---

## Layer 3: Damage Types & Resistances

Two damage categories (physical and magical), each with subtypes. Every attack has a damage category + subtype. Every defender has a resistance profile.

### 5-Level Resistance Scale

All damage type interactions use this fixed multiplier table:

| Level | Multiplier | Description |
|-------|-----------|-------------|
| **Fatal** | 2.0× | Devastating weakness — thematic hard counters |
| **Weak** | 1.5× | Notable vulnerability — meaningful advantage |
| **Neutral** | 1.0× | No modifier — baseline |
| **Resist** | 0.5× | Strong resistance — halved damage |
| **Immune** | 0.0× | Complete immunity — zero damage |

Fatal and Immune are rare — reserved for strong thematic matchups (undead vs Light, fire elemental vs Fire).

### Physical Damage Types (3)

Determined by weapon type. Applied against target's armor type.

| Type | Weapons | Description |
|------|---------|-------------|
| **Slash** | Sword, Axe | Cutting attacks — deflected by hard surfaces |
| **Pierce** | Dagger, Bow, Spear | Penetrating attacks — finds gaps in armor |
| **Blunt** | Mace, Staff (melee) | Impact attacks — transfers force through armor |

### Armor Types (3)

Each armor type has default physical resistances. Equipment items declare their armor type.

| Armor Type | Materials | Slash | Pierce | Blunt | Compensation |
|------------|-----------|-------|--------|-------|--------------|
| **Heavy** | Plate, full armor | Resist (0.5×) | Neutral (1.0×) | Weak (1.5×) | Highest raw DEF |
| **Medium** | Chain, leather | Neutral (1.0×) | Weak (1.5×) | Neutral (1.0×) | Balanced DEF + speed |
| **Light** | Cloth, robes | Weak (1.5×) | Neutral (1.0×) | Neutral (1.0×) | MDEF bonuses, no speed penalty, cast speed bonuses |

**Design rationale:**
- **Heavy vs Blunt**: Concussive force transfers through rigid plate — a warhammer dents what a sword cannot cut
- **Medium vs Pierce**: Chainmail rings separate under piercing force — daggers find gaps between links
- **Light vs Slash**: Cloth offers no resistance to cutting edges — but mages rely on distance, evasion, and magical defense

### Magical Damage Types (7)

Staff skills each declare a magic element. Three opposing pairs plus one neutral type.

| Element | Opposing | Theme |
|---------|----------|-------|
| **Fire** | Ice | Heat, burning, damage over time |
| **Ice** | Fire | Cold, freezing, slowing |
| **Lightning** | Earth | Sky energy, burst damage, chain |
| **Earth** | Lightning | Ground force, defense, crowd control |
| **Light** | Dark | Sacred, purification, anti-undead |
| **Dark** | Light | Shadow, life drain, curses |
| **Arcane** | — | Pure magic, neutral, no advantages or weaknesses |

**Element interaction defaults:**
- Attacking with an element against its opposite → Weak (1.5×)
- Attacking with an element against itself → Resist (0.5×)
- Arcane vs anything / anything vs Arcane → Neutral (1.0×)
- All other combinations → Neutral (1.0×)

These are the defaults. Individual monsters can override with their own resistance profiles (e.g., an ice slime might be Immune to Ice, Fatal to Fire).

### Skill Element Assignments

**Current staff skills:**

| Skill | Element |
|-------|---------|
| Arcane Bolt | Arcane |
| Flame Burst | Fire |
| Drain | Dark |

**All non-staff weapon skills:** Physical damage, no element (element modifier = 1.0×). Physical type determined by weapon.

**New fields on each skill entry:**
- `"damage_category"`: `"physical"` or `"magical"` — determines ATK vs MATK and DEF vs MDEF
- `"element"`: `"fire"`, `"ice"`, `"lightning"`, `"earth"`, `"light"`, `"dark"`, `"arcane"`, or `null` — determines element modifier

Physical type (`slash`/`pierce`/`blunt`) is derived from the weapon, not stored on the skill.

**Example updated skill entry:**
```
"flame_burst": {
    "name": "Flame Burst",
    "type": "melee_attack",
    "damage_category": "magical",
    "element": "fire",
    "required_proficiency": {"skill": "staff", "level": 3},
    "damage_multiplier": 1.8,
    "cooldown": 4.0,
    "stamina_cost": 19,
    ...
}
```

### Combined Damage Formula

```
# Step 1: Determine damage category
if weapon == staff and skill.is_magical:
    raw = MATK × skill_multiplier
    after_def = max(1, raw - target.MDEF)
    element_mod = get_element_modifier(skill.element, target.element_resistances)
    phys_type_mod = 1.0  # not applicable for magic
else:
    raw = ATK × skill_multiplier  # (or DEX-based ATK for bow)
    after_def = max(1, raw - target.DEF)
    element_mod = get_element_modifier(skill.element, target.element_resistances)  # usually 1.0 for physical
    phys_type_mod = get_phys_type_modifier(weapon.phys_type, target.armor_type)

# Step 2: Apply modifiers
damage = after_def × element_mod × phys_type_mod

# Step 3: Critical hit
if is_crit:
    damage *= crit_multiplier

# Step 4: Floor
final_damage = max(1, int(damage))
```

**Staff auto-attacks:** Staff melee auto-attacks are physical Blunt damage using ATK (not MATK). For a pure mage with low STR, this means auto-attacks deal minimal damage. This is intentional — mages must use skills for meaningful damage output.

---

## Implementation Architecture

Component responsibilities for implementing this system:

### StatsComponent
Holds all 16 base stats as properties. New fields to add: `matk`, `mdef`, `accuracy`, `evasion`, `crit_rate`, `crit_damage`, `move_speed`, `cast_speed`, `max_stamina`, `stamina_regen`, `hp_regen`, `cooldown_reduction`. Existing fields kept: `hp`, `max_hp`, `atk`, `def`, `level`, `attack_range`.

**attack_speed change**: The existing `attack_speed` field stays as the base cooldown interval (e.g., 0.8s = attacks every 0.8s). A new `attack_speed_mult` field (from AGI) acts as a multiplier. Effective cooldown: `attack_speed / attack_speed_mult`. This preserves the existing semantic while adding AGI scaling.

### ProgressionComponent
`_recalculate_stats()` computes base stats (without equipment) from proficiency levels and writes them to StatsComponent. Equipment bonuses are NOT included here — CombatComponent adds those at read time.

### CombatComponent
Reads stats from StatsComponent + equipment bonuses from EquipmentComponent.
- `get_effective_atk()` = `stats.atk + equipment.get_atk_bonus()`
- `get_effective_matk()` = `stats.matk + equipment.get_matk_bonus()` (new)
- `get_effective_def()` = `stats.def + equipment.get_def_bonus()`
- `get_effective_mdef()` = `stats.mdef + equipment.get_mdef_bonus()` (new)
- `get_armor_type()` = `equipment.get_armor_type()` (new)

### EquipmentComponent
New methods:
- `get_matk_bonus()` — sum `matk_bonus` across all equipped items
- `get_mdef_bonus()` — sum `mdef_bonus` across all equipped items
- `get_armor_type() -> String` — returns armor type from torso slot ("heavy", "medium", or "light"). Defaults to "light" if nothing equipped.

### SkillEffectResolver
Owns the full damage formula. `resolve_skill_hit()` receives skill data with `damage_category`, `element` fields. Queries weapon `phys_type` from weapon data, monster resistances from MonsterDatabase. Applies the combined damage formula (ATK/MATK, DEF/MDEF, element modifier, phys type modifier, crit).

### MonsterDatabase
Each monster entry gets new fields:
- `"element": "earth"` — innate element (affects own attack element + provides default resistances)
- `"resistances": {"slash": "neutral", "pierce": "resist", ...}` — per-type overrides

### StaminaComponent
Receives `stats_component` ref via `setup(stats)`. Reads `max_stamina` and `stamina_regen` from StatsComponent instead of using hardcoded values. ProgressionComponent updates StatsComponent on level-up, StaminaComponent reads dynamically.

---

## Monster Resistance Profiles

Each monster has a resistance entry for all 10 damage subtypes (3 physical + 7 magical). Defaults to Neutral unless specified.

The **Element** column is the monster's innate element — it determines both the element of the monster's own attacks AND provides default magical resistances (resist own element, weak to opposite). The per-type columns override these defaults where specified.

### Current Monsters

| Monster | Element | Slash | Pierce | Blunt | Fire | Ice | Lgtn | Earth | Light | Dark | Arcane | Notes |
|---------|---------|-------|--------|-------|------|-----|------|-------|-------|------|--------|-------|
| **Slime** | Earth | Neutral | Resist | Weak | Weak | Neutral | Neutral | Resist | Neutral | Neutral | Neutral | Blunt squashes, fire dries, piercing passes through |
| **Wolf** | Neutral | Neutral | Neutral | Neutral | Weak | Resist | Neutral | Neutral | Neutral | Neutral | Neutral | Natural beast, slight fire vulnerability |
| **Goblin** | Earth | Neutral | Neutral | Neutral | Weak | Neutral | Neutral | Resist | Neutral | Weak | Neutral | Cave dwellers, fear fire and light |
| **Skeleton Warrior** | Dark | Resist | Resist | Weak | Neutral | Neutral | Neutral | Neutral | Fatal | Immune | Neutral | Bones shatter under blunt force, sacred light destroys |
| **Skeleton Mage** | Dark | Resist | Resist | Weak | Neutral | Neutral | Neutral | Neutral | Fatal | Immune | Neutral | Same skeleton weaknesses, dark magic wielder |
| **Skeleton Minion** | Dark | Neutral | Neutral | Neutral | Neutral | Neutral | Neutral | Neutral | Weak | Resist | Neutral | Weaker undead, less extreme resistances |

---

## NPC Trait Profile Starting Attributes

Each trait profile defines starting proficiency levels for all 6 attributes. This replaces the current 2-attribute system (constitution + agility only).

### Migration from existing profiles

| Old Profile | New Profile | Change |
|-------------|------------|--------|
| bold_warrior | bold_warrior | Kept — expanded with STR/INT/DEX/WIS |
| cautious_mage | cautious_mage | Kept — expanded |
| sly_rogue | sly_rogue | Kept — expanded |
| stern_guardian | stern_guardian | Kept — expanded |
| gentle_healer | gentle_healer | Kept — expanded |
| charming_bard | charming_bard | Kept — expanded |
| earnest_apprentice | earnest_apprentice | Kept — expanded |
| boisterous_brawler | wild_berserker | Renamed + reworked for axe/medium |
| cheerful_scholar | devout_cleric | Renamed + reworked for staff/WIS focus |
| mysterious_loner | shadow_stalker | Renamed + reworked for dagger/AGI focus |
| stoic_knight | stoic_knight | Kept — reworked for spear/heavy |
| merchant | merchant | Kept — see below |
| — | keen_archer | New — for bow users |

### New profiles

| Profile | STR | CON | AGI | INT | DEX | WIS | Primary Weapon | Armor Type |
|---------|-----|-----|-----|-----|-----|-----|----------------|------------|
| bold_warrior | 3 | 2 | 1 | 1 | 2 | 1 | Sword | Heavy |
| cautious_mage | 1 | 1 | 1 | 3 | 1 | 3 | Staff | Light |
| sly_rogue | 1 | 1 | 3 | 1 | 3 | 1 | Dagger | Light |
| stern_guardian | 2 | 3 | 1 | 1 | 1 | 2 | Sword | Heavy |
| gentle_healer | 1 | 2 | 1 | 2 | 1 | 3 | Staff | Light |
| charming_bard | 1 | 1 | 2 | 2 | 2 | 2 | Dagger | Medium |
| wild_berserker | 3 | 2 | 2 | 1 | 1 | 1 | Axe | Medium |
| stoic_knight | 2 | 3 | 1 | 1 | 2 | 1 | Spear | Heavy |
| keen_archer | 1 | 1 | 2 | 1 | 3 | 2 | Bow | Medium |
| earnest_apprentice | 2 | 2 | 1 | 1 | 2 | 2 | Mace | Medium |
| devout_cleric | 1 | 2 | 1 | 2 | 1 | 3 | Staff | Medium |
| shadow_stalker | 2 | 1 | 3 | 1 | 2 | 1 | Dagger | Light |
| merchant | 2 | 2 | 1 | 1 | 2 | 2 | Dagger | Light |

### NpcGenerator archetype → profile mapping

| Archetype | Possible Profiles |
|-----------|------------------|
| warrior | bold_warrior, stern_guardian, wild_berserker, stoic_knight |
| mage | cautious_mage, devout_cleric, gentle_healer |
| rogue | sly_rogue, charming_bard, shadow_stalker |
| ranger | keen_archer |
| merchant | merchant |

NpcGenerator selects a random profile from the archetype's allowed list and includes it directly in the loadout dict as `trait_profile`.

---

## Stamina as Unified Resource

Stamina serves as the single resource pool for all actions (physical skills and magic). No separate mana.

**Stamina behavior** (changes from current system noted):
- **In combat**: Drains 0.5/sec passively (unchanged). Skills cost additional stamina per use. Default formula: `stamina_cost = 10 + int(damage_multiplier × 5)`. Magical skills (staff) cost 1.5× the base amount. Examples: Bash (1.2× mult) = 16 stamina. Flame Burst (1.8× mult, magical) = 29 stamina.
- **Moving**: Drains 0.15/sec while navigating (unchanged)
- **Out of combat**: Regens at base 1.0/sec × Stamina Regen multiplier (**NEW** — currently no out-of-combat regen)
- **At rest spots**: Regens at base 3.0/sec × Stamina Regen multiplier (unchanged base rate, now modified by WIS)
- **At zero stamina**: Cannot use skills. Auto-attacks still work but at reduced speed (**NEW** — currently no zero-stamina penalty)

**Max Stamina** scales with CON. **Stamina Regen** scales with WIS. This creates a meaningful choice: CON gives you a bigger pool (burst capacity), WIS gives you faster recovery (sustained efficiency).

---

## HP Regeneration

Passive HP recovery. Only active out of combat (no damage taken for 5 seconds).

```
hp_regen_per_second = CON × 0.5
```

- Level 1 CON: 0.5 HP/sec (slow, takes ~2 min to full heal from near-death)
- Level 10 CON: 5.0 HP/sec (significant, full heal from 50% in ~20s at 200 max HP)
- In combat: 0 HP/sec (must use potions, food, or healing skills)

---

## Equipment Stat Contributions

Equipment provides flat bonuses to base stats. Each piece declares:
- **Stat bonuses**: `atk_bonus`, `matk_bonus`, `def_bonus`, `mdef_bonus` (new fields alongside existing `atk_bonus`/`def_bonus`)
- **Armor type**: `armor_type` field — "heavy", "medium", or "light". Applies to body armor slots (torso, legs, gloves, feet, head)
- **Weapon type**: Determines physical attack type (`phys_type` field)
- **Required proficiency**: `required_skill` + `required_level` (existing fields)

**Equipment slots** (8, unchanged): head, torso, legs, gloves, feet, back, main_hand, off_hand

**Armor type resolution**: The entity's effective armor type for physical damage resistance is determined by the **torso** slot. If no torso armor is equipped, defaults to Light. Mixed armor across slots does not blend — torso is authoritative.

**Armor type stat tendencies:**
- Heavy: highest DEF, no MDEF, no speed bonuses
- Medium: moderate DEF, low MDEF, no penalties
- Light: low DEF, highest MDEF, cast speed bonuses

---

## Interaction Examples

**Scenario 1: Sword warrior vs Skeleton Warrior**
- Warrior uses Cleave (Slash, physical)
- Skeleton has Slash = Resist (0.5×)
- Damage halved — warrior should switch to Mace (Blunt, Weak = 1.5×)
- Player learns: bring a mace to the skeleton dungeon

**Scenario 2: Fire mage vs Slime**
- Mage uses Flame Burst (Fire, magical)
- Slime has Fire = Weak (1.5×), MDEF is low
- Massive damage — fire is the hard counter to slimes

**Scenario 3: Dagger rogue vs Heavy armor knight**
- Rogue uses Backstab (Pierce, physical)
- Heavy armor has Pierce = Neutral (1.0×)
- No advantage or penalty — rogue relies on crits and speed instead
- But rogue vs Medium armor (chain): Pierce = Weak (1.5×) — ideal matchup

**Scenario 4: Any build vs Skeleton (Light element)**
- Skeleton Warrior has Light = Fatal (2.0×)
- A staff user with a Light-element spell deals double damage
- This creates demand for Light-element skills, even for primarily physical builds

---

## Future Considerations (not in this spec)

- **Monster stat rebalance** (hard dependency): Monster HP/ATK/DEF values must be rebalanced to match new stat ranges before this system ships
- **Weapon enchantments**: Physical weapons gaining elemental damage
- **Status effects**: Burn (fire DoT), Freeze (ice slow), Shock (lightning stun), etc.
- **Elemental resistance on equipment**: Armor granting magic element resistances
- **More monsters with diverse resistance profiles**
- **Ranged combat mechanics**: Bow projectile system, range calculations
- **Spear reach mechanics**: Extended melee range, line-of-effect skills
- **Synergy system update**: Current SkillDatabase synergies reference `con`/`agi` — update to include new attributes (str, int, dex, wis) as secondary synergy sources
