extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var opening = load("res://Stories/Start/start.tscn").instantiate()
	opening.play_intro_on_ready = false
	root.add_child(opening)
	var woman: AnimatedSprite2D = opening.get_node("Elevator/NPCs/NPC0")
	var man: AnimatedSprite2D = opening.get_node("Elevator/NPCs/NPC1")
	var original_frames := woman.sprite_frames
	var original_offset := woman.offset

	await opening.play_mutation(woman)
	assert(woman.animation == &"transformed_idle")
	await opening.start_story_breakdown(man)
	assert(woman.animation == &"fall_loop")
	assert(woman.sprite_frames.get_frame_texture(&"fall_loop", 0) \
		== load("res://Assets/caracter/lizard_girl/liz_falling/蜥蜴下落1.png"))
	await opening.finish_story_breakdown()
	assert(woman.animation == &"land")
	await opening.play_reversion()
	assert(woman.sprite_frames == original_frames)
	assert(woman.offset == original_offset)
	opening.queue_free()
	await process_frame

	var middle = load("res://Stories/Middle/middle.tscn").instantiate()
	middle.play_intro_on_ready = false
	root.add_child(middle)
	await middle.close_doors()
	await middle.start_descent()
	var shaft: CanvasItem = middle.get_node("Elevator/ElevatorBreakdownFX/ShaftScroll")
	assert(shaft.visible and is_equal_approx(shaft.modulate.a, 1.0))
	assert(is_zero_approx(middle.get_node("Elevator/ElevatorLeftDoor").modulate.a))
	var cg_woman: AnimatedSprite2D = middle.get_node("Elevator/NPCs/NPC0")
	await middle.play_woman_jump(cg_woman)
	assert(cg_woman.sprite_frames.get_frame_count(&"jump") == 2)
	assert(cg_woman.sprite_frames.get_frame_texture(&"jump", 0) \
		== load("res://Assets/caracter/lizard_girl/liz_falling/女下落1.png"))
	print("PASS: lizard fall, reverse mutation, shaft reveal, door fade, woman jump")
	middle.queue_free()
	await process_frame
	quit()
