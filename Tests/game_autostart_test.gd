extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://Stories/Bentootoo/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	assert(not game.get_node("TestUI").visible)
	assert(game._dialogue_test_running, "The full story must start automatically")
	assert(game.get_node("IntroUI/Black").visible)
	for key in [KEY_K, KEY_B, KEY_L, KEY_V, KEY_G, KEY_4, KEY_8]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		Input.parse_input_event(event)
	await process_frame
	assert(current_scene == game, "Test shortcuts must not change the scene")
	assert(game._current_anchor == null, "Test shortcuts must not skip the opening")
	print("PASS: hidden test UI, disabled shortcuts, automatic full-story opening")
	game.queue_free()
	await process_frame
	quit()
