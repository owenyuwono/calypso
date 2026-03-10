extends Node3D
## Floating damage number that rises and fades out.

var _label: Label3D

func _ready() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.01
	_label.font_size = 64
	_label.outline_size = 6
	_label.modulate = Color(1, 1, 1, 1)
	_label.outline_modulate = Color(0, 0, 0, 1)
	_label.no_depth_test = true
	add_child(_label)

func setup(damage: int, color: Color = Color(1, 1, 1)) -> void:
	_label.text = str(damage)
	_label.modulate = color

	# Random horizontal offset
	position.x += randf_range(-0.3, 0.3)
	position.z += randf_range(-0.3, 0.3)

	# Animate: float up and fade out
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 1.5, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(_label, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tween.chain().tween_callback(queue_free)
