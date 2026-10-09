extends CanvasLayer
## 两张关注卡片（只在网页版出现），点名字去那位作者的 B 站主页，点别的地方（或按空格）继续。
## - 片尾：「感谢游玩」+ 已达成几个结局 + 这条线的作者 + 三位作者。情绪最高的时候，关注入口最有用。
## - 开局前：第一次进游戏弹一次「喜欢的话，可以关注一下我们」，直接点别处就跳过，之后不再弹。
## 都不锁内容：Toy 规定不能拿关注 / 点赞 / 三连锁基础功能，违反会下架。
## 用法：await ThanksCard.show_on(self, "ben")    await ThanksCard.show_follow_prompt(self)
## 不在网页上就直接返回。

signal closed

const AuthorLinks := preload("res://Stories/Shared/Web/author_links.gd")
const PIXEL_FONT := preload("res://Assets/Theme/像素字体.ttf")
const TITLE_COLOR := Color(1.0, 0.93, 0.6)
const DIM := Color(0.5, 0.5, 0.56)

## 片尾卡片是哪条线的（Toy.ROUTE_AUTHORS 的键）；空 = 开局前那张
var route := ""
var opening := false

var _root: Control
var _links: Array[CanvasLayer] = []
var _ready_for_input := false
var _done := false


static func show_on(host: Node, route_id: String) -> void:
	if not Toy.is_web():
		return
	var card = load("res://Stories/Shared/Web/thanks_card.gd").new()
	card.route = route_id
	host.add_child(card)
	await card.closed


## 第一次进游戏时弹一次；弹过就记在存档里
static func show_follow_prompt(host: Node) -> void:
	if not Toy.is_web() or SaveData.follow_prompted:
		return
	SaveData.set_follow_prompted()
	var card = load("res://Stories/Shared/Web/thanks_card.gd").new()
	card.opening = true
	host.add_child(card)
	await card.closed


func _ready() -> void:
	layer = 70
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.045)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	if opening:
		_build_opening()
	else:
		_build_ending()

	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.6)
	await tw.finished
	_ready_for_input = true


func _build_opening() -> void:
	var title := _label("喜欢的话，可以关注一下我们", 104.0, 22, TITLE_COLOR)
	title.add_theme_constant_override("outline_size", 5)
	_label("这个游戏是三个人一起做的", 148.0, 13, DIM)
	_add_links(196.0, 18, "-", [])
	_label("点名字去主页  ·  关不关注都能玩", 236.0, 12, DIM)
	_label("点其他地方开始" if TouchPad.active else "点其他地方 / 空格 开始", 318.0, 13, DIM)


func _build_ending() -> void:
	var title := _label("感谢游玩", 92.0, 30, TITLE_COLOR)
	title.add_theme_constant_override("outline_size", 5)
	var got := "已达成结局 %d / %d" % [SaveData.endings.size(), SaveData.ENDINGS.size()]
	_label(got, 138.0, 13, DIM)
	if Toy.ROUTE_AUTHORS.has(route):
		_add_links(186.0, 16, "这条线的作者：", Toy.ROUTE_AUTHORS[route], false)
	_add_links(232.0, 13, "", [])
	_label("点其他地方继续" if TouchPad.active else "点其他地方 / 空格 继续", 318.0, 12, DIM)


func _add_links(y: float, size: int, prefix: String, only: Array, video := true) -> void:
	var links := AuthorLinks.new()
	links.y = y
	links.font_size = size
	links.prefix = prefix
	links.only = only
	links.show_video = video
	links.layer = layer + 1
	add_child(links)
	_links.append(links)


func _label(text: String, y: float, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", PIXEL_FONT)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(0.0, y)
	lbl.size = Vector2(640.0, size + 12.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lbl)
	return lbl


## 名字那几行自己先处理点击（它们在更上层、先收到）；落到这里的点击就是「点别的地方」
func _unhandled_input(event: InputEvent) -> void:
	if not _ready_for_input or _done:
		return
	var go: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE])
	if not go:
		return
	get_viewport().set_input_as_handled()
	_done = true
	for links in _links:
		links.visible = false
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.5)
	await tw.finished
	closed.emit()
	queue_free()
