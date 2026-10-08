extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game = load("res://Stories/game.tscn").instantiate()
	game.auto_start_story = false
	root.add_child(game)
	var opening = load("res://Stories/Start/start.tscn").instantiate()
	opening.play_intro_on_ready = false
	game.get_node("AnchorHost").add_child(opening)
	var woman: AnimatedSprite2D = opening.get_node("Elevator/NPCs/NPC0")
	var man: AnimatedSprite2D = opening.get_node("Elevator/NPCs/NPC1")
	var camera: Camera2D = game.get_node("Camera2D")
	var original_woman := woman.sprite_frames
	var original_man := man.sprite_frames
	var qte: AttackQTE = load("res://Stories/QTE/attack_qte.gd").new()
	game.add_child(qte)
	qte.begin(woman, man, camera)
	qte.set_process(false)
	assert(qte.state == qte.State.MASH and qte.progress == 0)
	assert(woman.sprite_frames.get_frame_texture(&"default", 0).resource_path.ends_with("attack_woman_1.png"))
	var starting_zoom_target: float = qte.target_zoom
	qte.press_e()
	qte.press_e()
	assert(is_equal_approx(qte.target_zoom, starting_zoom_target))
	qte.press_e()
	assert(qte.target_zoom > starting_zoom_target)
	for i in 7:
		qte.press_e()
	assert(qte.progress == 10 and woman.frame == 1)
	assert(woman.sprite_frames.get_frame_texture(&"default", 1).resource_path.ends_with("attack_woman_2.png"))
	var zoom_before: float = camera.zoom.x
	qte._process(0.25)
	assert(is_equal_approx(camera.zoom.x - zoom_before, 0.2), "Camera must move at fixed zoom speed")
	for i in 10:
		qte.press_e()
	assert(qte.progress == 20 and is_equal_approx(qte.target_zoom, qte.FINAL_ZOOM))
	qte.press_e()
	assert(qte.progress == 20)
	qte._process(2.0)
	assert(qte.state == qte.State.READY and qte.ui.ready_for_q)
	qte.press_q()
	assert(qte.state == qte.State.STRIKE and woman.frame == 2 and man.frame == 0)
	assert(qte._whoosh_player.stream == qte.AIR_HIT_SOUND and qte._whoosh_player.playing)
	await create_timer(0.17, true, false, true).timeout
	assert(qte.state == qte.State.IMPACT and woman.frame == 3 and man.frame == 2 and qte.ui.impact_mode)
	assert(qte._impact_player.stream == qte.STRONG_PUNCH_SOUND and qte._impact_player.playing)
	assert(is_equal_approx(Engine.time_scale, qte.IMPACT_TIME_SCALE))
	var pre_impact_position := qte._impact_start_position
	qte._process(0.03)
	var early_impact_zoom := camera.zoom.x
	assert(early_impact_zoom > qte.FINAL_ZOOM and early_impact_zoom < qte.IMPACT_ZOOM)
	assert(qte.ui.impact_progress > 0.0)
	qte._process(0.06)
	assert(camera.zoom.x > early_impact_zoom and camera.zoom.x < qte.IMPACT_ZOOM, "The push-in must continue throughout the slow-motion beat")
	await create_timer(0.38, true, false, true).timeout
	assert(game.get_node_or_null("QTEImpactEcho1") != null and game.get_node_or_null("QTEImpactEcho2") != null, "The hit should have two delayed echoes")
	await create_timer(qte.IMPACT_DURATION + qte.IMPACT_PULLBACK_DURATION - 0.35, true, false, true).timeout
	assert(qte.state == qte.State.DONE)
	assert(not qte.ui.impact_mode)
	assert(is_equal_approx(Engine.time_scale, 1.0))
	assert(camera.global_position.distance_to(pre_impact_position) < 0.1 and is_equal_approx(camera.zoom.x, qte._start_zoom), "The camera must pull back before the ejection")
	assert(woman.sprite_frames == original_woman and man.sprite_frames == original_man)
	qte.begin(woman, man, camera)
	qte.set_process(false)
	for i in 20:
		qte.press_e()
	qte._process(2.0)
	qte.press_q()
	await create_timer(0.17, true, false, true).timeout
	assert(is_equal_approx(Engine.time_scale, qte.IMPACT_TIME_SCALE))
	qte.queue_free()
	await process_frame
	assert(is_equal_approx(Engine.time_scale, 1.0), "Removing QTE mid-hit must restore normal speed")
	print("PASS: eight split frames, 10+10 E presses, constant camera zoom, Q gate, hit poses and restoration")
	game.queue_free()
	await process_frame
	quit()

