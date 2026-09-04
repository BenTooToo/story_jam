extends "res://Stories/Phases/Shared/arena_phase.gd"
## 阶段一：90 秒互扔大战。
## 砸中对面 +10 分，被砸中眩晕 2 秒；空中掉落 1 / 3 / 5 分的物品，碰到即得分。

const BGM := "res://Assets/Music/乐队之歌.mp3"

@export var duration := 90.0
@export var item_interval := 2.4

var time_left := 0.0
var items := []                # {pos, item, tier, half_h, landed, rest}

var _item_timer := 1.2
var _score_left: Label
var _score_right: Label
var _timer_label: Label


func _ready() -> void:
	_rng.randomize()
	floor_tint = Color(0.36, 0.46, 0.85)   # 扔东西阶段地板是蓝的
	# 中间的教室门（127x255 按 0.40 缩放 = 51x102），比人高，跳也翻不过去，
	# 只能把东西抛过门顶
	obstacles.append(Rect2(294.5, 198, 51, 102))
	setup_players(120.0, 520.0)
	time_left = duration
	_build_hud()
	_start()


func _start() -> void:
	play_bgm(BGM)
	await run_countdown()
	running = true


func _build_hud() -> void:
	_score_left = make_hud_label("P1  0", 10, 58, 220, 15, P1_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	_score_right = make_hud_label("P2  0", 410, 58, 220, 15, P2_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)
	_timer_label = make_hud_label(str(ceili(duration)), 270, 56, 100, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	make_hud_label(
		"P1：A/D 移动  W 跳  F 扔      " + p2_hint("P2：←/→ 移动  ↑ 跳  / 扔"),
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
		if p.id == int(proj.from) or not can_be_stunned(p):
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
	stun_player(victim)
	shake(5.0, 0.3)


# ---------- 电脑操控的 P2 ----------

## 单人模式的男生：守着右半场捡东西、隔一会儿扔一发、看见砸过来的就躲。
## 反应故意留了余量，不然玩家根本赢不了。
func ai_command(p: PlayerState, delta: float) -> Dictionary:
	var cmd := {dir = 0.0, jump = false, throw = false}
	p.ai_timer -= delta

	# 眩晕一解除立刻跳起来往远处跑：对面这两秒里扔的全对着原地，站着不动就被连控
	if p.ai_just_freed:
		p.ai_just_freed = false
		p.ai_target_x = 560.0 if p.pos.x < 480.0 else 400.0
		cmd.jump = true
		cmd.dir = ai_step_toward(p, p.ai_target_x, 6.0)
		return cmd

	# 躲：对面扔过来、还在半空的，往远离它的方向挪；快到头顶时顺手跳一下
	for proj in projectiles:
		if int(proj.from) == p.id:
			continue
		if not proj.has("ai_dodge"):
			# 每一发只判一次躲不躲，八成会躲
			proj.ai_dodge = _rng.randf() < 0.8
		if not bool(proj.ai_dodge):
			continue
		var dx: float = float(proj.pos.x) - p.pos.x
		if absf(dx) < 90.0 and float(proj.pos.y) < GROUND_Y - 20.0:
			cmd.dir = -1.0 if dx > 0.0 else 1.0
			if p.pos.x < 372.0 and cmd.dir < 0.0:
				cmd.dir = 1.0   # 左边是门，别往门上撞
			if p.pos.x > ARENA_RIGHT - 16.0 and cmd.dir > 0.0:
				cmd.dir = -1.0  # 顶到右墙了，往回跑
			cmd.jump = absf(dx) < 45.0 and float(proj.vel.y) > 0.0
			return cmd

	# 捡：右半场有掉落物就去够，越值钱越先去
	var best_x := -1.0
	var best_tier := 0
	for it in items:
		if float(it.pos.x) < 372.0:
			continue
		if int(it.tier) > best_tier or (int(it.tier) == best_tier and absf(float(it.pos.x) - p.pos.x) < absf(best_x - p.pos.x)):
			best_tier = int(it.tier)
			best_x = float(it.pos.x)
	if best_x >= 0.0:
		cmd.dir = ai_step_toward(p, best_x, 10.0)
	else:
		# 没东西捡就慢慢晃，别杵着像卡住了
		if p.ai_target_x < 0.0 or absf(p.ai_target_x - p.pos.x) < 8.0:
			p.ai_target_x = _rng.randf_range(400.0, 590.0)
		cmd.dir = ai_step_toward(p, p.ai_target_x, 6.0)

	# 扔：冷却好了再等一小会儿，不要机器般准时
	if p.cooldown <= 0.0 and p.throw_timer <= 0.0 and p.ai_timer <= 0.0:
		cmd.throw = true
		p.ai_timer = _rng.randf_range(0.6, 1.4)
	return cmd


# ---------- 掉落物品 ----------

func _spawn_item() -> void:
	# 越大的东西越少见：文具最多，马桶凳子最少
	var roll := _rng.randf()
	var tier := 1
	if roll > 0.85:
		tier = 5
	elif roll > 0.05:
		tier = 3
	var index := Art.random_item(_rng, tier)
	# 障碍物顶上落不到，只在两侧半场掉
	var x := _rng.randf_range(40.0, 250.0) if _rng.randf() < 0.5 else _rng.randf_range(390.0, 600.0)
	items.append({
		pos = Vector2(x, -20.0),
		item = index,
		tier = tier,
		half_h = Art.item_screen_size(index).y * 0.5,
		landed = false,
		rest = 0.0,
	})


func _step_items(delta: float) -> void:
	var i := items.size() - 1
	while i >= 0:
		var it: Dictionary = items[i]
		if not it.landed:
			it.pos = it.pos + Vector2(0.0, 95.0 * delta)
			# 按各自的高度停在地面上，别半截埋进地里
			var rest_y: float = GROUND_Y + 1.0 - float(it.half_h)
			if it.pos.y >= rest_y:
				it.pos = Vector2(it.pos.x, rest_y)
				it.landed = true
		else:
			it.rest += delta
		var taken := false
		for p in players:
			if p.stun > 0.0:
				continue
			# 东西越大越容易碰到
			var reach: float = 20.0 + float(it.half_h) * 0.6
			if (p.pos + Vector2(0, -CHAR_H * 0.5)).distance_to(it.pos) < reach:
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
	# 曲子让位给哭声
	fade_out_bgm(1.6)
	Sfx.play(self, Sfx.blip(523.0, 784.0, 0.35, 0.4))
	# 不管谁输谁赢都放这段哭，太好笑了。46 秒太长，只放开头，然后渐弱退出
	var wait := 2.4
	if _play_cry():
		wait = 5.4
	await get_tree().create_timer(wait).timeout
	phase_finished.emit({p1 = p1.score, p2 = p2.score, winner = winner})


## 放 cry.mp3 的开头：全音量 3 秒，再用 2.4 秒淡到听不见然后清掉。
func _play_cry() -> bool:
	var stream := Art.sound("cry")
	if stream == null:
		return false
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.play()
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(player, "volume_db", -40.0, 2.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(player.queue_free)
	return true


func _draw_front() -> void:
	for it in items:
		# 快消失前平滑地明暗呼吸，最后一段整体淡出，不做硬切
		var alpha := 1.0
		if it.rest > 2.0:
			alpha = 0.45 + 0.55 * (0.5 + 0.5 * sin(float(it.rest) * 16.0))
			alpha *= clampf((3.2 - float(it.rest)) / 0.5, 0.0, 1.0)
		Art.draw_item(self, int(it.item), it.pos, 0.0, Color(1, 1, 1, alpha))
