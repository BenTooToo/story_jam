extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dialogue = root.get_node("BenDialogue")
	var box = dialogue._dialogue_box
	dialogue.set_npc0_transformed(true)
	box._update_portrait(dialogue.Character.NPC0, dialogue.ExpressionState.SPEAKING)
	assert(box._portrait_closed == load("res://Assets/caracter/lizard_girl/pp/蜥蜴人大头像.png"))
	assert(box._portrait_open == load("res://Assets/caracter/lizard_girl/pp/蜥蜴人大头像2.png"))
	dialogue.set_npc0_transformed(false)
	box._update_portrait(dialogue.Character.NPC0, dialogue.ExpressionState.SPEAKING)
	assert(box._portrait_closed == load("res://Assets/ROMART/npc0.png"))
	assert(box._portrait_open == load("res://Assets/ROMART/npc0说话.png"))
	print("PASS: NPC0 portrait follows woman/lizard state")
	quit()
