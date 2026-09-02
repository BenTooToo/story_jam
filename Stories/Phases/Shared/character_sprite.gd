class_name JamCharacter
extends Node2D
## 角色显示：切 Assets/Branch/ 里的三张动作表，每张都是 4 列 × 2 行、每帧 256×256。
## 上排是 NPC1（男），下排是 NPC0（女）。原点在脚底，向右为正面朝向。
##
## 落脚线和胯部中轴是量素材得到的，显示时以胯部为轴压在原点，
## 所以换动作时身体不会左右跳；镜像时符号跟着 face 翻。

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

const Art := preload("res://Stories/Phases/Shared/phase_art.gd")
const SHEETS := [
	preload("res://Assets/Branch/dance.png"),        # 0 跳舞：站立 / 甩手 / 抬手 / 收手
	preload("res://Assets/Branch/扔东西.png"),        # 1 投掷：站立 / 抬手 / 挥臂 / 出手
	preload("res://Assets/Branch/新人物行走.png"),    # 2 行走：4 帧循环
]
const FRAME_SIZE := 256.0
const FOOT_Y := 253.0                        # 素材里脚底所在的行，三张表一致
const SHEET_ROW := [1, 0]                    # NPC0 -> 下排，NPC1 -> 上排
const PIVOT := [117.0, 113.0]                # 按行给的胯部中轴：上排男 / 下排女

## 每个姿势对应哪张表的哪几帧。loop = false 的播完停在最后一帧。
const POSE_CLIP := {
	Pose.IDLE: {sheet = 0, frames = [0], fps = 0.0, loop = true},
	Pose.RUN: {sheet = 2, frames = [0, 1, 2, 3], fps = 10.0, loop = true},
	Pose.JUMP: {sheet = 2, frames = [0], fps = 0.0, loop = true},
	Pose.THROW: {sheet = 1, frames = [1, 2, 3], fps = 11.0, loop = false},
	Pose.STUNNED: {sheet = 0, frames = [0], fps = 0.0, loop = true},
	Pose.DANCE_LEFT: {sheet = 0, frames = [1], fps = 0.0, loop = true},
	Pose.DANCE_DOWN: {sheet = 0, frames = [3], fps = 0.0, loop = true},
	Pose.DANCE_UP: {sheet = 0, frames = [2], fps = 0.0, loop = true},
	Pose.DANCE_RIGHT: {sheet = 0, frames = [1], fps = 0.0, loop = true},
	Pose.MISS: {sheet = 0, frames = [3], fps = 0.0, loop = true},
	Pose.CHEER: {sheet = 0, frames = [2], fps = 0.0, loop = true},
}

## 屏幕上的身高约 84 像素（素材内容高约 248）。
@export var char_scale := 0.34

var character := 0            # 0 = NPC0（女），1 = NPC1（男）
var facing := 1
var pose: int = Pose.IDLE
var color := Color.WHITE      # 只用于 UI 强调色（飘字、计分板）

var _body: Sprite2D
var _time := 0.0
var _clip_time := 0.0
var _last_pose := -1
var _pose_hold := 0.0


func _ready() -> void:
	_body = Sprite2D.new()
	_body.centered = false
	_body.region_enabled = true
	add_child(_body)
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	_clip_time += delta
	if _pose_hold > 0.0:
		_pose_hold -= delta
		if _pose_hold <= 0.0 and pose != Pose.STUNNED:
			pose = Pose.IDLE
	_refresh()
	if pose == Pose.STUNNED:
		queue_redraw()


## 屏幕上的身高，供碰撞盒和飘字定位用。
func body_height() -> float:
	return 248.0 * char_scale


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


func _refresh() -> void:
	if _body == null:
		return
	if pose != _last_pose:
		_last_pose = pose
		_clip_time = 0.0

	var clip: Dictionary = POSE_CLIP.get(pose, POSE_CLIP[Pose.IDLE])
	var frames: Array = clip.frames
	var idx := 0
	if float(clip.fps) > 0.0 and frames.size() > 1:
		idx = int(_clip_time * float(clip.fps))
		idx = idx % frames.size() if bool(clip.loop) else mini(idx, frames.size() - 1)
	var frame: int = frames[idx]

	var row: int = SHEET_ROW[clampi(character, 0, 1)]
	_body.texture = SHEETS[int(clip.sheet)]
	_body.region_rect = Rect2(frame * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)

	# 舞蹈的左右两个方向直接靠镜像区分，其余姿势跟随移动朝向
	var face := facing
	match pose:
		Pose.DANCE_LEFT:
			face = -1
		Pose.DANCE_RIGHT:
			face = 1

	# 跑和扔现在是真动画，不再靠代码位移凑；只有静止的姿势加一点点动静
	var lift := 0.0
	var tilt := 0.0
	match pose:
		Pose.IDLE:
			lift = sin(_time * 2.2) * 0.8
		Pose.STUNNED:
			tilt = sin(_time * 8.0) * 0.12
		Pose.MISS:
			lift = 2.0
		Pose.CHEER:
			lift = -absf(sin(_time * 6.0)) * 6.0

	rotation = tilt
	var s := char_scale
	_body.scale = Vector2(s * face, s)
	# 把素材里的胯部中轴和落脚线搬到本节点原点上
	_body.position = Vector2(-PIVOT[row] * s * face, -FOOT_Y * s + lift)


## 头顶转圈的眩晕提示
func _draw() -> void:
	if pose != Pose.STUNNED:
		return
	var head_y := -body_height() - 8.0
	for k in 3:
		var a := _time * 4.0 + k * TAU / 3.0
		Art.draw_sprite(self, "眩晕星星", Vector2(cos(a) * 13.0, head_y + sin(a) * 3.0), 7.0)
