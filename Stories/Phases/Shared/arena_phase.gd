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
const SFX_CLANK := preload("res://Assets/Sound Effects/哐当.mp3")

const GROUND_Y := 300.0
const ARENA_LEFT := 18.0
const ARENA_RIGHT := 622.0
const GRAVITY := 980.0
const PROJ_GRAVITY := 420.0
const PROJ_FLIGHT := 1.05
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

var players := []
var projectiles := []          # {pos, vel, from, item, rot, spin}
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
	# 子类各自实现 _ready，这里用延后调用挂缺素材清单，省得三个阶段各写一遍
	call_deferred("_setup_missing_art_hud")


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
	Sfx.play(self, SFX_CLANK, -6.0, _rng.randf_range(0.9, 1.15))
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
	var target_x := throw_target_x(p)
	var vx := (target_x - p.pos.x) / PROJ_FLIGHT + _rng.randf_range(-26.0, 26.0)
	var vy := -PROJ_GRAVITY * PROJ_FLIGHT * 0.5 - 24.0
	# 抓到什么扔什么，马桶凳子都能上
	var index := Art.random_item(_rng)
	projectiles.append({
		pos = p.pos + Vector2(p.fig.facing * 14.0, SHOULDER_Y),
		vel = Vector2(vx, vy),
		from = p.id,
		item = index,
		rot = 0.0,
		spin = _rng.randf_range(-7.0, 7.0),
	})


func step_projectiles(delta: float) -> void:
	var i := projectiles.size() - 1
	while i >= 0:
		var pr: Dictionary = projectiles[i]
		pr.vel = pr.vel + Vector2(0.0, PROJ_GRAVITY * delta)
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
	draw_rect(Rect2(0, 0, 640, 360), Color(0.055, 0.055, 0.075))
	_draw_back()
	draw_line(Vector2(0, GROUND_Y + 3.0), Vector2(640, GROUND_Y + 3.0), Color(0.85, 0.82, 0.72), 4.0, true)
	if draw_obstacle_blocks:
		for r in obstacles:
			Art.draw_in_rect(self, "隔断", r)
	_draw_projectiles()
	_draw_front()


func _draw_projectiles() -> void:
	for pr in projectiles:
		Art.draw_item(self, int(pr.item), pr.pos, pr.rot)
