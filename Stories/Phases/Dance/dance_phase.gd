extends "res://Stories/Phases/Shared/arena_phase.gd"
## 阶段二：舞蹈对决。上下左右音游，两边谱面完全相同。
## P1 用 WASD，P2 用方向键；完美 +5，还行 +2，错过记一次“烂”。

const ELEVATOR_TEX := preload("res://Assets/Edited/电梯箱.png")

const BEAT := 60.0 / 96.0      # 96 BPM
const LEAD_IN := 2.0
const RECEPTOR_Y := 52.0
const NOTE_SPAWN_Y := 236.0    # 音符只在这条线以上滚动，不挡住两人的立绘
const SCROLL_SPEED := 130.0

var lane_pose := [
	CharSprite.Pose.DANCE_LEFT,
	CharSprite.Pose.DANCE_DOWN,
	CharSprite.Pose.DANCE_UP,
	CharSprite.Pose.DANCE_RIGHT,
]
## 素材只需要一个朝上的箭头，四个方向靠旋转
var arrow_rot := [-PI / 2.0, PI, 0.0, PI / 2.0]

var _chart := []               # {time, lane}
var _sides := []               # 每边一份状态字典
var _elapsed := 0.0
var _next_beat := LEAD_IN - 2.0 * BEAT
var _last_note_time := 0.0
var _end_time := 0.0


func _ready() -> void:
	draw_obstacle_blocks = false
	_chart = _build_chart()
	_build_stage()
	_sides = [_make_side(0), _make_side(1)]
	_start()


func _start() -> void:
	await run_countdown()
	running = true


func _build_chart() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260831
	var notes := []
	var t := LEAD_IN
	var prev := -1
	for i in 40:
		var lane := rng.randi_range(0, 3)
		if lane == prev and rng.randf() < 0.6:
			lane = (lane + rng.randi_range(1, 3)) % 4
		prev = lane
		notes.append({time = t, lane = lane})
		if i >= 16 and rng.randf() < 0.28:
			notes.append({time = t + BEAT * 0.5, lane = (lane + rng.randi_range(1, 3)) % 4})
		t += BEAT
	_last_note_time = 0.0
	for n in notes:
		_last_note_time = maxf(_last_note_time, float(n.time))
	_end_time = _last_note_time + 1.2
	return notes


func _build_stage() -> void:
	# 中间的电梯：两人隔着它斗舞，高度按人物身高配比
	var sprite := Sprite2D.new()
	sprite.texture = ELEVATOR_TEX
	var s := 152.0 / float(ELEVATOR_TEX.get_height())
	sprite.scale = Vector2.ONE * s
	sprite.position = Vector2(320.0, GROUND_Y + 4.0 - ELEVATOR_TEX.get_height() * s * 0.5)
	sprite.modulate = Color(0.62, 0.6, 0.66)
	add_child(sprite)


func _make_side(idx: int) -> Dictionary:
	var side := {
		score = 0,
		combo = 0,
		miss = 0,
		xs = [66.0, 114.0, 162.0, 210.0] if idx == 0 else [430.0, 478.0, 526.0, 574.0],
		keymap = {KEY_A: 0, KEY_S: 1, KEY_W: 2, KEY_D: 3} if idx == 0 \
			else {KEY_LEFT: 0, KEY_DOWN: 1, KEY_UP: 2, KEY_RIGHT: 3},
		arrow_key = "绿箭头" if idx == 0 else "红箭头",
		flash = [0.0, 0.0, 0.0, 0.0],
		notes = [],
		fig = null,
		label = null,
	}
	for n in _chart:
		side.notes.append({time = n.time, lane = n.lane, judged = false})
	# 两人贴着电梯站，各自的箭头轨道在自己外侧
	side.fig = make_character(
		idx,
		P1_COLOR if idx == 0 else P2_COLOR,
		1 if idx == 0 else -1,
		Vector2(225.0 if idx == 0 else 415.0, GROUND_Y),
	)
	var fig: Node2D = side.fig
	side.label = make_hud_label(
		"得分 0   连击 0",
		10.0 if idx == 0 else 330.0, 316.0, 300.0, 13,
		fig.color,
		HORIZONTAL_ALIGNMENT_LEFT if idx == 0 else HORIZONTAL_ALIGNMENT_RIGHT,
	)
	if idx == 0:
		make_hud_label(
			"P1：WASD      P2：方向键",
			0, 342, 640, 10, Color(0.75, 0.75, 0.8), HORIZONTAL_ALIGNMENT_CENTER,
		)
	return side


func phase_tick(delta: float) -> void:
	for side in _sides:
		for lane in 4:
			side.flash[lane] = maxf(side.flash[lane] - delta * 3.0, 0.0)
	if not running:
		return
	_elapsed += delta
	while _next_beat <= _elapsed and _next_beat <= _last_note_time + 0.01:
		Sfx.play(self, Sfx.blip(175.0, 165.0, 0.05, 0.2))
		_next_beat += BEAT
	for side in _sides:
		for n in side.notes:
			if not n.judged and _elapsed > float(n.time) + 0.30:
				n.judged = true
				side.miss += 1
				side.combo = 0
				_popup(side, int(n.lane), "烂!", Color(0.9, 0.35, 0.3))
				side.fig.strike(CharSprite.Pose.MISS, 0.3)
				Sfx.play(self, Sfx.blip(220.0, 90.0, 0.16, 0.25))
				_refresh_score(side)
	if _elapsed > _end_time:
		running = false
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		for side in _sides:
			if side.keymap.has(event.physical_keycode):
				_judge(side, int(side.keymap[event.physical_keycode]))


func _judge(side: Dictionary, lane: int) -> void:
	side.flash[lane] = 0.3
	side.fig.strike(lane_pose[lane], 0.35)
	var best := {}
	var best_dt := 999.0
	for n in side.notes:
		if n.judged or int(n.lane) != lane:
			continue
		var dt: float = _elapsed - float(n.time)
		if absf(dt) < absf(best_dt):
			best_dt = dt
			best = n
	if best.is_empty() or absf(best_dt) > 0.35:
		return
	best.judged = true
	var d := absf(best_dt)
	if d <= 0.11:
		side.score += 5
		side.combo += 1
		_popup(side, lane, "完美!", Color(1.0, 0.85, 0.3))
		Sfx.play(self, Sfx.blip(1046.0, 1200.0, 0.08, 0.3))
	elif d <= 0.24:
		side.score += 2
		side.combo += 1
		_popup(side, lane, "还行", Color(0.55, 0.85, 0.5))
		Sfx.play(self, Sfx.blip(660.0, 700.0, 0.07, 0.28))
	else:
		side.miss += 1
		side.combo = 0
		_popup(side, lane, "烂!", Color(0.9, 0.35, 0.3))
		side.fig.strike(CharSprite.Pose.MISS, 0.3)
		Sfx.play(self, Sfx.blip(220.0, 90.0, 0.16, 0.25))
	_refresh_score(side)


func _popup(side: Dictionary, lane: int, text: String, color: Color) -> void:
	float_text(Vector2(float(side.xs[lane]), 96.0), text, color, 12)


func _refresh_score(side: Dictionary) -> void:
	side.label.text = "得分 %d   连击 %d" % [side.score, side.combo]


func _finish() -> void:
	var total_miss: int = _sides[0].miss + _sides[1].miss
	var text := "跳完了……这也太烂了吧！" if total_miss > 0 else "跳完了！整齐得可怕……"
	for side in _sides:
		side.fig.strike(CharSprite.Pose.MISS, 2.2)
	show_banner(text, Color(0.9, 0.8, 0.5))
	Sfx.play(self, Sfx.blip(392.0, 196.0, 0.5, 0.35))
	await get_tree().create_timer(2.2).timeout
	phase_finished.emit({
		p1 = _sides[0].score,
		p2 = _sides[1].score,
		misses = total_miss,
	})


func _draw_front() -> void:
	for side in _sides:
		var key: String = side.arrow_key
		# 判定线上的箭头压暗，打中时闪一下
		for lane in 4:
			var at := Vector2(float(side.xs[lane]), RECEPTOR_Y)
			Art.draw_sprite(self, key, at, 26.0, arrow_rot[lane], Color(0.55, 0.55, 0.58))
			if side.flash[lane] > 0.0:
				Art.draw_sprite(
					self, key, at, 26.0, arrow_rot[lane],
					Color(1.8, 1.8, 1.8, minf(side.flash[lane] * 3.0, 1.0)),
				)
		# 往上滚的音符
		for n in side.notes:
			if n.judged:
				continue
			var y := RECEPTOR_Y + (float(n.time) - _elapsed) * SCROLL_SPEED
			if y > NOTE_SPAWN_Y or y < 34.0:
				continue
			Art.draw_sprite(
				self, key,
				Vector2(float(side.xs[int(n.lane)]), y), 26.0,
				arrow_rot[int(n.lane)],
			)
