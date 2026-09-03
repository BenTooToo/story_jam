extends Node2D

const CAMERA_HOME := Vector2(320.0, 180.0)
const CAMERA_CHARACTER_OFFSET := Vector2(0.0, -30.0)
const CAMERA_CHARACTER_ZOOM := 1.35
const START_SCENE := preload("res://Stories/Start/start.tscn")
const MIDDLE_SCENE := preload("res://Stories/Middle/middle.tscn")
const END_SCENE := preload("res://Stories/End/end.tscn")

@export var show_status := false
@export_range(1.0, 30.0, 0.5) var camera_follow_speed := 10.0

@onready var _camera: Camera2D = $Camera2D
@onready var _anchor_host: Node2D = $AnchorHost
@onready var _status: Label = $TestUI/Status

var _current_anchor: Node
var _dialogue_test_running := false
var _camera_tween: Tween
var _camera_follow_target: Node2D
var _camera_follow_offset := CAMERA_CHARACTER_OFFSET
var _camera_follow_zoom := CAMERA_CHARACTER_ZOOM
var _choice_camera_targets: Array[Node2D] = []


func _ready() -> void:
	_status.text = "请选择测试内容"
	_status.visible = show_status
	Dialogue.choice_focused.connect(_on_dialogue_choice_focused)


func _process(delta: float) -> void:
	if not is_instance_valid(_camera_follow_target):
		_camera_follow_target = null
		return

	var follow_weight := 1.0 - exp(-camera_follow_speed * delta)
	var target_position := _camera_follow_target.global_position + _camera_follow_offset
	var target_zoom := Vector2.ONE * _camera_follow_zoom
	_camera.global_position = _camera.global_position.lerp(target_position, follow_weight)
	_camera.zoom = _camera.zoom.lerp(target_zoom, follow_weight)


func follow_camera(
	target: Node2D,
	zoom_amount: float = CAMERA_CHARACTER_ZOOM,
	offset: Vector2 = CAMERA_CHARACTER_OFFSET,
) -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_follow_target = target
	_camera_follow_zoom = maxf(zoom_amount, 0.01)
	_camera_follow_offset = offset


func move_camera(
	target_position: Vector2,
	zoom_amount: float = 1.0,
	duration: float = 0.5,
) -> Tween:
	_camera_follow_target = null
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()

	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.set_trans(Tween.TRANS_SINE)
	_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(
		_camera,
		"global_position",
		target_position,
		duration,
	)
	_camera_tween.tween_property(
		_camera,
		"zoom",
		Vector2.ONE * maxf(zoom_amount, 0.01),
		duration,
	)
	return _camera_tween


func reset_camera(duration: float = 0.5) -> Tween:
	return move_camera(CAMERA_HOME, 1.0, duration)


func _on_dialogue_choice_focused(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= _choice_camera_targets.size():
		return
	var target := _choice_camera_targets[choice_index]
	if is_instance_valid(target):
		follow_camera(target)


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_test_running:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_1:
			get_viewport().set_input_as_handled()
			_play_anchor(START_SCENE, "正在播放：开场锚点")
		KEY_2:
			get_viewport().set_input_as_handled()
			_play_anchor(MIDDLE_SCENE, "正在播放：中间锚点")
		KEY_3:
			get_viewport().set_input_as_handled()
			_play_anchor(END_SCENE, "正在播放：结尾锚点")
		KEY_4:
			get_viewport().set_input_as_handled()
			_run_dialogue_test()


func _play_anchor(scene: PackedScene, status_text: String) -> Node:
	_clear_anchor()
	_current_anchor = scene.instantiate()
	_anchor_host.add_child(_current_anchor)
	_status.text = status_text
	return _current_anchor


func _clear_anchor() -> void:
	if not is_instance_valid(_current_anchor):
		return
	_anchor_host.remove_child(_current_anchor)
	_current_anchor.queue_free()
	_current_anchor = null


func _run_dialogue_test() -> void:
	_dialogue_test_running = true
	var opening := _play_anchor(
		START_SCENE,
		"对话测试：等待开场动画与电梯门打开……",
	)

	await opening.anchor_finished
	_status.text = "对话测试进行中"
	var npc0: Node2D = opening.get_node("Elevator/NPCs/NPC0")
	var npc1: Node2D = opening.get_node("Elevator/NPCs/NPC1")

	follow_camera(npc0)
	await Dialogue.entree(
		Dialogue.Character.NPC0,
		Dialogue.ExpressionState.SPEAKING,
		"哈基米，南北绿豆，东边一勺西边一兜，电梯门口转三圈，十六层里点点头；等我把这段唱完，我来问你一个非常重要的大事，非常重要。",
	)
	await Dialogue.entree(
		Dialogue.Character.NPC0,
		Dialogue.ExpressionState.SPEAKING,
		"你是傻福么",
	)

	follow_camera(npc1)
	await Dialogue.entree(
		Dialogue.Character.NPC1,
		Dialogue.ExpressionState.SPEAKING,
		"嗯，我是傻福，",
	)

	reset_camera()
	_choice_camera_targets.clear()
	_choice_camera_targets.append(npc0)
	_choice_camera_targets.append(npc1)
	var selected := await Dialogue.entree(
		Dialogue.Character.NARRATOR,
		Dialogue.ExpressionState.NORMAL,
		"谁是傻福",
		["女的", "男的"],
	)
	_choice_camera_targets.clear()

	follow_camera(npc0)
	if selected == 1:
		await Dialogue.entree(
			Dialogue.Character.NPC0,
			Dialogue.ExpressionState.SPEAKING,
			"不错嘛，[rainbow freq=1.0 sat=0.8 val=0.8 speed=1.0][shake rate=20 level=4]你还蛮聪明的[/shake][/rainbow]。",
		)
	else:

		await Dialogue.entree(
			Dialogue.Character.NPC0,
			Dialogue.ExpressionState.SPEAKING,
			"原来[rainbow freq=1.0 sat=0.8 val=0.8 speed=1.0][shake rate=20 level=4]傻福是你啊[/shake][/rainbow]。",
		)

	var answer := "女的" if selected == 0 else "男的"
	_status.text = "对话测试完成，选择：%s（可继续按 1～4）" % answer
	reset_camera()
	_dialogue_test_running = false
