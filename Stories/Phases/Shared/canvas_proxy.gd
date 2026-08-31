extends Node2D
## 绘制转发节点：让宿主能把一部分绘制画在子节点（例如精灵）上层。
## 宿主实现 `_proxy_draw(canvas: Node2D, tag: String)` 即可。

var host: Node
var tag := ""


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if host != null and host.has_method("_proxy_draw"):
		host._proxy_draw(self, tag)
