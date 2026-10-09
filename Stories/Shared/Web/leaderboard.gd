extends CanvasLayer
## 选线界面里的「排行榜」（只在网页版出现），用 Toy 的排行榜。
##   1～4 号榜：四首歌各自的最高得分        5 号榜：集齐了几个结局
## Toy 的规则是同分先达成的排前面、名次不并列，所以结局榜的第一名就是最先集齐的人。
##
## 打开时先把本地还没上报的成绩一个个报上去（submitScore 第一次会弹平台的数据确认窗，
## 所以只在玩家自己点开排行榜时报，不在剧情里报），再读当前这一页的前 7 名和自己的名次。
## 每页读一次就缓存，不轮询：Toy 的排行榜全体玩家共享频率额度。
## 隐藏关的三首歌没跳过之前，标签写「？？？」，不剧透。
## Esc / 点「返回」关掉，发 closed。

signal closed

const PIXEL_FONT := preload("res://Assets/Theme/像素字体.ttf")
const Sfx := preload("res://Stories/Phases/Shared/retro_sfx.gd")
const TITLE_COLOR := Color(1.0, 0.93, 0.6)
const DIM := Color(0.5, 0.5, 0.56)
const TEXT := Color(0.82, 0.82, 0.86)
const LIT := Color(1.0, 1.0, 1.0)
const MINE := Color(0.62, 0.7, 0.95)
const ROWS := 7
const ROW_TOP := 112.0
const ROW_H := 23.0
const TAB_Y := 58.0
const NAME_LEN := 10

var _root: Control
var _tabs: Array[Label] = []
var _caption: Label
var _rows: Array[Array] = []    # [名次, 昵称, 分数] 三个 Label 一行
var _me: Label
var _back: Label
var _board := 1
var _cache := {}                # 榜位 -> {list, mine}
var _submitted := false
var _failed := {}               # 没报上去的榜位 -> 原因（多半是没登录）
var _busy := false
var _done := false


func _ready() -> void:
	layer = 62
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.045)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var title := _label("排 行 榜", 0.0, 14.0, 640.0, 26, TITLE_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 5)
	var n := SaveData.SONG_BOARDS.size() + 1
	for i in n:
		var tab := _label("", 20.0 + i * 600.0 / n, TAB_Y, 600.0 / n, 13, DIM, HORIZONTAL_ALIGNMENT_CENTER)
		_tabs.append(tab)
	_caption = _label("", 0.0, 84.0, 640.0, 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	for i in ROWS:
		var y := ROW_TOP + i * ROW_H
		_rows.append([
			_label("", 150.0, y, 40.0, 14, TEXT, HORIZONTAL_ALIGNMENT_RIGHT),
			_label("", 206.0, y, 200.0, 14, TEXT, HORIZONTAL_ALIGNMENT_LEFT),
			_label("", 400.0, y, 90.0, 14, TEXT, HORIZONTAL_ALIGNMENT_RIGHT),
		])
	_me = _label("", 0.0, 282.0, 640.0, 13, MINE, HORIZONTAL_ALIGNMENT_CENTER)
	var hint := "返回" if TouchPad.active else "Esc  返回"
	_back = _label(hint, 0.0, 318.0, 640.0, 14, TEXT, HORIZONTAL_ALIGNMENT_CENTER)

	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.25)
	_show_board(1)
	_submit_then_load()


func _label(text: String, x: float, y: float, w: float, size: int, color: Color, align: HorizontalAlignment) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", PIXEL_FONT)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(x, y)
	lbl.size = Vector2(w, size + 10.0)
	lbl.horizontal_alignment = align
	lbl.clip_text = true
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lbl)
	return lbl


# ---------- 页面 ----------

func _tab_name(board: int) -> String:
	if board == SaveData.ENDINGS_BOARD:
		return "结局收集"
	var song: String = SaveData.SONG_BOARDS[board - 1]
	# 主线那首一定见过；隐藏关的三首跳过了、或者打通过木木线才露名字
	var seen := board == 1 or SaveData.dance_best.has(song) or SaveData.has_ending("mumu")
	return song if seen else "？？？"


func _show_board(board: int) -> void:
	_board = board
	for i in _tabs.size():
		var on := i + 1 == board
		_tabs[i].text = ("[%s]" if on else "%s") % _tab_name(i + 1)
		_tabs[i].add_theme_color_override("font_color", LIT if on else DIM)
	if board == SaveData.ENDINGS_BOARD:
		_caption.text = "集齐了几个结局（共 %d 个）· 一样多的，先集齐的排前面" % SaveData.ENDINGS.size()
	else:
		_caption.text = "这首歌的最高得分 · 同分的，先跳出来的排前面"
	_fill()
	if _submitted and not _cache.has(board):
		_load(board)


func _fill() -> void:
	for row in _rows:
		for lbl: Label in row:
			lbl.text = ""
	var mine_local := SaveData.board_score(_board)
	var unit := " 个" if _board == SaveData.ENDINGS_BOARD else ""
	if not _cache.has(_board):
		_rows[0][1].text = "加载中……"
		_me.text = ""
		return
	var got: Dictionary = _cache[_board]
	if got.has("error"):
		_rows[0][1].text = "排行榜加载失败，稍后再试。"
	else:
		var list: Array = got.list
		if list.is_empty():
			_rows[0][1].text = "还没有人上榜。"
		for i in mini(list.size(), ROWS):
			var e = list[i]
			if not (e is Dictionary):
				continue
			_rows[i][0].text = str(int(e.get("rank", i + 1)))
			_rows[i][1].text = _printable(str(e.get("nickname", "")))
			_rows[i][2].text = str(int(e.get("score", 0))) + unit
	var mine = got.get("mine")
	if mine is Dictionary and bool(mine.get("ranked", false)):
		_me.text = "你：第 %d 名  ·  %d%s" % [int(mine.rank), int(mine.score), unit]
	elif mine_local <= 0:
		_me.text = "你还没有成绩。" if _board != SaveData.ENDINGS_BOARD else "你还没有达成结局。"
	elif str(got.get("submit", "ok")) != "ok":
		_me.text = "你的成绩 %d%s  ·  登录 B 站后才能上榜" % [mine_local, unit]
	else:
		_me.text = "你的成绩 %d%s  ·  还没挤进榜单" % [mine_local, unit]


## 昵称里像素字体没有的字（表情之类）换成 ?，太长的截掉
func _printable(s: String) -> String:
	var out := ""
	for i in s.length():
		var c := s.unicode_at(i)
		out += char(c) if PIXEL_FONT.has_char(c) else "?"
	return out.left(NAME_LEN - 1) + "…" if out.length() > NAME_LEN else out


# ---------- Toy ----------

func _submit_then_load() -> void:
	var jobs: Array = []
	for board in range(1, SaveData.ENDINGS_BOARD + 1):
		if SaveData.needs_report(board):
			jobs.append([board, SaveData.board_score(board)])
	if jobs.is_empty():
		_on_submitted({status = "ok", data = {}}, jobs)
		return
	# 一个接一个地报（一起报的话，平台的确认窗可能弹好几次）
	Toy.call_toy("rank_submit", """var jobs = %s, out = {};
		return jobs.reduce(function (p, j) {
			return p.then(function () {
				return toy.submitScore({ board: j[0], score: j[1] }).then(
					function () { out[j[0]] = 'ok'; },
					function (e) { out[j[0]] = String((e && (e.message || e.type)) || e); });
			});
		}, Promise.resolve()).then(function () { return out; });""" % JSON.stringify(jobs),
		_on_submitted.bind(jobs))


func _on_submitted(answer: Dictionary, jobs: Array) -> void:
	if _done:
		return
	_submitted = true
	var out = answer.get("data")
	for j in jobs:
		var result := "error"
		if out is Dictionary:
			result = str(out.get(str(j[0]), "error"))
		if result == "ok":
			SaveData.mark_reported(int(j[0]), int(j[1]))
		else:
			_failed[int(j[0])] = result
	_load(_board)


func _load(board: int) -> void:
	if _busy:
		return
	_busy = true
	Toy.call_toy("rank_%d" % board, """return Promise.all([
			toy.getRankList({ board: %d, period: 'all', limit: %d }),
			toy.getMyRank({ board: %d, period: 'all' }).catch(function () { return null; }),
		]).then(function (r) { return { list: r[0], mine: r[1] }; });""" % [board, ROWS, board],
		_on_loaded.bind(board))


func _on_loaded(r: Dictionary, board: int) -> void:
	_busy = false
	if _done:
		return
	if r.get("status") != "ok" or not (r.get("data") is Dictionary) or not (r.data.get("list") is Array):
		_cache[board] = {error = str(r.get("error", ""))}
	else:
		_cache[board] = {list = r.data.list, mine = r.data.get("mine"), submit = _failed.get(board, "ok")}
	if board == _board:
		_fill()
	elif not _cache.has(_board):
		_load(_board)


# ---------- 输入 ----------

func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE, KEY_BACKSPACE:
				_close()
			KEY_LEFT, KEY_A:
				_step(-1)
			KEY_RIGHT, KEY_D:
				_step(1)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if _back.get_global_rect().grow(8.0).has_point(event.position):
			_close()
			return
		for i in _tabs.size():
			if _tabs[i].get_global_rect().grow_individual(0, 8, 0, 8).has_point(event.position) and i + 1 != _board:
				Sfx.play(self, Sfx.blip(520.0, 560.0, 0.04, 0.25), -10.0)
				_show_board(i + 1)
				return


func _step(d: int) -> void:
	Sfx.play(self, Sfx.blip(520.0, 560.0, 0.04, 0.25), -10.0)
	_show_board(posmod(_board - 1 + d, _tabs.size()) + 1)


func _close() -> void:
	_done = true
	Sfx.play(self, Sfx.blip(660.0, 330.0, 0.12, 0.4), -6.0)
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.25)
	await tw.finished
	closed.emit()
	queue_free()
