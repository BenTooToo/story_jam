extends "res://Stories/Phases/Shared/arena_phase.gd"
## 阶段二：舞蹈对决。上下左右音游，两边谱面完全相同。
## P1 用 WASD，P2 用方向键；完美 +5，还行 +2，错过记一次“烂”。
##
## 谱面跟着曲子走：150 BPM、4/4、56 小节。曲子放进 Assets/Branch/ 就自动接上，
## 没有曲子时回退到代码生成的节拍音，方便单独调玩法。

const ELEVATOR_TEX := preload("res://Assets/Edited/电梯箱.png")

const BEAT := 60.0 / 150.0           # 150 BPM -> 一拍 0.4 秒
const BEATS_PER_BAR := 4             # 4/4
const BAR := BEAT * BEATS_PER_BAR    # 一小节 1.6 秒
const BARS := 56                     # 音乐主体 56 小节 = 89.6 秒
const RECEPTOR_Y := 52.0
const NOTE_SPAWN_Y := 236.0    # 音符只在这条线以上滚动，不挡住两人的立绘
const SCROLL_SPEED := 140.0
## 判定窗口。150 BPM 一拍才 0.4 秒，窗口得比 96 BPM 那会儿收紧，
## 否则一个窗口能盖住小半拍开外的音符。
const PERFECT_WINDOW := 0.08
const GOOD_WINDOW := 0.16
const MISS_WINDOW := 0.22
## 同一条轨道上两个音符的最小间隔，必须大于判定窗口，
## 否则玩家打掉前一个之后，后一个在窗口里已经无音符可配，必漏。
const MIN_LANE_GAP := MISS_WINDOW + 0.06

## 曲子路径。文件名不一样也没关系，找不到会自动扫 Assets/Branch/ 里的音频。
const MUSIC_PATH := "res://Assets/Branch/可爱的小曲.wav"
const MUSIC_DIR := "res://Assets/Branch/"
const MUSIC_EXTS := ["ogg", "wav", "mp3"]

## 谱面按曲子的段落铺：主歌 1-16、副歌 17-32、过渡 33-40、第二次副歌 41-56。
## step = 每几拍放一个音符（0 = 这段不放音符）；eighth = 额外插半拍切分的概率。
## bars 加起来必须正好是 BARS。副歌踩满四分音符——跟着鼓点拍最顺手，
## 难度靠切分给，不靠堆密度。
const SECTIONS := [
	{bars = 2, step = 0.0, eighth = 0.0},    # 1-2   开头留两小节，第一个音符才有滚进来的时间
	{bars = 6, step = 2.0, eighth = 0.0},    # 3-8   主歌前半，两拍一个，先热身
	{bars = 8, step = 2.0, eighth = 0.2},    # 9-16  主歌后半，开始加切分
	{bars = 16, step = 1.0, eighth = 0.15},  # 17-32 副歌，踩满四分
	{bars = 8, step = 2.0, eighth = 0.1},    # 33-40 过渡，收一收喘口气
	{bars = 16, step = 1.0, eighth = 0.3},   # 41-56 第二次副歌，切分最多
]

## 曲子里第几秒对上谱面的第 1 小节第 1 拍。
## 分析过 可爱的小曲.wav：0 秒就出声，起音全落在 0.4 秒的网格上，所以是 0。
## 以后换曲子或者觉得整体偏早/偏晚，调这一个数就行。
@export var music_offset := 0.0

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
var _elapsed := 0.0            # 谱面时间轴，0 = 第 1 小节第 1 拍
var _next_beat := 0.0
var _last_note_time := 0.0
var _music: AudioStreamPlayer
var _finishing := false


func _ready() -> void:
	draw_obstacle_blocks = false
	_chart = _build_chart()
	_build_stage()
	_setup_music()
	_sides = [_make_side(0), _make_side(1)]
	_start()


func _start() -> void:
	# 曲子和倒计时一起开始：倒计时正好压在前 4 小节的前奏上，
	# 数完 3-2-1 音符也快滚到判定线了，中间不用干等。
	if _music != null:
		_music.play()
	await run_countdown()
	running = true


# ---------- 音乐 ----------

## 阶段被换掉 / 提前退出时把曲子停掉，别让它继续放到下一段去。
func _exit_tree() -> void:
	if _music != null and _music.playing:
		_music.stop()


func _setup_music() -> void:
	var path := _find_music()
	if path == "":
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	# 必须关掉循环，否则曲子放不到头，结尾那段等不到。
	# ogg/mp3 是 loop，wav 是 loop_mode（0 = 不循环），两种都关一下。
	if "loop" in stream:
		stream.set("loop", false)
	if "loop_mode" in stream:
		stream.set("loop_mode", 0)
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	add_child(_music)


func _find_music() -> String:
	if ResourceLoader.exists(MUSIC_PATH):
		return MUSIC_PATH
	# 名字对不上也认：扫一遍目录挑第一个音频文件
	var dir := DirAccess.open(MUSIC_DIR)
	if dir == null:
		return ""
	for f in dir.get_files():
		var file_name := f.trim_suffix(".import").trim_suffix(".remap")
		if MUSIC_EXTS.has(file_name.get_extension().to_lower()):
			var full := MUSIC_DIR + file_name
			if ResourceLoader.exists(full):
				return full
	return ""


## 谱面时间一律以音频的播放位置为准，不要自己累加 delta——
## 累加会和音乐越跑越偏，90 秒下来能差出好几拍。
## 加 get_time_since_last_mix、减 output_latency 是为了补上声卡缓冲的延迟。
func _chart_time() -> float:
	if _music == null or not _music.playing:
		return _elapsed
	var t := _music.get_playback_position() + AudioServer.get_time_since_last_mix()
	return t - AudioServer.get_output_latency() - music_offset


## 按 SECTIONS 把音符铺到 56 小节的格子上。固定种子，两边拿到的谱面完全一样。
func _build_chart() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260902
	var notes := []
	var bar := 0
	var prev := -1
	for sec: Dictionary in SECTIONS:
		var step: float = float(sec.step)
		for _b in int(sec.bars):
			if step > 0.0:
				var beat := 0.0
				while beat < float(BEATS_PER_BAR):
					var t := bar * BAR + beat * BEAT
					prev = _pick_lane(rng, prev)
					notes.append({time = t, lane = prev})
					# 偶尔插一个半拍的切分，别整首都在正拍上
					if rng.randf() < float(sec.eighth):
						prev = _pick_lane(rng, prev)
						notes.append({time = t + BEAT * 0.5, lane = prev})
					beat += step
			bar += 1
	if bar != BARS:
		push_warning("谱面小节数对不上：SECTIONS 合计 %d，应为 %d" % [bar, BARS])
	notes.sort_custom(func(a, b): return float(a.time) < float(b.time))
	_spread_lanes(notes)
	_last_note_time = 0.0
	for n in notes:
		_last_note_time = maxf(_last_note_time, float(n.time))
	return notes


## 同轨道上挨得太近的音符挪到别的方向去，保证每个都打得出来。
func _spread_lanes(notes: Array) -> void:
	var lane_last := [-99.0, -99.0, -99.0, -99.0]
	for n in notes:
		var t := float(n.time)
		var lane := int(n.lane)
		if t - float(lane_last[lane]) < MIN_LANE_GAP:
			# 换到空得最久的那条轨道
			var best := lane
			var best_gap := -1e9
			for k in 4:
				var gap: float = t - float(lane_last[k])
				if gap > best_gap:
					best_gap = gap
					best = k
			lane = best
			n.lane = lane
		lane_last[lane] = t


## 尽量别连着两个同一个方向，跳起来才有左右上下的感觉。
func _pick_lane(rng: RandomNumberGenerator, prev: int) -> int:
	var lane := rng.randi_range(0, 3)
	if lane == prev and rng.randf() < 0.7:
		lane = (lane + rng.randi_range(1, 3)) % 4
	return lane


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
	# 时间轴在倒计时期间就要走，音符才能提前滚进画面；判定要等 running 才开始
	if _music != null and _music.playing:
		# 有曲子就以音频位置为准
		_elapsed = _chart_time()
	elif running:
		_elapsed += delta
		# 只有没曲子的时候才补代码生成的节拍音，免得和真曲子打架
		while _next_beat <= _elapsed and _next_beat <= _last_note_time + 0.01:
			Sfx.play(self, Sfx.blip(175.0, 165.0, 0.05, 0.2))
			_next_beat += BEAT
	if not running:
		return
	for side in _sides:
		for n in side.notes:
			if not n.judged and _elapsed > float(n.time) + MISS_WINDOW:
				n.judged = true
				side.miss += 1
				side.combo = 0
				_popup(side, int(n.lane), "烂!", Color(0.9, 0.35, 0.3))
				side.fig.strike(CharSprite.Pose.MISS, 0.3)
				Sfx.play(self, Sfx.blip(220.0, 90.0, 0.16, 0.25))
				_refresh_score(side)
	if not _finishing and _elapsed > _last_note_time + 0.4:
		_finishing = true
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
	if best.is_empty() or absf(best_dt) > MISS_WINDOW:
		return
	best.judged = true
	var d := absf(best_dt)
	if d <= PERFECT_WINDOW:
		side.score += 5
		side.combo += 1
		_popup(side, lane, "完美!", Color(1.0, 0.85, 0.3))
		Sfx.play(self, Sfx.blip(1046.0, 1200.0, 0.08, 0.3))
	elif d <= GOOD_WINDOW:
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
	running = false
	var total_miss: int = _sides[0].miss + _sides[1].miss
	var text := "跳完了……这也太烂了吧！" if total_miss > 0 else "跳完了！整齐得可怕……"
	for side in _sides:
		side.fig.strike(CharSprite.Pose.MISS, 2.2)
	show_banner(text, Color(0.9, 0.8, 0.5))
	# 谱面完了但曲子后面还有一段收尾，等它放完再进下一段
	var wait := 2.2
	if _music != null and _music.playing:
		var remain: float = _music.stream.get_length() - _music.get_playback_position()
		wait = maxf(remain + 0.4, 0.6)
	else:
		Sfx.play(self, Sfx.blip(392.0, 196.0, 0.5, 0.35))
	await get_tree().create_timer(wait).timeout
	if _music != null:
		_music.stop()
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
