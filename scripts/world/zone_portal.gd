extends Area3D
## Area3D trigger that fires a ZoneManager transition when the player walks through.
## Instantiated and configured at runtime by ZoneManager via setup().

var target_zone: String = ""
var target_spawn: Vector3 = Vector3.ZERO

func setup(portal_def: Dictionary) -> void:
	target_zone = portal_def["target"]
	target_spawn = portal_def["target_spawn"]

	# Create collision shape from source_rect
	var rect: Rect2 = portal_def["source_rect"]
	var shape: BoxShape3D = BoxShape3D.new()
	# rect is in XZ plane: rect.position.x/y map to world X/Z
	shape.size = Vector3(rect.size.x, 4.0, rect.size.y)  # 4m tall trigger

	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	add_child(col)

	# Position at center of rect, vertically centered on the 4m trigger height
	global_position = Vector3(
		rect.position.x + rect.size.x / 2.0,
		2.0,  # center of 4m height
		rect.position.y + rect.size.y / 2.0
	)

	# Detect bodies on layer 1 (physics/player) only; this Area3D emits no layer
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if "entity_id" in body and body.entity_id == "player":
		if not ZoneManager.is_transitioning():
			ZoneManager.load_zone(target_zone, target_spawn)
