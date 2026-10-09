extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game = load("res://Stories/Bentootoo/game.tscn").instantiate()
	game.auto_start_story = false
	root.add_child(game)
	game._run_attack_qte_test()
	await create_timer(0.55).timeout
	var qte: AttackQTE
	for child in game.get_children():
		if child is AttackQTE:
			qte = child
	assert(qte != null and qte.state == qte.State.MASH)
	for i in 20:
		qte.press_e()
	await create_timer(1.8).timeout
	assert(qte.state == qte.State.READY)
	qte.press_q()
	await create_timer(4.6, true, false, true).timeout
	var opening = game.get_node("AnchorHost").get_child(0)
	assert(not opening.get_node("Elevator/NPCs/NPC1").visible)
	assert(not game._dialogue_test_running)
	print("PASS: direct QTE preview accepts E/Q, ejects man, and returns control")
	game.queue_free()
	await process_frame
	quit()
