extends "res://Stories/Phases/Shared/arena_phase.gd"
## 阶段二：舞蹈对决。上下左右音游，两边谱面完全相同。
## P1 用 WASD，P2 用方向键；完美 +5，还行 +2，错过记一次“烂”。
##
## 谱面跟着曲子走：150 BPM、4/4、56 小节。曲子放进 Assets/Branch/ 就自动接上，
## 没有曲子时回退到代码生成的节拍音，方便单独调玩法。

const ELEVATOR_TEX := preload("res://Assets/Edited/电梯箱.png")
const SHAFT_SHADER := preload("res://Assets/Theme/light_shafts.gdshader")
## 人物按电梯场景结尾的大小来（那边 NPC 是 0.55 / 0.586，电梯箱 1.0）
const DANCER_SCALE := 0.56
const DANCER_X := [195.0, 445.0]
## 轨道整体挪到人物外侧，不和放大后的人物重叠
const LANE_XS := [[30.0, 72.0, 114.0, 156.0], [484.0, 526.0, 568.0, 610.0]]
## 颜色 / 亮度都用 tween 过渡，不硬切
const TINT_TWEEN := 0.6
const ENERGY_TWEEN := BAR
## 副歌段光柱打满，主歌 / 过渡收一点
const CHORUS_BARS := [[16, 32], [40, 56]]

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
## 空按（附近没音符也按了）的惩罚：计一次烂、连击归零、扣这么多分。
## 没有这条的话，狂点或者四个键一起按就能白吃所有音符。
const WHIFF_PENALTY := 2
## 同一条轨道上两个音符的最小间隔，必须大于判定窗口，
## 否则玩家打掉前一个之后，后一个在窗口里已经无音符可配，必漏。
const MIN_LANE_GAP := MISS_WINDOW + 0.06

## 曲子路径。文件名不一样也没关系，找不到会自动扫 Assets/Branch/ 里的音频。
const MUSIC_PATH := "res://Assets/Branch/可爱的小曲.wav"
const MUSIC_DIR := "res://Assets/Branch/"
const MUSIC_EXTS := ["ogg", "wav", "mp3"]

## 谱面用"图案"拼，不是随机撒点。
## 一个图案 = 一小节 4 拍的方向序列（相对根方向的偏移，0=根，1=根的下一个……）。
## 同一个图案会连着重复 phrase 小节再换——重复才好记、好跟，
## 也是"频率加上去但难度不加上去"的办法：4 个一样的箭头连着按，密但不难。
const PATTERNS := {
	"连打": [0, 0, 0, 0],   # 同一个方向连按四下，最好跟
	"两两": [0, 0, 1, 1],   # 两下一换
	"交替": [0, 1, 0, 1],   # 两个方向来回
	"扫过": [0, 1, 2, 3],   # 四个方向扫一遍
}

## 段落跟着曲式：主歌 1-16、副歌 17-32、过渡 33-40、第二次副歌 41-56。
## per_bar = 每小节几个音符（2 = 只打第 1、3 拍；4 = 每拍都打）
## patterns = 这段允许哪几种图案；phrase = 同一个图案连续几小节再换
## bars 合计必须正好是 BARS。全部音符都在正拍上，没有八分切分。
const SECTIONS := [
	{bars = 16, per_bar = 2, patterns = ["连打", "两两"], phrase = 4},                  # 主歌：最简单
	{bars = 16, per_bar = 4, patterns = ["连打", "两两"], phrase = 4},                  # 副歌：密但只有连打和两两
	{bars = 8, per_bar = 2, patterns = ["连打", "交替"], phrase = 4},                   # 过渡：喘口气，开始有交替
	{bars = 16, per_bar = 4, patterns = ["连打", "两两", "交替", "扫过"], phrase = 2},  # 副歌2：图案最全、换得最勤
]

## 前奏打几拍节拍再起曲子。第一个箭头正好在第 0 拍到判定线，曲子也在那一刻响。
const LEAD_IN_BEATS := 8
const LEAD_IN := BEAT * LEAD_IN_BEATS

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
var _disco: Array[ShaderMaterial] = []   # 两层交叉的光柱
var _disco_color: Array[Color] = []       # 每层当前颜色（被 tween 推着走）
var _bg_tint := Color(0.055, 0.055, 0.075)
var _energy := 0.6                        # 副歌 1.0 / 其他 0.6，换段时 tween
var _bar_seen := -1
var _tint_tweens: Array[Tween] = []
const BG_BASE := Color(0.055, 0.055, 0.075)
var _music_started := false
var _finishing := false
var _count_label: Label


func _ready() -> void:
	draw_obstacle_blocks = false
	draw_ground_line = false
	_chart = _build_chart()
	_build_stage()
	_build_disco()
	_setup_music()
	_sides = [_make_side(0), _make_side(1)]
	_start()


func _start() -> void:
	# 时间轴从 -LEAD_IN 开始走：前面 8 拍只打节拍、数 3-2-1，箭头先滚进来；
	# 第一个箭头到判定线的那一刻（第 0 拍）曲子才响。
	_elapsed = -LEAD_IN
	_next_beat = -LEAD_IN
	running = true


## 前奏每一拍：打节拍音，隔一拍报一个数。
func _count_in_beat(beat_time: float) -> void:
	var idx := roundi(beat_time / BEAT)          # -8 … -1
	var downbeat := posmod(idx, BEATS_PER_BAR) == 0
	Sfx.play(self, Sfx.blip(1046.0 if downbeat else 740.0, 1000.0 if downbeat else 700.0, 0.045, 0.32))
	match idx:
		-8:
			_show_count("3")
		-6:
			_show_count("2")
		-4:
			_show_count("1")
		-2:
			_show_count("开始!")


func _show_count(text: String) -> void:
	if _count_label == null:
		_count_label = make_hud_label("", 0.0, 120.0, 640.0, 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_count_label.text = text
	_pulse_in(_count_label, 0.3 if text == "开始!" else 0.22)
	if text == "开始!":
		var out := _count_label.create_tween()
		out.tween_interval(0.6)
		out.tween_property(_count_label, "modulate:a", 0.0, 0.25)
		out.tween_callback(_count_label.queue_free)


func _start_music() -> void:
	_music_started = true
	if _music != null:
		_music.play()


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


## 按 SECTIONS 把图案铺到 56 小节上。固定种子，两边拿到的谱面完全一样。
func _build_chart() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260902
	var notes := []
	var bar := 0
	var root := rng.randi_range(0, 3)
	for sec: Dictionary in SECTIONS:
		var per_bar: int = int(sec.per_bar)
		var names: Array = sec.patterns
		var phrase: int = int(sec.phrase)
		var step_beats := float(BEATS_PER_BAR) / float(per_bar)
		var b := 0
		while b < int(sec.bars):
			# 换一个图案、根方向和上一句错开，然后连着用 phrase 小节
			var pname: String = names[rng.randi_range(0, names.size() - 1)]
			var pat: Array = PATTERNS[pname]
			# 半拍时只用图案的前两位，"两两"[0,0,1,1] 会退化成 [0,0]——
			# 凡是这一小节里全是同一个方向的，都按"连打"处理：每 4 个音符换方向
			var flat := true
			for i in per_bar:
				if int(pat[i]) != int(pat[0]):
					flat = false
			root = (root + rng.randi_range(1, 3)) % 4
			var run: int = mini(phrase, int(sec.bars) - b)
			var emitted := 0
			for _k in run:
				for i in per_bar:
					# "连打"每 4 个音符换一个方向：要的是"4 个一样"，不是同一个键按 16 下
					if flat and emitted > 0 and emitted % 4 == 0:
						root = (root + rng.randi_range(1, 3)) % 4
					notes.append({
						time = bar * BAR + i * step_beats * BEAT,
						lane = (root + int(pat[i])) % 4,
					})
					emitted += 1
				bar += 1
				b += 1
	if bar != BARS:
		push_warning("谱面小节数对不上：SECTIONS 合计 %d，应为 %d" % [bar, BARS])
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


func _build_stage() -> void:
	# 中间的电梯：和电梯场景结尾一样用原尺寸，两人隔着它斗舞
	var sprite := Sprite2D.new()
	sprite.texture = ELEVATOR_TEX
	sprite.position = Vector2(320.0, GROUND_Y + 4.0 - ELEVATOR_TEX.get_height() * 0.5)
	sprite.modulate = Color(0.62, 0.6, 0.66)
	add_child(sprite)


## 迪斯科灯：两层 light_shafts 交叉打，颜色每小节换、强度每拍冲一下、角度慢慢扫。
## 铺在人物上面（z 3），又在反光地板下面（z 5），所以地板会把光柱倒映出来。
func _build_disco() -> void:
	for i in 2:
		var mat := ShaderMaterial.new()
		mat.shader = SHAFT_SHADER
		mat.set_shader_parameter("beam_count", 4)
		mat.set_shader_parameter("beam_pos_a", -0.28 + i * 0.1)
		mat.set_shader_parameter("beam_pos_b", 0.18 - i * 0.1)
		mat.set_shader_parameter("spread", 1.4)
		mat.set_shader_parameter("seed", 3.0 + i * 5.0)
		mat.set_shader_parameter("shaft_w", 0.07)
		mat.set_shader_parameter("sway", 0.03)
		mat.set_shader_parameter("sway_speed", 0.6)
		mat.set_shader_parameter("fade_start", -0.2)
		mat.set_shader_parameter("fade_end", 1.3)
		mat.set_shader_parameter("dust_amount", 0.35)
		mat.set_shader_parameter("dust_scale", 26.0)
		mat.set_shader_parameter("dust_speed", 0.2)
		mat.set_shader_parameter("pulse_amount", 0.0)
		mat.set_shader_parameter("intensity", 0.0)
		mat.set_shader_parameter("aspect", Vector2(1.7778, 1.0))
		mat.set_shader_parameter("clip_enable", 0.0)
		mat.set_shader_parameter("angle_deg", -30.0 + i * 60.0)
		var rect := ColorRect.new()
		rect.name = "Disco%d" % i
		rect.material = mat
		rect.size = Vector2(640.0, 360.0)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.z_index = 3
		add_child(rect)
		_disco.append(mat)
		_disco_color.append(Color.from_hsv(0.5 * i, 0.75, 1.0))
		_tint_tweens.append(null)


func _in_chorus(bar: int) -> bool:
	for r in CHORUS_BARS:
		if bar >= int(r[0]) and bar < int(r[1]):
			return true
	return false


## 换小节：给每层灯、背景算新目标色，用 tween 推过去；进/出副歌时亮度也用一小节缓过去。
func _retint(bar: int) -> void:
	for i in _disco.size():
		var hue := fmod(float(bar) * 0.17 + float(i) * 0.5, 1.0)
		var target := Color.from_hsv(hue, 0.75, 1.0)
		if _tint_tweens[i] != null and _tint_tweens[i].is_valid():
			_tint_tweens[i].kill()
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_method(_set_disco_color.bind(i), _disco_color[i], target, TINT_TWEEN)
		_tint_tweens[i] = tw
	var bg_target := Color.from_hsv(fmod(float(bar) * 0.17, 1.0), 0.6, 0.35)
	var bg_tw := create_tween()
	bg_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bg_tw.tween_property(self, "_bg_tint", bg_target, TINT_TWEEN)
	var energy_target := 1.0 if _in_chorus(bar) else 0.6
	if not is_equal_approx(energy_target, _energy):
		var en_tw := create_tween()
		en_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		en_tw.tween_property(self, "_energy", energy_target, ENERGY_TWEEN)


func _set_disco_color(c: Color, i: int) -> void:
	_disco_color[i] = c
	_disco[i].set_shader_parameter("light_color", c)


## 每帧按谱面时钟驱动灯光和人物的律动。
func _drive_disco(delta: float) -> void:
	var t := _elapsed
	var beat_pos := t / BEAT
	var frac := beat_pos - floorf(beat_pos)
	var bar := maxi(int(floorf(t / BAR)), 0)
	# 起曲前灯只留一点底光，不抢倒计时
	var started := _music_started and t >= 0.0
	var kick := exp(-frac * 5.0) if started else 0.0
	if started and bar != _bar_seen:
		_bar_seen = bar
		_retint(bar)
	for i in _disco.size():
		var mat := _disco[i]
		var base := 0.22 if started else 0.12
		mat.set_shader_parameter("intensity", (base + 0.85 * kick) * _energy)
		var ang := (-30.0 + i * 60.0) + 24.0 * sin(t * 0.7 + i * PI)
		mat.set_shader_parameter("angle_deg", ang)
	# 背景跟着拍子染一点当前色（目标色本身是 tween 过去的），整个画面一起呼吸
	bg_color = BG_BASE.lerp(_bg_tint, 0.35 * kick * _energy) if started else BG_BASE
	# 人物：每拍小幅点头，打中时弹一下并闪白
	for side in _sides:
		side.punch = maxf(float(side.punch) - delta * 4.5, 0.0)
		var fig: Node2D = side.fig
		var sc := 1.0 + 0.045 * kick + 0.16 * float(side.punch)
		fig.scale = Vector2(sc, sc)
		var w := 1.0 + 0.9 * float(side.punch)
		fig.modulate = Color(w, w, w)


func _make_side(idx: int) -> Dictionary:
	var side := {
		score = 0,
		combo = 0,
		miss = 0,
		xs = LANE_XS[idx],
		keymap = {KEY_A: 0, KEY_S: 1, KEY_W: 2, KEY_D: 3} if idx == 0 \
			else {KEY_LEFT: 0, KEY_DOWN: 1, KEY_UP: 2, KEY_RIGHT: 3},
		arrow_key = "绿箭头" if idx == 0 else "红箭头",
		flash = [0.0, 0.0, 0.0, 0.0],
		punch = 0.0,          # 打中后的弹跳量，每帧衰减
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
		Vector2(DANCER_X[idx], GROUND_Y),
	)
	var fig: Node2D = side.fig
	fig.char_scale = DANCER_SCALE
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
	_drive_disco(delta)
	if not running:
		return
	if _music_started and _music != null and _music.playing:
		# 曲子响起之后，时间轴一律以音频位置为准
		_elapsed = _chart_time()
	else:
		_elapsed += delta
		if not _music_started:
			# 前奏：打节拍、数拍子；第 0 拍第一个箭头到判定线，曲子响
			while _next_beat <= _elapsed and _next_beat < 0.0:
				_count_in_beat(_next_beat)
				_next_beat += BEAT
			if _elapsed >= 0.0:
				_start_music()
		if _music == null:
			# 没曲子的时候整首都用节拍音顶着，方便不带音乐调玩法
			while _next_beat <= _elapsed and _next_beat <= _last_note_time + 0.01:
				Sfx.play(self, Sfx.blip(175.0, 165.0, 0.05, 0.2))
				_next_beat += BEAT
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
		# 空按。起曲之前（还在数拍子）随便试键不罚
		if _elapsed >= -MISS_WINDOW:
			side.miss += 1
			side.combo = 0
			side.score = maxi(int(side.score) - WHIFF_PENALTY, 0)
			_popup(side, lane, "乱按!", Color(0.75, 0.45, 0.4))
			side.fig.strike(CharSprite.Pose.MISS, 0.25)
			Sfx.play(self, Sfx.blip(160.0, 110.0, 0.09, 0.22))
			_refresh_score(side)
		return
	best.judged = true
	var d := absf(best_dt)
	side.punch = 1.0
	var fig_pos: Vector2 = side.fig.position
	var burst_col := Color(0.5, 0.9, 0.45) if side.arrow_key == "绿箭头" else Color(1.0, 0.45, 0.35)
	if d <= PERFECT_WINDOW:
		Fx.hit_burst(self, fig_pos + Vector2(0, -side.fig.body_height() * 0.62), burst_col, 18, 1.1)
		side.score += 5
		side.combo += 1
		_popup(side, lane, "完美!", Color(1.0, 0.85, 0.3))
		Sfx.play(self, Sfx.blip(1046.0, 1200.0, 0.08, 0.3))
	elif d <= GOOD_WINDOW:
		Fx.hit_burst(self, fig_pos + Vector2(0, -side.fig.body_height() * 0.62), burst_col, 10, 0.7)
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
