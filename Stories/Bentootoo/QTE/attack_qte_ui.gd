extends Control
class_name AttackQTEUI

const FONT = preload("res://Assets/Theme/像素字体.ttf")
const INK := Color(0.13, 0.07, 0.12)

var ready_for_q := false
var active := true
var press_age := 1.0
var clock := 0.0
var impact_mode := false
var impact_progress := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(640, 360)

func _process(delta: float) -> void:
	clock += delta
	press_age += delta
	queue_redraw()

func register_press() -> void:
	press_age = 0.0

func _draw() -> void:
	if impact_mode:
		var inset := 34.0 * clampf(impact_progress, 0.0, 1.0)
		draw_rect(Rect2(0, 0, 640, inset), Color.BLACK)
		draw_rect(Rect2(0, 360 - inset, 640, inset), Color.BLACK)
		return
	if not active:
		return
	var automatic_press := maxf(0.0, sin(clock * TAU * 1.9)) * 3.0 if not ready_for_q else 0.0
	var actual_press := maxf(0.0, 1.0 - press_age / 0.14) * 5.0
	var down := automatic_press + actual_press
	var center := Vector2(320, 305 + down)
	# Offset shadow and rounded keycap read as one cartoon button.
	draw_circle(Vector2(320, 316), 27, Color(0.32, 0.045, 0.08))
	draw_circle(center, 27, Color.WHITE)
	draw_circle(center, 23, INK)
	draw_circle(center + Vector2(-7, -10), 5, Color(0.42, 0.24, 0.3, 0.8))
	var letter := "Q" if ready_for_q else "E"
	draw_string(FONT, center + Vector2(-9, 10), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color.WHITE)
	if not ready_for_q:
		var pulse := 0.45 + 0.4 * sin(clock * TAU * 1.9)
		for side in [-1, 1]:
			var x: float = 320.0 + side * 45.0
			draw_line(Vector2(x, 287), Vector2(x + side * 8, 296), Color(1, 1, 1, pulse), 2)
			draw_line(Vector2(x + side * 8, 296), Vector2(x, 305), Color(1, 1, 1, pulse), 2)
	else:
		var glow := 0.3 + 0.3 * sin(clock * TAU * 1.5)
		draw_arc(center, 33, 0, TAU, 32, Color(1, 0.25, 0.35, glow), 2)
