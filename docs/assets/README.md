# Arcadia — Asset Reference

Complete inventory of all assets referenced by code, organized by type.

## Documents

| File | Contents |
|---|---|
| [BUILDINGS.md](BUILDINGS.md) | All ~97 city buildings by district, wall/gate structures, Meshy prompts |
| [CHARACTERS.md](CHARACTERS.md) | Player + NPC character models, animation whitelist, Meshy prompts |
| [MONSTERS.md](MONSTERS.md) | Monster database (stats, drops, models), Meshy prompts |
| [PROPS.md](PROPS.md) | Dungeon props, procedural props (benches, lamps, fountains), Meshy prompts |
| [ITEMS.md](ITEMS.md) | Weapons, shields, consumables, materials, equipment slots, proficiency system |
| [SKILLS.md](SKILLS.md) | 16 active skills by weapon type, scaling formulas |
| [NATURE.md](NATURE.md) | Trees, foliage (no Meshy — use asset packs) |
| [TERRAIN.md](TERRAIN.md) | Terrain textures, shader channels, per-zone assignments |

## Meshy AI Art Style

Validated prompt suffix for all asset generation:

```
flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready model
```

- **Characters**: chibi anime proportions (big head, small body) + humanoid rigging
- **Monsters**: realistic proportions (NOT chibi) + quadruped rigging where needed
- **Buildings/Props**: detailed medieval fantasy descriptions, warm tones
- **Trees/Foliage**: skip Meshy (poor results) — use asset packs
