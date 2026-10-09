extends CanvasLayer
## 一行「喜欢的话，可以关注我们。  本2兔 · 小名是木木 · 小高星 · 介绍视频」，
## 选线界面底下、开局前的关注卡片、片尾卡片都用这个。名字能点，点了去那个人的 B 站主页。
## 前半句默认跟着关注 / 三连状态变（Toy.thanks_text），也可以换成固定的话（prefix）。
## 介绍视频还没发（Toy.VIDEO_BVID 为空）就不显示。
## 只是感谢和入口，不锁任何内容。点击判定用事件自己的坐标（触屏转来的点击，鼠标位置不一定跟上了）。

const PIXEL_FONT := preload("res://Assets/Theme/像素字体.ttf")
const Sfx := preload("res://Stories/Phases/Shared/retro_sfx.gd")
const DIM := Color(0.5, 0.5, 0.56)
const LINK := Color(0.85, 0.85, 0.9)
const HOVER := Color(1.0, 0.93, 0.6)

## 这一行的 y（游戏画面坐标），整行水平居中
var y := 338.0
var font_size := 12
## 前半句：空 = 用 Toy.thanks_text()（跟着关注状态变）；设成 "-" 就不要前半句
var prefix := ""
## 只列这几位（名字，见 Toy.AUTHORS）；空 = 全部
var only: Array = []
var show_video := true

var _row: HBoxContainer
var _thanks: Label
var _links := {}     # Label -> 名字（"" 表示介绍视频）
var _hover: Label


func _ready() -> void:
	# 默认压在标题菜单（60）上面；放在别的层上的（感谢卡）add_child 之前自己设好
	layer = maxi(layer, 61)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.position = Vector2(0.0, y)
	_row.size = Vector2(640.0, font_size + 10.0)
	_row.add_theme_constant_override("separation", 0)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_thanks = _label("", DIM)
	_thanks.visible = prefix != "-"
	var first := true
	for author in Toy.AUTHORS:
		if not only.is_empty() and not only.has(author):
			continue
		if not first:
			_label("  ·  ", DIM)
		first = false
		_links[_label(author, LINK)] = author
	if show_video and Toy.has_video():
		_label("  ·  ", DIM)
		_links[_label("介绍视频", LINK)] = ""
	Toy.relation_changed.connect(_refresh)
	_refresh()
	Toy.ask_relation()


func _label(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", PIXEL_FONT)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(lbl)
	return lbl


func _refresh() -> void:
	_thanks.text = (prefix if prefix != "" else Toy.thanks_text()) + "    "


## 点在哪个链接上（四周放宽几像素，手指粗）
func link_at(pos: Vector2) -> Label:
	for lbl: Label in _links:
		if lbl.is_visible_in_tree() and lbl.get_global_rect().grow(6.0).has_point(pos):
			return lbl
	return null


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		_set_hover(link_at(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var lbl := link_at(event.position)
		if lbl == null:
			return
		get_viewport().set_input_as_handled()
		Sfx.play(self, Sfx.blip(880.0, 1320.0, 0.12, 0.4), -6.0)
		var author: String = _links[lbl]
		if author == "":
			Toy.open_video()
		else:
			Toy.open_author_page(Toy.AUTHORS[author])


func _set_hover(lbl: Label) -> void:
	if lbl == _hover:
		return
	if _hover != null:
		_hover.add_theme_color_override("font_color", LINK)
	_hover = lbl
	if _hover != null:
		_hover.add_theme_color_override("font_color", HOVER)
