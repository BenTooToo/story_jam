extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	var woman := AnimatedSprite2D.new()
	woman.position = Vector2(290, 215)
	stage.add_child(woman)
	var man := AnimatedSprite2D.new()
	man.position = Vector2(358, 215)
	stage.add_child(man)
	var camera := Camera2D.new()
	camera.position = Vector2(320, 180)
	stage.add_child(camera)
	var duel: RooftopDuel = load("res://Stories/Bentootoo/QTE/rooftop_duel.gd").new()
	stage.add_child(duel)
	duel.begin(woman, man, camera)
	await create_timer(1.0).timeout
	assert(duel._visual.size == Vector2(640, 360))
	assert(woman.is_playing() and woman.sprite_frames.get_frame_count(&"default") == 4)
	assert(man.is_playing() and man.sprite_frames.get_frame_count(&"default") == 4)
	assert(woman.sprite_frames.get_frame_texture(&"default", 0) is AtlasTexture)
	assert(man.scale.x < 0.0)
	assert(duel.showing_rule and duel.message == "必须要在时间内敲击正确的方向键")
	assert(not duel.running and duel.time_left == 5.0)
	for glyph in ["↑", "↓", "←", "→"]:
		assert(duel.FONT.has_char(glyph.unicode_at(0)), "Direction glyph missing from the QTE font")
	await create_timer(3.7).timeout
	assert(not duel.showing_rule and duel.message == "" and duel.countdown_left > 0.0)
	duel._process(3.0)
	assert(duel.running and duel.round_index == 0 and duel.time_left == 5.0)
	assert(duel._glyph_color(0) == Color.WHITE)
	duel.press_key(KEY_UP)
	assert(duel._glyph_color(0) == Color(1.0, 0.2, 0.29))
	assert(duel._glyph_color(1) == Color.WHITE)
	duel.press_key(KEY_RIGHT)
	assert(man.animation == &"attack" and man.sprite_frames.get_frame_count(&"attack") == 4)
	assert(man.sprite_frames.get_frame_texture(&"attack", 0) == duel.MAN_ATTACK_FRAMES[0])
	var man_hit := duel.get_node_or_null("ManAttackSound") as AudioStreamPlayer
	assert(man_hit != null and man_hit.playing and man_hit.stream == duel.HIT_SOUND)
	await create_timer(1.3).timeout
	assert(duel.running and duel.round_index == 0 and duel.input_index == 0)
	assert(man.animation == &"default" and man.is_playing())
	assert(woman.position == Vector2(290, 215) and man.position == Vector2(358, 215))
	for key in duel.sequence.duplicate():
		duel.press_key(key)
	assert(duel.running and not duel._busy and duel.round_index == 1 and duel.input_index == 0)
	assert(duel.message == "")
	assert(woman.animation == &"attack" and woman.sprite_frames.get_frame_count(&"attack") == 4)
	assert(woman.sprite_frames.get_frame_texture(&"attack", 0) == duel.WOMAN_ATTACK_FRAMES[0])
	var woman_hit := duel.get_node_or_null("WomanAttackSound") as AudioStreamPlayer
	assert(woman_hit != null and woman_hit.playing and woman_hit.stream == duel.HIT_SOUND)
	duel.press_key(KEY_UP)
	assert(duel.input_index == 1, "The next direction must be accepted during the hit animation")
	await create_timer(0.7).timeout
	assert(duel.running and duel.round_index == 1 and woman.animation == &"default" and woman.is_playing())
	assert(duel.time_left <= 5.0 and duel._round_time() == 5.0)
	duel._process(5.1)
	await create_timer(1.3).timeout
	assert(duel.running and duel.round_index == 1 and duel.input_index == 0)
	for key in duel.sequence.duplicate():
		duel.press_key(key)
	assert(duel.running and not duel._busy and duel.round_index == 2 and duel.sequence.size() == 12 and duel._round_time() == 10.0)
	duel.press_key(KEY_UP)
	assert(duel.input_index == 1, "Final directions must start without a round transition pause")
	duel.press_key(KEY_LEFT)
	await create_timer(1.3).timeout
	assert(duel.running and duel.final_retry and duel.sequence == duel.FINAL_RETRY)
	duel.press_key(KEY_LEFT)
	await create_timer(1.3).timeout
	assert(duel.running and not duel.final_retry and duel.sequence.size() == 12)
	for key in duel.sequence.duplicate():
		duel.press_key(key)
	await duel.completed
	assert(duel.bar_progress == 0.0)
	duel.begin(woman, man, camera)
	await create_timer(4.7).timeout
	duel._process(3.0)
	for round_number in duel.ROUNDS.size():
		for key in duel.ROUNDS[round_number]:
			duel.press_key(key)
		if round_number < duel.ROUNDS.size() - 1:
			assert(duel.running and not duel._busy and duel.round_index == round_number + 1)
	await duel.completed
	assert(duel.bar_progress == 0.0)
	print("PASS: rooftop duel accepts uninterrupted sequences, retries failures, and completes")
	stage.queue_free()
	await process_frame
	quit()
