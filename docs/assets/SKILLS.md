# Arcadia — Active Skill Database

Source: `scripts/data/skill_database.gd`

All 16 active skills. All skills have `max_level: 5` and use animation `1H_Melee_Attack_Chop`.

---

## Per-Level Scaling Formulas

```
effective_multiplier(skill_id, level) = damage_multiplier + (level - 1) * damage_multiplier_per_level
effective_cooldown(skill_id, level)   = max(0.5, cooldown - (level - 1) * cooldown_reduction_per_level)
```

---

## Sword Skills

| Skill | ID | Type | Req. Prof Level | Cooldown (s) | Damage Mult | Mult/Level | CD Reduction/Level | Color (RGB) | AoE Radius | AoE Center | Special |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Bash | `bash` | `melee_attack` | sword 2 | 3.0 | 1.5 | +0.1 | -0.2 | (0.9, 0.4, 0.2) | — | — | — |
| Cleave | `cleave` | `aoe_melee` | sword 4 | 5.0 | 1.0 | +0.08 | -0.2 | (0.9, 0.6, 0.2) | 3.0 | target | — |
| Rend | `rend` | `bleed` | sword 6 | 6.0 | 0.6 | +0.06 | -0.2 | (0.8, 0.2, 0.2) | — | — | 3 ticks, 3.0s duration, 0.3× per tick |

---

## Axe Skills

| Skill | ID | Type | Req. Prof Level | Cooldown (s) | Damage Mult | Mult/Level | CD Reduction/Level | Color (RGB) | AoE Radius | AoE Center | Special |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Chop | `chop` | `melee_attack` | axe 2 | 3.0 | 1.6 | +0.1 | -0.2 | (0.7, 0.5, 0.2) | — | — | — |
| Whirlwind | `whirlwind` | `aoe_melee` | axe 4 | 5.0 | 1.1 | +0.08 | -0.2 | (0.7, 0.7, 0.3) | 3.5 | self | — |
| Execute | `execute` | `armor_pierce` | axe 6 | 7.0 | 1.8 | +0.1 | -0.2 | (0.6, 0.1, 0.1) | — | — | Ignores 75% DEF |

---

## Mace Skills

| Skill | ID | Type | Req. Prof Level | Cooldown (s) | Damage Mult | Mult/Level | CD Reduction/Level | Color (RGB) | AoE Radius | AoE Center | Special |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Crush | `crush` | `melee_attack` | mace 2 | 3.0 | 1.5 | +0.1 | -0.2 | (0.5, 0.5, 0.7) | — | — | — |
| Shatter | `shatter` | `armor_pierce` | mace 4 | 5.0 | 1.3 | +0.08 | -0.2 | (0.4, 0.4, 0.8) | — | — | Ignores 50% DEF |
| Quake | `quake` | `aoe_melee` | mace 6 | 6.0 | 0.9 | +0.07 | -0.2 | (0.6, 0.4, 0.3) | 4.0 | self | — |

---

## Dagger Skills

| Skill | ID | Type | Req. Prof Level | Cooldown (s) | Damage Mult | Mult/Level | CD Reduction/Level | Color (RGB) | AoE Radius | AoE Center | Special |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Stab | `stab` | `melee_attack` | dagger 2 | 2.0 | 1.3 | +0.1 | -0.15 | (0.3, 0.7, 0.3) | — | — | — |
| Lacerate | `lacerate` | `bleed` | dagger 4 | 4.0 | 0.5 | +0.05 | -0.15 | (0.7, 0.2, 0.3) | — | — | 4 ticks, 4.0s duration, 0.25× per tick |
| Backstab | `backstab` | `armor_pierce` | dagger 6 | 5.0 | 2.0 | +0.12 | -0.15 | (0.2, 0.2, 0.2) | — | — | Ignores 100% DEF |

---

## Staff Skills

| Skill | ID | Type | Req. Prof Level | Cooldown (s) | Damage Mult | Mult/Level | CD Reduction/Level | Color (RGB) | AoE Radius | AoE Center | Special |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Arcane Bolt | `arcane_bolt` | `melee_attack` | staff 2 | 2.5 | 1.4 | +0.1 | -0.2 | (0.5, 0.3, 0.9) | — | — | — |
| Flame Burst | `flame_burst` | `aoe_melee` | staff 4 | 5.0 | 0.8 | +0.06 | -0.2 | (0.9, 0.3, 0.1) | 3.5 | target | — |
| Drain | `drain` | `bleed` | staff 6 | 6.0 | 0.5 | +0.05 | -0.2 | (0.4, 0.1, 0.5) | — | — | 3 ticks, 3.0s duration, 0.35× per tick |

---

## Skill Type Definitions

| Type | Behavior |
|---|---|
| `melee_attack` | Single-target hit against primary target |
| `aoe_melee` | Hits all entities within `aoe_radius` of `aoe_center` (self or target) via PerceptionComponent |
| `armor_pierce` | Ignores `def_ignore_percent` of target's DEF |
| `bleed` | Initial hit at `damage_multiplier`, then `bleed_ticks` ticks of `bleed_multiplier_per_tick × ATK` over `bleed_duration` seconds |
