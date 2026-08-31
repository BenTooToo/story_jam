class_name JamStickFigure
extends Node2D
## 手绘风火柴人：用 _draw 画出来，支持奔跑 / 跳跃 / 投掷 / 眩晕 / 跳舞等姿势。
## 原点在脚底，蓝色 = 左边玩家，粉色 = 右边玩家。

enum Pose {
	IDLE,
	RUN,
	JUMP,
	THROW,
	STUNNED,
	DANCE_LEFT,
	DANCE_DOWN,
	DANCE_UP,
	DANCE_RIGHT,
	MISS,
	CHEER,
}

var color := Color(0.38, 0.58, 0.9)
var facing := 1
var pose: int = Pose.IDLE

var _time := 0.0
var _pose_hold := 0.0


func _process(delta: float) -> void:
	_time += delta
	if _pose_hold > 0.0:
		_pose_hold -= delta
		if _pose_hold <= 0.0 and pose != Pose.STUNNED:
			pose = Pose.IDLE
	queue_redraw()


## 摆一个临时姿势，hold 秒后自动回到 IDLE。
func strike(new_pose: int, hold := 0.35) -> void:
	pose = new_pose
	_pose_hold = hold


func set_stunned(on: bool) -> void:
	if on:
		pose = Pose.STUNNED
		_pose_hold = 0.0
	elif pose == Pose.STUNNED:
		pose = Pose.IDLE


## 根据移动状态自动选姿势；不打断临时姿势和眩晕。
func auto_pose(on_ground_now: bool, vx: float) -> void:
	if pose == Pose.STUNNED or _pose_hold > 0.0:
		return
	if not on_ground_now:
		pose = Pose.JUMP
	elif absf(vx) > 5.0:
		pose = Pose.RUN
	else:
		pose = Pose.IDLE


func _draw() -> void:
	var t := _time
	var offset := Vector2.ZERO
	var tilt := 0.0
	var squat := 0.0
	match pose:
		Pose.STUNNED:
			tilt = sin(t * 9.0) * 0.14
		Pose.DANCE_DOWN:
			squat = 7.0
		Pose.DANCE_LEFT:
			tilt = -0.12
		Pose.DANCE_RIGHT:
			tilt = 0.12
		Pose.CHEER:
			offset.y = -absf(sin(t * 7.0)) * 7.0
		Pose.MISS:
			offset.y = 2.0
	draw_set_transform(offset, tilt, Vector2.ONE)

	var hip := Vector2(0, -13 + squat)
	var neck := Vector2(0, -30 + squat)
	var shoulder := Vector2(0, -26 + squat)
	var head := Vector2(0, -37 + squat)
	if pose == Pose.IDLE:
		head.y += sin(t * 3.0) * 1.2

	# 腿
	var left_foot := Vector2(-5, 0)
	var right_foot := Vector2(5, 0)
	match pose:
		Pose.RUN:
			var swing := sin(t * 13.0) * 6.0
			left_foot = Vector2(-4 + swing, 0)
			right_foot = Vector2(4 - swing, 0)
		Pose.JUMP:
			left_foot = Vector2(-6, -6)
			right_foot = Vector2(6, -3)
		Pose.DANCE_UP, Pose.CHEER:
			left_foot = Vector2(-7, 0)
			right_foot = Vector2(7, 0)
		Pose.DANCE_LEFT:
			left_foot = Vector2(-9, 0)
			right_foot = Vector2(2, 0)
		Pose.DANCE_RIGHT:
			left_foot = Vector2(-2, 0)
			right_foot = Vector2(9, 0)
	_limb(hip, left_foot)
	_limb(hip, right_foot)
	_limb(hip, neck)

	# 手
	var left_hand := Vector2(-6, -17 + squat + sin(t * 3.0))
	var right_hand := Vector2(6, -17 + squat - sin(t * 3.0))
	match pose:
		Pose.RUN:
			var swing := sin(t * 13.0) * 5.0
			left_hand = Vector2(-5 - swing, -20 + squat)
			right_hand = Vector2(5 + swing, -20 + squat)
		Pose.JUMP:
			left_hand = Vector2(-8, -32)
			right_hand = Vector2(8, -32)
		Pose.THROW:
			left_hand = Vector2(-6 * facing, -18 + squat)
			right_hand = Vector2(14 * facing, -33 + squat)
		Pose.STUNNED, Pose.MISS:
			left_hand = Vector2(-4, -14 + squat)
			right_hand = Vector2(4, -14 + squat)
		Pose.DANCE_UP, Pose.CHEER:
			left_hand = Vector2(-9, -40 + squat)
			right_hand = Vector2(9, -40 + squat)
		Pose.DANCE_DOWN:
			left_hand = Vector2(-9, -8 + squat)
			right_hand = Vector2(9, -8 + squat)
		Pose.DANCE_LEFT:
			left_hand = Vector2(-15, -30 + squat)
			right_hand = Vector2(-13, -22 + squat)
		Pose.DANCE_RIGHT:
			left_hand = Vector2(13, -22 + squat)
			right_hand = Vector2(15, -30 + squat)
	_limb(shoulder, left_hand)
	_limb(shoulder, right_hand)

	draw_circle(head, 6.5, color)

	# 眩晕星星
	if pose == Pose.STUNNED:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for k in 3:
			var a := t * 4.0 + k * TAU / 3.0
			var star_pos := Vector2(cos(a) * 12.0, -46.0 + sin(a) * 3.0)
			_star(star_pos, 2.6, Color(1.0, 0.85, 0.3))


func _limb(from_point: Vector2, to_point: Vector2) -> void:
	draw_line(from_point, to_point, color, 2.4, true)


func _star(at: Vector2, r: float, c: Color) -> void:
	draw_line(at + Vector2(-r, 0), at + Vector2(r, 0), c, 1.5, true)
	draw_line(at + Vector2(0, -r), at + Vector2(0, r), c, 1.5, true)
	draw_line(at + Vector2(-r, -r) * 0.7, at + Vector2(r, r) * 0.7, c, 1.2, true)
	draw_line(at + Vector2(-r, r) * 0.7, at + Vector2(r, -r) * 0.7, c, 1.2, true)
