extends CanvasLayer
## 游戏一开始的像素标题菜单：游戏名 tween 进场，选「单人 / 双人」。
## 底下还有一条灰掉的「开发者模式」，光标跳不上去、鼠标也点不了，
## 但在这个菜单里按 F8 就能进（回到按 1～9 单独测试各段的模式）。
## 用法：var menu := TitleMenu.new(); add_child(menu); var mode: int = await menu.mode_chosen

signal mode_chosen(mode: int)

enum Mode { SINGLE, DUO, DEV }

const PIXEL_FONT := preload("res://Assets/Theme/像素字体.ttf")
const Sfx := preload("res://Stories/Phases/Shared/retro_sfx.gd")

## 游戏名，改这里就行
const GAME_TITLE := "电梯风云"
const OPTIONS := ["单人", "双人", "开发者模式"]
const OPTION_HINTS := [
	"你操控女生，男生交给电脑",
	"两个人各管一个，正面对决",
]
## 从这一项开始（含）都是灰的，选不了
const LOCKED_FROM := Mode.DEV
const LOCKED := Color(0.26, 0.26, 0.3)
const TITLE_COLOR := Color(1.0, 0.93, 0.6)
const DIM := Color(0.5, 0.5, 0.56)
const LIT := Color(1.0, 1.0, 1.0)

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

	_title = _label(GAME_TITLE, 0.0, 78.0, 640.0, 48, TITLE_COLOR)
	_title.add_theme_constant_override("outline_size", 6)

	var sub := _label("选 择 模 式", 0.0, 168.0, 640.0, 14, DIM)
	sub.modulate.a = 0.0

	for i in OPTIONS.size():
		var locked := i >= LOCKED_FROM
		var lbl := _label(OPTIONS[i], 0.0, 200.0 + i * 34.0, 640.0, 16 if locked else 22, LOCKED if locked else DIM)
		if locked:
			lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		lbl.modulate.a = 0.0
		_option_labels.append(lbl)

	_hint = _label("", 0.0, 318.0, 640.0, 12, DIM)
	_hint.modulate.a = 0.0

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
	for i in LOCKED_FROM:
		var lbl := _option_labels[i]
		var on := i == _selected
		lbl.text = ("→ %s ←" % OPTIONS[i]) if on else OPTIONS[i]
		lbl.add_theme_color_override("font_color", LIT if on else DIM)
		if on:
			lbl.pivot_offset = lbl.size * 0.5
			lbl.scale = Vector2(1.12, 1.12)
			var tw := lbl.create_tween()
			tw.tween_property(lbl, "scale", Vector2.ONE, 0.18) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			lbl.scale = Vector2.ONE
	_hint.text = OPTION_HINTS[_selected] + "      W/S 或 ↑/↓ 选择   空格 确认"


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
				_selected = Mode.DEV
				_confirm()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		for i in LOCKED_FROM:
			if _option_labels[i].get_global_rect().has_point(event.position) and i != _selected:
				_selected = i
				Sfx.play(self, Sfx.blip(520.0, 560.0, 0.04, 0.25), -10.0)
				_refresh()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in LOCKED_FROM:
			if _option_labels[i].get_global_rect().has_point(event.position):
				_selected = i
				_refresh()
				_confirm()
				get_viewport().set_input_as_handled()
				return


func _move(step: int) -> void:
	_selected = posmod(_selected + step, LOCKED_FROM)
	Sfx.play(self, Sfx.blip(520.0, 560.0, 0.04, 0.25), -10.0)
	_refresh()


func _confirm() -> void:
	_done = true
	Sfx.play(self, Sfx.blip(880.0, 1320.0, 0.12, 0.4), -6.0)
	var chosen := _option_labels[_selected]
	if _selected == Mode.DEV:
		chosen.text = "→ 开发者模式 ←"
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
