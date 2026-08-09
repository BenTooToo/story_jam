extends Node2D

const SCREEN_CENTER := Vector2(320, 180)

@export var start_scale := 0.01     # 开场时电梯的初始大小
@export var black_hold := 0.6       # 开场纯黑停留时间（秒）
@export var zoom_duration := 4.0    # 电梯放大到 100% 的时长（秒）
@export var floor_from := 20        # 楼层数字起点
@export var floor_to := 16          # 楼层数字终点
@export var door_delay := 0.6       # 放大结束到开门之间的停顿（秒）
@export var door_duration := 1.8    # 开门时长（秒）
@export var door_slide := 92.0      # 每扇门向外滑开的距离（像素）

@onready var _elevator: Node2D = $Elevator
@onready var _left_door: Sprite2D = $Elevator/ElevatorLeftDoor
@onready var _right_door: Sprite2D = $Elevator/ElevatorRightDoor
@onready var _floor_label: Label = $Elevator/FloorDisplay/Label


func _ready() -> void:
	_set_zoom(start_scale)
	_floor_label.text = str(floor_from)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(black_hold)
	tween.tween_method(_set_zoom, start_scale, 1.0, zoom_duration)
	tween.parallel().tween_method(
		_set_floor_number, float(floor_from), float(floor_to), zoom_duration
	)
	tween.tween_interval(door_delay)
	tween.tween_property(
		_left_door, "position:x", _left_door.position.x - door_slide, door_duration
	)
	tween.parallel().tween_property(
		_right_door, "position:x", _right_door.position.x + door_slide, door_duration
	)


# 围绕屏幕中心缩放整个电梯
func _set_zoom(s: float) -> void:
	_elevator.scale = Vector2(s, s)
	_elevator.position = SCREEN_CENTER * (1.0 - s)


func _set_floor_number(value: float) -> void:
	_floor_label.text = str(roundi(value))
