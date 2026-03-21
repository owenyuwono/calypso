extends Node3D
## Floating damage number that arcs up then falls down like a fountain.

var _label: Label3D
var _time: float = 0.0
var _drift: Vector3 = Vector3.ZERO
var _start_pos: Vector3 = Vector3.ZERO
var _duration: float = 1.0
var _rise_time: float = 0.2
var _jump_height: float = 1.5
var _fall_depth: float = 0.5
const DRIFT_DISTANCE := 2.0

# Styled system
const HIT_STYLES: Dictionary = {
	"normal":  {"color": Color(1, 1, 1),         "outline": Color(0, 0, 0),       "size": 64, "duration": 1.0},
	"crit":    {"color": Color(1, 0.85, 0.0),    "outline": Color(0.8, 0.2, 0.0), "size": 96, "duration": 1.5},
	"weak":    {"color": Color(1, 0.55, 0.1),    "outline": Color(0, 0, 0),       "size": 72, "duration": 1.0},
	"fatal":   {"color": Color(1, 0.15, 0.0),    "outline": Color(1, 0.8, 0.0),   "size": 96, "duration": 1.5},
	"resist":  {"color": Color(0.55, 0.65, 0.8), "outline": Color(0, 0, 0),       "size": 44, "duration": 0.8},
	"immune":  {"color": Color(0.35, 0.35, 0.4), "outline": Color(0, 0, 0),       "size": 44, "duration": 0.6},
	"miss":    {"color": Color(0.5, 0.5, 0.5),   "outline": Color(0, 0, 0),       "size": 40, "duration": 0.5},
}

const FX_TEXTURES: Dictionary = {
	"starburst_gold": "res://assets/textures/ui/fx/starburst_gold.png",
	"starburst_red":  "res://assets/textures/ui/fx/starburst_red.png",
	"sparks":         "res://assets/textures/ui/fx/sparks.png",
	"chevron_up":     "res://assets/textures/ui/fx/chevron_up.png",
	"chevron_down":   "res://assets/textures/ui/fx/chevron_down.png",
	"shield_flash":   "res://assets/textures/ui/fx/shield_flash.png",
	"ring_flash":     "res://assets/textures/ui/fx/ring_flash.png",
}

var _style: String = "normal"
var _is_wobble: bool = false
var _wobble_time: float = 0.0

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

func setup(damage: int, color: Color = Color(1, 1, 1), direction: Vector3 = Vector3.ZERO) -> void:
	_label.text = str(damage)
	_label.modulate = color
	_duration = 1.0
	_rise_time = 0.2
	_jump_height = 1.5
	_fall_depth = 0.5
	_start_pos = position
	_setup_drift(direction)

func setup_text(text: String, color: Color = Color(1, 1, 1), direction: Vector3 = Vector3.ZERO) -> void:
	_label.text = text
	_label.modulate = color
	_duration = 1.0
	_rise_time = 0.2
	_jump_height = 1.5
	_fall_depth = 0.5
	_start_pos = position
	_setup_drift(direction)

func setup_styled(damage: int, hit_type: String, is_crit: bool, direction: Vector3) -> void:
	# Determine effective style
	if hit_type == "miss":
		_style = "miss"
	elif hit_type == "immune":
		_style = "immune"
	elif is_crit and (hit_type == "normal" or hit_type == "weak"):
		_style = "crit"
	elif hit_type == "fatal" or (is_crit and hit_type == "fatal"):
		_style = "fatal"
	else:
		_style = hit_type

	var style: Dictionary = HIT_STYLES.get(_style, HIT_STYLES["normal"])

	# Set text
	if _style == "miss":
		_label.text = "MISS"
	elif _style == "immune":
		_label.text = "IMMUNE"
	elif _style == "crit":
		_label.text = str(damage) + "!"
	elif _style == "fatal":
		_label.text = str(damage) + "!!"
	else:
		_label.text = str(damage)

	# Apply label style (Label3D uses direct properties, not theme overrides)
	_label.font_size = style["size"]
	_label.modulate = style["color"]
	_label.outline_modulate = style["outline"]
	_label.outline_size = 6 if _style in ["crit", "fatal"] else 4

	# Per-style motion parameters
	_duration = style["duration"]
	match _style:
		"resist":
			_rise_time = 0.15
			_jump_height = 0.8
			_fall_depth = 0.8
		"immune":
			_rise_time = 0.1
			_jump_height = 0.5
			_fall_depth = 0.5
		"miss":
			_rise_time = 0.1
			_jump_height = 0.4
			_fall_depth = 0.2
		"crit", "fatal":
			_rise_time = 0.25
			_jump_height = 2.0
			_fall_depth = 0.6
		_:
			_rise_time = 0.2
			_jump_height = 1.5
			_fall_depth = 0.5

	_start_pos = position

	# Add FX graphics before animating
	_add_fx_effects()

	# Pop-scale for crit/fatal
	if _style in ["crit", "fatal"]:
		scale = Vector3(2.0, 2.0, 2.0)
		var tween: Tween = create_tween()
		tween.tween_property(self, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Wobble for miss
	if _style == "miss":
		_is_wobble = true

	_setup_drift(direction)

func _add_fx_effects() -> void:
	match _style:
		"crit":
			_add_sprite_fx("starburst_gold", Vector3(0, 0, -0.01), 0.8, 0.3)
		"fatal":
			_add_sprite_fx("starburst_red", Vector3(0, 0, -0.01), 0.8, 0.3)
			_add_sprite_fx("sparks", Vector3(0, 0, -0.005), 0.5, 0.4)
			# Shake effect on label
			var tween: Tween = create_tween()
			tween.tween_property(_label, "position:x", 3.0, 0.05)
			tween.tween_property(_label, "position:x", -3.0, 0.05)
			tween.tween_property(_label, "position:x", 2.0, 0.05)
			tween.tween_property(_label, "position:x", 0.0, 0.05)
		"weak":
			_add_sprite_fx("chevron_up", Vector3(0.4, 0.1, 0), 0.25, -1.0)
		"resist":
			_add_sprite_fx("chevron_down", Vector3(0.4, -0.1, 0), 0.25, -1.0)

func _add_sprite_fx(texture_key: String, offset: Vector3, sprite_scale: float, fade_duration: float) -> void:
	var path: String = FX_TEXTURES.get(texture_key, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var sprite := Sprite3D.new()
	sprite.texture = load(path)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.transparent = true
	sprite.no_depth_test = true
	sprite.pixel_size = 0.01
	sprite.position = offset
	sprite.scale = Vector3.ONE * sprite_scale
	add_child(sprite)

	if fade_duration > 0:
		# Scale up and fade out
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "scale", Vector3.ONE * sprite_scale * 1.5, fade_duration)
		tween.tween_property(sprite, "modulate:a", 0.0, fade_duration)

func _setup_drift(direction: Vector3) -> void:
	# Compute drift direction (XZ plane) with slight randomness
	_drift = direction
	if _drift.length_squared() < 0.01:
		var angle := randf() * TAU
		_drift = Vector3(cos(angle), 0, sin(angle))
	_drift += Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
	_drift = _drift.normalized()

func _process(delta: float) -> void:
	if not _label:
		return
	_time += delta

	# Wobble for miss style
	if _is_wobble:
		_wobble_time += delta * 15.0
		_label.position.x = sin(_wobble_time) * 2.0

	# XZ drift: linear outward
	var t_total := clampf(_time / _duration, 0.0, 1.0)
	position.x = _start_pos.x + _drift.x * DRIFT_DISTANCE * t_total
	position.z = _start_pos.z + _drift.z * DRIFT_DISTANCE * t_total

	# Y: rise phase then fall phase
	if _time < _rise_time:
		# Rise: ease out (fast start, slow end)
		var t := _time / _rise_time
		position.y = _start_pos.y + _jump_height * (1.0 - (1.0 - t) * (1.0 - t))
	else:
		# Fall: ease in (slow start, fast end) — like gravity
		var t := clampf((_time - _rise_time) / (_duration - _rise_time), 0.0, 1.0)
		var peak_y := _start_pos.y + _jump_height
		var end_y := _start_pos.y - _fall_depth
		position.y = peak_y + (end_y - peak_y) * t * t

	# Fade out in the fall phase
	if _time > _rise_time:
		var fade_t := clampf((_time - _rise_time) / (_duration - _rise_time), 0.0, 1.0)
		_label.modulate.a = 1.0 - fade_t

	if _time >= _duration:
		queue_free()
