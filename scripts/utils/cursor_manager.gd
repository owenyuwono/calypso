extends RefCounted
## PNG-based fantasy cursor manager with contextual icons.
## Loads 512x512 source textures, resizes to 64x64 for in-game use (Godot max 256x256).

const CURSOR_SIZE: int = 64

var _cursors: Dictionary = {}

var _hotspots: Dictionary = {
	"default": Vector2(2, 2),
	"click": Vector2(6, 2),
	"attack": Vector2(2, 2),
	"talk": Vector2(32, 32),
	"woodcut": Vector2(32, 32),
}

var _current_type: String = ""

func _init() -> void:
	var names: Array = ["default", "click", "attack", "talk", "woodcut"]
	for cursor_name: String in names:
		var src: Texture2D = load("res://assets/textures/ui/cursors/cursor_%s.png" % cursor_name)
		var img: Image = src.get_image()
		img.resize(CURSOR_SIZE, CURSOR_SIZE, Image.INTERPOLATE_LANCZOS)
		_cursors[cursor_name] = ImageTexture.create_from_image(img)
	set_cursor("default")

func set_cursor(type: String) -> void:
	if type == _current_type:
		return
	_current_type = type
	var tex: Texture2D = _cursors.get(type, _cursors["default"])
	var hotspot: Vector2 = _hotspots.get(type, Vector2.ZERO)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, hotspot)

func press() -> void:
	pass

func release() -> void:
	pass

func reset() -> void:
	_current_type = ""
	set_cursor("default")

func cleanup() -> void:
	Input.set_custom_mouse_cursor(null)
	_cursors.clear()
	_current_type = ""
