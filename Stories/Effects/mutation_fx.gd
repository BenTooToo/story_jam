extends Node
class_name MutationFX
## Plays the three transformation poses, then keeps the character in a breathing loop.

signal transformation_finished

const TRANSFORM_TEXTURES: Array[Texture2D] = [
	preload("res://Assets/caracter/lizard_girl/mutate/变异1.png"),
	preload("res://Assets/caracter/lizard_girl/mutate/变异2.png"),
	preload("res://Assets/caracter/lizard_girl/mutate/变异3.png"),
]
const BREATH_TEXTURE := preload("res://Assets/caracter/lizard_girl/trans_stand/呼吸.png")
const TRANSFORM_ANIMATION := &"transform"
const IDLE_ANIMATION := &"transformed_idle"
const FOREGROUND_Z_INDEX := 100
const TRANSFORM_FPS := 1.0
const IDLE_FPS := 2.0
const SHAKE_SECONDS := 0.12
const SHAKE_DISTANCE := 1.5

# Keep the torso on the original woman's horizontal axis. The growing tail is
# deliberately excluded from alignment because it extends the alpha bounds leftward.
# Vertical offsets align every pose by its feet.
const TRANSFORM_OFFSETS: Array[Vector2] = [
	Vector2(-23.0, -1.0),
	Vector2(-23.0, -4.0),
	Vector2(-23.0, -8.0),
]
const IDLE_OFFSET := Vector2(-23.0, -8.0)

var _character: AnimatedSprite2D
var _saved_frames: SpriteFrames
var _saved_animation: StringName
var _saved_frame := 0
var _saved_progress := 0.0
var _saved_playing := false
var _saved_offset := Vector2.ZERO
var _saved_flip := false
var _saved_z_index := 0
var _home := Vector2.ZERO


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if not is_instance_valid(_character):
		set_process(false)
		return
	_character.position = _home
	if _character.animation != TRANSFORM_ANIMATION:
		return
	var frame_seconds := 1.0 / TRANSFORM_FPS
	var shake_start := 1.0 - SHAKE_SECONDS / frame_seconds
	if _character.frame_progress >= shake_start:
		var shake_phase := (
			(_character.frame_progress - shake_start)
			/ (1.0 - shake_start)
		)
		_character.position.x += sin(shake_phase * TAU * 2.0) * SHAKE_DISTANCE


## Transforms [param character] and returns when the third pose has finished.
## The transformed breathing animation continues until [method stop] is called.
func play(character: AnimatedSprite2D) -> void:
	stop()
	if not is_instance_valid(character) or character.sprite_frames == null:
		push_warning("MutationFX.play() requires a valid AnimatedSprite2D.")
		return

	_character = character
	_saved_frames = character.sprite_frames
	_saved_animation = character.animation
	_saved_frame = character.frame
	_saved_progress = character.frame_progress
	_saved_playing = character.is_playing()
	_saved_offset = character.offset
	_saved_flip = character.flip_h
	_saved_z_index = character.z_index
	_home = character.position

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(TRANSFORM_ANIMATION)
	frames.set_animation_loop(TRANSFORM_ANIMATION, false)
	frames.set_animation_speed(TRANSFORM_ANIMATION, TRANSFORM_FPS)
	for texture in TRANSFORM_TEXTURES:
		frames.add_frame(TRANSFORM_ANIMATION, texture)
	frames.add_animation(IDLE_ANIMATION)
	frames.set_animation_loop(IDLE_ANIMATION, true)
	frames.set_animation_speed(IDLE_ANIMATION, IDLE_FPS)
	frames.add_frame(IDLE_ANIMATION, TRANSFORM_TEXTURES[2])
	frames.add_frame(IDLE_ANIMATION, BREATH_TEXTURE)

	character.stop()
	character.sprite_frames = frames
	character.flip_h = false
	character.z_index = FOREGROUND_Z_INDEX
	character.frame_changed.connect(_on_frame_changed)
	character.animation_finished.connect(_on_animation_finished)
	character.play(TRANSFORM_ANIMATION)
	_apply_frame_offset()
	set_process(true)
	await transformation_finished


## Restores the character state from before the transformation.
func stop() -> void:
	set_process(false)
	if not is_instance_valid(_character):
		_character = null
		return
	_disconnect_character_signals()
	_character.stop()
	_character.position = _home
	_character.sprite_frames = _saved_frames
	_character.animation = _saved_animation
	_character.offset = _saved_offset
	_character.flip_h = _saved_flip
	_character.z_index = _saved_z_index
	_character.set_frame_and_progress(_saved_frame, _saved_progress)
	if _saved_playing:
		_character.play()
	_character = null


func _on_frame_changed() -> void:
	_apply_frame_offset()


func _on_animation_finished() -> void:
	if not is_instance_valid(_character):
		return
	if _character.animation != TRANSFORM_ANIMATION:
		return
	_character.position = _home
	set_process(false)
	_character.play(IDLE_ANIMATION)
	_apply_frame_offset()
	transformation_finished.emit()


func _apply_frame_offset() -> void:
	if not is_instance_valid(_character):
		return
	if _character.animation == TRANSFORM_ANIMATION:
		var index := clampi(_character.frame, 0, TRANSFORM_OFFSETS.size() - 1)
		_character.offset = _saved_offset + TRANSFORM_OFFSETS[index]
	else:
		_character.offset = _saved_offset + IDLE_OFFSET


func _disconnect_character_signals() -> void:
	var frame_callable := Callable(self, "_on_frame_changed")
	var finished_callable := Callable(self, "_on_animation_finished")
	if _character.frame_changed.is_connected(frame_callable):
		_character.frame_changed.disconnect(frame_callable)
	if _character.animation_finished.is_connected(finished_callable):
		_character.animation_finished.disconnect(finished_callable)
