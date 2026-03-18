# Props

Source: `assets/models/environment/dungeon/`, `scripts/world/city_builder.gd`, `scripts/world/districts/`

Props fall into two categories: KayKit model files loaded from disk, and procedural geometry built entirely in code. Procedural props are candidates for replacement with real models.

---

## Dungeon Props (KayKit Models)

Source: KayKit Dungeon Remastered (CC0)
Path: `assets/models/environment/dungeon/`
Spawned via `AssetSpawner.spawn_dungeon_model(ctx, filename, pos)`.

Each `.gltf.glb` file has a corresponding `_dungeon_texture.png` sidecar used by the model's built-in material.

| File | Actively Used | Where / Count |
|---|---|---|
| `torch_lit.gltf.glb` | Yes | East gate (4), west gate (4), market shops (4), temple quarter (1), craft district (1), garrison (3), library (1), chapel annex (1), guard tower (2), armory (1), gazebo (1), gatehouse (1), commerce row (3), artisan quarter (2), civic district (2), craft row (1), military compound (2), gate district (2); city wall north (8), south (8), west (5), east (4). Total ~60+ |
| `torch_mounted.gltf.glb` | Yes | City wall north (8), south (8), west (5), east (4). Total 25 |
| `banner_red.gltf.glb` | Yes | East gate road (8), temple/noble quarter (2), garrison (1). Total ~11 |
| `barrel_large.gltf.glb` | Yes | Market (6+), craft (2), residential (1), house props (2), garrison (4), bakery (1), commerce row (1), artisan quarter (1), craft row (2), military compound (2). Total ~25 |
| `barrel_small.gltf.glb` | Yes | Market district (1 at Vector3(-53, 0, 28)) |
| `crates_stacked.gltf.glb` | Yes | Market (2+), craft (2), residential stalls (1), bakery (1), storage shed (2), garrison (2), gatehouse (1), cluster districts. Total ~20+ |
| `pillar_decorated.gltf.glb` | Yes | Temple/noble quarter (2), central plaza corners (4). Total 6 |
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

The 14 unused wall/floor/stair files are a complete interior/dungeon building kit, likely left over from a removed dungeon zone.

---

## Procedural Props (Built in Code)

These props are built entirely from primitive meshes (`CylinderMesh`, `BoxMesh`, `SphereMesh`) in the district scripts. They have no model files and are candidates for replacement with real assets.

| Prop | Where | How Many | Code Location |
|---|---|---|---|
| Fountain | Central Plaza, Park/Gardens | 2 total | `DistrictPlaza`, `DistrictPark` |
| Bench | Central Plaza (4), Park (6) | 10 total | `DistrictPlaza`, `DistrictPark` |
| Street Lamp | Central Plaza corners | 4 | `DistrictPlaza` |
| Well | Residential Quarter | 1 | `DistrictResidential` |
| Training Dummy | Garrison (6) | 6 | `DistrictGarrison` |
| Weapon Rack | Garrison (3) | 3 | `DistrictGarrison` |
| Archery Target | Garrison (2) | 2 | `DistrictGarrison` |
| Rock Cluster | Field biomes | Many | `BiomeScatter.create_rock_cluster()` — `SphereMesh`, `Color(0.4, 0.38, 0.36)` |
| Statue | Noble/Temple Quarter | 1 | `DistrictNoble` — pedestal + cylinder figure |
| Gazebo | Park/Gardens | 1 | `DistrictPark` — 6 CylinderMesh posts + BoxMesh roof |
| Market Stall | Market District (5) | 5 | `DistrictMarket` — BoxMesh frame + canopy |

Gathering resource nodes (mining rocks, fishing spots, choppable trees) are not yet placed in the world — the proficiency system exists in code but has no interactable world objects.

---

## Meshy AI Prompts

Use these prompts to generate replacement props in Meshy AI. All props use flat color / anime style to match the toon shader aesthetic.

Props with existing KayKit models (torch, barrel, crates, banner) are already covered. The prompts below target procedural props that need real models, plus gathering nodes not yet in the game.

### Fountain

Replaces procedural `CylinderMesh` fountains in Central Plaza and Park/Gardens.

```
Medieval fantasy ornate stone fountain, tiered water basin, cobblestone base, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready model
```

### Street Lamp

Replaces procedural `CylinderMesh` post + `SphereMesh` glow in Central Plaza.

```
Medieval fantasy wrought iron street lamp, warm glowing lantern top, ornate metal post, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready prop
```

### Well

Replaces procedural cylinder well in Residential Quarter.

```
Medieval fantasy stone well, wooden roof cover, rope and bucket, cobblestone base, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready prop
```

### Training Dummy

Replaces procedural post + crossbar + head dummies in Garrison.

```
Medieval fantasy wooden training dummy, wooden post with crossbar arms, straw head, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready prop
```

### Bench

Replaces procedural plank + legs benches in Central Plaza and Park.

```
Medieval fantasy wooden bench, simple plank seat, sturdy legs, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready prop
```

### Weapon Rack

Replaces procedural bar + 2 legs racks in Garrison.

```
Medieval fantasy wooden weapon rack, wall-mounted, swords and axes displayed, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready prop
```

### Archery Target

Replaces procedural post + disc face targets in Garrison.

```
Medieval fantasy archery target, wooden post, circular straw target face, red and white rings, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready prop
```

### Barrel

Supplements existing `barrel_large.gltf.glb` and `barrel_small.gltf.glb` if style replacement is needed.

```
Medieval fantasy wooden barrel, iron bands, warm brown wood, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready prop
```

### Crates

Supplements existing `crates_stacked.gltf.glb` if style replacement is needed.

```
Medieval fantasy stacked wooden crates, nailed planks, warm brown wood, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready prop
```

### Banner

Supplements existing `banner_red.gltf.glb` if style replacement is needed.

```
Medieval fantasy red banner on wooden pole, cloth flowing, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready prop
```

### Mining Rock

New asset — no equivalent exists yet. Required for mining proficiency to become functional.

```
Fantasy mineral ore deposit, jagged crystals protruding from rock, warm earth tones with blue crystal highlights, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready prop
```

### Fishing Post

New asset — no equivalent exists yet. Required for fishing proficiency to become functional.

```
Medieval fantasy small wooden fishing dock, single post with plank, rope, flat color texture, anime style coloring, no realistic shading, no specular highlights, simple diffuse colors, 3D game-ready prop
```
