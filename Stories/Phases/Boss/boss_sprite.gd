class_name JamBoss
extends Node2D
## 电梯怪兽显示：切 Assets/Branch/电梯.png（24 帧横排一行，每帧 400×350）。
##
## 帧的分配（量素材得到）：
## - 0/1/2 左手：张开 / 拳头 / 竖拇指；3/4/5 右手，同样三个、镜像
## - 6 本体静立（没脚）；7 本体站起（有脚）
## - 8→15 从蹲到站的弹起序列（8 最矮、嘴闭着；13 起长出脚）；16 和 15 一样
## - 17→23 带脚的晃动循环，当待机
##
## 原点在脚底中点。本体和两只手是三个 Sprite2D，手的位置由动画状态驱动。

const Art := preload("res://Stories/Phases/Shared/phase_art.gd")

const FRAME_W := 400.0
const FRAME_H := 350.0
const BODY_CENTER_X := 204.0     # 本体在帧里的横向中轴
## 每帧本体最底下那一行：有脚的帧是 349，没脚的是 343
const BODY_FOOT_ROW := {
	6: 343.0, 7: 349.0,
	8: 343.0, 9: 343.0, 10: 343.0, 11: 343.0, 12: 343.0, 13: 349.0, 14: 349.0, 15: 349.0, 16: 349.0,
	17: 349.0, 18: 349.0, 19: 349.0, 20: 349.0, 21: 349.0, 22: 349.0, 23: 349.0,
}
const BODY_W := 187.0            # 站起时本体内容宽
const BODY_H := 318.0            # 站起时本体内容高
const FOOT_SINK := 1.5           # 和人物一样，脚底沉进反光地板

const IDLE_FRAMES := [17, 18, 19, 20, 21, 22, 23]
const IDLE_FPS := 7.0
const RISE_FRAMES := [8, 9, 10, 11, 12, 13, 14, 15]   # 蹲 -> 站；倒着放就是砸下去

enum Hand { OPEN, FIST, THUMB }
## 左手 / 右手三种姿势各自的帧
const HAND_FRAMES := [[0, 1, 2], [3, 4, 5]]

## 屏幕上站起来约 178px 高，比人物（84px）高一倍多
@export var boss_scale := 0.56
## 手和本体同一套缩放会比人还高，压到 0.62：举过头顶时正好不碰到血条
@export var hand_scale_mul := 0.62
## 手离身体多远：手心到本体边缘的距离 = 手宽的一半 × 这个数。0 就是手心贴着本体边，1 是整只手都在外面
@export var hand_gap := 0.55
## 手心多高：0 是脚底，1 是头顶
@export var hand_height := 0.48
## 单独微调某一只手（屏幕像素，x 正 = 往右，y 正 = 往下）。
## 素材左右手是镜像的，但张开那帧左手靠身体的一侧是暗色手背，看着像有条缝，所以左手往里多推 4 像素（8 太贴了）
@export var hand_nudge_left := Vector2(4.0, 0.0)
@export var hand_nudge_right := Vector2.ZERO

## 震地：手举起 -> 砸到地上（回调）-> 蹲着 -> 站起来
const STOMP_RAISE := 0.30
const STOMP_SLAM := 0.12
const STOMP_HOLD := 0.18
const STOMP_RISE := 0.40
## 扔东西：手把东西举过头顶 -> 出手（回调）-> 手甩下来
const THROW_RAISE := 0.35
const THROW_SWING := 0.22
const TAUNT_TIME := 0.7

var _body: Sprite2D
var _hands: Array[Sprite2D] = []
var _tex: Texture2D
var _time := 0.0
var _anim := "idle"
var _anim_t := 0.0
var _hand_pose: int = Hand.OPEN
var _callback := Callable()
var _callback_fired := false
var _held_items: Array = []      # 扔东西时两只手里各拿一件（物品登记表下标），宿主负责画
# 每帧由 _step_anim 算出：本体用哪一帧、两只手相对休息位挪多少
var _body_frame := 17
var _hand_off := [Vector2.ZERO, Vector2.ZERO]


func _ready() -> void:
	_tex = Art.tex("怪兽")
	_body = Sprite2D.new()
	_body.centered = false
	_body.region_enabled = true
	_body.texture = _tex
	add_child(_body)
	for i in 2:
		var h := Sprite2D.new()
		h.region_enabled = true
		h.texture = _tex
		add_child(h)
		_hands.append(h)
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	_anim_t += delta
	_step_anim()
	_refresh()


## 本体在屏幕上的宽高（站起来的样子），给碰撞盒用。
func body_size() -> Vector2:
	return Vector2(BODY_W, BODY_H) * boss_scale


## 第 i 只手（0 左 1 右）现在的全局位置，宿主拿它画手里的东西、定出手点。
func hand_pos(i: int) -> Vector2:
	return _hands[clampi(i, 0, 1)].global_position


func held_items() -> Array:
	return _held_items


## 震地：手举起再砸到地上，砸到那一刻调 on_impact。
func stomp(on_impact: Callable) -> void:
	_begin("stomp", Hand.FIST, on_impact)


## 扔东西：两只手各拿一件举过头顶，出手那一刻调 on_release。
func throw_items(items: Array, on_release: Callable) -> void:
	_held_items = items.duplicate()
	_begin("throw", Hand.OPEN, on_release)


## 砸中人之后竖个拇指嘲讽一下。正在攻击就不打断。
func taunt() -> void:
	if _anim == "idle":
		_begin("taunt", Hand.THUMB)


func _begin(anim: String, hand: int, cb := Callable()) -> void:
	_anim = anim
	_anim_t = 0.0
	_hand_pose = hand
	_callback = cb
	_callback_fired = false


func _fire_callback() -> void:
	if _callback_fired:
		return
	_callback_fired = true
	if _callback.is_valid():
		_callback.call()


func _end_anim() -> void:
	_anim = "idle"
	_anim_t = 0.0
	_hand_pose = Hand.OPEN
	_held_items.clear()


func _step_anim() -> void:
	var t := _anim_t
	match _anim:
		"stomp":
			if t < STOMP_RAISE:
				# 举拳：慢慢抬起来，带点后仰蓄力
				var k := _ease_out(t / STOMP_RAISE)
				_body_frame = 16
				_set_hands(Vector2(6.0, -46.0) * k)
			elif t < STOMP_RAISE + STOMP_SLAM:
				# 砸下去：手直落到地面，身体同时从站压到蹲
				var k := (t - STOMP_RAISE) / STOMP_SLAM
				_body_frame = RISE_FRAMES[RISE_FRAMES.size() - 1 - int(k * (RISE_FRAMES.size() - 1))]
				_set_hands(Vector2(6.0, -46.0).lerp(_ground_hand_off(), k * k))
			elif t < STOMP_RAISE + STOMP_SLAM + STOMP_HOLD:
				_fire_callback()
				_body_frame = RISE_FRAMES[0]
				_set_hands(_ground_hand_off())
			elif t < STOMP_RAISE + STOMP_SLAM + STOMP_HOLD + STOMP_RISE:
				var k := (t - STOMP_RAISE - STOMP_SLAM - STOMP_HOLD) / STOMP_RISE
				_body_frame = RISE_FRAMES[mini(int(k * RISE_FRAMES.size()), RISE_FRAMES.size() - 1)]
				_set_hands(_ground_hand_off().lerp(Vector2.ZERO, _ease_out(k)))
			else:
				_end_anim()
		"throw":
			var top := Vector2(-BODY_W * 0.22 * boss_scale, -BODY_H * 0.5 * boss_scale)
			if t < THROW_RAISE:
				# 把东西举过头顶，手往中间收一点
				var k := _ease_out(t / THROW_RAISE)
				_body_frame = 7
				_set_hands(Vector2.ZERO.lerp(top, k))
			elif t < THROW_RAISE + THROW_SWING:
				_fire_callback()
				_held_items.clear()
				# 甩出去：手朝外朝下过冲再回来
				var k := (t - THROW_RAISE) / THROW_SWING
				var out := Vector2(BODY_W * 0.18 * boss_scale, 14.0)
				var p := top.lerp(out, _ease_out(k)) if k < 0.5 else out.lerp(Vector2.ZERO, _ease_out((k - 0.5) * 2.0))
				_body_frame = 7
				_set_hands(p)
			else:
				_end_anim()
		"taunt":
			if t < TAUNT_TIME:
				_body_frame = IDLE_FRAMES[int(_time * IDLE_FPS) % IDLE_FRAMES.size()]
				var k := sin(minf(t / 0.15, 1.0) * PI * 0.5)
				_set_hands(Vector2(0.0, -18.0 * k))
			else:
				_end_anim()
		_:
			_body_frame = IDLE_FRAMES[int(_time * IDLE_FPS) % IDLE_FRAMES.size()]
			# 待机：两只手错开相位轻轻浮动
			_hand_off[0] = Vector2(0.0, sin(_time * 2.4) * 3.0)
			_hand_off[1] = Vector2(0.0, sin(_time * 2.4 + 1.7) * 3.0)


## 拳头砸到地上时手心相对休息位的偏移（落到脚底那条线）
func _ground_hand_off() -> Vector2:
	return Vector2(10.0, -_hand_rest().y - 263.0 * 0.5 * boss_scale * hand_scale_mul + 4.0)


## 给右手的偏移，左手按 x 镜像（所以 x 正 = 往外张，负 = 往身体中间收）
func _set_hands(off: Vector2) -> void:
	_hand_off[0] = Vector2(-off.x, off.y)
	_hand_off[1] = off


func _ease_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - (1.0 - k) * (1.0 - k)


## 右手的休息位（相对脚底原点）；左手取 x 的负值。178 是素材里手的内容宽
func _hand_rest() -> Vector2:
	var s := boss_scale
	return Vector2(BODY_W * 0.5 * s + 178.0 * 0.5 * s * hand_scale_mul * hand_gap, -BODY_H * hand_height * s)


func _refresh() -> void:
	if _body == null:
		return
	var s := boss_scale
	var frame := _body_frame
	_body.region_rect = Rect2(frame * FRAME_W, 0.0, FRAME_W, FRAME_H)
	var foot_y: float = BODY_FOOT_ROW.get(frame, 349.0)
	_body.scale = Vector2.ONE * s
	_body.position = Vector2(-BODY_CENTER_X * s, FOOT_SINK - (foot_y + 1.0) * s)

	var hs := s * hand_scale_mul
	var rest := _hand_rest()
	for i in 2:
		var h := _hands[i]
		h.region_rect = Rect2(HAND_FRAMES[i][_hand_pose] * FRAME_W, 0.0, FRAME_W, FRAME_H)
		h.scale = Vector2.ONE * hs
		var side := -1.0 if i == 0 else 1.0
		var nudge := hand_nudge_left if i == 0 else hand_nudge_right
		h.position = Vector2(rest.x * side, rest.y) + _hand_off[i] + nudge


func _draw() -> void:
	# 素材没到货就画中性灰占位，形状按站起来的大小
	if _tex == null:
		var sz := body_size()
		draw_rect(Rect2(-sz.x * 0.5, -sz.y, sz.x, sz.y), Art.PLACEHOLDER)
