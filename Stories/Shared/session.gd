extends Node
## 整局游戏的全局设定（自动加载为 Session）。
## 标题菜单里选完模式写进来，三个阶段开局时读。

## 选线界面（游戏入口）：两条线打完、或者在标题菜单按 Esc，都回这里。
const ROUTE_SELECT_SCENE := "res://Stories/Shared/RouteSelect/route_select.tscn"

## true = 单人：玩家只操控女生（P1），男生（P2）交给电脑。
var single_player := false


func back_to_route_select() -> void:
	get_tree().change_scene_to_file.call_deferred(ROUTE_SELECT_SCENE)
