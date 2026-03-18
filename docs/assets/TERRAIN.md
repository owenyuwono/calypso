# Arcadia — Terrain Textures & Shaders Reference

Source: `scenes/game_world/game_world.gd`, `assets/shaders/`

---

## Shader Channel Mapping

The terrain shader (`terrain_blend.gdshader`) blends up to 5 texture channels per zone using vertex colors painted by terrain rules. Additional shader parameter: `blend_sharpness = 1.5`.

| Channel | Shader Param | Texture Role | UV Scale Param | UV Scale Value |
|---|---|---|---|---|
| Default (no paint) | `texture_grass` | Base ground / grass / pavement | `uv_scale_pavement` | 0.5 |
| R (channel 0) | `texture_dirt` | Dirt paths, market district | `uv_scale_dirt` | 0.25 |
| G (channel 1) | `texture_stone` | Stone roads, rocky clearings | `uv_scale_stone` | 0.2 |
| B (channel 2) | `texture_cobble` | Cobblestone roads (city roads, central plaza) | `uv_scale_cobble` | 0.5 |
| A inverted (channel 3) | `texture_packed_earth` | Packed earth / brick pavement (district grounds) | `uv_scale_earth` | 0.5 |

---

## Per-Zone Texture Assignments

| Zone | `texture_grass` (default) | `texture_dirt` (ch 0) | `texture_stone` (ch 1) | `texture_cobble` (ch 2) | `texture_packed_earth` (ch 3) |
|---|---|---|---|---|---|
| City | `Bricks/Bricks_23-512x512.png` | `dirt_albedo.png` | `stone_albedo.png` | `Bricks/Bricks_17-512x512.png` | `Bricks/Bricks_23-512x512.png` |
| East Field | `grass_town.png` | `dirt_albedo.png` | `stone_albedo.png` | (null — not used) | (null — not used) |
| West Field | `grass_town.png` | `dirt_albedo.png` | `stone_albedo.png` | (null — not used) | (null — not used) |

---

## Texture File Paths

All textures are under `assets/textures/terrain/`:

| File | Role |
|---|---|
| `dirt_albedo.png` | Dirt paths and market district ground (channel 0) |
| `stone_albedo.png` | Stone roads and rocky clearings (channel 1) |
| `grass_town.png` | Base grass ground for field zones (default channel) |
| `Bricks/Bricks_17-512x512.png` | Cobblestone roads — shader param `texture_cobble` (channel 2) |
| `Bricks/Bricks_23-512x512.png` | Packed earth pavement and city grass base — shader params `texture_packed_earth` (channel 3) and `texture_grass` (default) in city |

---

## Unused Terrain Textures on Disk

The `assets/textures/terrain/` directory contains large texture libraries not referenced by code:

| Directory | Contents | Status |
|---|---|---|
| `Bricks/` | 25 brick variants (Bricks_01 through Bricks_25) | Only Bricks_17 and Bricks_23 are used |
| `Roofs/` | 25 roof texture variants (Roofs_01 through Roofs_25) | None used — buildings are procedural colored BoxMesh |
| `Wood/` | 25 wood texture variants (Wood_01 through Wood_25) | None used |
| `Tile/` | 25 tile texture variants (Tile_01 through Tile_25) | None used |

---

## Shaders

Source: `assets/shaders/`

| File | Type | Purpose | Used By |
|---|---|---|---|
| `toon.gdshader` | Vertex/Fragment | Toon shading with hard shadow bands; supports `albedo_color`, `albedo_texture`, `use_texture`, `alpha_multiplier` params | All characters (player, NPCs, monsters) via `ModelHelper.apply_toon_to_model()` and `ModelHelper.create_toon_material()` |
| `terrain_blend.gdshader` | Vertex/Fragment | Vertex-color-based texture blending for terrain meshes; 5-channel blend with configurable UV scales and `blend_sharpness` | All terrain meshes (city, east field, west field) via `game_world.gd` |
| `toon_cutout.gdshader` | Vertex/Fragment | Toon shading variant with alpha-cutout transparency | On disk; not confirmed to be actively referenced in current codebase |
| `outline.gdshader` | Vertex/Fragment | Object outline pass | On disk; not confirmed to be actively referenced in current codebase |
