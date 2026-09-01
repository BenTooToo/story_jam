extends "res://Stories/Phases/Shared/arena_phase.gd"
## 阶段一：90 秒互扔大战。
## 砸中对面 +10 分，被砸中眩晕 2 秒；空中掉落 1 / 3 / 5 分的物品，碰到即得分。

@export var duration := 90.0
@export var item_interval := 2.4

var time_left := 0.0
var items := []                # {pos, tier, landed, rest}

var _item_timer := 1.2
var _score_left: Label
var _score_right: Label
var _timer_label: Label


func _ready() -> void:
	_rng.randomize()
	# 中间的隔断要比人高，跳也翻不过去，只能抛物线越过
	obstacles.append(Rect2(292, 202, 56, 98))
	setup_players(120.0, 520.0)
	time_left = duration
	_build_hud()
	_start()


func _start() -> void:
	await run_countdown()
	running = true


func _build_hud() -> void:
	_score_left = make_hud_label("P1  0", 10, 58, 220, 15, P1_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	_score_right = make_hud_label("P2  0", 410, 58, 220, 15, P2_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	_timer_label = make_hud_label(str(ceili(duration)), 270, 56, 100, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	make_hud_label(
		"P1：A/D 移动  W 跳  F 扔      P2：←/→ 移动  ↑ 跳  / 扔",
		0, 342, 640, 10, Color(0.75, 0.75, 0.8), HORIZONTAL_ALIGNMENT_CENTER,
	)


func phase_tick(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	_timer_label.text = str(ceili(maxf(time_left, 0.0)))
	_item_timer -= delta
	if _item_timer <= 0.0:
		_item_timer = item_interval * _rng.randf_range(0.7, 1.3)
		_spawn_item()
	_step_items(delta)
	if time_left <= 0.0:
		running = false
		controls_enabled = false
		_finish()


func throw_target_x(p: PlayerState) -> float:
	var other := get_player(3 - p.id)
	return other.pos.x if other != null else 320.0


func projectile_hit_test(proj: Dictionary) -> bool:
	for p in players:
		if p.id == int(proj.from) or p.stun > 0.0:
			continue
		if player_rect(p).has_point(proj.pos):
			_on_player_hit(p, proj)
			return true
	return false


func _on_player_hit(victim: PlayerState, proj: Dictionary) -> void:
	var thrower := get_player(int(proj.from))
	if thrower != null and running:
		thrower.score += 10
		float_text(victim.pos + Vector2(0, -CHAR_H - 26.0), "+10", thrower.fig.color, 15)
		_update_scores()
	victim.vel = Vector2.ZERO
	stun_player(victim, "晕!")
	shake(5.0, 0.3)


# ---------- 掉落物品 ----------

func _spawn_item() -> void:
	var roll := _rng.randf()
	var tier := 1
	if roll > 0.85:
		tier = 5
	elif roll > 0.55:
		tier = 3
	# 障碍物顶上落不到，只在两侧半场掉
	var x := _rng.randf_range(40.0, 250.0) if _rng.randf() < 0.5 else _rng.randf_range(390.0, 600.0)
	items.append({pos = Vector2(x, -12.0), tier = tier, landed = false, rest = 0.0})


func _step_items(delta: float) -> void:
	var i := items.size() - 1
	while i >= 0:
		var it: Dictionary = items[i]
		if not it.landed:
			it.pos = it.pos + Vector2(0.0, 95.0 * delta)
			if it.pos.y >= GROUND_Y - 4.0:
				it.pos = Vector2(it.pos.x, GROUND_Y - 4.0)
				it.landed = true
		else:
			it.rest += delta
		var taken := false
		for p in players:
			if p.stun > 0.0:
				continue
			if (p.pos + Vector2(0, -CHAR_H * 0.5)).distance_to(it.pos) < 26.0:
				p.score += int(it.tier)
				float_text(it.pos + Vector2(0, -10), "+%d" % int(it.tier), p.fig.color, 13)
				Sfx.play(self, Sfx.blip(880.0, 1318.0, 0.09, 0.3))
				_update_scores()
				taken = true
				break
		if taken or it.rest > 3.2:
			items.remove_at(i)
		i -= 1


# ---------- 结算 ----------

func _update_scores() -> void:
	_score_left.text = "P1  %d" % players[0].score
	_score_right.text = "P2  %d" % players[1].score


func _finish() -> void:
	var p1: PlayerState = players[0]
	var p2: PlayerState = players[1]
	var winner := 0
	var text := "平局！"
	var color := Color.WHITE
	if p1.score > p2.score:
		winner = 1
		text = "P1 获胜！"
		color = P1_COLOR
	elif p2.score > p1.score:
		winner = 2
		text = "P2 获胜！"
		color = P2_COLOR
	for p in players:
		p.fig.set_stunned(false)
		p.stun = 0.0
		if winner == 0 or p.id == winner:
			p.fig.strike(CharSprite.Pose.CHEER, 2.4)
		else:
			p.fig.strike(CharSprite.Pose.MISS, 2.4)
	show_banner(text, color)
	Sfx.play(self, Sfx.blip(523.0, 784.0, 0.35, 0.4))
	await get_tree().create_timer(2.4).timeout
	phase_finished.emit({p1 = p1.score, p2 = p2.score, winner = winner})


func _draw_front() -> void:
	for it in items:
		# 快消失前闪烁提示
		var alpha := 1.0
		if it.rest > 2.0:
			alpha = 0.4 if fmod(float(it.rest), 0.3) < 0.15 else 1.0
		# 分值越高的素材画得越大，方便一眼看出该抢哪个
		var height := 11.0 + int(it.tier) * 1.6
		Art.draw_sprite(
			self, "掉落%d分" % int(it.tier), it.pos, height, 0.0,
			Color(1, 1, 1, alpha),
		)
