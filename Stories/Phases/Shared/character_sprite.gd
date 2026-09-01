class_name JamCharacter
extends Node2D
## 角色显示：直接用 Assets/Branch/dance.png（4 列 × 2 行，每帧 256×256）。
## 上排是 NPC1（男），下排是 NPC0（女）。原点在脚底，向右为正面朝向。
##
## 每帧的落脚线和胯部中轴是量过素材得到的，换姿势时以胯部为轴，
## 所以身体不会左右跳，只有四肢向外伸展。
## 目前只有 4 帧舞蹈素材，跑 / 跳 / 眩晕先用现有帧加代码位移拼；
## 等专门的动作素材进来，只要改 POSE_FRAME 就能替换。

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

const SHEET := preload("res://Assets/Branch/dance.png")
const FRAME_SIZE := 256.0
const FOOT_Y := 253.0                                # 素材里脚底所在的行
const SHEET_ROW := [1, 0]                            # NPC0 -> 下排，NPC1 -> 上排
const PIVOTS := [                                    # 每帧胯部中轴（素材坐标）
	[117.0, 114.5, 118.0, 120.0],                    # 上排：男
	[112.0, 122.0, 108.0, 114.0],                    # 下排：女
]
const POSE_FRAME := {
	Pose.IDLE: 0,
	Pose.RUN: 0,
	Pose.JUMP: 3,
	Pose.THROW: 1,
	Pose.STUNNED: 0,
	Pose.DANCE_LEFT: 1,
	Pose.DANCE_DOWN: 3,
	Pose.DANCE_UP: 2,
	Pose.DANCE_RIGHT: 1,
	Pose.MISS: 3,
	Pose.CHEER: 2,
}

## 屏幕上的身高约 84 像素（素材内容高约 248）。
@export var char_scale := 0.34

var character := 0            # 0 = NPC0（女），1 = NPC1（男）
var facing := 1
var pose: int = Pose.IDLE
var color := Color.WHITE      # 只用于 UI 强调色（飘字、计分板）

var _body: Sprite2D
var _time := 0.0
var _pose_hold := 0.0


func _ready() -> void:
	_body = Sprite2D.new()
	_body.texture = SHEET
	_body.centered = false
	_body.region_enabled = true
	add_child(_body)
	_refresh()


func _process(delta: float) -> void:
	_time += delta
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
	var row: int = SHEET_ROW[clampi(character, 0, 1)]
	var frame: int = POSE_FRAME.get(pose, 0)
	_body.region_rect = Rect2(frame * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)

	# 舞蹈的左右两个方向直接靠镜像区分，其余姿势跟随移动朝向
	var face := facing
	match pose:
		Pose.DANCE_LEFT:
			face = -1
		Pose.DANCE_RIGHT:
			face = 1

	var lift := 0.0
	var tilt := 0.0
	match pose:
		Pose.IDLE:
			lift = sin(_time * 2.2) * 0.8
		Pose.RUN:
			lift = -absf(sin(_time * 11.0)) * 2.5
			tilt = 0.04 * face
		Pose.JUMP:
			tilt = 0.06 * face
		Pose.STUNNED:
			tilt = sin(_time * 8.0) * 0.12
		Pose.MISS:
			lift = 2.0
			tilt = -0.05 * face
		Pose.CHEER:
			lift = -absf(sin(_time * 6.0)) * 6.0

	rotation = tilt
	var pivot: float = PIVOTS[row][frame]
	var s := char_scale
	# 贴图左上角对齐：把素材里的胯部中轴和落脚线搬到本节点原点上，
	# 镜像时符号跟着 face 翻，胯部才会一直压在原点、不会左右跳。
	_body.scale = Vector2(s * face, s)
	_body.position = Vector2(-pivot * s * face, -FOOT_Y * s + lift)


func _draw() -> void:
	if pose != Pose.STUNNED:
		return
	var head_y := -body_height() - 8.0
	for k in 3:
		var a := _time * 4.0 + k * TAU / 3.0
		_star(Vector2(cos(a) * 13.0, head_y + sin(a) * 3.0), 3.0, Color(1.0, 0.85, 0.3))


func _star(at: Vector2, r: float, c: Color) -> void:
	draw_line(at + Vector2(-r, 0), at + Vector2(r, 0), c, 1.6, true)
	draw_line(at + Vector2(0, -r), at + Vector2(0, r), c, 1.6, true)
	draw_line(at + Vector2(-r, -r) * 0.7, at + Vector2(r, r) * 0.7, c, 1.3, true)
	draw_line(at + Vector2(-r, r) * 0.7, at + Vector2(r, -r) * 0.7, c, 1.3, true)
