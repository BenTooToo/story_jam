extends Node2D

const CAMERA_HOME := Vector2(320.0, 180.0)
const CAMERA_CHARACTER_OFFSET := Vector2(0.0, -30.0)
const CAMERA_CHARACTER_ZOOM := 1.35
const MONOLOGUE_CAMERA_COOLDOWN := 1.0
const MONOLOGUE_LIGHT_HOLD := 0.5
const MONOLOGUE_END_HOLD := 1.5
const GREETING_DELAY := 1.0
const CG_FADE_DURATION := 0.8
const START_SCENE := preload("res://Stories/Start/start.tscn")
const MIDDLE_SCENE := preload("res://Stories/Middle/middle.tscn")
const END_SCENE := preload("res://Stories/End/end.tscn")
const HEART_FX := preload("res://Stories/Effects/heart_fx.gd")

@export var show_status := false
@export_range(1.0, 30.0, 0.5) var camera_follow_speed := 10.0

@onready var _camera: Camera2D = $Camera2D
@onready var _anchor_host: Node2D = $AnchorHost
@onready var _monologue_fx: MonologueFX = $MonologueFX
@onready var _intro_black: ColorRect = $IntroUI/Black
@onready var _intro_message: Label = $IntroUI/Black/Message
@onready var _status: Label = $TestUI/Status

var _current_anchor: Node
var _dialogue_test_running := false
var _camera_tween: Tween
var _camera_follow_target: Node2D
var _camera_follow_offset := CAMERA_CHARACTER_OFFSET
var _camera_follow_zoom := CAMERA_CHARACTER_ZOOM
var _choice_camera_targets: Array[Node2D] = []
var _camera_home_zoom := 1.0


func _ready() -> void:
	_status.text = "请选择测试内容"
	_status.visible = show_status
	Dialogue.choice_focused.connect(_on_dialogue_choice_focused)


func _process(delta: float) -> void:
	if not is_instance_valid(_camera_follow_target):
		_camera_follow_target = null
		return

	var follow_weight := 1.0 - exp(-camera_follow_speed * delta)
	var target_position := _camera_follow_target.global_position + _camera_follow_offset
	var target_zoom := Vector2.ONE * _camera_follow_zoom
	_camera.global_position = _camera.global_position.lerp(target_position, follow_weight)
	_camera.zoom = _camera.zoom.lerp(target_zoom, follow_weight)


func follow_camera(
	target: Node2D,
	zoom_amount: float = CAMERA_CHARACTER_ZOOM,
	offset: Vector2 = CAMERA_CHARACTER_OFFSET,
) -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_follow_target = target
	_camera_follow_zoom = maxf(zoom_amount, 0.01)
	_camera_follow_offset = offset


func move_camera(
	target_position: Vector2,
	zoom_amount: float = 1.0,
	duration: float = 0.5,
) -> Tween:
	_camera_follow_target = null
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()

	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.set_trans(Tween.TRANS_SINE)
	_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(
		_camera,
		"global_position",
		target_position,
		duration,
	)
	_camera_tween.tween_property(
		_camera,
		"zoom",
		Vector2.ONE * maxf(zoom_amount, 0.01),
		duration,
	)
	return _camera_tween


func reset_camera(duration: float = 0.5) -> Tween:
	return move_camera(CAMERA_HOME, _camera_home_zoom, duration)


func start_monologue(target: Node2D) -> void:
	_monologue_fx.start_monologue(target)


func stop_monologue() -> void:
	_monologue_fx.stop_monologue()


func play_hearts(character: Node2D, offset := Vector2(-10.0, -10.0)) -> void:
	await HEART_FX.play(character, 8.0, offset)


func _play_headphone_intro() -> void:
	_intro_black.modulate.a = 1.0
	_intro_black.show()
	_intro_message.show()
	_intro_message.modulate.a = 0.0
	await get_tree().create_timer(0.6).timeout

	var fade_in := create_tween()
	fade_in.tween_property(_intro_message, "modulate:a", 1.0, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_in.finished
	await get_tree().create_timer(2.0).timeout

	var fade_out := create_tween()
	fade_out.tween_property(_intro_message, "modulate:a", 0.0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_out.finished


func _say(character_id: int, text: String) -> void:
	await Dialogue.entree(
		character_id,
		Dialogue.ExpressionState.SPEAKING,
		text,
	)


func _narrate(text: String) -> void:
	await Dialogue.entree(
		Dialogue.Character.NARRATOR,
		Dialogue.ExpressionState.NORMAL,
		text,
	)


func _on_dialogue_choice_focused(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= _choice_camera_targets.size():
		return
	var target := _choice_camera_targets[choice_index]
	if is_instance_valid(target):
		follow_camera(target)


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_test_running:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_L:
			get_viewport().set_input_as_handled()
			_run_branch_test(&"love")
		KEY_V:
			get_viewport().set_input_as_handled()
			_run_branch_test(&"disgust")
		KEY_M:
			get_viewport().set_input_as_handled()
			_run_effect_test(&"mutation")
		KEY_H:
			get_viewport().set_input_as_handled()
			_run_effect_test(&"hearts")
		KEY_0:
			get_viewport().set_input_as_handled()
			_run_effect_test(&"vomit")
		KEY_1:
			get_viewport().set_input_as_handled()
			_play_anchor(START_SCENE, "正在播放：开场锚点")
		KEY_2:
			get_viewport().set_input_as_handled()
			_play_anchor(MIDDLE_SCENE, "正在播放：中间锚点")
		KEY_3:
			get_viewport().set_input_as_handled()
			_play_anchor(END_SCENE, "正在播放：结尾锚点")
		KEY_4:
			get_viewport().set_input_as_handled()
			_run_dialogue_test()
		KEY_5:
			get_viewport().set_input_as_handled()
			_run_effect_test(&"sparks")
		KEY_6:
			get_viewport().set_input_as_handled()
			_run_effect_test(&"shock")
		KEY_7:
			get_viewport().set_input_as_handled()
			_run_effect_test(&"smoke")
		KEY_8:
			get_viewport().set_input_as_handled()
			_run_effect_test(&"drop")
		KEY_9:
			get_viewport().set_input_as_handled()
			_run_effect_test(&"descent")


func _play_anchor(scene: PackedScene, status_text: String) -> Node:
	_clear_anchor()
	_current_anchor = scene.instantiate()
	_anchor_host.add_child(_current_anchor)
	_status.text = status_text
	return _current_anchor


func _clear_anchor() -> void:
	_monologue_fx.reset_immediately()
	_camera_home_zoom = 1.0
	reset_camera(0.0)
	if not is_instance_valid(_current_anchor):
		return
	_anchor_host.remove_child(_current_anchor)
	_current_anchor.queue_free()
	_current_anchor = null


func _run_dialogue_test() -> void:
	_dialogue_test_running = true
	_clear_anchor()
	_status.text = "剧情第一部分：开场"
	await _play_headphone_intro()
	await _narrate("你，是一个蜥蜴人")
	await _narrate("作为渗透地表世界的精英，你已然控制了很多公司，默默的操纵着这个世界")
	await _narrate("而，你不知道的是")
	await _narrate("一个危险，缓慢的向你靠近")
	await _narrate("今天的外边的天气不大好")
	await _narrate("所以电梯并没有被使用过")
	await _narrate("当然，这件事情很快就会变得不一样了")
	await _narrate("两个截然不同的脚步向着电梯靠近")
	await _narrate("一个沉稳，透露着一丝紧张")
	await _narrate("一个轻盈，却让人不寒而栗")
	_intro_black.hide()

	var opening := _play_anchor(
		START_SCENE,
		"对话测试：等待开场动画与电梯门打开……",
	)

	await opening.anchor_finished
	await opening.wait_for_opening_sound()
	await get_tree().create_timer(GREETING_DELAY).timeout
	_status.text = "剧情第一部分进行中"
	var npc0: Node2D = opening.get_node("Elevator/NPCs/NPC0")
	var npc1: Node2D = opening.get_node("Elevator/NPCs/NPC1")

	await _say(Dialogue.Character.NPC1, "你好")
	await _say(Dialogue.Character.NPC0, "你好")
	await _play_departure(opening)

	await move_camera(
		npc1.global_position + CAMERA_CHARACTER_OFFSET,
		CAMERA_CHARACTER_ZOOM,
	).finished
	await get_tree().create_timer(MONOLOGUE_CAMERA_COOLDOWN).timeout
	start_monologue(npc1)
	await get_tree().create_timer(MONOLOGUE_LIGHT_HOLD).timeout
	await _say(Dialogue.Character.NPC1, "（我，是一个男特工）")
	await _say(Dialogue.Character.NPC1, "（今天我的任务非常的重要）")
	await _say(Dialogue.Character.NPC1, "（那就是，暗杀我眼前的这个漂亮女人）")
	await opening.play_shock(1)
	await _say(Dialogue.Character.NPC1, "（不过，她可真是漂亮啊）")
	await _say(Dialogue.Character.NPC1, "（怎么会这么的漂亮）")
	await get_tree().create_timer(MONOLOGUE_END_HOLD).timeout
	stop_monologue()

	await reset_camera().finished
	await _narrate("眼前的这位男人，陷入了一个经典的陷阱")
	await _narrate("他的名字叫小木，他有一点性压抑")
	await _narrate("而他，毫无疑问，爱上了眼前的女人")

	await move_camera(
		npc0.global_position + CAMERA_CHARACTER_OFFSET,
		CAMERA_CHARACTER_ZOOM,
	).finished
	await get_tree().create_timer(MONOLOGUE_CAMERA_COOLDOWN).timeout
	start_monologue(npc0)
	await get_tree().create_timer(MONOLOGUE_LIGHT_HOLD).timeout
	await _say(Dialogue.Character.NPC0, "（不妙啊，真的很不妙啊）")
	await _say(Dialogue.Character.NPC0, "（作为蜥蜴人当中的精英，很显然，我被这个男人盯上了，他一定是冲着我来的）")
	await get_tree().create_timer(MONOLOGUE_END_HOLD).timeout
	stop_monologue()

	await reset_camera().finished
	await _narrate("空气中充满了尖锐的信息")
	await _say(Dialogue.Character.NPC1, "（不管了，我要上了）")
	await _say(Dialogue.Character.NPC1, "那个")
	await _say(Dialogue.Character.NPC0, "（要来了么）")
	await _say(Dialogue.Character.NPC1, "我觉得你很好看，可不可以，成为我的女朋友")
	await _say(Dialogue.Character.NPC0, "啊？")
	await _say(Dialogue.Character.NPC0, "（他真的是神经病么？这一定是他的伪装吧？）")
	await _say(Dialogue.Character.NPC0, "为什么我的肠胃感觉怪怪的，感觉，有一点痒痒的")

	_choice_camera_targets.clear()
	_choice_camera_targets.append(npc0)
	_choice_camera_targets.append(npc0)
	var selected := await Dialogue.entree(
		Dialogue.Character.NPC0,
		Dialogue.ExpressionState.SPEAKING,
		"我应该是",
		[
			"不可救药的坠入爱河",
			"对眼前的男人感到恶心",
		],
	)
	_choice_camera_targets.clear()

	var answer := "不可救药的坠入爱河" if selected == 0 else "对眼前的男人感到恶心"
	if selected == 0:
		await _run_love_route(opening, npc0, npc1)
	else:
		await _run_disgust_route(opening, npc0, npc1)
	_status.text = "剧情分支完成，选择：%s（可继续按 1～4）" % answer
	await reset_camera().finished
	_dialogue_test_running = false


func _run_love_route(opening: Node, woman: AnimatedSprite2D, man: AnimatedSprite2D) -> void:
	_status.text = "爱河分支进行中"
	follow_camera(woman)
	play_hearts(woman)
	await _say(Dialogue.Character.NPC0, "我……")
	await _say(Dialogue.Character.NPC1, "（拜托了，工作什么的都无所谓，一定要同意啊）")
	await _say(Dialogue.Character.NPC0, "我也喜欢你！")

	follow_camera(man)
	await opening.play_shock(1)
	await _say(Dialogue.Character.NPC1, "！！！")
	follow_camera(woman)
	await opening.play_shock(0)
	await _say(Dialogue.Character.NPC0, "！！！")
	await _say(Dialogue.Character.NPC0, "糟糕，我要抑制不住自己的心情了")
	await _say(Dialogue.Character.NPC0, "要出来了")
	await _say(Dialogue.Character.NPC1, "？？")

	await opening.play_mutation(woman)
	follow_camera(man)
	await _say(Dialogue.Character.NPC1, "这……")
	# 欢呼动作素材尚未提供；函数入口已经保留。
	await opening.play_cheer(man)
	await opening.play_shock(1)
	await _say(Dialogue.Character.NPC1, "这也太棒了吧")
	await _say(Dialogue.Character.NPC1, "蜥蜴人什么的最喜欢了")
	await _say(Dialogue.Character.NPC1, "任务报告里面竟然没有提到这一点么，这些可恶的家伙啊")
	await _say(Dialogue.Character.NPC1, "那个")
	await _say(Dialogue.Character.NPC1, "你叫什么名字")
	follow_camera(woman)
	await _say(Dialogue.Character.NPC0, "我叫——")

	await opening.play_sparks()
	await reset_camera().finished
	await _narrate("或许是因为电梯本身年久失修")
	await _narrate("又或者是因为，这爱情故事过于的完美")
	await _narrate("而游戏的创作者是一个单身狗")
	await _narrate("电梯")
	await _narrate("失控了")

	await opening.play_breakdown()
	await opening.eject_character(man)
	await _say(Dialogue.Character.NPC0, "糟糕，我要出去救小林啊")
	await _play_cg2_transition()


func _run_disgust_route(opening: Node, woman: AnimatedSprite2D, man: AnimatedSprite2D) -> void:
	_status.text = "反胃分支进行中"
	follow_camera(woman)
	await _narrate("伴随着一阵反胃，你由衷地对面前的这个生物感到恶心")
	await _narrate("尽管自己被指示要在地表世界保持淑女的姿势，你认识到自己已经忍耐到了极限")

	# 呕吐前摇结束后会持续喷吐，直到 QTE 开始前停止。
	await opening.play_vomit()
	follow_camera(man)
	await _say(Dialogue.Character.NPC1, "（这个女人）")
	await _say(Dialogue.Character.NPC1, "原来如此")
	follow_camera(woman)
	await _say(Dialogue.Character.NPC0, "完蛋了，暴露了")
	follow_camera(man)
	await _say(Dialogue.Character.NPC1, "原来还会有晕电梯的女人啊")
	follow_camera(woman)
	await _say(Dialogue.Character.NPC0, "给我滚啊")
	await _say(Dialogue.Character.NPC0, "（糟糕了，我的唾液）")
	await _say(Dialogue.Character.NPC0, "（昨天不该吃那么多猕猴桃的）")

	await reset_camera().finished
	await _narrate("在玩家看不见的位置，纵然一个被胃酸腐蚀的大洞出现在墙壁上")
	await _narrate("这个洞足够的大，就算是一个成年男性也可以不小心掉出去")
	follow_camera(man)
	await _say(Dialogue.Character.NPC1, "没关系的，等你吐完再回答我的问题也不迟")
	await _say(Dialogue.Character.NPC1, "怎么样，对我有兴趣么")

	opening.stop_vomit()
	_choice_camera_targets.clear()
	_choice_camera_targets.append(man)
	await Dialogue.entree(
		Dialogue.Character.NARRATOR,
		Dialogue.ExpressionState.NORMAL,
		"QTE",
		["把男人打出电梯！"],
	)
	_choice_camera_targets.clear()

	await opening.eject_character(man)
	await reset_camera(0.2).finished
	await opening.play_drop()
	await _narrate("小木愤怒了")
	await _narrate("他现在会拼尽全力去报仇")
	await _narrate("来找回自己本就所剩无几的尊严")
	follow_camera(woman)
	await _say(Dialogue.Character.NPC0, "麻烦啊，谁会喜欢这种下头男啊")
	await _play_cg2_transition()


func _play_cg2_transition() -> void:
	_camera_follow_target = null
	_intro_message.hide()
	_intro_black.modulate.a = 0.0
	_intro_black.show()
	var fade_to_black := create_tween()
	fade_to_black.tween_property(
		_intro_black,
		"modulate:a",
		1.0,
		CG_FADE_DURATION,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_to_black.finished

	_play_anchor(MIDDLE_SCENE, "正在播放：测试 2 / CG2")
	await get_tree().process_frame
	var reveal_cg := create_tween()
	reveal_cg.tween_property(
		_intro_black,
		"modulate:a",
		0.0,
		CG_FADE_DURATION,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await reveal_cg.finished
	_intro_black.hide()
	_intro_message.show()


func _run_branch_test(branch: StringName) -> void:
	_dialogue_test_running = true
	_clear_anchor()
	_intro_black.hide()
	_intro_black.modulate.a = 1.0
	_intro_message.show()
	await reset_camera(0.0).finished

	var opening = START_SCENE.instantiate()
	opening.play_intro_on_ready = false
	_current_anchor = opening
	_anchor_host.add_child(opening)
	_status.text = "分支测试准备中：关闭电梯门"
	await _play_departure(opening)

	var woman: AnimatedSprite2D = opening.get_node("Elevator/NPCs/NPC0")
	var man: AnimatedSprite2D = opening.get_node("Elevator/NPCs/NPC1")
	if branch == &"love":
		await _run_love_route(opening, woman, man)
	else:
		await _run_disgust_route(opening, woman, man)
	_dialogue_test_running = false


func _play_departure(opening: Node) -> void:
	# Start the push as soon as the greetings end; keep it moving through closing
	# and the shaft reveal. Later wide shots return to this travelling view.
	_camera_home_zoom = opening.departure_camera_zoom
	move_camera(
		CAMERA_HOME,
		_camera_home_zoom,
		opening.door_duration + opening.departure_duration,
	)
	await opening.close_doors()
	await opening.start_descent()


func _run_effect_test(effect_name: StringName) -> void:
	_dialogue_test_running = true
	_clear_anchor()
	await reset_camera(0.0).finished
	var opening = START_SCENE.instantiate()
	opening.play_intro_on_ready = false
	_current_anchor = opening
	_anchor_host.add_child(opening)

	match effect_name:
		&"mutation":
			_status.text = "特效测试：女人变身为蜥蜴人"
			await opening.play_mutation()
		&"hearts":
			_status.text = "特效测试：冒爱心（1～6 帧，播放一次）"
			await play_hearts(opening.get_node("Elevator/NPCs/NPC0"))
		&"vomit":
			_status.text = "特效测试：呕吐前摇 → 持续呕吐"
			await opening.play_vomit()
		&"sparks":
			_status.text = "特效测试：火花"
			await opening.play_sparks()
		&"shock":
			_status.text = "特效测试：人物震惊残影"
			await opening.play_shock(0)
		&"smoke":
			_status.text = "特效测试：黑色烟雾"
			await opening.preview_smoke()
		&"drop":
			_status.text = "特效测试：电梯坠落"
			await opening.play_drop()
		&"descent":
			_status.text = "特效测试：关门与电梯下降"
			await _play_departure(opening)

	_status.text = "特效测试就绪（M 变身，H 冒爱心，0～9 其他特效）"
	_dialogue_test_running = false
