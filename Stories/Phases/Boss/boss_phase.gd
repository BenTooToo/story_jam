extends "res://Stories/Phases/Shared/arena_phase.gd"
## 阶段三：跳得太烂召唤出的电梯怪兽。
## 两人合力投掷打怪：怪兽会震地放冲击波（跳起躲开）、朝人丢齿轮（看落点预警）。
## 打倒怪兽后进入和解——本阶段没有对抗计分，只记每人的输出。

const BOSS_TEX := preload("res://Assets/Edited/电梯箱.png")
const BOSS_TINT := Color(0.58, 0.56, 0.62)

@export var boss_hp_max := 60

var boss_hp := 0
var boss_alive := true
var waves := []                # 地面冲击波 {x, dir}
var boss_projs := []           # 怪兽的投掷物 {pos, vel}
var markers := []              # 落点预警 {x, t}

var _boss_rect := Rect2()
var _boss_sprite: Sprite2D
var _boss_flash := 0.0
var _attack_timer := 2.5
var _attack_kind := 0


func _ready() -> void:
	_rng.randomize()
	draw_obstacle_blocks = false
	boss_hp = boss_hp_max
	setup_players(90.0, 550.0)
	_build_boss()
	_build_hud()
	_intro()


func _build_boss() -> void:
	var s := 92.0 / float(BOSS_TEX.get_width())
	var h := BOSS_TEX.get_height() * s
	_boss_rect = Rect2(320.0 - 46.0, GROUND_Y + 2.0 - h, 92.0, h)
	obstacles.append(_boss_rect)
	_boss_sprite = Sprite2D.new()
	_boss_sprite.texture = BOSS_TEX
	_boss_sprite.scale = Vector2.ONE * s
	_boss_sprite.position = Vector2(320.0, GROUND_Y + 2.0 - h * 0.5)
	_boss_sprite.modulate = BOSS_TINT
	add_child(_boss_sprite)
	# 脸和血条画在精灵上层
	var overlay := CanvasProxy.new()
	overlay.host = self
	overlay.z_index = 20
	add_child(overlay)


func _build_hud() -> void:
	make_hud_label("电梯怪兽", 0, 40, 640, 13, Color(0.9, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	make_hud_label(
		"合力打倒它！  P1：A/D/W + F      P2：←/→/↑ + /",
		0, 342, 640, 10, Color(0.75, 0.75, 0.8), HORIZONTAL_ALIGNMENT_CENTER,
	)


func _intro() -> void:
	Sfx.play(self, Sfx.noise(0.4, 0.55), -2.0, 0.6)
	shake(8.0, 0.6)
	var banner := show_banner("电梯怪兽出现了！", Color(0.9, 0.5, 0.5))
	await get_tree().create_timer(1.4).timeout
	banner.queue_free()
	controls_enabled = true
	running = true


func phase_tick(delta: float) -> void:
	_boss_flash = maxf(_boss_flash - delta, 0.0)
	if _boss_sprite != null and boss_alive:
		_boss_sprite.modulate = Color.WHITE if _boss_flash > 0.0 else BOSS_TINT
	if not running:
		return
	if boss_alive:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack_timer = lerpf(1.5, 2.7, float(boss_hp) / float(boss_hp_max))
			_do_attack()
	_step_waves(delta)
	_step_boss_projs(delta)
	var i := markers.size() - 1
	while i >= 0:
		markers[i].t -= delta
		if markers[i].t <= 0.0:
			markers.remove_at(i)
		i -= 1


func throw_target_x(_player: PlayerState) -> float:
	return 320.0


func projectile_hit_test(proj: Dictionary) -> bool:
	if boss_alive and _boss_rect.has_point(proj.pos):
		_damage_boss(3, proj.pos, int(proj.from))
		return true
	return false


func _damage_boss(amount: int, at: Vector2, from_id: int) -> void:
	boss_hp = maxi(boss_hp - amount, 0)
	_boss_flash = 0.12
	shake(3.0, 0.15)
	var attacker := get_player(from_id)
	if attacker != null:
		attacker.score += amount
	float_text(at + Vector2(0, -8), "-%d" % amount, Color(1.0, 0.5, 0.4), 13)
	Sfx.play(self, Sfx.blip(200.0, 90.0, 0.07, 0.35))
	if boss_hp <= 0 and boss_alive:
		_die()


# ---------- 怪兽攻击 ----------

func _do_attack() -> void:
	_attack_kind = (_attack_kind + 1) % 2
	if _attack_kind == 0:
		# 震地：两道沿地面扩散的冲击波，跳起躲开
		Sfx.play(self, SFX_CLANK, -4.0, 0.7)
		shake(6.0, 0.35)
		waves.append({x = 320.0 - 50.0, dir = -1.0})
		waves.append({x = 320.0 + 50.0, dir = 1.0})
	else:
		# 丢齿轮：朝每个玩家的当前位置抛一枚，地上有落点预警
		Sfx.play(self, Sfx.blip(140.0, 320.0, 0.2, 0.35))
		for p in players:
			var start := Vector2(320.0, _boss_rect.position.y + 8.0)
			var land_x: float = clampf(p.pos.x + _rng.randf_range(-14.0, 14.0), ARENA_LEFT, ARENA_RIGHT)
			var vx := (land_x - start.x) / 1.0
			var vy := ((GROUND_Y - start.y) - 0.5 * PROJ_GRAVITY * 1.0) / 1.0
			boss_projs.append({pos = start, vel = Vector2(vx, vy)})
			markers.append({x = land_x, t = 1.0})


func _step_waves(delta: float) -> void:
	var i := waves.size() - 1
	while i >= 0:
		var w: Dictionary = waves[i]
		w.x = float(w.x) + float(w.dir) * 230.0 * delta
		if absf(float(w.x) - 320.0) > 340.0:
			waves.remove_at(i)
		else:
			for p in players:
				if p.stun <= 0.0 and p.on_ground and absf(p.pos.x - float(w.x)) < 13.0:
					stun_player(p, "晕!")
		i -= 1


func _step_boss_projs(delta: float) -> void:
	var i := boss_projs.size() - 1
	while i >= 0:
		var bp: Dictionary = boss_projs[i]
		bp.vel = bp.vel + Vector2(0.0, PROJ_GRAVITY * delta)
		bp.pos = bp.pos + bp.vel * delta
		var dead: bool = bp.pos.y > GROUND_Y
		if not dead:
			for p in players:
				if p.stun <= 0.0 and player_rect(p).has_point(bp.pos):
					stun_player(p, "晕!")
					dead = true
					break
		if dead:
			pops.append({pos = bp.pos, t = 0.0})
			boss_projs.remove_at(i)
		i -= 1


# ---------- 战败 ----------

func _die() -> void:
	boss_alive = false
	running = false
	obstacles.clear()
	waves.clear()
	boss_projs.clear()
	markers.clear()
	Sfx.play(self, SFX_CLANK, -2.0, 0.8)
	Sfx.play(self, Sfx.blip(400.0, 60.0, 0.6, 0.4))
	shake(8.0, 0.6)
	for p in players:
		p.fig.set_stunned(false)
		p.stun = 0.0
		p.fig.strike(StickFigure.Pose.CHEER, 3.0)
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(_boss_sprite, "rotation", PI / 2.0, 0.9) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_boss_sprite, "position:y", _boss_sprite.position.y + 26.0, 0.9)
	tw.parallel().tween_property(_boss_sprite, "modulate:a", 0.0, 1.2)
	show_banner("电梯怪兽被打败了！", Color(1.0, 0.85, 0.4))
	await get_tree().create_timer(2.6).timeout
	phase_finished.emit({p1 = players[0].score, p2 = players[1].score})


# ---------- 绘制 ----------

func _draw_front() -> void:
	# 地面冲击波
	for w in waves:
		var x := float(w.x)
		draw_circle(Vector2(x, GROUND_Y + 1.0), 8.0, Color(0.8, 0.7, 0.5, 0.8))
		draw_arc(Vector2(x, GROUND_Y + 1.0), 12.0, PI, TAU, 10, Color(0.9, 0.85, 0.6), 2.0, true)
	# 怪兽投掷物：带齿的圆
	for bp in boss_projs:
		var pos: Vector2 = bp.pos
		draw_circle(pos, 6.0, Color(0.4, 0.4, 0.45))
		for k in 4:
			var a := _t * 6.0 + k * TAU / 4.0
			draw_line(pos, pos + Vector2(cos(a), sin(a)) * 9.0, Color(0.55, 0.55, 0.6), 2.0, true)


## CanvasProxy 转发来的上层绘制：血条、预警、怪兽的脸和手臂。
func _proxy_draw(cv: Node2D, _tag: String) -> void:
	# 血条
	cv.draw_rect(Rect2(170, 60, 300, 10), Color(0.1, 0.1, 0.12))
	var ratio := float(boss_hp) / float(boss_hp_max)
	cv.draw_rect(Rect2(171, 61, 298.0 * ratio, 8), Color(0.85, 0.25, 0.25))
	cv.draw_rect(Rect2(170, 60, 300, 10), Color(0.7, 0.7, 0.75), false, 1.5)
	# 落点预警（闪烁的红叉）
	for m in markers:
		if fmod(float(m.t) * 6.0, 1.0) < 0.6:
			var mx := float(m.x)
			var my := GROUND_Y - 3.0
			cv.draw_line(Vector2(mx - 6, my - 6), Vector2(mx + 6, my + 6), Color(0.95, 0.35, 0.3), 2.0, true)
			cv.draw_line(Vector2(mx - 6, my + 6), Vector2(mx + 6, my - 6), Color(0.95, 0.35, 0.3), 2.0, true)
	if not boss_alive:
		return
	# 怒目、锯齿嘴、挥舞的手臂
	var cx := _boss_rect.get_center().x
	var top := _boss_rect.position.y
	var white := Color(0.95, 0.95, 0.9)
	var wob := sin(_t * 6.0) * 5.0
	cv.draw_line(Vector2(cx - 20, top + 24), Vector2(cx - 7, top + 30), white, 3.0, true)
	cv.draw_line(Vector2(cx + 20, top + 24), Vector2(cx + 7, top + 30), white, 3.0, true)
	var mouth := PackedVector2Array()
	for k in 9:
		mouth.append(Vector2(cx - 22 + k * 5.5, top + 46 + (3.0 if k % 2 == 0 else -3.0)))
	cv.draw_polyline(mouth, white, 2.5, true)
	cv.draw_line(
		Vector2(_boss_rect.position.x, top + 34),
		Vector2(_boss_rect.position.x - 20, top + 6 - wob),
		white, 3.0, true,
	)
	cv.draw_line(
		Vector2(_boss_rect.end.x, top + 34),
		Vector2(_boss_rect.end.x + 20, top + 6 + wob),
		white, 3.0, true,
	)
