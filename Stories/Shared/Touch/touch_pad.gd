extends CanvasLayer
## 手机上的触屏操作，自动加载为 TouchPad。
##
## 1. 屏幕上的按键：每个阶段开局时 use(布局名)，结束时 clear()。按下去就是往 Input 里塞一个
##    对应的键盘事件（keycode 和 physical_keycode 都填），所以各阶段原来读键盘的代码一行不用改。
##    多根手指可以同时按；手指从一个键滑到隔壁的键，会松开前一个、按下后一个。
## 2. 点屏幕 = 点鼠标：项目里关掉了 Godot 自带的「触摸当鼠标」，改由这里转发。
##    这样按在屏幕按键上的那一下不会再变成一次鼠标点击（不然一边走路一边就把对话点过去了）。
##
## 按键的样子：电梯里那块数字面板（Assets/Edited/数字面板.png）当底座，方向键用跳舞关的
## 绿 / 红箭头（P1 绿、P2 红），其余写一个像素字。按下去像电梯按钮一样亮一圈暖黄。
## 只有触屏设备才显示（第一次摸到屏幕也会打开）；电脑上一直是空的。

const PANEL := preload("res://Assets/Edited/数字面板.png")
const ARROW_P1 := preload("res://Assets/Branch/绿箭头.png")
const ARROW_P2 := preload("res://Assets/Branch/红箭头.png")
const FONT := preload("res://Assets/Theme/像素字体.ttf")
## 面板四周倒角的宽度，九宫格按这个切
const PANEL_MARGIN := 9
const GLYPH_IDLE := Color(0.84, 0.82, 0.78)
const LIT := Color(1.0, 0.93, 0.6)
const LIT_PANEL := Color(1.18, 1.1, 0.86)

enum { P1, P2 }

## 触屏设备：要显示按键、提示文字也换成「点一下」
var active := false

var _widgets: Array[Dictionary] = []   # {kind, rect, keys, glyph, rot, text, side, fingers}
var _finger_widget := {}               # 手指 index -> 按着的那个 widget
var _key_count := {}                   # Key -> 有几处按着它
var _mouse_finger := -1                # 正在当鼠标用的那根手指
var _canvas: Control
var _panel_idle: StyleBoxTexture
var _panel_lit: StyleBoxTexture


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	active = DisplayServer.is_touchscreen_available()
	_panel_idle = _panel_style(Color.WHITE)
	_panel_lit = _panel_style(LIT_PANEL)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_widgets)
	add_child(_canvas)


func _panel_style(tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = PANEL
	sb.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, PANEL_MARGIN)
	return sb


# ---------- 布局 ----------

## 换一套按键。名字见 _build；单人 / 双人按 Session.single_player 自己分。
func use(layout: StringName) -> void:
	_release_all()
	_widgets = _build(layout)
	_canvas.queue_redraw()


func clear() -> void:
	use(&"")


## 整屏都是一个看不见的键（比如「点一下重新开始」）
func use_tap(keys: Array) -> void:
	_release_all()
	_widgets = [_zone(Rect2(0, 0, 640, 360), keys)]
	_canvas.queue_redraw()


func _build(layout: StringName) -> Array[Dictionary]:
	var duo := not Session.single_player
	var w: Array[Dictionary] = []
	match layout:
		&"arena":
			# 扔东西 / 打怪兽：左右走在左下角，跳和扔在右下角
			if duo:
				_row(w, 8, P1, [[KEY_A, "←"], [KEY_D, "→"], [KEY_W, "↑"], [KEY_F, "扔"]])
				_row(w, 466, P2, [[KEY_LEFT, "←"], [KEY_RIGHT, "→"], [KEY_UP, "↑"], [KEY_SLASH, "扔"]])
			else:
				w.append(_button(Rect2(10, 308, 48, 44), [KEY_A], "←", P1))
				w.append(_button(Rect2(64, 308, 48, 44), [KEY_D], "→", P1))
				w.append(_button(Rect2(528, 308, 48, 44), [KEY_W], "↑", P1))
				w.append(_button(Rect2(582, 308, 48, 44), [KEY_F], "扔", P1))
		&"dance":
			# 双人时每人四个键正对着自己的四条轨道；单人时拆成左右两半，两个拇指各管两个
			if duo:
				_row(w, 11, P1, [[KEY_A, "←"], [KEY_S, "↓"], [KEY_W, "↑"], [KEY_D, "→"]])
				_row(w, 465, P2, [[KEY_LEFT, "←"], [KEY_DOWN, "↓"], [KEY_UP, "↑"], [KEY_RIGHT, "→"]])
			else:
				w.append(_button(Rect2(10, 308, 48, 44), [KEY_A], "←", P1))
				w.append(_button(Rect2(64, 308, 48, 44), [KEY_S], "↓", P1))
				w.append(_button(Rect2(528, 308, 48, 44), [KEY_W], "↑", P1))
				w.append(_button(Rect2(582, 308, 48, 44), [KEY_D], "→", P1))
		&"duel":
			# 天台对决：左边十字键，右边 B / A，和红白机一个摆法
			# 整体压在底下黑边的上方：黑边里要显示整串要按的键
			w.append(_button(Rect2(44, 188, 38, 38), [KEY_UP], "↑", P1))
			w.append(_button(Rect2(4, 228, 38, 38), [KEY_LEFT], "←", P1))
			w.append(_button(Rect2(84, 228, 38, 38), [KEY_RIGHT], "→", P1))
			w.append(_button(Rect2(44, 268, 38, 38), [KEY_DOWN], "↓", P1))
			w.append(_button(Rect2(524, 250, 46, 44), [KEY_B], "B", P1))
			w.append(_button(Rect2(580, 232, 46, 44), [KEY_A], "A", P1))
		&"bullet":
			# 弹幕：左下角一块摇杆（八个方向），右下角按住慢走
			w.append(_stick(Rect2(8, 258, 94, 94), [KEY_W, KEY_S, KEY_A, KEY_D]))
			w.append(_button(Rect2(568, 304, 62, 48), [KEY_SHIFT], "慢", P1))
		&"qte":
			# 连按 E 再按 Q：画面中间已经画了那颗大键帽，整屏随便点就行
			w.append(_zone(Rect2(0, 0, 640, 360), [KEY_E, KEY_Q]))
	return w


func _row(w: Array[Dictionary], x: float, side: int, keys: Array) -> void:
	for i in keys.size():
		w.append(_button(Rect2(x + i * 42.0, 314, 38, 38), [keys[i][0]], keys[i][1], side))


func _button(rect: Rect2, keys: Array, label: String, side: int) -> Dictionary:
	var rot := {"↑": 0.0, "→": PI * 0.5, "↓": PI, "←": PI * 1.5}
	return {
		kind = &"button", rect = rect, keys = keys, side = side,
		arrow = rot.has(label), rot = rot.get(label, 0.0), text = label,
		fingers = [],
	}


## keys 依次是 上 下 左 右
func _stick(rect: Rect2, keys: Array) -> Dictionary:
	return {kind = &"stick", rect = rect, keys = keys, side = P1, fingers = [], dirs = []}


func _zone(rect: Rect2, keys: Array) -> Dictionary:
	return {kind = &"zone", rect = rect, keys = keys, fingers = []}


# ---------- 输入 ----------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		active = true
		_canvas.queue_redraw()
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index, event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position)
		get_viewport().set_input_as_handled()


func _touch_down(finger: int, pos: Vector2) -> void:
	var w := _widget_at(pos)
	if not w.is_empty():
		_finger_widget[finger] = w
		_press(w, finger, pos)
		return
	if _mouse_finger < 0:
		_mouse_finger = finger
		_mouse_motion(pos, MOUSE_BUTTON_MASK_LEFT)
		_mouse_button(pos, true)


func _touch_move(finger: int, pos: Vector2) -> void:
	if finger == _mouse_finger:
		_mouse_motion(pos, MOUSE_BUTTON_MASK_LEFT)
		return
	if not _finger_widget.has(finger):
		return
	var w: Dictionary = _finger_widget[finger]
	if w.kind == &"stick":
		_aim_stick(w, pos)
		return
	if w.rect.grow(4.0).has_point(pos):
		return
	# 滑出了这个键：松开它；滑到了隔壁的键上就按下隔壁那个
	_release(w, finger)
	_finger_widget.erase(finger)
	var next := _widget_at(pos)
	if not next.is_empty() and next.kind == &"button":
		_finger_widget[finger] = next
		_press(next, finger, pos)


func _touch_up(finger: int, pos: Vector2) -> void:
	if finger == _mouse_finger:
		_mouse_finger = -1
		_mouse_button(pos, false)
		return
	if _finger_widget.has(finger):
		_release(_finger_widget[finger], finger)
		_finger_widget.erase(finger)


func _widget_at(pos: Vector2) -> Dictionary:
	# 后加的在上面（全屏的 zone 都是单独一套，不会和按键叠在一起）
	for i in range(_widgets.size() - 1, -1, -1):
		var w: Dictionary = _widgets[i]
		# 判定比画出来的大一圈，手指粗
		if w.rect.grow(3.0).has_point(pos):
			return w
	return {}


func _press(w: Dictionary, finger: int, pos: Vector2) -> void:
	w.fingers.append(finger)
	if w.kind == &"stick":
		_aim_stick(w, pos)
		return
	if w.fingers.size() == 1:
		for k in w.keys:
			_key(k, true)
	_canvas.queue_redraw()


func _release(w: Dictionary, finger: int) -> void:
	w.fingers.erase(finger)
	if not w.fingers.is_empty():
		return
	if w.kind == &"stick":
		_set_stick_dirs(w, [])
		return
	for k in w.keys:
		_key(k, false)
	_canvas.queue_redraw()


## 摇杆：手指离中心的方向，分成八个方向；离中心太近算不动
func _aim_stick(w: Dictionary, pos: Vector2) -> void:
	var rect: Rect2 = w.rect
	var d := pos - rect.get_center()
	var dirs: Array = []
	if d.length() > rect.size.x * 0.12:
		var a := d.angle()   # 右 = 0，下 = +PI/2
		var dead := PI / 8.0
		if absf(angle_difference(a, -PI * 0.5)) < PI * 0.5 - dead:
			dirs.append(0)
		if absf(angle_difference(a, PI * 0.5)) < PI * 0.5 - dead:
			dirs.append(1)
		if absf(angle_difference(a, PI)) < PI * 0.5 - dead:
			dirs.append(2)
		if absf(angle_difference(a, 0.0)) < PI * 0.5 - dead:
			dirs.append(3)
	_set_stick_dirs(w, dirs)


func _set_stick_dirs(w: Dictionary, dirs: Array) -> void:
	for i in 4:
		var was: bool = w.dirs.has(i)
		var now := dirs.has(i)
		if was != now:
			_key(w.keys[i], now)
	w.dirs = dirs
	_canvas.queue_redraw()


func _key(k: int, down: bool) -> void:
	var n: int = _key_count.get(k, 0) + (1 if down else -1)
	n = maxi(n, 0)
	var was_down: bool = _key_count.get(k, 0) > 0
	_key_count[k] = n
	if was_down == (n > 0):
		return
	var ev := InputEventKey.new()
	ev.keycode = k as Key
	ev.physical_keycode = k as Key
	ev.pressed = n > 0
	Input.parse_input_event(ev)


func _release_all() -> void:
	for w in _widgets:
		if w.kind == &"stick":
			_set_stick_dirs(w, [])
		w.fingers.clear()
	for k in _key_count.keys():
		if _key_count[k] > 0:
			_key_count[k] = 1
			_key(k, false)
	_finger_widget.clear()


# ---------- 点屏幕 = 点鼠标 ----------

## 在下一帧以「游戏画面坐标」推给视口：按钮、对话框、菜单都按鼠标来处理
func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input.call_deferred(ev, true)


func _mouse_motion(pos: Vector2, mask: int) -> void:
	var ev := InputEventMouseMotion.new()
	ev.button_mask = mask
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input.call_deferred(ev, true)


# ---------- 画 ----------

func _draw_widgets() -> void:
	if not active:
		return
	for w in _widgets:
		match w.kind:
			&"button":
				_draw_button(w)
			&"stick":
				_draw_stick(w)


func _draw_button(w: Dictionary) -> void:
	var rect: Rect2 = w.rect
	var down: bool = not w.fingers.is_empty()
	_draw_panel(rect, down)
	var center := rect.get_center() + Vector2(0, 1 if down else 0)
	if w.arrow:
		_draw_arrow(center, float(w.rot), minf(rect.size.x, rect.size.y) * 0.56, int(w.side), down)
	else:
		_draw_text(center, str(w.text), 18 if rect.size.y >= 40.0 else 15, down)


func _draw_stick(w: Dictionary) -> void:
	var rect: Rect2 = w.rect
	var lit: Array = w.dirs
	_draw_panel(rect, not lit.is_empty())
	var c := rect.get_center()
	var r := rect.size.x * 0.32
	var size := rect.size.x * 0.26
	_draw_arrow(c + Vector2(0, -r), 0.0, size, P1, lit.has(0))
	_draw_arrow(c + Vector2(0, r), PI, size, P1, lit.has(1))
	_draw_arrow(c + Vector2(-r, 0), PI * 1.5, size, P1, lit.has(2))
	_draw_arrow(c + Vector2(r, 0), PI * 0.5, size, P1, lit.has(3))


func _draw_panel(rect: Rect2, down: bool) -> void:
	_canvas.draw_style_box(_panel_lit if down else _panel_idle, rect)
	if down:
		# 电梯按钮亮起来的那一圈
		_canvas.draw_rect(rect.grow(-4.0), LIT, false, 1.0)


func _draw_arrow(center: Vector2, rot: float, size: float, side: int, lit: bool) -> void:
	var tex: Texture2D = ARROW_P1 if side == P1 else ARROW_P2
	_canvas.draw_set_transform(center, rot, Vector2.ONE)
	var tint := Color(1.35, 1.3, 1.1) if lit else Color(0.9, 0.9, 0.9)
	_canvas.draw_texture_rect(tex, Rect2(Vector2(-size, -size) * 0.5, Vector2(size, size)), false, tint)
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_text(center: Vector2, text: String, font_size: int, lit: bool) -> void:
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var base := center + Vector2(-width * 0.5, font_size * 0.36)
	_canvas.draw_string_outline(FONT, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color.BLACK)
	_canvas.draw_string(FONT, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, LIT if lit else GLYPH_IDLE)
