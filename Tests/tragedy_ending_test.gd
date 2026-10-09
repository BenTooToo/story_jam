extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var love = load("res://Stories/Bentootoo/End/love_ending.tscn").instantiate()
	var tragedy = load("res://Stories/Bentootoo/End/tragedy_ending.tscn").instantiate()
	love.play_on_ready = false
	root.add_child(love)
	root.add_child(tragedy)
	assert(love.ending_route == 0 and tragedy.ending_route == 1)
	love._show_credits()
	var lines := [
		"只见两个人倒在血泊之中",
		"红色与绿色的血液融合在了一起",
		"小林 缓缓的睁开了眼睛，用尽最后的力气说出了最后一个问题",
		"殊不知那个女人的身体也早已经被电梯的碎片所贯穿",
		"拜托了，告诉我",
		"告诉我",
		"你的名字",
		"好吧，我就告诉我你吧",
		"我",
		"叫",
		"高晨",
		"等你到了地狱，要再跟我打一架啊",
	]
	var dialogue_box = root.get_node("BenDialogue")._dialogue_box
	for line in lines:
		await process_frame
		assert(dialogue_box._dialogue_text.text == line)
		assert(tragedy.get_node("Overlay/Black").visible)
		dialogue_box._finish_typing()
		dialogue_box._finish_entry(-1)
	await process_frame
	var cg = tragedy.get_node("CGHost").get_child(0)
	assert(cg.name == "End")
	await cg.anchor_finished
	await cg.wait_for_opening_sound()
	await create_timer(cg.door_duration + 1.3).timeout
	assert(is_equal_approx(cg._left_door.position.x, cg._left_door_x))
	assert(is_equal_approx(cg._right_door.position.x, cg._right_door_x))
	assert(tragedy.get_node("Overlay/Black").modulate.a > 0.9)
	await create_timer(7.5).timeout
	assert(tragedy.get_node("Overlay/Credits").visible)
	assert(love.get_node("Overlay/Credits").text == tragedy.get_node("Overlay/Credits").text)
	print("PASS: black tragedy dialogue, third CG, closed doors, fade to titles and shared credits")
	love.queue_free()
	tragedy.queue_free()
	await process_frame
	quit()
