extends Node2D
class_name ElevatorRoof

func _draw() -> void:
	# A narrow metal roof keeps the shaft visible around the characters.
	draw_rect(Rect2(220, 286, 200, 15), Color(0.13, 0.15, 0.2))
	draw_rect(Rect2(216, 282, 208, 5), Color(0.48, 0.51, 0.55))
	draw_rect(Rect2(220, 288, 200, 3), Color(0.27, 0.3, 0.35))
	draw_rect(Rect2(232, 301, 176, 59), Color(0.09, 0.11, 0.15))
	for x in [236, 278, 320, 362, 404]:
		draw_rect(Rect2(x, 284, 3, 3), Color(0.77, 0.78, 0.73))
