extends Node2D

signal anchor_finished

const SCREEN_CENTER := Vector2(320, 180)
const REVERB_BUS := "StartReverb"
const VOMIT_FX := preload("res://Stories/Effects/vomit_fx.gd")
const MUTATION_FX := preload("res://Stories/Effects/mutation_fx.gd")

@export var start_scale := 0.55     # 开场时电梯的初始大小（中等）
@export var black_hold := 0.6       # 开场纯黑停留时间（秒）
@export var zoom_duration := 4.0    # 电梯放大到 100% 的时长（秒）
@export var floor_from := 32        # 楼层数字起点
@export var floor_to := 16          # 楼层数字终点
@export var door_delay := 0.2       # 到达声播完到开门的停顿（秒）
@export var door_duration := 1.8    # 开门时长（秒）
@export var door_slide := 92.0      # 每扇门向外滑开的距离（像素）
@export var floor_fade_duration := 2.2  # 开门时地板浮现的时长（秒）
@export var shafts_intensity := 0.1  # 门内光束的最终强度（0 = 关闭）
@export var reverb_wet := 0.12      # 场景回声的湿度（0 = 完全关闭）
@export var play_intro_on_ready := true  # 特效预览可关闭开场，直接显示就绪状态
@export var departure_duration := 2.4
@export var departure_camera_zoom := 1.08
@export var travel_speed := 28.0  # 井壁向上滚动的速度（像素/秒）

@onready var _elevator: Node2D = $Elevator
@onready var _left_door: Sprite2D = $Elevator/ElevatorLeftDoor
@onready var _right_door: Sprite2D = $Elevator/ElevatorRightDoor
@onready var _floor_label: Label = $Elevator/FloorDisplay/Label
@onready var _floor: ColorRect = $Floor
@onready var _shafts: ColorRect = $Elevator/LightShafts
@onready var _sfx_arrive: AudioStreamPlayer = $SfxArrive
@onready var _sfx_door_move: AudioStreamPlayer = $SfxDoorMove
@onready var _sfx_clank: AudioStreamPlayer = $SfxClank
@onready var _breakdown_fx: ElevatorBreakdownFX = $Elevator/ElevatorBreakdownFX

var _left_door_x: float
var _right_door_x: float
var _vomit_fx: Node2D
var _mutation_fx: Node


func _ready() -> void:
	_vomit_fx = VOMIT_FX.new()
	_vomit_fx.name = "VomitFX"
	_elevator.add_child(_vomit_fx)
	_mutation_fx = MUTATION_FX.new()
	_mutation_fx.name = "MutationFX"
	_elevator.add_child(_mutation_fx)
	_left_door_x = _left_door.position.x
	_right_door_x = _right_door.position.x

	# 门在编辑器里可能被隐藏着预览，运行时必须从关闭状态出现
	_left_door.show()
	_right_door.show()

	_setup_reverb()
	_floor_label.text = str(floor_from)
	if play_intro_on_ready:
		_set_zoom(start_scale)
		_elevator.modulate = Color.BLACK
		_floor.material.set_shader_parameter("fade", 0.0)
		_set_door_progress(0.0)
		_run_intro()
	else:
		_set_zoom(1.0)
		_elevator.modulate = Color.WHITE
		_floor_label.text = str(floor_to)
		_floor.material.set_shader_parameter("fade", 1.0)
		_set_door_progress(1.0)
		anchor_finished.emit.call_deferred()


func _exit_tree() -> void:
	var idx := AudioServer.get_bus_index(REVERB_BUS)
	if idx != -1:
		AudioServer.remove_bus(idx)


func _run_intro() -> void:
	# 下降：黑场后电梯放大、由黑转亮，楼层数字同步倒数
	var descend := create_tween()
	descend.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	descend.tween_interval(black_hold)
	descend.tween_method(_set_zoom, start_scale, 1.0, zoom_duration)
	descend.parallel().tween_property(_elevator, "modulate", Color.WHITE, zoom_duration)
	descend.parallel().tween_method(
		_set_floor_number, float(floor_from), float(floor_to), zoom_duration
	)
	await descend.finished

	# 到达：叮一声，地板随之浮现，播完再开门
	_sfx_arrive.play()
	var reveal := create_tween()
	reveal.tween_property(_floor.material, "shader_parameter/fade", 1.0, floor_fade_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _sfx_arrive.finished
	await get_tree().create_timer(door_delay).timeout

	# 开门：门内光束随门缝亮起
	_sfx_door_move.play()
	var open := create_tween()
	open.tween_method(_set_door_progress, 0.0, 1.0, door_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await open.finished

	# 门到位：哐当
	_sfx_door_move.stop()
	_sfx_clank.play()
	anchor_finished.emit()


# 建一个只给本场景音效用的回声总线，不动 Master
func _setup_reverb() -> void:
	if reverb_wet <= 0.0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, REVERB_BUS)
	AudioServer.set_bus_send(idx, &"Master")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.55
	reverb.damping = 0.7
	reverb.wet = reverb_wet
	reverb.dry = 1.0
	AudioServer.add_bus_effect(idx, reverb)
	for player: AudioStreamPlayer in [_sfx_arrive, _sfx_door_move, _sfx_clank]:
		player.bus = REVERB_BUS


# 围绕屏幕中心缩放整个电梯
func _set_zoom(s: float) -> void:
	_elevator.scale = Vector2(s, s)
	_elevator.position = SCREEN_CENTER * (1.0 - s)


func _set_floor_number(value: float) -> void:
	_floor_label.text = str(roundi(value))


# 同步驱动门的位置和门内光束强度，t: 0 = 关死, 1 = 全开
func _set_door_progress(t: float) -> void:
	_left_door.position.x = _left_door_x - door_slide * t
	_right_door.position.x = _right_door_x + door_slide * t
	_shafts.material.set_shader_parameter("intensity", shafts_intensity * t)


func play_sparks() -> void:
	await _breakdown_fx.play_sparks()


func play_vomit() -> void:
	_vomit_fx.play($Elevator/NPCs/NPC0)
	await _vomit_fx.streaming_started


func stop_vomit() -> void:
	_vomit_fx.stop()


func play_mutation(character: AnimatedSprite2D = null) -> void:
	if character == null:
		character = $Elevator/NPCs/NPC0
	await _mutation_fx.play(character)


func stop_mutation() -> void:
	_mutation_fx.stop()


## Reserved for the male cheer pose. Add the future texture animation here.
func play_cheer(character: AnimatedSprite2D = null) -> void:
	if character == null:
		character = $Elevator/NPCs/NPC1
	# Keep the current pose until the cheer artwork is available.
	await get_tree().process_frame


func play_breakdown() -> void:
	# Shake the whole elevator while sparks burst, then enter the fast drop.
	_breakdown_fx.play_sparks()
	var home := _elevator.position
	var shake := create_tween()
	for index in 8:
		var direction := -1.0 if index % 2 == 0 else 1.0
		shake.tween_property(
			_elevator,
			"position",
			home + Vector2(direction * 2.5, 0.0),
			0.045,
		)
	shake.tween_property(_elevator, "position", home, 0.045)
	await shake.finished
	_elevator.position = home
	await _breakdown_fx.play_drop()


func eject_character(character: AnimatedSprite2D, duration := 0.7) -> void:
	if not is_instance_valid(character):
		return
	character.z_index = 110
	var flight := create_tween().set_parallel(true)
	flight.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_property(
		character,
		"position",
		character.position + Vector2(360.0, -260.0),
		duration,
	)
	flight.tween_property(character, "rotation", character.rotation + TAU, duration)
	await flight.finished
	character.hide()


func close_doors() -> void:
	_sfx_door_move.play()
	var closing := create_tween()
	closing.tween_method(_set_door_progress, 1.0, 0.0, door_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await closing.finished
	_sfx_door_move.stop()
	_sfx_clank.play()


func wait_for_opening_sound() -> void:
	if _sfx_clank.playing:
		await _sfx_clank.finished


func start_descent() -> void:
	await _breakdown_fx.start_descent(departure_duration, travel_speed)


func play_shock(character_index := 0) -> void:
	var characters := _breakdown_fx._characters()
	if character_index >= 0 and character_index < characters.size():
		await _breakdown_fx.play_shock(characters[character_index])


func start_smoke() -> void:
	_breakdown_fx.start_smoke()


func stop_smoke() -> void:
	_breakdown_fx.stop_smoke()


func preview_smoke() -> void:
	await _breakdown_fx.preview_smoke()


func play_drop(duration := 1.05) -> void:
	await _breakdown_fx.play_drop(duration)
