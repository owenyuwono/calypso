extends StaticBody3D
## Fishing spot entity. Spawned into field zones for the fishing skill.
## Uses HarvestableComponent with skill_id="fishing" and FishDatabase tier data.
## Visual: flat blue water disc at ground level. Fades on depletion, restores on respawn.

const FishDatabase = preload("res://scripts/data/fish_database.gd")
const HarvestableComponent = preload("res://scripts/components/harvestable_component.gd")
const SfxDatabase = preload("res://scripts/audio/sfx_database.gd")

const WATER_COLOR: Color = Color(0.2, 0.4, 0.8, 0.5)
const WATER_COLOR_DEPLETED: Color = Color(0.2, 0.4, 0.8, 0.05)
const DISC_RADIUS: float = 1.0

static var _next_id: int = 1

var entity_id: String = ""
var fish_tier: String = ""
var fish_name: String = ""

var _disc_instance: MeshInstance3D = null
var _disc_mat: StandardMaterial3D = null
var _harvestable: Node = null
var _depletion_player: AudioStreamPlayer3D = null
var _pulse_timer: float = 0.0

var last_chopper_pos: Vector3 = Vector3.ZERO


func setup(tier: String) -> void:
	entity_id = "fishing_spot_%03d" % _next_id
	_next_id += 1
	fish_tier = tier

	var fish_data: Dictionary = FishDatabase.get_fish(tier)
	fish_name = fish_data.get("name", "Fishing Spot")

	_build_collision()
	_build_water_disc()
	_add_harvestable_component()

	WorldState.register_entity(entity_id, self, {
		"type": "fishing_spot",
		"name": fish_name,
		"fish_tier": fish_tier,
		"harvestable": true,
	})


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = DISC_RADIUS
	shape.height = 0.2
	col.shape = shape
	col.position = Vector3(0.0, 0.1, 0.0)
	add_child(col)
	collision_layer = 1
	collision_mask = 0


func _exit_tree() -> void:
	if not entity_id.is_empty():
		WorldState.unregister_entity(entity_id)


func _build_water_disc() -> void:
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.albedo_color = WATER_COLOR
	_disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_disc_mat.no_depth_test = false

	_disc_instance = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = DISC_RADIUS
	cylinder.bottom_radius = DISC_RADIUS
	cylinder.height = 0.05
	cylinder.radial_segments = 24
	cylinder.rings = 1
	_disc_instance.mesh = cylinder
	_disc_instance.material_override = _disc_mat
	_disc_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disc_instance.position = Vector3(0.0, 0.05, 0.0)
	add_child(_disc_instance)


func _add_harvestable_component() -> void:
	_depletion_player = AudioStreamPlayer3D.new()
	_depletion_player.max_distance = 40.0
	_depletion_player.bus = &"SFX"
	add_child(_depletion_player)

	var comp := HarvestableComponent.new()
	comp.name = "HarvestableComponent"
	add_child(comp)
	comp.setup(fish_tier, "fishing", FishDatabase.get_fish)
	_harvestable = comp
	comp.depleted.connect(_on_depleted)
	comp.respawned.connect(_on_respawned)


func _process(delta: float) -> void:
	if not is_instance_valid(_disc_mat):
		return
	if _disc_mat.albedo_color.a < 0.1:
		return
	# Subtle alpha pulse on active spots
	_pulse_timer += delta * 1.5
	var pulse: float = sin(_pulse_timer) * 0.08
	var current: Color = _disc_mat.albedo_color
	_disc_mat.albedo_color = Color(current.r, current.g, current.b, WATER_COLOR.a + pulse)


func _on_depleted() -> void:
	WorldState.set_entity_data(entity_id, "harvestable", false)
	var sfx: Dictionary = SfxDatabase.get_sfx("gather_fish_catch")
	if not sfx.is_empty():
		var stream: AudioStream = load(sfx["path"]) if ResourceLoader.exists(sfx["path"]) else null
		if stream:
			_depletion_player.stream = stream
			_depletion_player.volume_db = sfx["volume_db"]
			_depletion_player.play()
	if is_instance_valid(_disc_mat):
		var tween := create_tween()
		tween.tween_property(_disc_mat, "albedo_color:a", WATER_COLOR_DEPLETED.a, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _on_respawned() -> void:
	WorldState.set_entity_data(entity_id, "harvestable", true)
	if is_instance_valid(_disc_mat):
		var tween := create_tween()
		tween.tween_property(_disc_mat, "albedo_color:a", WATER_COLOR.a, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func spawn_loot(item_id: String, bonus_item: String = "") -> void:
	var fish_data: Dictionary = FishDatabase.get_fish(fish_tier)
	var max_casts: int = fish_data.get("chops", [2, 4])[1]
	var drop_count: int = maxi(max_casts / 2, 1)
	var loot_scene := preload("res://scenes/objects/loot_drop.gd")
	for i in drop_count:
		if item_id.is_empty():
			break
		var loot := Area3D.new()
		loot.set_script(loot_scene)
		loot.item_id = item_id
		loot.item_count = 1
		loot.gold_amount = 0
		var offset := Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2))
		loot.position = global_position + offset
		var loot_parent: Node = ZoneManager.get_loaded_zone()
		if not loot_parent:
			loot_parent = get_tree().current_scene
		loot_parent.call_deferred("add_child", loot)
	if not bonus_item.is_empty():
		var bonus := Area3D.new()
		bonus.set_script(loot_scene)
		bonus.item_id = bonus_item
		bonus.item_count = 1
		bonus.gold_amount = 0
		bonus.position = global_position + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		var bonus_parent: Node = ZoneManager.get_loaded_zone()
		if not bonus_parent:
			bonus_parent = get_tree().current_scene
		bonus_parent.call_deferred("add_child", bonus)


func highlight() -> void:
	if is_instance_valid(_disc_mat):
		var current_alpha: float = _disc_mat.albedo_color.a
		_disc_mat.albedo_color = Color(0.4, 0.7, 1.0, current_alpha)


func unhighlight() -> void:
	if is_instance_valid(_disc_mat):
		var current_alpha: float = _disc_mat.albedo_color.a
		_disc_mat.albedo_color = Color(WATER_COLOR.r, WATER_COLOR.g, WATER_COLOR.b, current_alpha)


func shake() -> void:
	if not is_instance_valid(_disc_instance):
		return
	var tween := create_tween()
	tween.tween_property(_disc_instance, "scale:x", 1.15, 0.07)
	tween.tween_property(_disc_instance, "scale:x", 0.9, 0.07)
	tween.tween_property(_disc_instance, "scale:x", 1.05, 0.06)
	tween.tween_property(_disc_instance, "scale:x", 1.0, 0.06)
