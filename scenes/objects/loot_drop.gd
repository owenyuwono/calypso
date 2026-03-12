extends StaticBody3D
## A clickable loot drop that spawns when a monster dies.
## Player clicks to walk to it and pick up the loot.

const ModelHelper = preload("res://scripts/utils/model_helper.gd")
const ItemDatabase = preload("res://scripts/data/item_database.gd")

var loot_id: String = ""
var entity_id: String = ""
var item_id: String = ""
var item_count: int = 1
var gold_amount: int = 0

var _overlay: StandardMaterial3D
var _despawn_timer: float = 120.0
var _visual: MeshInstance3D
var _label: Label3D

func _ready() -> void:
	if loot_id.is_empty():
		loot_id = "loot_%d" % get_instance_id()
	entity_id = loot_id

	_build_visual()
	_build_label()
	_start_bob()

	# Register with WorldState so raycasts can identify us
	var display_name := _get_display_name()
	WorldState.register_entity(loot_id, self, {
		"type": "loot_drop",
		"name": display_name,
	})

func _build_visual() -> void:
	_visual = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	_visual.mesh = box
	_visual.position.y = 0.3

	var mat := StandardMaterial3D.new()
	if gold_amount > 0:
		mat.albedo_color = Color(1.0, 0.85, 0.2)
	else:
		var item_data := ItemDatabase.get_item(item_id)
		var item_type: String = item_data.get("type", "material")
		match item_type:
			"consumable":
				mat.albedo_color = Color(0.3, 0.9, 0.3)
			"weapon":
				mat.albedo_color = Color(0.7, 0.7, 0.8)
			"armor":
				mat.albedo_color = Color(0.5, 0.6, 0.8)
			_:
				mat.albedo_color = Color(0.8, 0.7, 0.4)
	_visual.set_surface_override_material(0, mat)

	add_child(_visual)

	# Overlay for highlight
	_overlay = ModelHelper.create_overlay_material()
	_visual.material_overlay = _overlay

	# Collision
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.4, 0.4)
	col.shape = shape
	col.position.y = 0.3
	add_child(col)

func _build_label() -> void:
	_label = Label3D.new()
	_label.text = _get_display_name()
	_label.font_size = 32
	_label.pixel_size = 0.01
	_label.position = Vector3(0, 0.7, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = Color(1, 1, 0.8)
	add_child(_label)

func _get_display_name() -> String:
	if gold_amount > 0:
		return "%d Gold" % gold_amount
	return ItemDatabase.get_item_name(item_id)

func _start_bob() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_visual, "position:y", 0.5, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_visual, "position:y", 0.3, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _process(delta: float) -> void:
	_despawn_timer -= delta
	if _despawn_timer <= 0.0:
		_despawn()

func pickup(entity_id: String) -> void:
	var entity = WorldState.get_entity(entity_id)
	var inv = entity.get_node_or_null("InventoryComponent") if entity else null
	if gold_amount > 0:
		if inv:
			inv.add_gold_amount(gold_amount)
		GameEvents.item_looted.emit(entity_id, "gold", gold_amount)
	if not item_id.is_empty():
		if inv:
			inv.add_item(item_id, item_count)
		GameEvents.item_looted.emit(entity_id, item_id, item_count)
	WorldState.unregister_entity(loot_id)
	queue_free()

func _despawn() -> void:
	# Fade out then free
	if _visual:
		var mat = _visual.get_surface_override_material(0)
		if mat:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var tween := create_tween()
			tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
			tween.parallel().tween_property(_label, "modulate:a", 0.0, 0.5)
			tween.tween_callback(_cleanup)
			return
	_cleanup()

func _cleanup() -> void:
	WorldState.unregister_entity(loot_id)
	queue_free()

func highlight() -> void:
	ModelHelper.set_highlight(_overlay, true)

func unhighlight() -> void:
	ModelHelper.set_highlight(_overlay, false)
