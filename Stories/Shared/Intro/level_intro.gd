extends CanvasLayer
## 每一关开始前的像素标题 + 操作 / 规则确认页。
##
## 《第X关》先 tween 弹出来再缩到顶上；然后两栏按键说明（女生 / 男生）一条条出现，
## 每条都要把对应的键真按一下才变绿、才出下一条；两栏都按完了再出规则，
## 规则条按空格确认；最后按空格开始。全程小声放 time.mp3。
##
## 用法：
##   var intro := LevelIntro.new(); add_child(intro)
##   await intro.run(1, "扔物大战", p1_lines, p2_lines, rules)
## 每条 line 是 {text = "A  往左走", keys = [KEY_A]}；keys 为空的键位条不用按、直接算过。

signal finished

const PIXEL_FONT := preload("res://Assets/Theme/像素字体.ttf")
const Sfx := preload("res://Stories/Phases/Shared/retro_sfx.gd")
const MUSIC_PATH := "res://Assets/Branch/time.mp3"
const MUSIC_DB := -16.0

const COL_X := [36.0, 340.0]
const COL_W := 264.0
const ROW_H := 24.0
const KEYS_Y := 86.0
const RULES_Y := 214.0
const LINE_SIZE := 16
const CONFIRM_KEYS := [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]

const TITLE_COLOR := Color(1.0, 0.93, 0.6)
const HEAD_COLOR := [Color(0.62, 0.7, 0.95), Color(0.95, 0.7, 0.35)]   # 女生蓝 / 男生赭
const DIM := Color(0.55, 0.55, 0.6)
const LIT := Color(1.0, 1.0, 1.0)
const OK := Color(0.45, 0.95, 0.5)
const PENDING_MARK := "→ "
const DONE_MARK := "√ "

var _root: Control
var _music: AudioStreamPlayer
var _blink := 0.0
## 每一栏的进度：{lines, labels, index, done}
var _columns: Array[Dictionary] = []
var _rules: Array = []
var _rule_labels: Array[Label] = []
var _rule_index := -1
var _rules_active := false
var _rule_waiting := false
var _final_label: Label
var _final_active := false
var _done := false


func _ready() -> void:
	layer = 60
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.045)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)


func _process(delta: float) -> void:
	# 等着被按的那条箭头一闪一闪，告诉人"现在轮到这条"
	_blink += delta
	var a := 0.55 + 0.45 * (0.5 + 0.5 * sin(_blink * 7.0))
	for col in _columns:
		if not col.done and col.index < col.labels.size():
			col.labels[col.index].modulate.a = a
	if _rule_waiting and _rule_index >= 0 and _rule_index < _rule_labels.size():
		_rule_labels[_rule_index].modulate.a = a
	if _final_active and _final_label != null:
		_final_label.modulate.a = a


func run(
	level_no: int,
	subtitle: String,
	p1_lines: Array,
	p2_lines: Array,
	rules: Array,
	p2_heading := "男生  P2",
	title_text := "",
) -> void:
	_start_music()
	await _show_title(level_no, subtitle, title_text)
	if not is_inside_tree():
		return

	_rules = rules
	_columns.clear()
	_columns.append(_make_column(0, "女生  P1", p1_lines))
	_columns.append(_make_column(1, p2_heading, p2_lines))
	for col in _columns:
		_reveal_next_key(col)
		await get_tree().create_timer(0.15).timeout
	_check_keys_done()
	await finished


func _exit_tree() -> void:
	if _music != null and _music.playing:
		_music.stop()


# ---------- 标题 ----------

## title_text 不为空就用它当标题（隐藏关《不如跳舞》），否则按关数写《第X关》
func _show_title(level_no: int, subtitle: String, title_text := "") -> void:
	var names := ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
	if title_text == "":
		title_text = "《第%s关》" % names[clampi(level_no, 0, 9)]
	var title := _label(title_text, 0.0, 158.0, 640.0, 30, TITLE_COLOR)
	title.add_theme_constant_override("outline_size", 5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.pivot_offset = title.size * 0.5
	title.scale = Vector2(0.1, 0.1)
	title.modulate.a = 0.0

	Sfx.play(self, Sfx.blip(180.0, 540.0, 0.4, 0.45), -4.0)
	var pop := create_tween()
	pop.set_parallel(true)
	pop.tween_property(title, "modulate:a", 1.0, 0.3)
	pop.tween_property(title, "scale", Vector2(2.0, 2.0), 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop.finished
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree():
		return

	# 缩到顶上让位，副标题跟着亮出来
	var park := create_tween()
	park.set_parallel(true)
	park.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	park.tween_property(title, "scale", Vector2.ONE, 0.5)
	park.tween_property(title, "position", Vector2(0.0, 6.0), 0.5)
	await park.finished
	var sub := _label(subtitle, 0.0, 46.0, 640.0, 14, DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate.a = 0.0
	Sfx.play(self, Sfx.blip(600.0, 900.0, 0.06, 0.3), -8.0)
	sub.create_tween().tween_property(sub, "modulate:a", 1.0, 0.25)
	await get_tree().create_timer(0.35).timeout


# ---------- 按键栏 ----------

func _make_column(idx: int, heading: String, lines: Array) -> Dictionary:
	if not lines.is_empty():
		var head := _label(heading, COL_X[idx], KEYS_Y - 24.0, COL_W, 13, HEAD_COLOR[idx])
		head.modulate.a = 0.0
		head.create_tween().tween_property(head, "modulate:a", 1.0, 0.25)
	var col := {lines = lines, labels = [], index = 0, done = lines.is_empty(), x = COL_X[idx]}
	return col


func _reveal_next_key(col: Dictionary) -> void:
	if col.done:
		return
	var i: int = col.index
	if i >= col.lines.size():
		col.done = true
		_check_keys_done()
		return
	var line: Dictionary = col.lines[i]
	var needs_key: bool = not line.get("keys", []).is_empty()
	var lbl := _label(
		(PENDING_MARK if needs_key else "   ") + str(line.text),
		float(col.x), KEYS_Y + i * ROW_H, COL_W, LINE_SIZE,
		LIT if needs_key else DIM,
	)
	_slide_in(lbl)
	Sfx.play(self, Sfx.blip(600.0, 900.0, 0.06, 0.3), -8.0)
	col.labels.append(lbl)
	if not needs_key:
		# 不用按的条目（比如"由电脑控制"）直接算过，接着出下一条
		col.index += 1
		await get_tree().create_timer(0.35).timeout
		_reveal_next_key(col)


func _confirm_key(col: Dictionary) -> void:
	var lbl: Label = col.labels[col.index]
	var line: Dictionary = col.lines[col.index]
	lbl.text = DONE_MARK + str(line.text)
	lbl.modulate.a = 1.0
	lbl.add_theme_color_override("font_color", OK)
	_bump(lbl)
	Sfx.play(self, Sfx.blip(880.0, 1320.0, 0.09, 0.4), -6.0)
	col.index += 1
	await get_tree().create_timer(0.28).timeout
	_reveal_next_key(col)


func _check_keys_done() -> void:
	for col in _columns:
		if not col.done:
			return
	if _rules_active:
		return
	_rules_active = true
	_start_rules()


# ---------- 规则 ----------

func _start_rules() -> void:
	await get_tree().create_timer(0.4).timeout
	if _rules.is_empty():
		_show_final()
		return
	var head := _label("规则", COL_X[0], RULES_Y - 24.0, 200.0, 13, TITLE_COLOR)
	head.modulate.a = 0.0
	head.create_tween().tween_property(head, "modulate:a", 1.0, 0.25)
	await get_tree().create_timer(0.3).timeout
	_reveal_next_rule()


func _reveal_next_rule() -> void:
	_rule_index += 1
	if _rule_index >= _rules.size():
		_show_final()
		return
	var lbl := _label(
		PENDING_MARK + str(_rules[_rule_index]),
		COL_X[0], RULES_Y + _rule_index * ROW_H, 640.0 - COL_X[0] * 2.0, LINE_SIZE, LIT,
	)
	_slide_in(lbl)
	Sfx.play(self, Sfx.blip(600.0, 900.0, 0.06, 0.3), -8.0)
	_rule_labels.append(lbl)
	_rule_waiting = true


func _confirm_rule() -> void:
	if not _rule_waiting:
		return
	_rule_waiting = false
	var lbl := _rule_labels[_rule_index]
	lbl.text = DONE_MARK + str(_rules[_rule_index])
	lbl.modulate.a = 1.0
	lbl.add_theme_color_override("font_color", OK)
	_bump(lbl)
	Sfx.play(self, Sfx.blip(880.0, 1320.0, 0.09, 0.4), -6.0)
	await get_tree().create_timer(0.28).timeout
	_reveal_next_rule()


func _show_final() -> void:
	await get_tree().create_timer(0.3).timeout
	_final_label = _label("都明白了？  按 空格 开始！", 0.0, 322.0, 640.0, 15, TITLE_COLOR)
	_final_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slide_in(_final_label)
	Sfx.play(self, Sfx.blip(660.0, 990.0, 0.1, 0.35), -6.0)
	_final_active = true


func _finish() -> void:
	_done = true
	_final_active = false
	Sfx.play(self, Sfx.blip(880.0, 900.0, 0.16, 0.4), -4.0)
	if _music != null:
		var mt := create_tween()
		mt.tween_property(_music, "volume_db", -40.0, 0.5)
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.45)
	await tw.finished
	finished.emit()
	queue_free()


# ---------- 输入 ----------

func _input(event: InputEvent) -> void:
	if _done:
		return
	var key_event: bool = event is InputEventKey and event.pressed and not event.echo
	var click: bool = event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT
	if not key_event and not click:
		return

	if key_event:
		# 两栏各自等自己的键，谁按对了谁那栏往下走
		for col in _columns:
			if col.done or col.index >= col.labels.size():
				continue
			var line: Dictionary = col.lines[col.index]
			if line.get("keys", []).has(event.physical_keycode):
				_confirm_key(col)
				get_viewport().set_input_as_handled()
				return

	var confirm: bool = click or (key_event and CONFIRM_KEYS.has(event.physical_keycode))
	if not confirm:
		return
	if _final_active:
		_finish()
	elif _rule_waiting:
		_confirm_rule()
	get_viewport().set_input_as_handled()


# ---------- 小工具 ----------

func _label(text: String, x: float, y: float, w: float, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", PIXEL_FONT)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(x, y)
	lbl.size = Vector2(w, size + 10.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lbl)
	return lbl


## 从左边滑 12px 进来 + 淡入
func _slide_in(lbl: Label) -> void:
	var home := lbl.position
	lbl.position = home + Vector2(-12.0, 0.0)
	lbl.modulate.a = 0.0
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.18)
	tw.tween_property(lbl, "position", home, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## 确认时弹一下
func _bump(lbl: Label) -> void:
	lbl.pivot_offset = Vector2(0.0, lbl.size.y * 0.5)
	lbl.scale = Vector2(1.12, 1.12)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _start_music() -> void:
	if not ResourceLoader.exists(MUSIC_PATH):
		return
	var stream: AudioStream = load(MUSIC_PATH)
	if stream == null:
		return
	if "loop" in stream:
		stream.set("loop", true)
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = -40.0
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", MUSIC_DB, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
