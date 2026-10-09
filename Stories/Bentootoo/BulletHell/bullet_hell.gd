extends Node2D
## Standalone encounter. B opens it from the story test scene.
signal encounter_finished(won: bool)

enum Phase { BLACK, FADE, STILL, TRANSFORM, REVEAL, PLAY, BREAK, LOST, WON }
const HEART = preload("res://Assets/efx/love_efx/心心1.png")
const STANDING = preload("res://Assets/Prof. Gao/npc standing.png")
const WOMAN_HEAD = preload("res://Assets/ROMART/npc0.png")
const MAN_HEAD = preload("res://Assets/ROMART/npc1.png")
const FONT = preload("res://Assets/Theme/像素字体.ttf")
const ARENA := Rect2(112, 54, 384, 246)
const CENTER := Vector2(320, 180)
const DURATION := 40.0
const SPEED := 135.0
const RADIUS := 4.0
const RED := Color(1.0, 0.12, 0.22)
const TRANSFORM_BEAT := 0.4
const WARNING_TIME := 0.5
const METEOR_RADIUS := Vector2(22.0, 16.0)
var stage := -1
var stage_time := 0.0
var phase := Phase.BLACK
var phase_time := 0.0
var elapsed := 0.0
var hits := 0
var immunity := 0.0
var wave_time := 0.0
var wave := 0
var hazards: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var flash := 0.0
var portrait_time := 0.0
var woman: AnimatedSprite2D
var heart: Sprite2D
var woman_head: Sprite2D
var man_head: Sprite2D
var heartbeat: AudioStreamPlayer
var ending_layer: CanvasLayer
var ending_black: ColorRect
var ending_text: Label
var restart_prompt: Label
var ending_tween: Tween
var ending_blink_tween: Tween
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	woman = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 6.0)
	for i in 4:
		var frame := AtlasTexture.new()
		frame.atlas = STANDING
		frame.region = Rect2(i * 256, 256, 256, 256)
		frames.add_frame(&"default", frame)
	woman.sprite_frames = frames
	woman.position = CENTER
	woman.scale = Vector2.ONE * 0.65
	woman.offset = Vector2(10, 0)
	woman.modulate.a = 0.0
	add_child(woman)
	heart = Sprite2D.new()
	heart.texture = HEART
	heart.scale = Vector2.ONE * 2.0
	heart.position = CENTER
	heart.hide()
	add_child(heart)
	woman_head = _portrait(WOMAN_HEAD, Vector2(556, 76))
	man_head = _portrait(MAN_HEAD, Vector2(556, 278))
	heartbeat = AudioStreamPlayer.new()
	heartbeat.stream = preload("res://Assets/Sound Effects/sfx_heart_single.mp3")
	heartbeat.volume_db = -10.0
	add_child(heartbeat)
	ending_layer = CanvasLayer.new()
	ending_layer.layer = 100
	add_child(ending_layer)
	ending_black = ColorRect.new()
	ending_black.color = Color.BLACK
	ending_black.size = Vector2(640, 360)
	ending_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ending_black.modulate.a = 0.0
	ending_layer.add_child(ending_black)
	ending_text = Label.new()
	ending_text.text = "你的智商低低的，还蛮可爱"
	ending_text.size = Vector2(640, 360)
	ending_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ending_text.add_theme_font_override("font", FONT)
	ending_text.add_theme_font_size_override("font_size", 25)
	ending_text.add_theme_color_override("font_color", RED)
	ending_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ending_text.modulate.a = 0.0
	ending_text.visible_characters = 0
	ending_layer.add_child(ending_text)
	restart_prompt = Label.new()
	restart_prompt.text = "点一下重新开始" if TouchPad.active else "按r键重新开始"
	restart_prompt.position = Vector2(0, 218)
	restart_prompt.size = Vector2(640, 32)
	restart_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_prompt.add_theme_font_override("font", FONT)
	restart_prompt.add_theme_font_size_override("font_size", 12)
	restart_prompt.add_theme_color_override("font_color", RED)
	restart_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	restart_prompt.modulate.a = 0.0
	ending_layer.add_child(restart_prompt)

func _portrait(texture: Texture2D, at: Vector2) -> Sprite2D:
	var crop := AtlasTexture.new()
	crop.atlas = texture
	var side := minf(texture.get_width(), texture.get_height()) * 0.65
	crop.region = Rect2((texture.get_width() - side) * 0.5, 4, side, side)
	var sprite := Sprite2D.new()
	sprite.texture = crop
	sprite.position = at
	sprite.scale = Vector2.ONE * (34.0 / side)
	sprite.hide()
	add_child(sprite)
	return sprite

func _change(next: Phase) -> void:
	phase = next
	phase_time = 0.0

func _shake(time: float, beat: float = 1.0) -> float:
	# Same 1-second cadence and final 0.12-second, two-cycle shake as MutationFX.
	var local := fmod(time, beat)
	var start := beat - 0.12
	return sin((local - start) / 0.12 * TAU * 2.0) * 1.5 if local >= start else 0.0

func _process(delta: float) -> void:
	phase_time += delta
	portrait_time += delta
	_update_sparks(delta)
	match phase:
		Phase.BLACK:
			if phase_time >= 0.8:
				woman.play()
				_change(Phase.FADE)
		Phase.FADE:
			woman.modulate.a = smoothstep(0.0, 2.0, phase_time)
			if phase_time >= 2.0:
				woman.stop()
				woman.frame = 0
				_change(Phase.STILL)
		Phase.STILL:
			if phase_time >= 0.7:
				_change(Phase.TRANSFORM)
		Phase.TRANSFORM:
			woman.position.x = CENTER.x + _shake(phase_time, TRANSFORM_BEAT)
			if phase_time >= TRANSFORM_BEAT * 3.0:
				woman.hide()
				heart.show()
				_burst(CENTER)
				_change(Phase.REVEAL)
		Phase.REVEAL:
			if phase_time >= 0.7:
				woman_head.show()
				man_head.show()
				TouchPad.use(&"bullet")
				_change(Phase.PLAY)
		Phase.PLAY:
			_tick_play(delta)
		Phase.BREAK:
			heart.position.x = heart.get_meta("break_x") + _shake(phase_time)
			if phase_time >= 2.0:
				heart.hide()
				_burst(heart.position)
				TouchPad.clear()
				_change(Phase.LOST)
				_play_ending(false)
				encounter_finished.emit(false)
	woman_head.position.y = lerpf(76.0, 278.0, elapsed / DURATION)
	woman_head.rotation = sin(portrait_time * 3.0) * 0.10
	queue_redraw()

func _tick_play(delta: float) -> void:
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	var speed := SPEED * (0.45 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	heart.position += direction.normalized() * speed * delta
	heart.position = heart.position.clamp(ARENA.position + Vector2.ONE * 8, ARENA.end - Vector2.ONE * 8)
	immunity = maxf(0.0, immunity - delta)
	heart.modulate.a = 0.35 if immunity > 0.0 and fmod(immunity, 0.16) < 0.08 else 1.0
	if stage < 0:
		_begin_stage(0)
	stage_time += delta
	# Progress reserves the end of each section until its last obstacle leaves.
	elapsed = stage * 10.0 + minf(stage_time, 9.9)
	wave_time -= delta
	if wave_time <= 0.0 and stage_time < 8.0:
		_spawn_wave()
		wave_time = [0.8, 1.65, 2.35, 1.5][stage]
	for i in range(hazards.size() - 1, -1, -1):
		var hazard := hazards[i]
		if hazard["kind"] == 2:
			hazard["age"] += delta
			var age: float = hazard["age"]
			if age < WARNING_TIME:
				continue
			if hazard.get("through", false):
				hazard["position"] = hazard["origin"] + hazard["velocity"] * (age - WARNING_TIME)
				var body := Rect2(hazard["position"], hazard["size"])
				var velocity: Vector2 = hazard["velocity"]
				if (velocity.x > 0 and body.position.x > 640) or (velocity.x < 0 and body.end.x < 0) or (velocity.y > 0 and body.position.y > 360) or (velocity.y < 0 and body.end.y < 0):
					hazards.remove_at(i)
					continue
			else:
				_update_returning_ram(hazard, age)
				if age >= WARNING_TIME + 1.3:
					hazards.remove_at(i)
					continue
		else:
			hazard["position"] += hazard["velocity"] * delta
			if hazard["kind"] == 1:
				hazard["rotation"] = hazard.get("rotation", 0.0) + delta * hazard.get("spin", 2.0)
		var p: Vector2 = hazard["position"]
		# Meteors keep travelling after crossing the wall. The wall clips their
		# drawing below; only the outer cleanup margin actually frees them.
		if hazard["kind"] == 1 and not ARENA.grow(64.0).has_point(p):
			hazards.remove_at(i)
			continue
		if hazard["kind"] == 0 and (p.y < 20 or p.y > 338 or p.x < 78 or p.x > 528):
			hazards.remove_at(i)
			continue
		var collided := false
		if hazard["kind"] != 1:
			var bounds := Rect2(p, hazard["size"])
			var nearest := heart.position.clamp(bounds.position, bounds.end)
			collided = nearest.distance_to(heart.position) <= RADIUS
		else:
			var relative := (heart.position - p).rotated(-hazard.get("rotation", 0.0))
			var axes: Vector2 = hazard.get("radius", METEOR_RADIUS) + Vector2.ONE * RADIUS
			var ellipse: float = (relative.x / axes.x) ** 2 + (relative.y / axes.y) ** 2
			collided = ellipse <= 1.0
		if collided and immunity <= 0.0:
			_take_hit()
			if phase != Phase.PLAY:
				return
	if stage_time >= 10.0 and hazards.is_empty():
		if stage < 3:
			_begin_stage(stage + 1)
		else:
			elapsed = DURATION
			heart.modulate.a = 1.0
			TouchPad.clear()
			_change(Phase.WON)
			_play_ending(true)
			encounter_finished.emit(true)

func _play_ending(won: bool) -> void:
	if ending_tween != null and ending_tween.is_valid():
		ending_tween.kill()
	if ending_blink_tween != null and ending_blink_tween.is_valid():
		ending_blink_tween.kill()
	ending_tween = create_tween()
	ending_tween.tween_property(ending_black, "modulate:a", 1.0, 1.25 if won else 0.65)
	if won:
		ending_tween.tween_callback(
			func() -> void:
				get_tree().change_scene_to_file.call_deferred(
					"res://Stories/Bentootoo/End/love_ending.tscn"
				)
		)
	else:
		ending_tween.tween_callback(func() -> void: ending_text.modulate.a = 1.0)
		ending_tween.tween_property(ending_text, "visible_characters", ending_text.text.length(), 1.9)
		ending_tween.tween_interval(1.0)
		ending_tween.tween_callback(_start_restart_prompt)

func _start_restart_prompt() -> void:
	restart_prompt.modulate.a = 1.0
	# 手机上整屏就是那个 R 键
	TouchPad.use_tap([KEY_R])
	ending_blink_tween = create_tween().set_loops()
	ending_blink_tween.set_trans(Tween.TRANS_SINE)
	ending_blink_tween.tween_property(restart_prompt, "modulate:a", 0.25, 1.2)
	ending_blink_tween.tween_property(restart_prompt, "modulate:a", 1.0, 1.2)

func _begin_stage(index: int) -> void:
	stage = index
	stage_time = 0.0
	wave = 0
	wave_time = 0.35

func _update_returning_ram(hazard: Dictionary, age: float) -> void:
	var travel := (age - WARNING_TIME) / 0.65
	var weight := travel if travel <= 1.0 else 2.0 - travel
	hazard["position"] = hazard["origin"].lerp(hazard["target"], weight)

func _spawn_wave() -> void:
	if stage == 0:
		_spawn_meteor()
	elif stage == 2:
		_spawn_ram()
	else:
		_spawn_gate(stage == 3)
	wave += 1

func _spawn_meteor() -> void:
	# Sparse, rotating rocks aim at a central area, never home in on the player.
	var origin := Vector2.ZERO
	match rng.randi_range(0, 3):
		0: origin = Vector2(100, rng.randf_range(64, 290))
		1: origin = Vector2(508, rng.randf_range(64, 290))
		2: origin = Vector2(rng.randf_range(124, 484), 42)
		3: origin = Vector2(rng.randf_range(124, 484), 312)
	var target := ARENA.get_center() + Vector2(rng.randf_range(-65, 65), rng.randf_range(-40, 40))
	hazards.append({"kind": 1, "position": origin, "velocity": (target - origin).normalized() * rng.randf_range(48, 66), "rotation": rng.randf_range(0, TAU), "spin": rng.randf_range(-3, 3), "radius": METEOR_RADIUS * rng.randf_range(0.9, 1.15), "shape_seed": rng.randf_range(0, TAU)})

func _spawn_ram() -> void:
	if wave >= 2:
		_spawn_ram_wall(wave == 3)
		return
	# Freeze the target lane before warning; then enter and retrace the same path.
	var size := Vector2(150, 34) if wave % 2 == 0 else Vector2(34, 110)
	var target := (heart.position - size * 0.5).clamp(ARENA.position, ARENA.end - size)
	var origin := target
	match wave % 4:
		0: origin.x = -size.x
		1: origin.y = -size.y
		2: origin.x = 640
		3: origin.y = 360
	var warning := Rect2(origin, size).merge(Rect2(target, size)).intersection(ARENA)
	hazards.append({"kind": 2, "position": origin, "origin": origin, "target": target, "size": size, "age": 0.0, "warning": warning})

func _spawn_ram_wall(vertical: bool) -> void:
	# Two central safe lanes remain open; all other lanes sweep straight through.
	var count := 12 if vertical else 8
	var span := ARENA.size.x if vertical else ARENA.size.y
	var lane := span / count
	var safe_lanes := [4, 7] if vertical else [2, 5]
	for index in count:
		if index in safe_lanes:
			continue
		var size := Vector2(lane, 110) if vertical else Vector2(150, lane)
		var origin := Vector2(ARENA.position.x + index * lane, -size.y) if vertical else Vector2(640, ARENA.position.y + index * lane)
		var velocity := Vector2(0, 290) if vertical else Vector2(-380, 0)
		var warning := Rect2(Vector2(origin.x, ARENA.position.y), Vector2(lane, ARENA.size.y)) if vertical else Rect2(Vector2(ARENA.position.x, origin.y), Vector2(ARENA.size.x, lane))
		hazards.append({"kind": 2, "position": origin, "origin": origin, "size": size, "age": 0.0, "velocity": velocity, "through": true, "warning": warning})

func _spawn_gate(fast: bool) -> void:
	var gaps := [220.0, 320.0, 390.0, 290.0, 205.0, 310.0]
	var gap: float = gaps[wave % gaps.size()]
	var rise := 90.0 if fast else 74.0
	# The final two gates leave 18 px: just above the heart's 12 px visible width.
	var half_gap := 9.0 if fast and wave >= 4 else (29.0 if fast else 48.0)
	for segment in [Vector2(114, gap - half_gap), Vector2(gap + half_gap, 494)]:
		hazards.append({"kind": 0, "position": Vector2(segment.x, 306), "size": Vector2(segment.y - segment.x, 8), "velocity": Vector2(0, -rise)})

func _take_hit() -> void:
	if phase != Phase.PLAY or immunity > 0.0:
		return
	hits += 1
	immunity = 1.25
	heartbeat.play()
	if hits >= 3:
		hazards.clear()
		heart.modulate.a = 1.0
		heart.set_meta("break_x", heart.position.x)
		_change(Phase.BREAK)

func _burst(origin: Vector2) -> void:
	# Elevator spark physics: short-lived streaks, gravity, and a fast flash; red palette.
	flash = 0.14
	heartbeat.play()
	for i in 36:
		var angle := rng.randf_range(0.0, TAU)
		sparks.append({"position": origin, "velocity": Vector2.from_angle(angle) * rng.randf_range(75, 145), "age": 0.0, "life": rng.randf_range(0.24, 0.46), "size": rng.randf_range(1.0, 2.2)})

func _update_sparks(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	for i in range(sparks.size() - 1, -1, -1):
		var spark := sparks[i]
		spark["age"] += delta
		if spark["age"] >= spark["life"]:
			sparks.remove_at(i)
			continue
		spark["velocity"] += Vector2(0, 240) * delta
		spark["position"] += spark["velocity"] * delta

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and phase == Phase.LOST:
			_restart()
			get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	TouchPad.clear()

func _restart() -> void:
	TouchPad.clear()
	if ending_tween != null and ending_tween.is_valid():
		ending_tween.kill()
	if ending_blink_tween != null and ending_blink_tween.is_valid():
		ending_blink_tween.kill()
	ending_black.modulate.a = 0.0
	ending_text.modulate.a = 0.0
	ending_text.visible_characters = 0
	restart_prompt.modulate.a = 0.0
	hazards.clear()
	sparks.clear()
	hits = 0
	elapsed = 0.0
	immunity = 0.0
	wave = 0
	stage = -1
	stage_time = 0.0
	wave_time = 0.0
	flash = 0.0
	portrait_time = 0.0
	heart.position = CENTER
	heart.modulate.a = 1.0
	heart.hide()
	woman.position = CENTER
	woman.modulate.a = 0.0
	woman.show()
	woman_head.hide()
	man_head.hide()
	_change(Phase.BLACK)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color.BLACK)
	if phase >= Phase.PLAY:
		draw_rect(ARENA.grow(3), Color.WHITE, false, 3)
		draw_rect(Rect2(551, 78, 10, 200), Color(0.3, 0.3, 0.3), false, 1)
		draw_rect(Rect2(553, 78, 6, 200 * elapsed / DURATION), RED)
		for i in 3:
			var tint := RED if i < 3 - hits else Color(0.24, 0.24, 0.24)
			draw_texture(HEART, Vector2(116 + 20 * i, 321), tint)
		for hazard in hazards:
			var p: Vector2 = hazard["position"]
			if hazard["kind"] == 2 and hazard["age"] < WARNING_TIME:
				var warning: Rect2 = hazard["warning"]
				var alpha := 0.65 if fmod(hazard["age"], 0.16) < 0.08 else 0.18
				draw_rect(warning, Color(1, 0.05, 0.1, alpha))
				draw_rect(warning, RED, false, 2)
				# Edge chevrons distinguish the source even when a warning spans the arena.
				var origin: Vector2 = hazard["origin"]
				var direction := Vector2.RIGHT
				var marker := Vector2(ARENA.position.x + 8, warning.get_center().y)
				if origin.x >= 640:
					direction = Vector2.LEFT
					marker = Vector2(ARENA.end.x - 8, warning.get_center().y)
				elif origin.y < 0:
					direction = Vector2.DOWN
					marker = Vector2(warning.get_center().x, ARENA.position.y + 8)
				elif origin.y >= 360:
					direction = Vector2.UP
					marker = Vector2(warning.get_center().x, ARENA.end.y - 8)
				var side := direction.orthogonal() * 4
				draw_line(marker - direction * 4 + side, marker + direction * 4, RED, 2)
				draw_line(marker - direction * 4 - side, marker + direction * 4, RED, 2)
			elif hazard["kind"] != 1:
				var rect := Rect2(p, hazard["size"]).intersection(ARENA)
				if rect.has_area():
					draw_rect(rect, Color.WHITE)
					for x in [rect.position.x, rect.end.x - 3]:
						draw_rect(Rect2(x, rect.position.y - 2, 3, rect.size.y + 4).intersection(ARENA), Color.WHITE)
			else:
				_draw_meteor(hazard)
	for spark in sparks:
		var progress: float = spark["age"] / spark["life"]
		var color := Color(1.0, lerpf(0.25, 0.02, progress), 0.08, 1.0 - progress)
		var tail: Vector2 = spark["velocity"].normalized() * lerpf(8.0, 2.0, progress)
		draw_line(spark["position"] - tail, spark["position"], color, spark["size"])
	if flash > 0.0:
		draw_rect(Rect2(0, 0, 640, 360), Color(1, 0.02, 0.08, flash / 0.14 * 0.30))

func _draw_meteor(hazard: Dictionary) -> void:
	var center: Vector2 = hazard["position"]
	var radius: Vector2 = hazard.get("radius", METEOR_RADIUS)
	var rotation: float = hazard.get("rotation", 0.0)
	var seed: float = hazard.get("shape_seed", 0.0)
	# A hollow, irregular elliptical silhouette like a classic asteroid sprite.
	# Every line is clipped to the arena so the visible border acts as a wall.
	for ring in 2:
		var scale_factor := 1.0 if ring == 0 else 0.68
		var previous := Vector2.ZERO
		for i in 17:
			var angle := i * TAU / 16.0
			var roughness := 1.0 + 0.11 * sin(angle * 5.0 + seed) + 0.06 * cos(angle * 9.0 - seed)
			var point := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y).rotated(rotation) * scale_factor * roughness
			if i > 0:
				var segment := _clip_to_arena(previous, point)
				if segment.size() == 2:
					draw_line(segment[0], segment[1], Color.WHITE if ring == 0 else Color(0.65, 0.65, 0.65), 2.0 if ring == 0 else 1.0)
			previous = point

func _clip_to_arena(a: Vector2, b: Vector2) -> PackedVector2Array:
	var delta := b - a
	var enter := 0.0
	var leave := 1.0
	for edge in [Vector2(-delta.x, a.x - ARENA.position.x), Vector2(delta.x, ARENA.end.x - a.x), Vector2(-delta.y, a.y - ARENA.position.y), Vector2(delta.y, ARENA.end.y - a.y)]:
		var p: float = edge.x
		var q: float = edge.y
		if is_zero_approx(p):
			if q < 0.0:
				return PackedVector2Array()
			continue
		var t: float = q / p
		if p < 0.0:
			enter = maxf(enter, t)
		else:
			leave = minf(leave, t)
		if enter > leave:
			return PackedVector2Array()
	return PackedVector2Array([a + delta * enter, a + delta * leave])
