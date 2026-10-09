extends Node
## 整合版的入口：选走哪条线。直接复用标题菜单的样子，选完切到那条线自己的 game 场景。
## 两条线打完都会通过 Session.back_to_route_select() 回到这里。

const TitleMenu := preload("res://Stories/Shared/Title/title_menu.gd")

## 顺序和下面 ROUTE_SCENES 一一对应
const ROUTE_NAMES: Array[String] = ["本2兔 × 罗马特", "木木 × 小高星"]
const ROUTE_HINTS: Array[String] = [
	"蜥蜴人与男特工的电梯恋爱：剧情、QTE、弹幕",
	"电梯风云：扔东西、跳舞、打怪兽",
]
const ROUTE_SCENES: Array[String] = [
	"res://Stories/Bentootoo/game.tscn",
	"res://Stories/Shared/game.tscn",
]


func _ready() -> void:
	var menu := TitleMenu.new()
	menu.game_title = "Story Jam"
	menu.subtitle = "选 择 故 事"
	menu.options = ROUTE_NAMES
	menu.option_hints = ROUTE_HINTS
	menu.locked_from = ROUTE_NAMES.size()
	menu.can_go_back = false
	add_child(menu)
	var route: int = await menu.mode_chosen
	get_tree().change_scene_to_file(ROUTE_SCENES[route])
