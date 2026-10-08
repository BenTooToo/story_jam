extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var cg2 = load("res://Stories/Middle/middle.tscn").instantiate()
	cg2.play_intro_on_ready = false
	root.add_child(cg2)
	await cg2.close_doors()
	await cg2.start_descent()
	await cg2.play_sparks()
	cg2.start_smoke()
	await create_timer(0.25).timeout
	assert(cg2.get_node("Elevator/ElevatorBreakdownFX")._smoke_emitting)
	cg2.stop_smoke()
	var woman: AnimatedSprite2D = cg2.get_node("Elevator/NPCs/NPC0")
	var camera := Camera2D.new()
	cg2.add_child(camera)
	camera.global_position = Vector2(320, 180)
	await cg2.play_rooftop_landing(woman, camera)
	assert(woman.animation == &"land" and is_equal_approx(woman.position.y, 215.0))
	assert(camera.global_position.distance_to(Vector2(320, 180)) < 0.1)
	assert(cg2.get_node("Elevator/ElevatorRoof").visible)
	assert(cg2.get_node("Elevator/ElevatorBreakdownFX/ShaftScroll").visible)
	assert(is_equal_approx(cg2.get_node("Elevator/ElevatorBreakdownFX")._shaft_target_speed, 28.0))
	assert(not cg2.get_node("Elevator/ElevatorCar").visible)
	var man: AnimatedSprite2D = await cg2.play_rooftop_man_fall()
	assert(man.animation == &"land" and is_equal_approx(man.position.y, 215.0))
	print("PASS: CG2 doors and shaft, sparks, smoke, rooftop landing, falling man")
	cg2.queue_free()
	await process_frame
	quit()
