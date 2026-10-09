extends Node2D
## Three one-second poses, followed by a stationary pose and looping stream.

signal streaming_started

const POSES: Array[Texture2D] = [
	preload("res://Assets/caracter/lizard_girl/puke/呕吐1.png"),
	preload("res://Assets/caracter/lizard_girl/puke/呕吐2 .png"),
	preload("res://Assets/caracter/lizard_girl/puke/呕吐3.png"),
	preload("res://Assets/caracter/lizard_girl/puke/呕吐中.png"),
]
const STREAM: Array[Texture2D] = [
	preload("res://Assets/caracter/lizard_girl/puke/呕吐物1.png"),
	preload("res://Assets/caracter/lizard_girl/puke/呕吐物2.png"),
]
const POSE_SECONDS := 1.0
const SHAKE_SECONDS := 0.12
const STREAM_SECONDS := 0.15
const FOREGROUND_Z_INDEX := 100
# Align the puke artwork's visible body center and feet with the standing atlas.
const POSE_OFFSET := Vector2(-21.0, -3.0)
# Coordinates in the original 200 x 280 artwork, before centering/offset.
const MOUTH := Vector2(123.0, 65.0)
const STREAM_TIP := Vector2(120.0, 67.0)
const STREAM_END_Y := 270.0

var wall_x := 379.0 # Right inner wall, in elevator coordinates.
var _character: AnimatedSprite2D
var _stream: Sprite2D
var _elapsed := 0.0
var _pose := -1
var _home: Vector2
var _saved_frames: SpriteFrames
var _saved_animation: StringName
var _saved_frame: int
var _saved_progress: float
var _saved_playing: bool
var _saved_offset: Vector2
var _saved_flip: bool
var _saved_z_index: int
var _saved_z_as_relative: bool


func _ready() -> void:
	set_process(false)
	z_index = FOREGROUND_Z_INDEX
	_stream = Sprite2D.new()
	_stream.centered = false
	_stream.offset = -STREAM_TIP
	_stream.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Use absolute layers so different parent hierarchies cannot reverse the order.
	_stream.z_as_relative = false
	_stream.z_index = FOREGROUND_Z_INDEX + 1
	_stream.hide()
	add_child(_stream)


func play(character: AnimatedSprite2D) -> void:
	stop()
	_character = character
	_home = character.position
	_saved_frames = character.sprite_frames
	_saved_animation = character.animation
	_saved_frame = character.frame
	_saved_progress = character.frame_progress
	_saved_playing = character.is_playing()
	_saved_offset = character.offset
	_saved_flip = character.flip_h
	_saved_z_index = character.z_index
	_saved_z_as_relative = character.z_as_relative
	var frames := SpriteFrames.new()
	for texture in POSES:
		frames.add_frame(&"default", texture)
	character.stop()
	character.sprite_frames = frames
	character.animation = &"default"
	character.flip_h = false
	character.z_index = FOREGROUND_Z_INDEX
	character.z_as_relative = false
	character.offset = _saved_offset + POSE_OFFSET
	character.frame = 0
	_elapsed = 0.0
	_pose = 0
	set_process(true)


func _process(delta: float) -> void:
	if not is_instance_valid(_character):
		_stream.hide()
		set_process(false)
		return
	_elapsed += delta
	var next_pose := mini(int(_elapsed / POSE_SECONDS), 3)
	_character.position = _home
	if next_pose < 3:
		var phase := fmod(_elapsed, POSE_SECONDS)
		if phase >= POSE_SECONDS - SHAKE_SECONDS:
			var shake_phase := (phase - (POSE_SECONDS - SHAKE_SECONDS)) / SHAKE_SECONDS
			_character.position += Vector2(sin(shake_phase * TAU * 2.0) * 1.5, 0.0)
	if next_pose != _pose:
		_pose = next_pose
		_character.frame = _pose
		if _pose == 3:
			streaming_started.emit()
	if _pose == 3:
		_update_stream()


func _update_stream() -> void:
	var mouth_local := MOUTH - POSES[3].get_size() * 0.5 + _character.offset
	var mouth := to_local(_character.to_global(mouth_local))
	var distance := maxf(wall_x - mouth.x, 0.0)
	_stream.texture = STREAM[int((_elapsed - 3.0 * POSE_SECONDS) / STREAM_SECONDS) % 2]
	_stream.position = mouth
	# The source points down; a clockwise-facing quarter turn points at the wall.
	_stream.rotation = -PI / 2.0
	_stream.scale = Vector2(absf(_character.scale.x), distance / (STREAM_END_Y - STREAM_TIP.y))
	_stream.visible = distance > 0.0


func stop() -> void:
	set_process(false)
	if is_instance_valid(_stream):
		_stream.hide()
	if is_instance_valid(_character):
		_character.position = _home
		_character.sprite_frames = _saved_frames
		_character.animation = _saved_animation
		_character.offset = _saved_offset
		_character.flip_h = _saved_flip
		_character.z_index = _saved_z_index
		_character.z_as_relative = _saved_z_as_relative
		_character.set_frame_and_progress(_saved_frame, _saved_progress)
		if _saved_playing:
			_character.play()
	_character = null
