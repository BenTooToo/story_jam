extends Node2D
class_name ElevatorBreakdownFX

const SHAFT_BACKGROUND_SCENE := preload(
	"res://Assets/envirment/tiles/ElevatorShaftBackground.tscn"
)
const HEARTBEAT_SOUND := preload("res://Assets/Sound Effects/sfx_heart_single.mp3")
const FEMALE_FALL_TEXTURES: Array[Texture2D] = [
	preload("res://Assets/caracter/lizard_girl/liz_falling/女下落1.png"),
	preload("res://Assets/caracter/lizard_girl/liz_falling/女下落2.png"),
	preload("res://Assets/caracter/lizard_girl/liz_falling/女下落3.png"),
]
const MALE_FALL_TEXTURES: Array[Texture2D] = [
	preload("res://Assets/caracter/cop/cop_falling/男下落1.png"),
	preload("res://Assets/caracter/cop/cop_falling/男下落2.png"),
	preload("res://Assets/caracter/cop/cop_falling/男下落3.png"),
]

const CABIN_RECT := Rect2(234.0, 93.0, 177.0, 199.0)
const DEFAULT_SPARK_ORIGIN := Vector2(397.0, 111.0)
const DEFAULT_SMOKE_ORIGIN := Vector2(386.0, 116.0)

@export var shaft_max_speed := 900.0
@export var shaft_acceleration := 3600.0
@export var spark_count := 18
@export var smoke_rate := 11.0

var _rng := RandomNumberGenerator.new()
var _sparks: Array[Dictionary] = []
var _smoke: Array[Dictionary] = []
var _smoke_emitting := false
var _smoke_origin := DEFAULT_SMOKE_ORIGIN
var _smoke_spawn_accumulator := 0.0
var _shaft_background: Node2D
var _shaft_tile_a: TileMapLayer
var _shaft_tile_b: TileMapLayer
var _shaft_sprites: Array[Sprite2D] = []
var _shaft_sprite_home_y: Array[float] = []
var _shaft_tile_period := 272.0
var _shaft_sprite_period := 645.0
var _shaft_sprite_top := -125.5
var _shaft_offset := 0.0
var _shaft_speed := 0.0
var _shaft_target_speed := 0.0
var _heartbeat_player: AudioStreamPlayer


func _ready() -> void:
	_rng.randomize()
	z_index = 5
	_heartbeat_player = AudioStreamPlayer.new()
	_heartbeat_player.stream = HEARTBEAT_SOUND
	add_child(_heartbeat_player)
	_setup_visual_layers()
	_setup_shaft_scroll()


func _process(delta: float) -> void:
	_update_shaft(delta)
	_update_sparks(delta)
	_update_smoke(delta)
	queue_redraw()


func play_sparks(
	origin: Vector2 = DEFAULT_SPARK_ORIGIN,
	burst_count: int = -1,
) -> void:
	var count := spark_count if burst_count < 0 else burst_count
	for index in count:
		var angle := _rng.randf_range(0.25 * PI, 0.85 * PI)
		var speed := _rng.randf_range(75.0, 145.0)
		_sparks.append({
			"position": origin + Vector2(
				_rng.randf_range(-3.0, 3.0),
				_rng.randf_range(-2.0, 2.0),
			),
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"age": 0.0,
			"life": _rng.randf_range(0.24, 0.46),
			"size": _rng.randf_range(1.0, 2.2),
		})

	_flash_cabin()
	await get_tree().create_timer(0.09).timeout
	for index in maxi(4, count / 3):
		var angle := _rng.randf_range(0.15 * PI, 0.9 * PI)
		var speed := _rng.randf_range(55.0, 115.0)
		_sparks.append({
			"position": origin,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"age": 0.0,
			"life": _rng.randf_range(0.18, 0.34),
			"size": _rng.randf_range(1.0, 2.0),
		})
	await get_tree().create_timer(0.38).timeout


func play_shock(target: AnimatedSprite2D = null) -> void:
	if target == null:
		target = _first_character()
	if target == null or target.sprite_frames == null:
		return

	# 先让心跳声起音，再生成震惊残影与形变动画。
	_heartbeat_player.play()
	_spawn_shock_ghost(target, 1.65, 0.20, 0.52)
	await get_tree().create_timer(0.045).timeout
	_spawn_shock_ghost(target, 2.15, 0.29, 0.34)

	var original_scale := target.scale
	var squash := create_tween()
	squash.tween_property(
		target,
		"scale",
		original_scale * Vector2(1.15, 0.84),
		0.06,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	squash.tween_property(target, "scale", original_scale, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.32).timeout


func start_smoke(origin: Vector2 = DEFAULT_SMOKE_ORIGIN) -> void:
	_smoke_origin = origin
	_smoke_emitting = true
	_spawn_smoke_puff()


func stop_smoke(clear_immediately := false) -> void:
	_smoke_emitting = false
	_smoke_spawn_accumulator = 0.0
	if clear_immediately:
		_smoke.clear()


func preview_smoke(duration := 2.2) -> void:
	start_smoke()
	await get_tree().create_timer(duration).timeout
	stop_smoke()


func start_descent(duration := 2.4, speed := 28.0) -> void:
	_shaft_background.modulate.a = 0.0
	_shaft_background.show()
	var transition := create_tween().set_parallel(true)
	transition.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transition.tween_property(_shaft_background, "modulate:a", 1.0, duration)
	transition.tween_property(self, "_shaft_target_speed", speed, duration)
	for item in _drop_foreground():
		transition.tween_property(item, "modulate:a", 0.0, duration)
	await transition.finished
	for item in _drop_foreground():
		item.hide()


func play_drop(duration := 1.05) -> void:
	if _shaft_background == null:
		return

	var previous_visibility := _shaft_background.visible
	var previous_speed := _shaft_target_speed
	var foreground_states := _hide_drop_foreground()
	_shaft_background.show()
	_shaft_target_speed = shaft_max_speed
	var fall_states := _set_falling_poses()
	await get_tree().create_timer(duration).timeout

	_shaft_target_speed = 0.0
	_shaft_speed = 0.0
	_show_landing_poses(fall_states)
	await get_tree().create_timer(0.22).timeout
	_restore_character_poses(fall_states)
	_shaft_background.visible = previous_visibility
	_shaft_target_speed = previous_speed
	_restore_drop_foreground(foreground_states)


func _setup_visual_layers() -> void:
	var elevator := get_parent()
	var scene_root := elevator.get_parent()
	var background := scene_root.get_node_or_null("BackGround") as CanvasItem
	var elevator_car := elevator.get_node_or_null("ElevatorCar") as CanvasItem
	var npcs := elevator.get_node_or_null("NPCs") as CanvasItem
	var shafts := elevator.get_node_or_null("LightShafts") as CanvasItem
	if background != null:
		background.z_index = -10
	if elevator_car != null:
		elevator_car.z_index = 0
	if npcs != null:
		npcs.z_index = 2
	if shafts != null:
		shafts.z_index = 3
	for node_name in [
		"ElevatorLeftDoor",
		"ElevatorRightDoor",
		"LeftBorder",
		"RightBorder",
		"FloorDisplay",
	]:
		var item := elevator.get_node_or_null(node_name) as CanvasItem
		if item != null:
			item.z_index = 4


func _setup_shaft_scroll() -> void:
	_shaft_background = SHAFT_BACKGROUND_SCENE.instantiate() as Node2D
	_shaft_background.name = "ShaftScroll"
	_shaft_background.z_as_relative = false
	_shaft_background.z_index = -1
	add_child(_shaft_background)

	_shaft_tile_a = _shaft_background.get_node_or_null("TileMapLayer") as TileMapLayer
	if _shaft_tile_a != null:
		var used_rect := _shaft_tile_a.get_used_rect()
		var tile_height := _shaft_tile_a.tile_set.tile_size.y
		_shaft_tile_period = maxf(float(used_rect.size.y * tile_height), 1.0)
		_shaft_tile_b = _shaft_tile_a.duplicate() as TileMapLayer
		_shaft_tile_b.name = "TileMapLayerLoop"
		_shaft_background.add_child(_shaft_tile_b)
		_shaft_tile_b.position.y = _shaft_tile_period

	for child in _shaft_background.get_children():
		if child is Sprite2D:
			_shaft_sprites.append(child)
			_shaft_sprite_home_y.append(child.position.y)
	_align_shaft_to_cabin()

	if not _shaft_sprites.is_empty():
		_shaft_sprites.sort_custom(
			func(a: Sprite2D, b: Sprite2D) -> bool: return a.position.y < b.position.y
		)
		_shaft_sprite_home_y.clear()
		for sprite in _shaft_sprites:
			_shaft_sprite_home_y.append(sprite.position.y)
		var first: Sprite2D = _shaft_sprites.front()
		var last: Sprite2D = _shaft_sprites.back()
		var average_step: float = (
			(last.position.y - first.position.y)
			/ maxf(float(_shaft_sprites.size() - 1), 1.0)
		)
		_shaft_sprite_period = last.position.y - first.position.y + average_step
		_shaft_sprite_top = -first.texture.get_height() * 0.5

	_shaft_background.hide()


func _align_shaft_to_cabin() -> void:
	if _shaft_sprites.is_empty():
		return
	var shaft_center_x := 0.0
	for sprite in _shaft_sprites:
		shaft_center_x += sprite.position.x
	shaft_center_x /= float(_shaft_sprites.size())
	_shaft_background.position.x = CABIN_RECT.get_center().x - shaft_center_x


func _update_shaft(delta: float) -> void:
	_shaft_speed = move_toward(
		_shaft_speed,
		_shaft_target_speed,
		shaft_acceleration * delta,
	)
	if not _shaft_background.visible or is_zero_approx(_shaft_speed):
		return
	_shaft_offset += _shaft_speed * delta
	if _shaft_tile_a != null and _shaft_tile_b != null:
		var tile_offset := fposmod(_shaft_offset, _shaft_tile_period)
		_shaft_tile_a.position.y = -tile_offset
		_shaft_tile_b.position.y = _shaft_tile_period - tile_offset
	for index in _shaft_sprites.size():
		_shaft_sprites[index].position.y = fposmod(
			_shaft_sprite_home_y[index] - _shaft_offset - _shaft_sprite_top,
			_shaft_sprite_period,
		) + _shaft_sprite_top


func _update_sparks(delta: float) -> void:
	for index in range(_sparks.size() - 1, -1, -1):
		var spark := _sparks[index]
		spark["age"] += delta
		if spark["age"] >= spark["life"]:
			_sparks.remove_at(index)
			continue
		spark["velocity"] += Vector2(0.0, 240.0) * delta
		spark["position"] += spark["velocity"] * delta


func _update_smoke(delta: float) -> void:
	if _smoke_emitting:
		_smoke_spawn_accumulator += delta * smoke_rate
		while _smoke_spawn_accumulator >= 1.0:
			_smoke_spawn_accumulator -= 1.0
			_spawn_smoke_puff()

	for index in range(_smoke.size() - 1, -1, -1):
		var puff := _smoke[index]
		puff["age"] += delta
		if puff["age"] >= puff["life"]:
			_smoke.remove_at(index)
			continue
		puff["position"] += puff["velocity"] * delta
		puff["position"].x += sin(puff["age"] * 4.0 + puff["phase"]) * 5.0 * delta


func _draw() -> void:
	for spark in _sparks:
		var progress: float = spark["age"] / spark["life"]
		var color := Color(1.0, lerpf(0.96, 0.42, progress), 0.08, 1.0 - progress)
		var tail: Vector2 = spark["velocity"].normalized() * lerpf(5.0, 2.0, progress)
		draw_line(
			spark["position"] - tail,
			spark["position"],
			color,
			spark["size"],
			false,
		)

	for puff in _smoke:
		var progress: float = puff["age"] / puff["life"]
		var size := lerpf(puff["start_size"], puff["end_size"], progress)
		var alpha := sin(progress * PI) * 0.58
		var color := Color(0.055, 0.06, 0.07, alpha)
		var position: Vector2 = puff["position"].round()
		draw_rect(Rect2(position - Vector2.ONE * size * 0.5, Vector2.ONE * size), color)
		draw_rect(
			Rect2(
				position + Vector2(size * 0.28, -size * 0.25),
				Vector2.ONE * size * 0.62,
			),
			Color(color, alpha * 0.72),
		)


func _spawn_smoke_puff() -> void:
	_smoke.append({
		"position": _smoke_origin + Vector2(
			_rng.randf_range(-7.0, 7.0),
			_rng.randf_range(-3.0, 3.0),
		),
		"velocity": Vector2(
			_rng.randf_range(-5.0, 5.0),
			_rng.randf_range(-23.0, -11.0),
		),
		"age": 0.0,
		"life": _rng.randf_range(1.35, 2.25),
		"start_size": _rng.randf_range(4.0, 7.0),
		"end_size": _rng.randf_range(13.0, 21.0),
		"phase": _rng.randf_range(0.0, TAU),
	})


func _flash_cabin() -> void:
	var flash := ColorRect.new()
	flash.position = CABIN_RECT.position
	flash.size = CABIN_RECT.size
	flash.color = Color(1.0, 0.82, 0.28, 0.44)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 1
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.11) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_callback(flash.queue_free)


func _spawn_shock_ghost(
	target: AnimatedSprite2D,
	target_scale_multiplier: float,
	duration: float,
	alpha: float,
) -> void:
	var texture := target.sprite_frames.get_frame_texture(
		target.animation,
		target.frame,
	)
	if texture == null:
		return

	var ghost := Sprite2D.new()
	ghost.texture = texture
	ghost.position = to_local(target.global_position)
	ghost.scale = target.scale
	ghost.modulate = Color(1.0, 0.94, 0.82, alpha)
	ghost.z_index = 1
	add_child(ghost)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		ghost,
		"scale",
		target.scale * target_scale_multiplier,
		duration,
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		ghost,
		"position",
		ghost.position + Vector2(0.0, -8.0),
		duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(ghost.queue_free)


func _set_falling_poses() -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	var characters := _characters()
	for index in characters.size():
		var character := characters[index]
		states.append({
			"character": character,
			"sprite_frames": character.sprite_frames,
			"animation": character.animation,
			"frame": character.frame,
		})
		var fall_textures := FEMALE_FALL_TEXTURES if index == 0 else MALE_FALL_TEXTURES
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		frames.add_animation(&"fall_loop")
		frames.set_animation_speed(&"fall_loop", 8.0)
		frames.set_animation_loop(&"fall_loop", true)
		frames.add_frame(&"fall_loop", fall_textures[0])
		frames.add_frame(&"fall_loop", fall_textures[1])
		frames.add_animation(&"land")
		frames.set_animation_loop(&"land", false)
		frames.add_frame(&"land", fall_textures[2])
		character.sprite_frames = frames
		character.play(&"fall_loop")
	return states


func _show_landing_poses(states: Array[Dictionary]) -> void:
	for state in states:
		var character: AnimatedSprite2D = state["character"]
		if is_instance_valid(character):
			character.play(&"land")


func _restore_character_poses(states: Array[Dictionary]) -> void:
	for state in states:
		var character: AnimatedSprite2D = state["character"]
		if not is_instance_valid(character):
			continue
		character.sprite_frames = state["sprite_frames"]
		character.play(state["animation"])
		character.frame = state["frame"]


func _drop_foreground() -> Array[CanvasItem]:
	var items: Array[CanvasItem] = []
	for node_name in [
		"LeftBorder",
		"RightBorder",
		"ElevatorLeftDoor",
		"ElevatorRightDoor",
		"FloorDisplay",
	]:
		var item := get_parent().get_node_or_null(node_name) as CanvasItem
		if item == null:
			continue
		items.append(item)

	var floor := get_parent().get_parent().get_node_or_null("Floor") as CanvasItem
	if floor != null:
		items.append(floor)
	return items


func _hide_drop_foreground() -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for item in _drop_foreground():
		states.append({"item": item, "visible": item.visible})
		item.hide()
	return states


func _restore_drop_foreground(states: Array[Dictionary]) -> void:
	for state in states:
		var item: CanvasItem = state["item"]
		if is_instance_valid(item):
			item.visible = state["visible"]


func _characters() -> Array[AnimatedSprite2D]:
	var result: Array[AnimatedSprite2D] = []
	var container := get_parent().get_node_or_null("NPCs")
	if container == null:
		return result
	for child in container.get_children():
		if child is AnimatedSprite2D:
			result.append(child)
	return result


func _first_character() -> AnimatedSprite2D:
	var characters := _characters()
	return characters[0] if not characters.is_empty() else null
