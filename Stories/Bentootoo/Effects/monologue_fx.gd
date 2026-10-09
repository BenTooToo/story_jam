extends Node2D
class_name MonologueFX

signal started
signal stopped

const MONOLOGUE_LIGHT_MASK := 1 << 1

@export var head_offset := Vector2(0.0, -10.0)
@export var beam_end_offset := Vector2(0.0, 65.0)
@export_range(0.0, 4.0, 0.05) var light_energy := 1.55
@export_range(0.0, 2.0, 0.01) var beam_intensity := 0.18
@export var darkness := Color(0.025, 0.025, 0.035, 1.0)

@export_category("Audio")
@export var light_on_sound: AudioStream
@export var light_off_sound: AudioStream
@export_range(-80.0, 6.0, 0.5) var sound_volume_db := 0.0

@onready var _world_blackout: CanvasModulate = $WorldBlackout
@onready var _actor_light: PointLight2D = $ActorLight
@onready var _beam: ColorRect = $BeamLayer/Beam
@onready var _switch_sound: AudioStreamPlayer = $SwitchSound

var _target: Node2D
var _target_original_light_mask := 1
var _active := false


func _ready() -> void:
	_actor_light.enabled = false
	_actor_light.energy = 0.0
	_beam.hide()
	_set_beam_intensity(0.0)
	_switch_sound.volume_db = sound_volume_db


func _process(_delta: float) -> void:
	_update_target_position()


## Instantly darkens the world and puts a theatrical spotlight on [param target].
func start_monologue(target: Node2D) -> void:
	if not is_instance_valid(target):
		push_warning("MonologueFX.start_monologue() received an invalid target.")
		return

	# 先让开关声起音，再切换灯光画面。
	_play_switch_sound(light_on_sound)
	_restore_target_light_mask()
	_target = target
	_target_original_light_mask = target.light_mask
	target.light_mask = MONOLOGUE_LIGHT_MASK
	_active = true

	_actor_light.enabled = true
	_beam.show()
	_update_target_position()
	_world_blackout.color = darkness
	_actor_light.energy = light_energy
	_set_beam_intensity(beam_intensity)
	started.emit()


## Instantly restores the normal scene lighting and target light mask.
func stop_monologue() -> void:
	if not _active:
		return

	_play_switch_sound(light_off_sound)
	_world_blackout.color = Color.WHITE
	_actor_light.energy = 0.0
	_actor_light.enabled = false
	_set_beam_intensity(0.0)
	_beam.hide()
	_restore_target_light_mask()
	_target = null
	_active = false
	stopped.emit()


## Clears the effect without a transition. Useful before changing scenes.
func reset_immediately() -> void:
	_switch_sound.stop()
	_world_blackout.color = Color.WHITE
	_actor_light.energy = 0.0
	_actor_light.enabled = false
	_set_beam_intensity(0.0)
	_beam.hide()
	_restore_target_light_mask()
	_target = null
	_active = false


func is_active() -> bool:
	return _active


func _update_target_position() -> void:
	if not is_instance_valid(_target):
		return

	var light_world := _target.global_position + head_offset
	var beam_end_world := _target.global_position + beam_end_offset
	_actor_light.global_position = light_world

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var beam_end_screen := get_viewport().get_canvas_transform() * beam_end_world
	_beam.material.set_shader_parameter(
		"target_uv",
		beam_end_screen / viewport_size,
	)


func _restore_target_light_mask() -> void:
	if is_instance_valid(_target):
		_target.light_mask = _target_original_light_mask


func _set_beam_intensity(value: float) -> void:
	_beam.material.set_shader_parameter("intensity", value)


func _play_switch_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	_switch_sound.stream = stream
	_switch_sound.play()
