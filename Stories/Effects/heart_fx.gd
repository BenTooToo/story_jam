extends RefCounted
class_name HeartFX
## 冒爱心：传入人物，依次播放六帧，结束后自动释放。

const FRAMES: Array[Texture2D] = [
	preload("res://Assets/efx/love_efx/冒爱心1.png"),
	preload("res://Assets/efx/love_efx/冒爱心2.png"),
	preload("res://Assets/efx/love_efx/冒爱心3.png"),
	preload("res://Assets/efx/love_efx/冒爱心4.png"),
	preload("res://Assets/efx/love_efx/冒爱心5.png"),
	preload("res://Assets/efx/love_efx/冒爱心6.png"),
]


## 可直接调用，也可 await HeartFX.play(character) 等待播放结束。
## [param offset] 是相对自动计算出的头部中心位置进行微调。
static func play(character: Node2D, fps: float = 8.0, offset := Vector2.ZERO) -> void:
	if not is_instance_valid(character) or not character.is_inside_tree():
		push_warning("HeartFX.play() requires a character in the scene tree.")
		return
	if not is_finite(fps) or fps <= 0.0:
		push_warning("HeartFX.play() requires a positive, finite fps.")
		return

	var frames := SpriteFrames.new()
	frames.set_animation_loop(&"default", false)
	frames.set_animation_speed(&"default", fps)
	for texture in FRAMES:
		frames.add_frame(&"default", texture)

	var effect := AnimatedSprite2D.new()
	effect.name = "HeartFX"
	effect.sprite_frames = frames
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.z_index = 1
	# 人物节点原点通常在整张贴图中心，头部约位于贴图顶部 12% 处。
	# 爱心作为人物子节点，会自动跟随人物移动、翻转和缩放。
	effect.position = _get_head_position(character) + offset
	character.add_child(effect)
	effect.animation_finished.connect(effect.queue_free)
	effect.play()
	# 人物提前离场也会释放特效，等待调用方不会挂起。
	await effect.tree_exited


static func _get_head_position(character: Node2D) -> Vector2:
	if character is Sprite2D:
		var sprite := character as Sprite2D
		var rect: Rect2 = sprite.get_rect()
		return Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.12)

	if character is AnimatedSprite2D:
		var animated := character as AnimatedSprite2D
		if animated.sprite_frames == null:
			return animated.offset
		var texture: Texture2D = animated.sprite_frames.get_frame_texture(
			animated.animation,
			animated.frame,
		)
		if texture == null:
			return animated.offset
		var size := texture.get_size()
		if animated.centered:
			return animated.offset + Vector2(0.0, -size.y * 0.38)
		return animated.offset + Vector2(size.x * 0.5, size.y * 0.12)

	return Vector2.ZERO
