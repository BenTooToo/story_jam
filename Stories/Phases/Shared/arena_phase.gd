class_name JamArenaPhase
extends Node2D
## 三阶段玩法的公共基类：双人移动 / 跳跃 / 投掷 / 眩晕 / 抛物线物理 / HUD 工具。
## 子类通过覆写 phase_tick / projectile_hit_test / throw_target_x / _draw_front 定制玩法。

signal phase_finished(result: Dictionary)

const CharSprite := preload("res://Stories/Phases/Shared/character_sprite.gd")
const Art := preload("res://Stories/Phases/Shared/phase_art.gd")
const Fx := preload("res://Stories/Phases/Shared/phase_fx.gd")
const Sfx := preload("res://Stories/Phases/Shared/retro_sfx.gd")
const CanvasProxy := preload("res://Stories/Phases/Shared/canvas_proxy.gd")
const PIXEL_FONT := preload("res://Assets/Theme/像素字体.ttf")
const FLOOR_SHADER := preload("res://Assets/Theme/water.gdshader")
const SFX_CLANK := preload("res://Assets/Sound Effects/哐当.mp3")

const GROUND_Y := 300.0
const ARENA_LEFT := 18.0
const ARENA_RIGHT := 622.0
const GRAVITY := 980.0
const PROJ_FLIGHT := 1.05          # 飞行总时间固定，落点才可预测
## 弧线最高点（相对出手点）。离门越近抛得越高，离得远就压平。
const APEX_NEAR := 108.0           # 贴着门扔：几乎垂直吊过去
const APEX_FAR := 46.0             # 离门很远：压平了甩过去
const APEX_NEAR_DIST := 40.0
const APEX_FAR_DIST := 240.0
const OBSTACLE_CLEARANCE := 7.0    # 越过障碍物顶端至少留这么多余量
## 离障碍物比这还近时，出手点抬到障碍物顶端之上（举过头顶甩）。
## 不然从门边 2px 处固定 1.05 秒飞到对面，物理上根本升不过门沿，再大的重力都没用。
const NEAR_LOB_DIST := 36.0
const MOVE_SPEED := 155.0
const JUMP_VELOCITY := -330.0
const STUN_TIME := 2.0
const THROW_COOLDOWN := 0.65
## 挥臂到出手的间隔，对准"扔东西"动作表的第 3 帧
const THROW_RELEASE := 0.16
const CHAR_HALF_W := 11.0
const CHAR_H := 82.0
const SHOULDER_Y := -62.0
## 强调色取自两人的衣服，用在计分板和飘字上
const P1_COLOR := Color(0.58, 0.65, 0.88)   # NPC0：深蓝毛衣
const P2_COLOR := Color(0.85, 0.62, 0.28)   # NPC1：赭色衬衫


class PlayerState:
	var id := 0
	var fig: Node2D
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var on_ground := true
	var stun := 0.0
	var cooldown := 0.0
	var throw_timer := -1.0   # >0 表示正在挥臂，归零那一刻才真的出手
	var score := 0
	var keys := {}


## 打开后在左上角列出还没到货的素材，方便对着清单催素材
@export var show_missing_art := false

## 背景底色。子类可以按拍子改它，让整个画面跟着呼吸
var bg_color := Color(0.055, 0.055, 0.075)
## 地面上那条浅色接触线。跳舞不要，人直接站在反光地板上
var draw_ground_line := true

var players := []
var projectiles := []          # {pos, vel, grav, from, item, rot, spin}
var obstacles: Array[Rect2] = []
var draw_obstacle_blocks := true
var controls_enabled := false
var running := false

var _t := 0.0
var _shake_time := 0.0
var _shake_amp := 0.0
var _rng := RandomNumberGenerator.new()
var _hud: CanvasLayer


func _enter_tree() -> void:
	# 子类各自实现 _ready，这里用延后调用挂公共的东西，省得三个阶段各写一遍
	call_deferred("_setup_floor")
	call_deferred("_setup_missing_art_hud")


## 电梯场景那块反光地板，三个阶段都铺上。
## 它用 screen_texture 把上面的画面倒映下来，所以要在人物之后画：
## 靠 z_index = 5 排在所有默认层（人物 / 物品 / 粒子）之后、HUD 之前。
func _setup_floor() -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.008
	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.seamless = true
	var mat := ShaderMaterial.new()
	mat.shader = FLOOR_SHADER
	mat.set_shader_parameter("wave_noise", noise_tex)
	mat.set_shader_parameter("floor_tint", Color(0.75, 0.39, 0.34))
	mat.set_shader_parameter("tint_amount", 0.6)
	mat.set_shader_parameter("depth_dim", 0.35)
	mat.set_shader_parameter("perspective", 0.35)
	mat.set_shader_parameter("reflection_strength", 0.45)
	mat.set_shader_parameter("reflection_falloff", 2.5)
	mat.set_shader_parameter("blur_depth", 2.0)
	mat.set_shader_parameter("fade", 1.0)
	var floor_rect := ColorRect.new()
	floor_rect.name = "Floor"
	floor_rect.material = mat
	# 顶到脚下，白线关掉时人物和倒影之间不会露一条底色
	floor_rect.position = Vector2(0.0, GROUND_Y + 1.0)
	floor_rect.size = Vector2(640.0, 134.0)
	floor_rect.color = Color.BLACK
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor_rect.z_index = 5
	add_child(floor_rect)


func _setup_missing_art_hud() -> void:
	if not show_missing_art:
		return
	make_hud_label(
		Art.missing_report(), 6, 4, 628, 10,
		Color(0.95, 0.75, 0.4), HORIZONTAL_ALIGNMENT_LEFT,
	)


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_t += delta
	_apply_shake(delta)
	phase_tick(delta)
	for p in players:
		update_player(p, delta)
	step_projectiles(delta)
	queue_redraw()


# ---------- 子类覆写点 ----------

func phase_tick(_delta: float) -> void:
	pass


## 投掷物命中检测；返回 true 表示该投掷物已被消耗。
func projectile_hit_test(_proj: Dictionary) -> bool:
	return false


## 投掷瞄准的目标 x 坐标。
func throw_target_x(_player: PlayerState) -> float:
	return 320.0


func _draw_back() -> void:
	pass


func _draw_front() -> void:
	pass


# ---------- 玩家 ----------

## P1 在左边（NPC0），P2 在右边（NPC1）——和对话框里的头像左右一致。
func setup_players(x1: float, x2: float) -> void:
	var defs := [
		{id = 1, x = x1, character = 0, color = P1_COLOR, facing = 1,
			keys = {left = KEY_A, right = KEY_D, jump = KEY_W, throw = KEY_F}},
		{id = 2, x = x2, character = 1, color = P2_COLOR, facing = -1,
			keys = {left = KEY_LEFT, right = KEY_RIGHT, jump = KEY_UP, throw = KEY_SLASH}},
	]
	for d in defs:
		var p := PlayerState.new()
		p.id = d.id
		p.keys = d.keys
		p.pos = Vector2(d.x, GROUND_Y)
		p.fig = make_character(d.character, d.color, d.facing, p.pos)
		players.append(p)


func make_character(character: int, accent: Color, facing: int, at: Vector2) -> Node2D:
	var fig := CharSprite.new()
	fig.character = character
	fig.color = accent
	fig.facing = facing
	fig.position = at
	add_child(fig)
	return fig


func get_player(id: int) -> PlayerState:
	for p in players:
		if p.id == id:
			return p
	return null


func player_rect(p: PlayerState) -> Rect2:
	return Rect2(p.pos.x - CHAR_HALF_W, p.pos.y - CHAR_H, CHAR_HALF_W * 2.0, CHAR_H)


func update_player(p: PlayerState, delta: float) -> void:
	p.cooldown = maxf(p.cooldown - delta, 0.0)
	if p.throw_timer > 0.0:
		p.throw_timer -= delta
		if p.throw_timer <= 0.0:
			_release_throw(p)
	if p.stun > 0.0:
		p.stun -= delta
		if p.stun <= 0.0:
			p.fig.set_stunned(false)

	var dir := 0.0
	var wants_jump := false
	var wants_throw := false
	if controls_enabled and p.stun <= 0.0:
		if Input.is_physical_key_pressed(p.keys.left):
			dir -= 1.0
		if Input.is_physical_key_pressed(p.keys.right):
			dir += 1.0
		wants_jump = Input.is_physical_key_pressed(p.keys.jump)
		wants_throw = Input.is_physical_key_pressed(p.keys.throw) \
			or (p.id == 2 and Input.is_physical_key_pressed(KEY_KP_0))

	p.vel.x = dir * MOVE_SPEED
	if dir != 0.0:
		p.fig.facing = 1 if dir > 0.0 else -1
	if wants_jump and p.on_ground:
		p.vel.y = JUMP_VELOCITY
		p.on_ground = false
	p.vel.y += GRAVITY * delta
	p.pos += p.vel * delta
	p.pos.x = clampf(p.pos.x, ARENA_LEFT, ARENA_RIGHT)
	if p.pos.y >= GROUND_Y:
		p.pos.y = GROUND_Y
		p.vel.y = 0.0
		p.on_ground = true

	for r in obstacles:
		if player_rect(p).intersects(r):
			if p.pos.x < r.get_center().x:
				p.pos.x = r.position.x - CHAR_HALF_W
			else:
				p.pos.x = r.end.x + CHAR_HALF_W

	p.fig.position = p.pos
	if wants_throw and p.cooldown <= 0.0:
		throw_from(p)
	p.fig.auto_pose(p.on_ground, p.vel.x)


func stun_player(p: PlayerState, hint := "!") -> void:
	p.stun = STUN_TIME
	p.fig.set_stunned(true)
	Sfx.play(self, SFX_CLANK, -10.0, _rng.randf_range(0.9, 1.15))
	var voice := Art.hurt_sound(int(p.fig.character), _rng)
	if voice != null:
		Sfx.play(self, voice, 0.0, _rng.randf_range(0.96, 1.04))
	shake(4.0, 0.25)
	Fx.hit_burst(self, p.pos + Vector2(0, -CHAR_H * 0.6), Color(1.0, 0.86, 0.45), 22, 1.25)
	Fx.pop_text(self, p.pos + Vector2(0, -CHAR_H - 16.0), hint, Color(1.0, 0.85, 0.3), 22, 0.45)


# ---------- 投掷物 ----------

## 按下投掷键：先播挥臂动画，THROW_RELEASE 秒后才真的把东西扔出去
func throw_from(p: PlayerState) -> void:
	p.cooldown = THROW_COOLDOWN
	p.throw_timer = THROW_RELEASE
	var target_x := throw_target_x(p)
	p.fig.facing = 1 if target_x > p.pos.x else -1
	p.fig.strike(CharSprite.Pose.THROW, 0.42)
	Sfx.play(self, Sfx.blip(340.0, 190.0, 0.09, 0.3), -8.0)


## 挥臂到位，东西真正脱手
func _release_throw(p: PlayerState) -> void:
	p.throw_timer = -1.0
	var from := p.pos + Vector2(p.fig.facing * 14.0, SHOULDER_Y)
	var to := Vector2(throw_target_x(p), GROUND_Y - CHAR_H * 0.5)
	for r in obstacles:
		if not _is_between(r, p.pos.x, to.x):
			continue
		# 贴着门站时手会伸进门里，出手点先夹回门外
		if from.x > r.position.x and from.x < r.end.x:
			from.x = r.position.x - 2.0 if p.pos.x < r.get_center().x else r.end.x + 2.0
		# 离门太近就举过头顶扔：起点直接放到门顶之上，近沿天然过得去，远沿只要个温和的弧
		var edge_x := r.position.x if p.pos.x < r.get_center().x else r.end.x
		if absf(edge_x - from.x) <= NEAR_LOB_DIST:
			from.y = minf(from.y, r.position.y - OBSTACLE_CLEARANCE - 4.0)
	var arc := solve_arc(from, to)
	# 抓到什么扔什么，马桶凳子都能上
	projectiles.append({
		pos = from,
		vel = arc.vel,
		grav = arc.grav,
		from = p.id,
		item = Art.random_item(_rng),
		rot = 0.0,
		spin = _rng.randf_range(-7.0, 7.0),
	})


## 解一条抛物线：飞行时间固定成 PROJ_FLIGHT，落点精确落在 to。
##
## 关键在于——时间和起终点都定死之后，抛物线其实只剩一条，光改初速度是变不出
## 高低不同的弧线的。所以这里改的是**每一发自己的重力**：时间不变 -> 落点一定准；
## 重力越大，需要的初速就越大，弧线也就越高。
##
## 高度先按"离门多远"给（贴着门就得吊高，离得远就压平），再检查一遍能不能真的
## 越过中间的障碍，不够就往上抬，所以一定扔得过去。
func solve_arc(from: Vector2, to: Vector2) -> Dictionary:
	var vx := (to.x - from.x) / PROJ_FLIGHT
	var apex := _wanted_apex(from, to)
	for _i in 14:
		var g := _gravity_for_apex(apex, to.y - from.y)
		var vy := ((to.y - from.y) - 0.5 * g * PROJ_FLIGHT * PROJ_FLIGHT) / PROJ_FLIGHT
		if _clears_obstacles(from, to.x, vx, vy, g):
			return {vel = Vector2(vx, vy), grav = g}
		apex += 14.0
	# 抬到头还是过不去（正常玩不到），就用最高的那条
	var g_max := _gravity_for_apex(apex, to.y - from.y)
	var vy_max := ((to.y - from.y) - 0.5 * g_max * PROJ_FLIGHT * PROJ_FLIGHT) / PROJ_FLIGHT
	return {vel = Vector2(vx, vy_max), grav = g_max}


## 想要的最高点：离最近的障碍物越近，抛得越高。
func _wanted_apex(from: Vector2, to_x: Vector2) -> float:
	var dist := 1e9
	for r in obstacles:
		if _is_between(r, from.x, to_x.x):
			dist = minf(dist, absf(r.get_center().x - from.x))
	if dist > 1e8:
		# 中间没东西挡（比如打怪兽），按离目标的远近给个自然的弧度
		dist = absf(to_x.x - from.x)
	var k := clampf(
		(dist - APEX_NEAR_DIST) / (APEX_FAR_DIST - APEX_NEAR_DIST), 0.0, 1.0
	)
	return lerpf(APEX_NEAR, APEX_FAR, k)


## 由想要的最高点反解这一发的重力。
## 推导：y(t) = vy·t + ½g·t²，落点约束给出 vy = (Δy - ½gT²)/T，
## 最高点 h = vy²/(2g)。两式消去 vy 得 u² - 4(Δy+2h)·u + 4Δy² = 0（u = gT²），
## 取大根即可；Δy = 0 时正好退化成 g = 8h/T²。
func _gravity_for_apex(apex: float, dy: float) -> float:
	var b := dy + 2.0 * apex
	var disc := maxf(b * b - dy * dy, 0.0)
	var u := 2.0 * b + 2.0 * sqrt(disc)
	return maxf(u, 1.0) / (PROJ_FLIGHT * PROJ_FLIGHT)


## 这个障碍物是不是夹在出手点和目标之间。
## 目标本身落在障碍里的不算——打电梯怪兽就是要砸中它，不能绕过去；
## 出手点在障碍里的也不算——怪兽从自己身体里往外扔，不会被自己挡住。
func _is_between(r: Rect2, from_x: float, to_x: float) -> bool:
	if to_x >= r.position.x and to_x <= r.end.x:
		return false
	if from_x >= r.position.x and from_x <= r.end.x:
		return false
	return r.end.x >= minf(from_x, to_x) and r.position.x <= maxf(from_x, to_x)


## 这条弧线在障碍物的左右两个边缘处，是不是都在顶端之上。
func _clears_obstacles(from: Vector2, to_x: float, vx: float, vy: float, g: float) -> bool:
	if is_zero_approx(vx):
		return true
	for r in obstacles:
		if not _is_between(r, from.x, to_x):
			continue
		for edge_x in [r.position.x, r.end.x]:
			var t: float = (edge_x - from.x) / vx
			if t <= 0.0 or t >= PROJ_FLIGHT:
				continue
			var y: float = from.y + vy * t + 0.5 * g * t * t
			if y > r.position.y - OBSTACLE_CLEARANCE:
				return false
	return true


func step_projectiles(delta: float) -> void:
	var i := projectiles.size() - 1
	while i >= 0:
		var pr: Dictionary = projectiles[i]
		pr.vel = pr.vel + Vector2(0.0, float(pr.grav) * delta)
		pr.pos = pr.pos + pr.vel * delta
		pr.rot = pr.rot + pr.spin * delta
		var dead := projectile_hit_test(pr)
		if not dead:
			if pr.pos.y > GROUND_Y + 2.0 or pr.pos.x < -30.0 or pr.pos.x > 670.0:
				dead = true
			else:
				for r in obstacles:
					if r.has_point(pr.pos):
						dead = true
						break
		if dead:
			# 东西砸到什么就在那儿迸一下，粒子自己淡完自己清理
			Fx.hit_burst(self, pr.pos)
			projectiles.remove_at(i)
		i -= 1


# ---------- 表现 ----------

func shake(amp := 4.0, time := 0.25) -> void:
	_shake_amp = amp
	_shake_time = maxf(_shake_time, time)


func _apply_shake(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta
		position = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * _shake_amp
		if _shake_time <= 0.0:
			position = Vector2.ZERO


## 得分之类的小飘字。统一走 Fx.pop_text，淡入淡出，不会啪一下出现又啪一下消失。
func float_text(at: Vector2, text: String, color: Color, font_size := 13) -> void:
	Fx.pop_text(self, at, text, color, font_size, 0.35, 26.0)


func hud() -> CanvasLayer:
	if _hud == null:
		_hud = CanvasLayer.new()
		_hud.layer = 40
		add_child(_hud)
	return _hud


func make_hud_label(
	text: String,
	x: float,
	y: float,
	w: float,
	font_size: int,
	color: Color,
	align := HORIZONTAL_ALIGNMENT_LEFT,
) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(x, y)
	label.size = Vector2(w, font_size + 12.0)
	label.horizontal_alignment = align
	hud().add_child(label)
	return label


func show_banner(text: String, color := Color.WHITE) -> Label:
	var label := make_hud_label(text, 0.0, 128.0, 640.0, 26, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_constant_override("outline_size", 5)
	_pulse_in(label, 0.28)
	return label


## 淡入 + 轻微弹一下，别让文字啪一声直接出现
func _pulse_in(label: Label, duration := 0.22) -> void:
	label.pivot_offset = label.size * 0.5
	label.modulate.a = 0.0
	label.scale = Vector2(0.72, 0.72)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "modulate:a", 1.0, duration * 0.6)
	tw.tween_property(label, "scale", Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func run_countdown() -> void:
	var label := make_hud_label("3", 0.0, 120.0, 640.0, 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	for s in ["3", "2", "1"]:
		label.text = s
		_pulse_in(label)
		Sfx.play(self, Sfx.blip(440.0, 430.0, 0.1, 0.35))
		await get_tree().create_timer(0.7).timeout
	label.text = "开始!"
	_pulse_in(label, 0.3)
	Sfx.play(self, Sfx.blip(880.0, 900.0, 0.16, 0.4))
	controls_enabled = true
	await get_tree().create_timer(0.5).timeout
	# 淡出，不是直接消失
	var out := label.create_tween()
	out.tween_property(label, "modulate:a", 0.0, 0.25)
	out.tween_callback(label.queue_free)


# ---------- 绘制 ----------

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), bg_color)
	_draw_back()
	if draw_ground_line:
		draw_line(Vector2(0, GROUND_Y + 3.0), Vector2(640, GROUND_Y + 3.0), Color(0.85, 0.82, 0.72), 4.0, true)
	if draw_obstacle_blocks:
		for r in obstacles:
			Art.draw_in_rect(self, "隔断", r)
	_draw_projectiles()
	_draw_front()


func _draw_projectiles() -> void:
	for pr in projectiles:
		Art.draw_item(self, int(pr.item), pr.pos, pr.rot)
