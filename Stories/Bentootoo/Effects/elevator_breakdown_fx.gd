extends Node2D
class_name ElevatorBreakdownFX

const SHAFT_BACKGROUND_SCENE := preload(
	"res://Assets/envirment/tiles/ElevatorShaftBackground.tscn"
)
const HEARTBEAT_SOUND := preload("res://Assets/Sound Effects/sfx_heart_single.mp3")
const ROOF_SCENE := preload("res://Stories/Bentootoo/Effects/elevator_roof.gd")
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
const LIZARD_FALL_TEXTURES: Array[Texture2D] = [
	preload("res://Assets/caracter/lizard_girl/liz_falling/蜥蜴下落1.png"),
	preload("res://Assets/caracter/lizard_girl/liz_falling/蜥蜴下落2.png"),
	preload("res://Assets/caracter/lizard_girl/liz_falling/蜥蜴下落3.png"),
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
var _story_foreground_states: Array[Dictionary] = []
var _story_fall_states: Array[Dictionary] = []
var _roof: Node2D
var _roof_foreground_states: Array[Dictionary] = []
var _roof_woman_fall_frames: SpriteFrames


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


func start_story_drop(man: AnimatedSprite2D) -> void:
	if _shaft_background == null:
		return

	_story_foreground_states = _hide_drop_foreground()
	_shaft_background.show()
	_shaft_target_speed = shaft_max_speed
	_story_fall_states = _set_falling_poses(true)

	# 保持原来的上移速度，但持续到男人完全离开屏幕。
	var rise := create_tween()
	rise.tween_property(man, "position:y", -190.0, 1.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await rise.finished
	man.hide()


func finish_story_drop(returning_man: Sprite2D) -> void:
	# 减速开始时把蜥蜴人锁定为下落动画的最后一帧。
	_show_landing_poses(_story_fall_states)
	var slowdown := create_tween()
	slowdown.tween_property(self, "_shaft_target_speed", 0.0, 2.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await slowdown.finished

	_shaft_target_speed = 0.0
	_shaft_speed = 0.0
	_restore_drop_foreground(_story_foreground_states)
	await get_tree().create_timer(2.0).timeout

	# 使用场景顶部预埋的独立男人图，匀速穿过并离开屏幕。
	if is_instance_valid(returning_man):
		returning_man.position.y = -150.0
		returning_man.show()
		var fall := create_tween()
		fall.tween_property(returning_man, "position:y", 520.0, 2.65) \
			.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		await fall.finished
		returning_man.queue_free()

	_story_foreground_states.clear()
	_story_fall_states.clear()


func play_woman_jump(character: AnimatedSprite2D) -> void:
	if not is_instance_valid(character):
		return

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"jump")
	frames.set_animation_loop(&"jump", true)
	frames.set_animation_speed(&"jump", 8.0)
	# The last texture is the landing pose; the jump never reaches the ground.
	for index in range(FEMALE_FALL_TEXTURES.size() - 1):
		frames.add_frame(&"jump", FEMALE_FALL_TEXTURES[index])
	character.sprite_frames = frames
	character.flip_h = false
	character.play(&"jump")
	character.z_index = 110

	var start := character.position
	var finish := start + Vector2(125.0, 260.0)
	var jump := create_tween()
	jump.tween_method(
		_set_jump_progress.bind(character, start, finish),
		0.0,
		1.0,
		1.15,
	).set_trans(Tween.TRANS_LINEAR)
	await jump.finished
	character.hide()


func play_rooftop_landing(woman: AnimatedSprite2D, camera: Camera2D) -> void:
	if not is_instance_valid(woman) or not is_instance_valid(camera) or _shaft_background == null:
		return
	var camera_home := camera.global_position
	_roof_foreground_states = _hide_drop_foreground()
	for node_name in ["ElevatorCar", "LightShafts"]:
		var item := get_parent().get_node_or_null(node_name) as CanvasItem
		if item != null:
			_roof_foreground_states.append({"item": item, "visible": item.visible})
			item.hide()
	_shaft_background.modulate.a = 1.0
	_shaft_background.show()
	_shaft_target_speed = 250.0
	_roof = ROOF_SCENE.new()
	_roof.name = "ElevatorRoof"
	_roof.z_index = 1
	get_parent().add_child(_roof)

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"fall")
	frames.set_animation_loop(&"fall", true)
	frames.set_animation_speed(&"fall", 8.0)
	frames.add_frame(&"fall", FEMALE_FALL_TEXTURES[0])
	frames.add_frame(&"fall", FEMALE_FALL_TEXTURES[1])
	frames.add_animation(&"land")
	frames.add_frame(&"land", FEMALE_FALL_TEXTURES[2])
	_roof_woman_fall_frames = frames
	woman.sprite_frames = frames
	woman.z_index = 2
	woman.play(&"fall")
	woman.position = Vector2(290.0, 216.0)
	var rise := create_tween().set_parallel(true)
	rise.tween_property(woman, "position:y", -85.0, 1.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.tween_property(camera, "global_position", camera_home + Vector2(0.0, -205.0), 2.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await rise.finished
	var land := create_tween().set_parallel(true)
	land.tween_property(woman, "position:y", 215.0, 2.65) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	land.tween_property(camera, "global_position", camera_home, 2.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	land.tween_property(self, "_shaft_target_speed", 28.0, 2.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await land.finished
	woman.play(&"land")


func play_rooftop_man_fall() -> AnimatedSprite2D:
	var man := AnimatedSprite2D.new()
	man.name = "FallingMan"
	man.position = Vector2(358.0, -90.0)
	man.scale = Vector2.ONE * 0.55
	man.z_index = 2
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"fall")
	frames.set_animation_loop(&"fall", true)
	frames.set_animation_speed(&"fall", 8.0)
	frames.add_frame(&"fall", MALE_FALL_TEXTURES[0])
	frames.add_frame(&"fall", MALE_FALL_TEXTURES[1])
	frames.add_animation(&"land")
	frames.add_frame(&"land", MALE_FALL_TEXTURES[2])
	man.sprite_frames = frames
	get_parent().get_node("NPCs").add_child(man)
	man.play(&"fall")
	var fall := create_tween()
	fall.tween_property(man, "position:y", 215.0, 0.65) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall.finished
	man.play(&"land")
	return man


func play_rooftop_second_breakdown(woman: AnimatedSprite2D, camera: Camera2D) -> void:
	if not is_instance_valid(woman) or not is_instance_valid(camera) or not is_instance_valid(_roof):
		return
	var roof_home := _roof.position
	var camera_home := camera.global_position
	play_sparks(Vector2(367.0, 277.0), 28)
	_shaft_target_speed = 600.0
	var shake := create_tween()
	for index in 9:
		var direction := -1.0 if index % 2 == 0 else 1.0
		shake.tween_property(_roof, "position", roof_home + Vector2(direction * 3.0, 2.0), 0.045)
		shake.parallel().tween_property(camera, "global_position", camera_home + Vector2(direction * 2.0, 0.0), 0.045)
	shake.tween_property(_roof, "position", roof_home + Vector2(0.0, 12.0), 0.1)
	shake.parallel().tween_property(camera, "global_position", camera_home, 0.1)
	await shake.finished
	woman.sprite_frames = _roof_woman_fall_frames
	woman.play(&"fall")
	var plunge := create_tween().set_parallel(true)
	plunge.tween_property(woman, "position", woman.position + Vector2(-15.0, 430.0), 1.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	plunge.tween_property(woman, "rotation", -0.35, 1.15)
	plunge.tween_property(_roof, "position:y", roof_home.y + 110.0, 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await plunge.finished
	woman.hide()


func _set_jump_progress(
	progress: float,
	character: AnimatedSprite2D,
	start: Vector2,
	finish: Vector2,
) -> void:
	var jump_position := start.lerp(finish, progress)
	jump_position.y -= sin(progress * PI) * 72.0
	character.position = jump_position


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


func _set_falling_poses(lizard_woman := false) -> Array[Dictionary]:
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
		var fall_textures := MALE_FALL_TEXTURES
		if index == 0:
			fall_textures = LIZARD_FALL_TEXTURES if lizard_woman else FEMALE_FALL_TEXTURES
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
