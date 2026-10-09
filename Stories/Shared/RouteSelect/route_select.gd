extends Node
## 整合版的入口：选走哪条线。直接复用标题菜单的样子，选完切到那条线自己的 game 场景。
## 两条线打完都会通过 Session.back_to_route_select() 回到这里。
##
## 网页版（B 站 Toy）多几样：第一次进来先弹一次关注卡片（可以直接跳过）；菜单里多一项「排行榜」；
## 最底下一行感谢语 + 三位作者的主页链接；
## 左上角版本号（玩家反馈时好对版本）；右上角「画质：标准 / 流畅」，点一下切换，立即生效。

const TitleMenu := preload("res://Stories/Shared/Title/title_menu.gd")
const AuthorLinks := preload("res://Stories/Shared/Web/author_links.gd")
const Leaderboard := preload("res://Stories/Shared/Web/leaderboard.gd")
const ThanksCard := preload("res://Stories/Shared/Web/thanks_card.gd")
const Sfx := preload("res://Stories/Phases/Shared/retro_sfx.gd")
const PIXEL_FONT := preload("res://Assets/Theme/像素字体.ttf")
const DIM := Color(0.36, 0.36, 0.42)
const HOVER := Color(1.0, 0.93, 0.6)

## 顺序和下面 ROUTE_SCENES 一一对应
const ROUTE_NAMES: Array[String] = ["本2兔 × 罗马特", "木木 × 小高星"]
const ROUTE_SCENES: Array[String] = [
	"res://Stories/Bentootoo/game.tscn",
	"res://Stories/Shared/game.tscn",
]
const BOARD_OPTION := "排行榜"

var _corner: CanvasLayer
var _links: CanvasLayer
var _quality: Label


func _ready() -> void:
	await ThanksCard.show_follow_prompt(self)
	if Toy.is_web():
		_build_corners()
		_links = AuthorLinks.new()
		add_child(_links)
	while true:
		var menu := TitleMenu.new()
		menu.game_title = "Story Jam"
		menu.subtitle = "选 择 故 事"
		var options: Array[String] = ROUTE_NAMES.duplicate()
		if Toy.is_web():
			options.append(BOARD_OPTION)
		menu.options = options
		# 底下不写每条线讲什么，免得剧透，只留按键说明
		menu.option_hints = []
		menu.locked_from = options.size()
		menu.can_go_back = false
		add_child(menu)
		var pick: int = await menu.mode_chosen
		if pick >= 0 and pick < ROUTE_SCENES.size():
			get_tree().change_scene_to_file(ROUTE_SCENES[pick])
			return
		# 排行榜：看完回到这个菜单
		_set_extras_visible(false)
		var board := Leaderboard.new()
		add_child(board)
		await board.closed
		_set_extras_visible(true)


func _set_extras_visible(on: bool) -> void:
	if _links != null:
		_links.visible = on
	if _corner != null:
		_corner.visible = on


func _build_corners() -> void:
	_corner = CanvasLayer.new()
	_corner.layer = 61
	add_child(_corner)
	var version := _corner_label(Toy.version(), 8.0, HORIZONTAL_ALIGNMENT_LEFT)
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quality = _corner_label("", 432.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_refresh_quality()


func _corner_label(text: String, x: float, align: HorizontalAlignment) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", PIXEL_FONT)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", DIM)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(x, 6.0)
	lbl.size = Vector2(200.0, 22.0)
	lbl.horizontal_alignment = align
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corner.add_child(lbl)
	return lbl


func _refresh_quality() -> void:
	_quality.text = "画质：" + ("流畅" if Toy.smooth else "标准")


func _input(event: InputEvent) -> void:
	if _quality == null or not _corner.visible:
		return
	# 只认字本身那一块（右对齐，框比字宽），四周放宽一点给手指
	var w := PIXEL_FONT.get_string_size(_quality.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var hit := Rect2(_quality.position + Vector2(_quality.size.x - w, 0.0), Vector2(w, _quality.size.y)).grow(8.0)
	if event is InputEventMouseMotion:
		_quality.add_theme_color_override("font_color", HOVER if hit.has_point(event.position) else DIM)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and hit.has_point(event.position):
		get_viewport().set_input_as_handled()
		SaveData.set_smooth(not Toy.smooth)
		Sfx.play(self, Sfx.blip(600.0, 900.0, 0.06, 0.3), -8.0)
		_refresh_quality()
