extends Node2D

const START_SCENE := preload("res://Stories/Start/start.tscn")
const MIDDLE_SCENE := preload("res://Stories/Middle/middle.tscn")
const END_SCENE := preload("res://Stories/End/end.tscn")

@onready var _anchor_host: Node2D = $AnchorHost
@onready var _status: Label = $TestUI/Status

var _current_anchor: Node
var _dialogue_test_running := false


func _ready() -> void:
	_status.text = "请选择测试内容"


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

	await Dialogue.entree(
		Dialogue.Character.NPC0,
		Dialogue.ExpressionState.SPEAKING,
		"你是傻逼么",
	)

	await Dialogue.entree(
		Dialogue.Character.NPC1,
		Dialogue.ExpressionState.SPEAKING,
		"嗯，我是傻逼，",
	)

	var selected := await Dialogue.entree(
		Dialogue.Character.NARRATOR,
		Dialogue.ExpressionState.NORMAL,
		"谁是傻逼",
		["女的", "男的"],
	)

	var answer := "女的" if selected == 0 else "男的"
	_status.text = "对话测试完成，选择：%s（可继续按 1～4）" % answer
	_dialogue_test_running = false
