extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cg2 = load("res://Stories/Middle/middle.tscn").instantiate()
	cg2.play_intro_on_ready = false
	root.add_child(cg2)
	var camera := Camera2D.new()
	camera.position = Vector2(320, 180)
	cg2.add_child(camera)
	var woman: AnimatedSprite2D = cg2.get_node("Elevator/NPCs/NPC0")
	await cg2.play_rooftop_landing(woman, camera)
	var man: AnimatedSprite2D = await cg2.play_rooftop_man_fall()
	var attack: AttackQTE = load("res://Stories/QTE/attack_qte.gd").new()
	cg2.add_child(attack)
	attack.begin(woman, man, camera)
	for index in attack.REQUIRED_PRESSES:
		attack.press_e()
	attack._process(2.0)
	assert(attack.state == attack.State.READY)
	attack.press_q()
	await attack.completed
	attack.queue_free()
	await cg2.eject_character(man, 0.1)
	assert(not man.visible)
	var roof: Node2D = cg2.get_node("Elevator/ElevatorRoof")
	var starting_roof_y := roof.position.y
	await cg2.play_rooftop_second_breakdown(woman, camera)
	assert(not woman.visible)
	assert(roof.position.y > starting_roof_y + 100.0)
	assert(cg2.get_node("Elevator/ElevatorBreakdownFX")._shaft_target_speed == 600.0)
	print("PASS: rooftop QTE ejects the man, then second failure drops the woman")
	cg2.queue_free()
	await process_frame
	quit()
