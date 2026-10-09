extends CanvasLayer
## 游戏一开始的像素标题菜单：游戏名 tween 进场，选「单人 / 双人」。
## 底下还有一条灰掉的「开发者模式」，光标跳不上去、鼠标也点不了，
## 但在这个菜单里按 F8 就能进（回到按 1～9 单独测试各段的模式）。
## 用法：var menu := TitleMenu.new(); add_child(menu); var mode: int = await menu.mode_chosen
## 按 Esc 会发 Mode.BACK（回选线界面）。选线界面也是这个菜单，add_child 之前改掉下面几个 var 就行。

signal mode_chosen(mode: int)

enum Mode { SINGLE, DUO, DEV, BACK = -1 }

const PIXEL_FONT := preload("res://Assets/Theme/像素字体.ttf")
const Sfx := preload("res://Stories/Phases/Shared/retro_sfx.gd")

const LOCKED := Color(0.26, 0.26, 0.3)
const TITLE_COLOR := Color(1.0, 0.93, 0.6)
const DIM := Color(0.5, 0.5, 0.56)
const LIT := Color(1.0, 1.0, 1.0)

## 游戏名，改这里就行
var game_title := "电梯风云"
var subtitle := "选 择 模 式"
var options: Array[String] = ["单人", "双人", "开发者模式"]
var option_hints: Array[String] = [
	"你操控女生，男生交给电脑",
	"两个人各管一个，正面对决",
]
## 从这一项开始（含）都是灰的，选不了；F8 暗门直达最后一项。等于 options.size() 就是没有灰的、也没有暗门。
var locked_from: int = Mode.DEV
## 能不能按 Esc 回选线界面（选线界面自己就是入口，关掉）
var can_go_back := true

var _root: Control
var _title: Label
var _option_labels: Array[Label] = []
var _hint: Label
var _selected := 0
var _ready_for_input := false
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

	_title = _label(game_title, 0.0, 78.0, 640.0, 48, TITLE_COLOR)
	_title.add_theme_constant_override("outline_size", 6)

	var sub := _label(subtitle, 0.0, 168.0, 640.0, 14, DIM)
	sub.modulate.a = 0.0

	for i in options.size():
		var locked := i >= locked_from
		var lbl := _label(options[i], 0.0, 200.0 + i * 34.0, 640.0, 16 if locked else 22, LOCKED if locked else DIM)
		if locked:
			lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		lbl.modulate.a = 0.0
		_option_labels.append(lbl)

	_hint = _label("", 0.0, 318.0, 640.0, 12, DIM)
	_hint.modulate.a = 0.0

	if can_go_back:
		var back := _label("Esc 返回选线", 8.0, 6.0, 200.0, 12, LOCKED)
		back.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	_animate_in(sub)


func _label(text: String, x: float, y: float, w: float, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", PIXEL_FONT)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(x, y)
	lbl.size = Vector2(w, size + 14.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lbl)
	return lbl


func _animate_in(sub: Label) -> void:
	# 游戏名：从一个点弹开，再落定
	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2(0.1, 0.1)
	_title.modulate.a = 0.0
	Sfx.play(self, Sfx.blip(220.0, 660.0, 0.35, 0.4), -4.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_title, "modulate:a", 1.0, 0.35)
	tw.tween_property(_title, "scale", Vector2.ONE, 0.75) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not is_inside_tree():
		return

	# 副标题和选项一条条淡出来，每条一声
	await _fade_in(sub, 0.2)
	for lbl in _option_labels:
		Sfx.play(self, Sfx.blip(600.0, 900.0, 0.06, 0.3), -8.0)
		await _fade_in(lbl, 0.18)
	_refresh()
	await _fade_in(_hint, 0.3)
	_ready_for_input = true


func _fade_in(lbl: Label, duration: float) -> void:
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, duration)
	await tw.finished


func _refresh() -> void:
	for i in locked_from:
		var lbl := _option_labels[i]
		var on := i == _selected
		lbl.text = ("→ %s ←" % options[i]) if on else options[i]
		lbl.add_theme_color_override("font_color", LIT if on else DIM)
		if on:
			lbl.pivot_offset = lbl.size * 0.5
			lbl.scale = Vector2(1.12, 1.12)
			var tw := lbl.create_tween()
			tw.tween_property(lbl, "scale", Vector2.ONE, 0.18) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			lbl.scale = Vector2.ONE
	_hint.text = option_hints[_selected] + "      W/S 或 ↑/↓ 选择   空格 确认"


func _input(event: InputEvent) -> void:
	if not _ready_for_input or _done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_W, KEY_UP:
				_move(-1)
			KEY_S, KEY_DOWN:
				_move(1)
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				_confirm()
			KEY_F8:
				# 暗门：开发者模式
				if locked_from < options.size():
					_selected = options.size() - 1
					_confirm()
			KEY_ESCAPE:
				if can_go_back:
					_cancel()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		for i in locked_from:
			if _option_labels[i].get_global_rect().has_point(event.position) and i != _selected:
				_selected = i
				Sfx.play(self, Sfx.blip(520.0, 560.0, 0.04, 0.25), -10.0)
				_refresh()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in locked_from:
			if _option_labels[i].get_global_rect().has_point(event.position):
				_selected = i
				_refresh()
				_confirm()
				get_viewport().set_input_as_handled()
				return


func _move(step: int) -> void:
	_selected = posmod(_selected + step, locked_from)
	Sfx.play(self, Sfx.blip(520.0, 560.0, 0.04, 0.25), -10.0)
	_refresh()


func _confirm() -> void:
	_done = true
	Sfx.play(self, Sfx.blip(880.0, 1320.0, 0.12, 0.4), -6.0)
	var chosen := _option_labels[_selected]
	if _selected >= locked_from:
		chosen.text = "→ %s ←" % options[_selected]
		chosen.add_theme_color_override("font_color", TITLE_COLOR)
	var tw := create_tween()
	tw.set_parallel(true)
	for lbl in _option_labels:
		if lbl != chosen:
			tw.tween_property(lbl, "modulate:a", 0.0, 0.2)
	tw.tween_property(_hint, "modulate:a", 0.0, 0.2)
	tw.tween_property(chosen, "scale", Vector2(1.3, 1.3), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_root, "modulate:a", 0.0, 0.45)
	await tw.finished
	mode_chosen.emit(_selected)
	queue_free()


func _cancel() -> void:
	_done = true
	Sfx.play(self, Sfx.blip(660.0, 330.0, 0.12, 0.4), -6.0)
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.35)
	await tw.finished
	mode_chosen.emit(Mode.BACK)
	queue_free()
