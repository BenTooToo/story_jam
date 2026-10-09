extends Node2D

const END_SCENE := preload("res://Stories/Bentootoo/End/end.tscn")
const ThanksCard := preload("res://Stories/Shared/Web/thanks_card.gd")
const LIGHTS_OUT_DURATION := 0.18
## 演职员表停留多久再回选线界面
const CREDITS_HOLD := 6.0

@export_enum("Love", "Tragedy") var ending_route := 0
@export var play_on_ready := true

@onready var _cg_host: Node2D = get_node_or_null("CGHost") as Node2D
@onready var _black: ColorRect = $Overlay/Black
@onready var _card: Label = $Overlay/Card
@onready var _credits: Label = $Overlay/Credits
@onready var _light_off_sound: AudioStreamPlayer = $LightOffSound


func _ready() -> void:
	if not play_on_ready:
		return
	if ending_route == 1:
		_run_tragedy_ending()
	else:
		_run_ending()


func _run_ending() -> void:
	# The bullet hell has already faded out; keep the background black for dialogue.
	await _say(BenDialogue.Character.NPC0, "加油，你一定要跟我回到电梯里面，不然，你会死的！")
	await _say(BenDialogue.Character.NPC1, "对不起，不要管我了，我真的。。。好喜欢你现在的样子")
	await _say(BenDialogue.Character.NPC1, "至少告诉我。。。")
	await _say(BenDialogue.Character.NPC1, "你的名字")
	await _say(BenDialogue.Character.NPC0, "我叫高晨")
	await _say(BenDialogue.Character.NPC0, "请你不要忘记我")
	await _say(BenDialogue.Character.NPC1, "好的啊。。。我叫。。。小林")

	var ending_cg := END_SCENE.instantiate()
	_cg_host.add_child(ending_cg)
	await get_tree().process_frame
	_black.hide()
	await ending_cg.anchor_finished
	await ending_cg.wait_for_opening_sound()

	_black.modulate.a = 0.0
	_black.show()
	_light_off_sound.play()
	var lights_out := create_tween()
	lights_out.tween_property(_black, "modulate:a", 1.0, LIGHTS_OUT_DURATION)
	await lights_out.finished
	await get_tree().create_timer(0.6).timeout

	await _show_card("这就是", 24, 1.0)
	await _show_card("高晨与小林的爱情故事", 30, 2.2)
	await _show_card("本2兔出品", 28, 1.8)
	await _show_card("爱河线结束", 24, 1.2)
	SaveData.add_ending("ben_love")
	_show_credits()
	await _return_to_route_select()


func _run_tragedy_ending() -> void:
	_black.show()
	_black.modulate.a = 1.0
	await _narrate("只见两个人倒在血泊之中")
	await _narrate("红色与绿色的血液融合在了一起")
	await _narrate("小林 缓缓的睁开了眼睛，用尽最后的力气说出了最后一个问题")
	await _narrate("殊不知那个女人的身体也早已经被电梯的碎片所贯穿")
	await _say(BenDialogue.Character.NPC1, "拜托了，告诉我")
	await _say(BenDialogue.Character.NPC1, "告诉我")
	await _say(BenDialogue.Character.NPC1, "你的名字")
	await _narrate("好吧，我就告诉我你吧")
	await _narrate("我")
	await _narrate("叫")
	await _narrate("高晨")
	await _narrate("等你到了地狱，要再跟我打一架啊")

	var ending_cg := END_SCENE.instantiate()
	_cg_host.add_child(ending_cg)
	await get_tree().process_frame
	var reveal := create_tween()
	reveal.tween_property(_black, "modulate:a", 0.0, 0.8)
	await reveal.finished
	await ending_cg.anchor_finished
	await ending_cg.wait_for_opening_sound()
	await ending_cg.close_doors()
	var fade := create_tween()
	fade.tween_property(_black, "modulate:a", 1.0, 0.8)
	await fade.finished
	await get_tree().create_timer(0.5).timeout
	await _show_card("本2兔出品", 28, 1.8)
	await _show_card("高晨和小林的爱情悲剧", 30, 2.2)
	SaveData.add_ending("ben_tragedy")
	_show_credits()
	await _return_to_route_select()


func _return_to_route_select() -> void:
	await get_tree().create_timer(CREDITS_HOLD).timeout
	var fade := create_tween()
	fade.tween_property(_credits, "modulate:a", 0.0, 1.0)
	await fade.finished
	await ThanksCard.show_on(self, "ben")
	Session.back_to_route_select()


func _say(character_id: int, line: String) -> void:
	await BenDialogue.entree(character_id, BenDialogue.ExpressionState.SPEAKING, line)


func _narrate(line: String) -> void:
	await BenDialogue.entree(BenDialogue.Character.NARRATOR, BenDialogue.ExpressionState.NORMAL, line)


func _show_card(line: String, font_size: int, hold: float) -> void:
	_card.text = line
	_card.add_theme_font_size_override("font_size", font_size)
	_card.modulate.a = 0.0
	_card.show()
	var fade_in := create_tween()
	fade_in.tween_property(_card, "modulate:a", 1.0, 0.75)
	await fade_in.finished
	await get_tree().create_timer(hold).timeout
	var fade_out := create_tween()
	fade_out.tween_property(_card, "modulate:a", 0.0, 0.45)
	await fade_out.finished
	_card.hide()


func _show_credits() -> void:
	_credits.text = (
		"基础游戏框架\n"
		+ "策划  本2兔、小林、Romart、高老师\n"
		+ "代码、故事、音效  本2兔、小林\n"
		+ "美术  Romart、高老师\n\n"
		+ "版本分支剧情\n"
		+ "代码、策划、音效  本2兔\n"
		+ "故事  本2兔、Romort\n"
		+ "美术  Romort"
	)
	_credits.modulate.a = 0.0
	_credits.show()
	create_tween().tween_property(_credits, "modulate:a", 1.0, 1.0)
