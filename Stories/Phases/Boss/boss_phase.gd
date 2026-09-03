extends "res://Stories/Phases/Shared/arena_phase.gd"
## 阶段三：跳得太烂召唤出的电梯怪兽。
## 两人合力投掷打怪：怪兽会震地放冲击波（跳起躲开）、抓起大件砸人（看地上的感叹号）。
## 打倒怪兽后进入和解——本阶段没有对抗计分，只记每人的输出。

## 怪兽本体等 高艺晨 的 电梯怪兽.png；没到货之前先拿电梯箱压暗顶着。
const BOSS_FALLBACK_TEX := preload("res://Assets/Edited/电梯箱.png")
const BOSS_TINT := Color(0.58, 0.56, 0.62)
const BGM := "res://Assets/Music/番剧之歌.mp3"
## 冲击波贴地速度。玩家离波起点约 200px，140 给 1.5 秒左右的反应时间
const WAVE_SPEED := 140.0
const ARROW_POP_TIME := 0.2        # 冲击波箭头从地里弹出来的时间

## 每次砸中扣 3，150 血两个人合力大约要砸 50 下
@export var boss_hp_max := 150

var boss_hp := 0
var boss_alive := true
var waves := []                # 地面冲击波 {x, dir, puff}
var boss_projs := []           # 怪兽抓起来砸回去的东西 {pos, vel, grav, item, rot}

var _boss_rect := Rect2()
var _boss_sprite: Sprite2D
var _boss_base_tint := Color.WHITE
var _boss_flash := 0.0
var _attack_timer := 2.5
var _attack_kind := 0


func _ready() -> void:
	_rng.randomize()
	floor_tint = Color(0.75, 0.39, 0.34)   # 怪兽阶段地板是红的
	draw_obstacle_blocks = false
	boss_hp = boss_hp_max
	setup_players(90.0, 550.0)
	_build_boss()
	_build_hud()
	_intro()


func _build_boss() -> void:
	var tex: Texture2D = Art.tex("怪兽")
	var w := 148.0
	var s := w / float((tex if tex != null else BOSS_FALLBACK_TEX).get_width())
	var h := (tex if tex != null else BOSS_FALLBACK_TEX).get_height() * s
	_boss_rect = Rect2(320.0 - w * 0.5, GROUND_Y + 2.0 - h, w, h)
	obstacles.append(_boss_rect)
	_boss_sprite = Sprite2D.new()
	_boss_sprite.texture = tex if tex != null else BOSS_FALLBACK_TEX
	_boss_sprite.scale = Vector2.ONE * s
	_boss_sprite.position = Vector2(320.0, GROUND_Y + 2.0 - h * 0.5)
	# 拿电梯箱顶替时压暗一点，跟阶段二的普通电梯区分开
	_boss_base_tint = Color.WHITE if tex != null else BOSS_TINT
	_boss_sprite.modulate = _boss_base_tint
	add_child(_boss_sprite)
	# 血条画在怪兽精灵上层
	var overlay := CanvasProxy.new()
	overlay.host = self
	overlay.z_index = 20
	add_child(overlay)


func _build_hud() -> void:
	make_hud_label("电梯怪兽", 0, 40, 640, 13, Color(0.9, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	make_hud_label(
		"合力打倒它！  P1：A/D/W + F      " + p2_hint("P2：←/→/↑ + /"),
		0, 342, 640, 10, Color(0.75, 0.75, 0.8), HORIZONTAL_ALIGNMENT_CENTER,
	)


func _intro() -> void:
	Sfx.play(self, Sfx.noise(0.4, 0.55), -2.0, 0.6)
	shake(8.0, 0.6)
	var banner := show_banner("电梯怪兽出现了！", Color(0.9, 0.5, 0.5))
	await get_tree().create_timer(1.4).timeout
	banner.queue_free()
	play_bgm(BGM)
	controls_enabled = true
	running = true


func phase_tick(delta: float) -> void:
	_boss_flash = maxf(_boss_flash - delta, 0.0)
	if _boss_sprite != null and boss_alive:
		_boss_sprite.modulate = Color(1.6, 1.6, 1.6) if _boss_flash > 0.0 else _boss_base_tint
	if not running:
		return
	if boss_alive:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack_timer = lerpf(1.5, 2.7, float(boss_hp) / float(boss_hp_max))
			_do_attack()
	_step_waves(delta)
	_step_boss_projs(delta)


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
	Fx.hit_burst(self, at, Color(1.0, 0.6, 0.45), 12)
	float_text(at + Vector2(0, -8), "-%d" % amount, Color(1.0, 0.5, 0.4), 13)
	Sfx.play(self, Sfx.blip(200.0, 90.0, 0.07, 0.35))
	if boss_hp <= 0 and boss_alive:
		_die()


# ---------- 电脑操控的 P2 ----------

## 单人模式的男生：守右半场朝怪兽扔，冲击波快到就跳，落点感叹号在脚边就跑开。
func ai_command(p: PlayerState, delta: float) -> Dictionary:
	var cmd := {dir = 0.0, jump = false, throw = false}
	p.ai_timer -= delta
	if not boss_alive:
		return cmd

	# 跳：朝自己滚来的冲击波离脚下 50px 以内就起跳（跳一次约 0.67 秒，波速 140）
	for w in waves:
		var dx := float(w.x) - p.pos.x
		var coming := (dx < 0.0 and float(w.dir) > 0.0) or (dx > 0.0 and float(w.dir) < 0.0)
		if coming and absf(dx) < 50.0 and p.on_ground:
			cmd.jump = true

	# 躲：有东西要砸到脚边，往远离落点的方向跑，但别跑进怪兽的身位
	for bp in boss_projs:
		var land := float(bp.get("land_x", -999.0))
		if absf(land - p.pos.x) < 34.0:
			var away := 1.0 if land < p.pos.x else -1.0
			if p.pos.x + away * 30.0 < _boss_rect.end.x + CHAR_HALF_W + 6.0:
				away = 1.0
			if p.pos.x > ARENA_RIGHT - 20.0:
				away = -1.0
			cmd.dir = away
			return cmd

	# 平时在右半场慢慢换位，站太死容易被连砸
	if p.ai_target_x < 0.0 or absf(p.ai_target_x - p.pos.x) < 8.0:
		p.ai_target_x = _rng.randf_range(_boss_rect.end.x + 40.0, 600.0)
	cmd.dir = ai_step_toward(p, p.ai_target_x, 6.0)

	# 扔：冷却好了再等一小会儿
	if p.cooldown <= 0.0 and p.throw_timer <= 0.0 and p.ai_timer <= 0.0:
		cmd.throw = true
		p.ai_timer = _rng.randf_range(0.3, 0.9)
	return cmd


# ---------- 怪兽攻击 ----------

func _do_attack() -> void:
	_attack_kind = (_attack_kind + 1) % 2
	if _attack_kind == 0:
		# 震地：两道沿地面扩散的冲击波，跳起躲开
		Sfx.play(self, SFX_CLANK, -4.0, 0.7)
		shake(6.0, 0.35)
		waves.append({x = 320.0 - 50.0, dir = -1.0, puff = 0.0, age = 0.0})
		waves.append({x = 320.0 + 50.0, dir = 1.0, puff = 0.0, age = 0.0})
	else:
		# 砸东西：抓起水桶凳子马桶之类朝玩家扔，落点先亮感叹号
		Sfx.play(self, Sfx.blip(140.0, 320.0, 0.2, 0.35))
		for p in players:
			var start := Vector2(320.0, _boss_rect.position.y + _boss_rect.size.y * 0.35)
			var land_x: float = clampf(p.pos.x + _rng.randf_range(-14.0, 14.0), ARENA_LEFT, ARENA_RIGHT)
			# 和玩家一样：飞行时间固定、精确落点，弧线高低由每发自己的重力决定
			var arc := solve_arc(start, Vector2(land_x, GROUND_Y - 6.0))
			boss_projs.append({
				pos = start,
				vel = arc.vel,
				grav = arc.grav,
				item = Art.random_item(_rng, 5),
				rot = 0.0,
				land_x = land_x,   # 电脑玩家靠这个躲
			})
			# 落点先打个感叹号 + 火星，给玩家反应时间
			Fx.pop_text(self, Vector2(land_x, GROUND_Y - 30.0), "!", Color(0.95, 0.4, 0.32), 20, 0.5, 6.0)
			Fx.warn_sparks(self, Vector2(land_x, GROUND_Y - 4.0))


func _step_waves(delta: float) -> void:
	var i := waves.size() - 1
	while i >= 0:
		var w: Dictionary = waves[i]
		w.x = float(w.x) + float(w.dir) * WAVE_SPEED * delta
		w.puff = float(w.puff) - delta
		w.age = float(w.age) + delta
		if float(w.puff) <= 0.0:
			w.puff = 0.055
			Fx.ground_dust(self, Vector2(float(w.x), GROUND_Y - 2.0))
		if absf(float(w.x) - 320.0) > 340.0:
			waves.remove_at(i)
		else:
			for p in players:
				if can_be_stunned(p) and p.on_ground and absf(p.pos.x - float(w.x)) < 13.0:
					stun_player(p)
		i -= 1


func _step_boss_projs(delta: float) -> void:
	var i := boss_projs.size() - 1
	while i >= 0:
		var bp: Dictionary = boss_projs[i]
		bp.vel = bp.vel + Vector2(0.0, float(bp.grav) * delta)
		bp.pos = bp.pos + bp.vel * delta
		bp.rot = float(bp.rot) + 5.0 * delta
		var dead: bool = bp.pos.y > GROUND_Y
		if not dead:
			for p in players:
				if can_be_stunned(p) and player_rect(p).has_point(bp.pos):
					stun_player(p)
					dead = true
					break
		if dead:
			Fx.hit_burst(self, bp.pos)
			boss_projs.remove_at(i)
		i -= 1


# ---------- 战败 ----------

func _die() -> void:
	boss_alive = false
	running = false
	obstacles.clear()
	waves.clear()
	boss_projs.clear()
	fade_out_bgm(2.0)
	Sfx.play(self, SFX_CLANK, -2.0, 0.8)
	Sfx.play(self, Sfx.blip(400.0, 60.0, 0.6, 0.4))
	shake(8.0, 0.6)
	Fx.hit_burst(self, _boss_rect.get_center(), Color(1.0, 0.75, 0.4), 46, 1.8)
	for p in players:
		p.fig.set_stunned(false)
		p.stun = 0.0
		p.fig.strike(CharSprite.Pose.CHEER, 3.0)
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
	# 冲击波光靠地上的尘土看不清，借跳舞的红箭头贴地飞：箭头朝波前进的方向，
	# 随波一起走、微微上下浮，一眼就知道"这东西要过来了"
	for w in waves:
		var rot: float = PI * 0.5 * float(w.dir)
		var bob := sin(_t * 18.0 + float(w.x) * 0.05) * 3.0
		# 刚冒出来的 0.2 秒从地里弹出来：由小到大、由透明到实，带一点过冲，别啪一下出现
		var k := clampf(float(w.age) / ARROW_POP_TIME, 0.0, 1.0)
		var pop := 1.0 - pow(1.0 - k, 3.0)
		var size := 30.0 * (0.4 + 0.6 * pop) * (1.0 + 0.25 * sin(k * PI))
		var at := Vector2(float(w.x), GROUND_Y - 16.0 * pop + bob * pop)
		Art.draw_sprite(self, "红箭头", at, size, rot, Color(1.0, 0.55, 0.45, pop))
		Art.draw_sprite(self, "红箭头", at, size, rot, Color(1.6, 1.0, 0.9, (0.5 + 0.5 * sin(_t * 30.0)) * pop))
	# 落点预警是粒子 + 文字，这里只画怪兽砸回来的东西
	for bp in boss_projs:
		Art.draw_item(self, int(bp.item), bp.pos, float(bp.rot))


## CanvasProxy 转发来的上层绘制：血条（UI，用纯色条）。
func _proxy_draw(cv: Node2D, _tag: String) -> void:
	cv.draw_rect(Rect2(170, 60, 300, 10), Color(0.1, 0.1, 0.12))
	var ratio := float(boss_hp) / float(boss_hp_max)
	cv.draw_rect(Rect2(171, 61, 298.0 * ratio, 8), Color(0.85, 0.25, 0.25))
	cv.draw_rect(Rect2(170, 60, 300, 10), Color(0.7, 0.7, 0.75), false, 1.5)
