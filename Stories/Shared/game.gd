extends Node2D

const CAMERA_HOME := Vector2(320.0, 180.0)
const CAMERA_CHARACTER_OFFSET := Vector2(0.0, -30.0)
const CAMERA_CHARACTER_ZOOM := 1.35
const START_SCENE := preload("res://Stories/Start/start.tscn")
const MIDDLE_SCENE := preload("res://Stories/Middle/middle.tscn")
const END_SCENE := preload("res://Stories/End/end.tscn")
const THROW_PHASE := preload("res://Stories/Phases/Throw/throw_phase.tscn")
const DANCE_PHASE := preload("res://Stories/Phases/Dance/dance_phase.tscn")
const BOSS_PHASE := preload("res://Stories/Phases/Boss/boss_phase.tscn")
const TitleMenu := preload("res://Stories/Shared/Title/title_menu.gd")
const LevelIntro := preload("res://Stories/Shared/Intro/level_intro.gd")

# ---------- 每关规则页的内容 ----------
# 按键条：{text, keys}，keys 里任意一个键按下就算确认；keys 为空的条目不用按。
const P1_ARENA_KEYS := [
	{text = "A   往左走", keys = [KEY_A]},
	{text = "D   往右走", keys = [KEY_D]},
	{text = "W   跳起来", keys = [KEY_W]},
	{text = "F   扔东西", keys = [KEY_F]},
]
const P2_ARENA_KEYS := [
	{text = "←   往左走", keys = [KEY_LEFT]},
	{text = "→   往右走", keys = [KEY_RIGHT]},
	{text = "↑   跳起来", keys = [KEY_UP]},
	{text = "/   扔东西", keys = [KEY_SLASH, KEY_KP_0]},
]
const P1_DANCE_KEYS := [
	{text = "A   ← 左箭头", keys = [KEY_A]},
	{text = "S   ↓ 下箭头", keys = [KEY_S]},
	{text = "W   ↑ 上箭头", keys = [KEY_W]},
	{text = "D   → 右箭头", keys = [KEY_D]},
]
const P2_DANCE_KEYS := [
	{text = "←   左箭头", keys = [KEY_LEFT]},
	{text = "↓   下箭头", keys = [KEY_DOWN]},
	{text = "↑   上箭头", keys = [KEY_UP]},
	{text = "→   右箭头", keys = [KEY_RIGHT]},
]
## 隐藏关可选的三首（曲库在 dance_phase.gd 的 SONGS 里）
const HIDDEN_SONGS: Array[String] = ["不如跳舞", "秒針を噛む", "Levitating"]
## 单人模式下男生那一栏只有这一条，不用按
const P2_AI_LINE := [{text = "由电脑控制", keys = []}]
const THROW_RULES := [
	"90 秒内互相扔东西，砸中对面 +10 分",
	"被砸中会眩晕 2 秒，动不了",
	"天上会掉东西，碰到就捡：+1 / +3 / +5 分",
	"中间的门翻不过去，东西要抛过门顶",
	"时间一到，分高的赢",
]
const DANCE_RULES := [
	"箭头滚到上面的判定线时，按对应的方向",
	"按得准：完美 +5，还行 +2",
	"没按到、或者乱按：算一次「烂」",
	"曲子放完，分高的赢",
]
const BOSS_RULES := [
	"两个人合力，把东西扔到怪兽身上就掉血",
	"怪兽震地会放冲击波，红箭头滚过来就跳",
	"地上冒出 ! 是砸落点，赶紧跑开",
	"怪兽血条清空，就赢了",
]

## 打开后游戏一启动就直接跑完整流程（开场电梯 → 吵架 → 三阶段 → 和解），
## 关掉则回到按 1～9 单独测试各段的调试模式。
@export var auto_start := true
@export var show_status := false
@export_range(1.0, 30.0, 0.5) var camera_follow_speed := 10.0

@onready var _camera: Camera2D = $Camera2D
@onready var _anchor_host: Node2D = $AnchorHost
@onready var _status: Label = $TestUI/Status

var _current_anchor: Node
var _dialogue_test_running := false
var _camera_tween: Tween
var _camera_follow_target: Node2D
var _camera_follow_offset := CAMERA_CHARACTER_OFFSET
var _camera_follow_zoom := CAMERA_CHARACTER_ZOOM
var _choice_camera_targets: Array[Node2D] = []


func _ready() -> void:
	_status.text = "请选择测试内容"
	_status.visible = show_status
	Dialogue.choice_focused.connect(_on_dialogue_choice_focused)
	if auto_start:
		$TestUI/Help.visible = false
		_run_full_story.call_deferred()


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
	return move_camera(CAMERA_HOME, 1.0, duration)


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
			_play_phase(THROW_PHASE, "阶段一：扔物大战（90 秒互扔 + 掉落物品）")
		KEY_6:
			get_viewport().set_input_as_handled()
			_play_phase(DANCE_PHASE, "阶段二：舞蹈对决（P1：WASD / P2：方向键）")
		KEY_7:
			get_viewport().set_input_as_handled()
			_play_phase(BOSS_PHASE, "阶段三：电梯怪兽（合力投掷打倒它）")
		KEY_8:
			get_viewport().set_input_as_handled()
			_run_full_story()
		# 试玩用，没进正式流程：跳舞阶段换整首歌 + 电梯里的小屏幕放视频。
		# 字母别撞 WASD / F（阶段里是操作键）。
		KEY_9:
			get_viewport().set_input_as_handled()
			_play_dance_song("不如跳舞")
		KEY_J:
			get_viewport().set_input_as_handled()
			_play_dance_song("秒針を噛む")
		KEY_L:
			get_viewport().set_input_as_handled()
			_play_dance_song("Levitating")


func _play_dance_song(song: String) -> Node:
	return _play_phase(
		DANCE_PHASE, "试玩：%s（整首谱面 + 视频）" % song,
		func(phase: Node) -> void: phase.song_name = song,
	)


## setup 在挂进树之前调用，用来改导出变量（比如跳舞阶段换曲子）。
func _play_anchor(scene: PackedScene, status_text: String, setup := Callable()) -> Node:
	_clear_anchor()
	_current_anchor = scene.instantiate()
	if setup.is_valid():
		setup.call(_current_anchor)
	_anchor_host.add_child(_current_anchor)
	_status.text = status_text
	return _current_anchor


## 先把当前场景渐渐压黑，再真正清掉。说完话再用这个，别让画面啪一下没了。
func _fade_out_anchor(duration := 0.8) -> void:
	if is_instance_valid(_current_anchor):
		var tw := create_tween()
		tw.tween_property(_anchor_host, "modulate", Color.BLACK, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await tw.finished
	_clear_anchor()
	_anchor_host.modulate = Color.WHITE


func _clear_anchor() -> void:
	if not is_instance_valid(_current_anchor):
		return
	_anchor_host.remove_child(_current_anchor)
	_current_anchor.queue_free()
	_current_anchor = null


func _run_dialogue_test() -> void:
	_dialogue_test_running = true
	var opening := _play_anchor(
		START_SCENE,
		"对话测试：等待开场动画与电梯门打开……",
	)

	await opening.anchor_finished
	_status.text = "对话测试进行中"
	var npc0: Node2D = opening.get_node("Elevator/NPCs/NPC0")
	var npc1: Node2D = opening.get_node("Elevator/NPCs/NPC1")

	follow_camera(npc0)
	await Dialogue.entree(
		Dialogue.Character.NPC0,
		Dialogue.ExpressionState.SPEAKING,
		"哈基米，南北绿豆，东边一勺西边一兜，电梯门口转三圈，十六层里点点头；等我把这段唱完，我来问你一个非常重要的大事，非常重要。",
	)
	await Dialogue.entree(
		Dialogue.Character.NPC0,
		Dialogue.ExpressionState.SPEAKING,
		"你是傻福么",
	)

	follow_camera(npc1)
	await Dialogue.entree(
		Dialogue.Character.NPC1,
		Dialogue.ExpressionState.SPEAKING,
		"嗯，我是傻福，",
	)

	reset_camera()
	_choice_camera_targets.clear()
	_choice_camera_targets.append(npc0)
	_choice_camera_targets.append(npc1)
	var selected := await Dialogue.entree(
		Dialogue.Character.NARRATOR,
		Dialogue.ExpressionState.NORMAL,
		"谁是傻福",
		["女的", "男的"],
	)
	_choice_camera_targets.clear()

	follow_camera(npc0)
	if selected == 1:
		await Dialogue.entree(
			Dialogue.Character.NPC0,
			Dialogue.ExpressionState.SPEAKING,
			"不错嘛，[rainbow freq=1.0 sat=0.8 val=0.8 speed=1.0][shake rate=20 level=4]你还蛮聪明的[/shake][/rainbow]。",
		)
	else:

		await Dialogue.entree(
			Dialogue.Character.NPC0,
			Dialogue.ExpressionState.SPEAKING,
			"原来[rainbow freq=1.0 sat=0.8 val=0.8 speed=1.0][shake rate=20 level=4]傻福是你啊[/shake][/rainbow]。",
		)

	var answer := "女的" if selected == 0 else "男的"
	_status.text = "对话测试完成，选择：%s（可继续按 1～4）" % answer
	reset_camera()
	_dialogue_test_running = false


func _play_phase(scene: PackedScene, status_text: String, setup := Callable()) -> Node:
	reset_camera(0.1)
	var phase := _play_anchor(scene, status_text, setup)
	phase.phase_finished.connect(
		func(result: Dictionary) -> void:
			_status.text = "阶段结束：%s（按 1～9 继续）" % str(result)
	)
	return phase


## 完整流程：标题菜单 → 开场电梯 → 吵架 → 第一关 → 第二次电梯（只剩女生）→ 第二关
## → 第三次电梯（没人）→ 第三关 → 和解。
func _run_full_story() -> void:
	_dialogue_test_running = true
	_clear_anchor()
	reset_camera(0.0)

	# 标题菜单：选单人 / 双人
	_status.text = "完整流程：标题菜单"
	var menu := TitleMenu.new()
	add_child(menu)
	var mode: int = await menu.mode_chosen
	if mode == TitleMenu.Mode.DEV:
		# 菜单里按了 F8：回到按 1～9 单独测试各段的开发者模式
		_status.text = "开发者模式：按 1～9 选择测试内容（9/J/L = 跳舞试玩曲）"
		_status.visible = true
		$TestUI/Help.visible = true
		_dialogue_test_running = false
		return
	Session.single_player = mode == TitleMenu.Mode.SINGLE

	# 开场：电梯从 32 层降到 16 层，叮一声开门
	_status.text = "完整流程：开场电梯"
	var opening := _play_anchor(START_SCENE, _status.text)
	await opening.anchor_finished

	# 门一开，两个人就在电梯里吵起来了
	_status.text = "完整流程：开幕吵架"
	var npc0: Node2D = opening.get_node("Elevator/NPCs/NPC0")
	var npc1: Node2D = opening.get_node("Elevator/NPCs/NPC1")
	follow_camera(npc0)
	await Dialogue.entree(
		Dialogue.Character.NPC0,
		Dialogue.ExpressionState.SPEAKING,
		"喂！刚才是你先撞到我的吧！",
	)
	follow_camera(npc1)
	await Dialogue.entree(
		Dialogue.Character.NPC1,
		Dialogue.ExpressionState.SPEAKING,
		"明明是你自己横冲直撞！行啊，那就比划比划！",
	)
	reset_camera()

	# 《第一关》标题 + 操作 / 规则确认
	_status.text = "完整流程：第一关说明"
	_clear_anchor()
	await _show_level_intro(1, "扔物大战", P1_ARENA_KEYS, P2_ARENA_KEYS, THROW_RULES)

	_status.text = "完整流程：阶段一 扔物大战"
	reset_camera(0.0)
	var throw_phase := _play_anchor(THROW_PHASE, _status.text)
	var round1: Dictionary = await throw_phase.phase_finished

	if round1.winner == 1:
		await Dialogue.entree(
			Dialogue.Character.NPC0,
			Dialogue.ExpressionState.SPEAKING,
			"哼，扔东西你根本不是我的对手。",
		)
		await Dialogue.entree(
			Dialogue.Character.NPC1,
			Dialogue.ExpressionState.SPEAKING,
			"不服！再比一场——这次比[b]跳舞[/b]！我先去舞池热身！",
		)
	elif round1.winner == 2:
		await Dialogue.entree(
			Dialogue.Character.NPC1,
			Dialogue.ExpressionState.SPEAKING,
			"看到没，这就叫实力。",
		)
		await Dialogue.entree(
			Dialogue.Character.NPC0,
			Dialogue.ExpressionState.SPEAKING,
			"不服！再比一场——这次比[b]跳舞[/b]！",
		)
		await Dialogue.entree(
			Dialogue.Character.NPC1,
			Dialogue.ExpressionState.SPEAKING,
			"行啊，我先去舞池热身，等你。",
		)
	else:
		await Dialogue.entree(
			Dialogue.Character.NPC0,
			Dialogue.ExpressionState.SPEAKING,
			"居然……平手？",
		)
		await Dialogue.entree(
			Dialogue.Character.NPC1,
			Dialogue.ExpressionState.SPEAKING,
			"那就再比一场——这次比[b]跳舞[/b]！我先去舞池热身！",
		)

	# 第二次电梯：16 层到 8 层，门开了只剩女生一个人
	await _fade_out_anchor()
	_status.text = "完整流程：第二次电梯"
	reset_camera(0.0)
	var middle := _play_anchor(MIDDLE_SCENE, _status.text)
	await middle.anchor_finished
	follow_camera(middle.get_node("Elevator/NPCs/NPC0"))
	await Dialogue.entree(
		Dialogue.Character.NPC0,
		Dialogue.ExpressionState.SPEAKING,
		"咦？刚才那个男生呢？",
	)
	reset_camera()
	await Dialogue.entree(
		Dialogue.Character.NARRATOR,
		Dialogue.ExpressionState.NORMAL,
		"那个男生去哪儿了？",
		["躲在女生后面", "扒在电梯顶上", "卡到了后面的涂层里", "卡到了后室"],
	)
	await Dialogue.entree(
		Dialogue.Character.NARRATOR,
		Dialogue.ExpressionState.NORMAL,
		"那……现在该怎么办？",
		["跳舞", "还是跳舞", "坐电梯不如跳舞", "依然是跳舞"],
	)
	await Dialogue.entree(
		Dialogue.Character.NPC0,
		Dialogue.ExpressionState.SPEAKING,
		"[b]说的对！[/b]",
	)

	# 《第二关》
	_status.text = "完整流程：第二关说明"
	_clear_anchor()
	await _show_level_intro(2, "舞蹈对决", P1_DANCE_KEYS, P2_DANCE_KEYS, DANCE_RULES)

	_status.text = "完整流程：阶段二 舞蹈对决"
	reset_camera(0.0)
	var dance_phase := _play_anchor(DANCE_PHASE, _status.text)
	var round2: Dictionary = await dance_phase.phase_finished

	var total_miss := int(round2.misses)
	if total_miss > 0:
		await Dialogue.entree(
			Dialogue.Character.NARRATOR,
			Dialogue.ExpressionState.NORMAL,
			"两个人合计跳错了 %d 次……这舞跳得实在是[shake rate=20 level=5]太烂了[/shake]。" % total_miss,
		)
	else:
		await Dialogue.entree(
			Dialogue.Character.NARRATOR,
			Dialogue.ExpressionState.NORMAL,
			"居然一次都没跳错……但这份整齐的[shake rate=20 level=5]噪音[/shake]还是惊动了什么。",
		)
	await Dialogue.entree(
		Dialogue.Character.NARRATOR,
		Dialogue.ExpressionState.NORMAL,
		"烂舞的震动顺着井道传了下去——[shake rate=20 level=6]电梯深处的什么东西被吵醒了！[/shake]",
	)
	await Dialogue.entree(
		Dialogue.Character.NPC0,
		Dialogue.ExpressionState.SPEAKING,
		"什……什么声音？！",
	)
	await Dialogue.entree(
		Dialogue.Character.NPC1,
		Dialogue.ExpressionState.SPEAKING,
		"先别吵了——我去下面看看，你坐电梯下来！",
	)

	# 第三次电梯：8 层到 1 层，门开了一个人都没有
	await _fade_out_anchor()
	_status.text = "完整流程：第三次电梯"
	reset_camera(0.0)
	var ending_lift := _play_anchor(END_SCENE, _status.text)
	await ending_lift.anchor_finished
	await Dialogue.entree(
		Dialogue.Character.NARRATOR,
		Dialogue.ExpressionState.NORMAL,
		"为什么电梯里一个人都没有了？",
		["不知道", "我不知道", "无所谓", "另一个怎么选都没有区别的选项"],
	)
	await Dialogue.entree(
		Dialogue.Character.NARRATOR,
		Dialogue.ExpressionState.NORMAL,
		"……[shake rate=20 level=6]原来是电梯变异了！[/shake]",
	)

	# 《第三关》
	_status.text = "完整流程：第三关说明"
	_clear_anchor()
	await _show_level_intro(3, "电梯怪兽", P1_ARENA_KEYS, P2_ARENA_KEYS, BOSS_RULES)

	_status.text = "完整流程：阶段三 电梯怪兽"
	reset_camera(0.0)
	var boss_phase := _play_anchor(BOSS_PHASE, _status.text)
	await boss_phase.phase_finished

	await Dialogue.entree(
		Dialogue.Character.NARRATOR,
		Dialogue.ExpressionState.NORMAL,
		"电梯怪兽倒下了。楼道里重新安静下来。",
	)
	await Dialogue.entree(
		Dialogue.Character.NPC0,
		Dialogue.ExpressionState.SPEAKING,
		"刚才……谢了。要不是你引开它……",
	)
	await Dialogue.entree(
		Dialogue.Character.NPC1,
		Dialogue.ExpressionState.SPEAKING,
		"彼此彼此。扔东西是你厉害，跳舞我们都烂——打怪兽，算我们一起赢的。",
	)
	await Dialogue.entree(
		Dialogue.Character.NPC0,
		Dialogue.ExpressionState.SPEAKING,
		"那就……算平局？",
	)
	await Dialogue.entree(
		Dialogue.Character.NPC1,
		Dialogue.ExpressionState.SPEAKING,
		"平局。走吧，一起下楼。",
	)
	await Dialogue.entree(
		Dialogue.Character.NARRATOR,
		Dialogue.ExpressionState.NORMAL,
		"[center][font_size=20]—— 和解 ——[/font_size][/center]",
	)

	# 和解之后：不管怎么选，最后都得跳舞
	_status.text = "完整流程：隐藏关前的选择"
	var next := await Dialogue.entree(
		Dialogue.Character.NPC0,
		Dialogue.ExpressionState.SPEAKING,
		"那……我们接下来干什么？",
		["亲亲", "继续跳舞", "结束游戏"],
	)
	if next == 0:
		next = 1 + await Dialogue.entree(
			Dialogue.Character.NPC0,
			Dialogue.ExpressionState.SPEAKING,
			"爽！接下来干什么？",
			["继续跳舞", "结束游戏"],
		)
	if next == 2:
		# "结束游戏"灰着，只能选跳舞
		await Dialogue.entree(
			Dialogue.Character.NPC1,
			Dialogue.ExpressionState.SPEAKING,
			"真的不跳舞了吗？",
			["继续跳舞", "结束游戏"],
			[1],
		)

	# 隐藏关《接着奏乐接着舞》：先挑一首，跳完可以换一首接着跳，也可以真的退出回标题
	_status.text = "完整流程：隐藏关 接着奏乐接着舞"
	await _fade_out_anchor()
	var hidden := LevelIntro.new()
	add_child(hidden)
	await hidden.run(0, "隐藏关：按键和规则同第二关", [], [], [], "", "《接着奏乐接着舞》")
	var pick := await Dialogue.entree(
		Dialogue.Character.NPC0,
		Dialogue.ExpressionState.SPEAKING,
		"跳哪首？",
		HIDDEN_SONGS,
	)
	while pick >= 0 and pick < HIDDEN_SONGS.size():
		var song: String = HIDDEN_SONGS[pick]
		reset_camera(0.0)
		var encore := _play_anchor(
			DANCE_PHASE, "隐藏关：%s" % song,
			func(phase: Node) -> void: phase.song_name = song,
		)
		await encore.phase_finished
		var again: Array[String] = HIDDEN_SONGS.duplicate()
		again.append("退出游戏")
		pick = await Dialogue.entree(
			Dialogue.Character.NPC1,
			Dialogue.ExpressionState.SPEAKING,
			"再来一首？",
			again,
		)
		await _fade_out_anchor()
	await Dialogue.entree(
		Dialogue.Character.NARRATOR,
		Dialogue.ExpressionState.NORMAL,
		"[center][font_size=20]—— 完 ——[/font_size][/center][br][center]坐电梯不如跳舞。[/center]",
	)

	await _fade_out_anchor(1.2)
	_status.text = "完整流程结束（按 1～9 重新选择）"
	_dialogue_test_running = false
	if auto_start:
		# 打完一轮回到标题菜单，可以直接再来一局
		await get_tree().create_timer(1.0).timeout
		_run_full_story()


## 弹出《第X关》标题 + 操作 / 规则确认页，全部确认完才返回。
## 单人模式下男生那一栏只写"由电脑控制"。
func _show_level_intro(level_no: int, subtitle: String, p1_keys: Array, p2_keys: Array, rules: Array) -> void:
	var intro := LevelIntro.new()
	add_child(intro)
	if Session.single_player:
		await intro.run(level_no, subtitle, p1_keys, P2_AI_LINE, rules, "男生  电脑")
	else:
		await intro.run(level_no, subtitle, p1_keys, p2_keys, rules)
