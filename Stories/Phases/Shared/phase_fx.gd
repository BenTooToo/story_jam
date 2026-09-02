class_name JamFx
extends RefCounted
## 粒子特效和提示文字。
##
## 所有渐变都走同一条规则：**alpha 在最开头和最结尾是 0，中间几乎全程是 1**，
## 所以出现和消失都是渐变的，不会生硬地闪一下。粒子和文字都遵守这条。

const PIXEL_FONT := preload("res://Assets/Theme/像素字体.ttf")
## 淡入淡出各占生命周期的多少，中间那段保持不透明
const FADE_IN := 0.12
const FADE_OUT := 0.15

static var _square: Texture2D


## 粒子用的方块。像素风别用柔边光点，硬边才不糊。
## 故意用 1x1：这样 scale_amount 的数值就直接等于屏幕上的像素边长，
## 放大也不会出现一边 3 像素一边 4 像素的锯齿。
static func square() -> Texture2D:
	if _square == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_square = ImageTexture.create_from_image(img)
	return _square


## 两头透明、中间不透明的颜色渐变。
static func fade_ramp(from_color: Color, to_color: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, FADE_IN, 1.0 - FADE_OUT, 1.0])
	g.colors = PackedColorArray([
		Color(from_color.r, from_color.g, from_color.b, 0.0),
		from_color,
		to_color,
		Color(to_color.r, to_color.g, to_color.b, 0.0),
	])
	return g


static func _make(amount: int, lifetime: float, one_shot: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = square()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.local_coords = false
	p.gravity = Vector2.ZERO
	return p


## 一次性放完就自己清理掉，绝不留在场上。
static func _fire_and_forget(host: Node, p: CPUParticles2D, extra := 0.3) -> void:
	host.add_child(p)
	p.emitting = true
	var tree := host.get_tree()
	if tree != null:
		tree.create_timer(p.lifetime + extra).timeout.connect(p.queue_free)
	else:
		p.queue_free()


## 砸中 / 落地时的迸溅。
static func hit_burst(
	host: Node,
	at: Vector2,
	tint := Color(1.0, 0.92, 0.62),
	amount := 16,
	power := 1.0,
) -> void:
	var p := _make(amount, 0.45, true)
	p.position = at
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 55.0 * power
	p.initial_velocity_max = 145.0 * power
	p.gravity = Vector2(0, 320)
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color_ramp = fade_ramp(Color(1, 1, 1), tint)
	_fire_and_forget(host, p)


## 沿地面扬起的尘土，用来表现震地冲击波。
static func ground_dust(
	host: Node,
	at: Vector2,
	tint := Color(0.86, 0.8, 0.64),
	amount := 6,
) -> void:
	# 活得短一点，拖尾才不会长到看不出波前在哪
	var p := _make(amount, 0.35, true)
	p.position = at
	p.explosiveness = 0.85
	p.direction = Vector2(0, -1)
	p.spread = 62.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 80.0
	p.gravity = Vector2(0, 140)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color_ramp = fade_ramp(Color(1, 0.98, 0.9), tint)
	_fire_and_forget(host, p)


## 往上飘的小火星，给"这里要出事"的地方打个底。
static func warn_sparks(host: Node, at: Vector2, tint := Color(0.95, 0.4, 0.32)) -> void:
	var p := _make(10, 0.7, true)
	p.position = at
	p.explosiveness = 0.4
	p.direction = Vector2(0, -1)
	p.spread = 26.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 48.0
	p.gravity = Vector2(0, -30)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.color_ramp = fade_ramp(Color(1, 0.85, 0.6), tint)
	_fire_and_forget(host, p)


## 眩晕时头顶绕圈的星火。挂在角色身上跟着一起动，不晕了直接 queue_free。
static func make_stun_ring(head_y: float) -> CPUParticles2D:
	var p := _make(12, 1.2, false)
	p.position = Vector2(0, head_y)
	p.local_coords = true
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 14.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.orbit_velocity_min = 0.5
	p.orbit_velocity_max = 0.7
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.preprocess = 0.8            # 一出现就是转满的，不用等它铺开
	p.color_ramp = fade_ramp(Color(1.0, 0.92, 0.45), Color(1.0, 0.72, 0.25))
	p.emitting = true
	return p


## 弹出提示文字（感叹号之类）。淡入 -> 保持 -> 淡出，配一点点弹跳。
static func pop_text(
	host: Node,
	at: Vector2,
	text: String,
	color: Color,
	font_size := 16,
	hold := 0.5,
	rise := 14.0,
) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(64.0, font_size + 12.0)
	label.pivot_offset = label.size * 0.5
	label.position = at - label.size * 0.5
	label.z_index = 60
	label.modulate.a = 0.0
	label.scale = Vector2(0.7, 0.7)
	host.add_child(label)

	var fade_in := maxf(hold * 0.25, 0.1)
	var fade_out := maxf(hold * 0.45, 0.18)
	var tw := label.create_tween()
	tw.set_parallel(true)
	# 淡入
	tw.tween_property(label, "modulate:a", 1.0, fade_in)
	tw.tween_property(label, "scale", Vector2.ONE, fade_in) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "position:y", label.position.y - rise, hold + fade_in + fade_out) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 保持一段再淡出
	tw.chain().tween_interval(hold)
	tw.chain().tween_property(label, "modulate:a", 0.0, fade_out)
	tw.chain().tween_callback(label.queue_free)
	return label
