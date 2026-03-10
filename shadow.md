# Shadow Setup Notes

## What was needed to get shadows working

### 1. Enable shadows on DirectionalLight3D
- `shadow_enabled = true` in the scene file (was `false` by default)

### 2. Switch renderer to forward_plus
- `gl_compatibility` renderer has limited shadow support
- Changed `project.godot` → `renderer/rendering_method="forward_plus"`

### 3. Fix toon shader alpha issue
- The toon shader (`assets/shaders/toon.gdshader`) writes `ALPHA`, which puts meshes in transparent mode
- Transparent objects don't cast shadows by default in Godot
- Fix: added `depth_prepass_alpha` to the shader's render_mode line
- `render_mode diffuse_toon, specular_toon, depth_prepass_alpha;`

### 4. Replace procedural terrain with flat planes
- Procedural `ArrayMesh` terrain from `TerrainGenerator` had shadow issues
- Replaced with simple `PlaneMesh` per zone (Town 70x70, Field 80x80, Dungeon 50x50)

### 5. Tune shadow quality
- **Shadow map size**: 8192 (default 4096) in `project.godot` → `lights_and_shadows/directional_shadow/size=8192`
- **Shadow filter quality**: 3 (high) → `lights_and_shadows/directional_shadow/soft_shadow_filter_quality=3`
- **Shadow blur**: 0.5 (default 1.0) on the DirectionalLight3D for crisper edges
- **Shadow max distance**: 50 (started at 2048 which was way too high, spreads shadow map too thin)

### 6. Light angle matters
- Light pointing straight at camera = shadows behind objects (not visible)
- Rotated 30 degrees on Y-axis so shadows cast at an angle visible in isometric view
