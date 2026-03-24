# Arcadia App Icon — Design Spec

## Summary
A golden 4-point compass rose on a warm twilight background, representing exploration and the guiding journey into Arcadia. Cozy, inviting, reads well from 1024px down to 16px favicon.

## Visual Specification

### Composition
- **Shape**: Circle (for app icon contexts; square with rounded corners for platforms that require it)
- **Central element**: 4-point compass star with 4 smaller diagonal accent points
- **Center**: Glowing gold jewel with bright white core
- **Ambient detail**: 6 scattered tiny stars for depth

### Color Palette
| Element | Color | Notes |
|---------|-------|-------|
| Background center | `#2a2040` | Warm purple |
| Background edge | `#15102a` | Deep indigo |
| Gold border | `#c9a84c` | 3px stroke on outer circle |
| North star point | `#e8c860` | Brightest, full opacity |
| Other 3 star points | `#c9a84c` | 70% opacity |
| Diagonal accents | `#c9a84c` | 35% opacity |
| Center glow | `#ffcc44` | 12% opacity radial gradient, r=30% |
| Center jewel | `#e8c860` | Solid fill |
| Center bright core | `#fff8e0` → `#ffffff` | Layered circles |
| Scattered stars | `#fff8e0` | 30-50% opacity, r=1-2px |

### Sizes to Export
- `icon.svg` — vector source, project root (replaces Godot default)
- `icon_1024.png` — 1024×1024, marketing / store listing
- `icon.png` — 256×256, Godot project icon (referenced in `project.godot`)

### Implementation
1. Create the SVG as `icon.svg` in the project root
2. Export PNGs at required sizes
3. Update `project.godot` to reference the new icon
4. The SVG serves as the canonical source; PNGs are derived

### Mood & Intent
- **Cozy & inviting** — not epic or aggressive
- **Anime fantasy RPG** — aligns with Ragnarok Online inspiration
- **Warm gold on cool twilight** — high contrast, premium feel
- **The compass star as guiding light** — you're being drawn toward Arcadia
