# Arcadia — Nature Assets Reference

Source: FBX nature pack (CC0)
Paths: `assets/models/environment/nature/trees/fir/`, `assets/models/environment/nature/foliage/`

Note: No Meshy AI prompts — AI mesh generators produce poor results for trees and foliage. Use asset packs instead.

---

## Trees

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

### Tree Textures on Disk (Unused)

The `trees/textures/` directory contains textures for additional tree species whose models are not in the project:

Unused texture sets: Bamboo (BC/N/R), Banana, Birch, ChinaPina, CoconutPalm, DesertCoconutPalm, DesertPalm, Knotwood, Oak, PalmWood, PineBark, RedMaple, WindsweptBark, and all their leaf variants. Also unused fir normal/roughness maps: `T_FirBark_N.PNG`, `T_FirBark_R.PNG`, `T_FirBarkMisc_N.PNG`, `T_FirBarkMisc_R.PNG`.

---

## Foliage

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
| `SM_Grass1.FBX` | Field open meadow, dense forest, rocky clearing, transitional NE/SW, path-edge, border transition |
| `SM_Grass2.FBX` | Field open meadow, dense forest, rocky clearing, transitional NE/SW, path-edge, border transition |

Note: `SM_Flower_TulipsOrange.FBX` is on disk but the field meadow `flower_files` array uses Foxtails rather than TulipsOrange, so it is effectively unused despite being listed as a meadow color variant.

### Available (Unused)

All files below are in `assets/models/environment/nature/foliage/` but not referenced in any biome recipe:

`SM_BambooBush01.FBX`, `SM_BushChina01.FBX`, `SM_BushChina02.FBX`, `SM_BushChina03.FBX`, `SM_BushSnowDead01.FBX`, `SM_BushSnowDead02.FBX`, `SM_BushTropical01.FBX`, `SM_BushTropical02.FBX`, `SM_BushTropical03.FBX`, all `SM_Cactus*.FBX` (8 variants), all `SM_CactusBulb*.FBX` (2), all `SM_CactusPricklyPear*.FBX` (4), all `SM_DesertBush*.FBX` (6), all `SM_DesertTwigRoots*.FBX` (3), all `SM_DesertWeed*.FBX` (3), all `SM_ElephantEars*.FBX` (3), `SM_FlowerCrocus02.FBX`, all `SM_FlowerDesertBulb*.FBX` (5), all `SM_FlowerDesertPink*.FBX` (3), `SM_Flower_DaffodilsOrange.FBX`, `SM_Flower_DaffodilsPink.FBX`, `SM_Flower_FoxtailsLight1.FBX`, `SM_Flower_TulipsPink.FBX`, `SM_Flower_TulipsOrange.FBX`, all `SM_FlowersIce*.FBX` (3), all `SM_IvyCoastal*.FBX` (5), all `SM_IvyCoastalCurved*.FBX` (3), all `SM_IvyCoastalVine*.FBX` (8), `SM_LilyPad1.FBX`, `SM_LilyPad2.FBX`, `SM_LilyPad3.FBX`, `SM_LilyPadClump2.FBX`, `SM_Marshtail01.FBX`, `SM_Marshtail02.FBX`, `SM_Marshtail03.FBX`, and more. Approximately 100+ files covering desert, tropical, arctic, aquatic, and coastal plant types.
