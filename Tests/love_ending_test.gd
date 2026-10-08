extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var encounter = load("res://Stories/BulletHell/bullet_hell.tscn").instantiate()
	root.add_child(encounter)
	current_scene = encounter
	encounter._play_ending(true)
	await create_timer(1.4).timeout
	await process_frame
	var ending = current_scene
	assert(ending.name == "LoveEnding")
	var lines := [
		"加油，你一定要跟我回到电梯里面，不然，你会死的！",
		"对不起，不要管我了，我真的。。。好喜欢你现在的样子",
		"至少告诉我。。。",
		"你的名字",
		"我叫高晨",
		"请你不要忘记我",
		"好的啊。。。我叫。。。小林",
	]
	var dialogue_box = root.get_node("Dialogue")._dialogue_box
	for line in lines:
		await process_frame
		assert(dialogue_box._dialogue_text.text == line)
		assert(ending._black.visible)
		dialogue_box._finish_typing()
		dialogue_box._finish_entry(-1)

	await process_frame
	var cg = ending._cg_host.get_child(0)
	assert(cg.name == "End")
	await cg.anchor_finished
	await cg.wait_for_opening_sound()
	await create_timer(0.3).timeout
	assert(ending._black.visible and ending._black.modulate.a > 0.9)
	await create_timer(14.0).timeout
	assert(ending._credits.visible)
	assert(ending._credits.text.contains("基础游戏框架"))
	assert(ending._credits.text.contains("策划  本2兔、小林、Romart、高老师"))
	assert(ending._credits.text.contains("代码、故事、音效  本2兔、小林"))
	assert(ending._credits.text.contains("Romart、高老师"))
	assert(ending._credits.text.contains("版本分支剧情"))
	assert(ending._credits.text.contains("代码、策划、音效  本2兔"))
	assert(ending._credits.text.contains("故事  本2兔、Romort"))
	assert(ending._credits.text.contains("美术  Romort"))
	print("PASS: black dialogue, third CG, lights out, title cards, fixed credits")
	ending.queue_free()
	await process_frame
	quit()
