extends CanvasLayer

signal entry_completed(choice_index: int)

const NPC0_NORMAL := preload("res://Assets/ROMART/npc0.png")
const NPC0_SPEAKING := preload("res://Assets/ROMART/npc0说话.png")
const NPC1_NORMAL := preload("res://Assets/ROMART/npc1.png")
const NPC1_SPEAKING := preload("res://Assets/ROMART/npc1说话.png")
const PIXEL_FONT := preload("res://Assets/Theme/像素字体.ttf")

@export_range(0.001, 0.2, 0.001) var character_delay := 0.035

@onready var _root: Control = $Root
@onready var _portrait: TextureRect = $Root/Portrait
@onready var _dialogue_text: RichTextLabel = $Root/DialogueText
@onready var _choice_panel: PanelContainer = $Root/ChoicePanel
@onready var _choice_list: VBoxContainer = $Root/ChoicePanel/Margin/Choices

var _active := false
var _typing := false
var _generation := 0
var _options: Array[String] = []


func _ready() -> void:
	_root.hide()
	_choice_panel.hide()


func show_entry(
	character_id: int,
	expression_id: int,
	dialogue_text: String,
	options: Array[String],
) -> int:
	_generation += 1
	_active = true
	_typing = true
	_options = options.duplicate()
	_clear_choices()
	_update_portrait(character_id, expression_id)

	_dialogue_text.text = dialogue_text
	_dialogue_text.visible_characters = 0
	_root.show()

	_type_text(_generation)
	var selected_option: int = await entry_completed
	return selected_option


func _input(event: InputEvent) -> void:
	if not _active:
		return

	var advance_pressed := event.is_action_pressed("ui_accept")
	if event is InputEventMouseButton:
		advance_pressed = advance_pressed or (
			event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		)

	if not advance_pressed:
		return

	if _typing:
		get_viewport().set_input_as_handled()
		_finish_typing()
	elif _options.is_empty():
		get_viewport().set_input_as_handled()
		_finish_entry(-1)
	# When choices are visible, keyboard and mouse events are left to the
	# focused Button nodes.


func _type_text(generation: int) -> void:
	# RichTextLabel needs one frame to finish parsing BBCode and count only the
	# visible characters. The markup tags are therefore never revealed as text.
	await get_tree().process_frame
	if generation != _generation or not _active:
		return

	var total_characters := _dialogue_text.get_total_character_count()
	while (
		_dialogue_text.visible_characters < total_characters
		and generation == _generation
		and _active
	):
		await get_tree().create_timer(character_delay).timeout
		_dialogue_text.visible_characters += 1

	if generation == _generation and _active:
		_finish_typing()


func _finish_typing() -> void:
	if not _typing:
		return
	_typing = false
	_generation += 1
	_dialogue_text.visible_characters = -1
	if not _options.is_empty():
		_show_choices()


func _show_choices() -> void:
	for index in _options.size():
		var button := Button.new()
		button.text = _options[index]
		button.custom_minimum_size = Vector2(0.0, 28.0)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_override("font", PIXEL_FONT)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_on_choice_pressed.bind(index))
		_choice_list.add_child(button)

	_choice_panel.show()
	if _choice_list.get_child_count() > 0:
		_choice_list.get_child(0).grab_focus()


func _on_choice_pressed(index: int) -> void:
	if not _active or _typing:
		return
	_finish_entry(index)


func _finish_entry(choice_index: int) -> void:
	_active = false
	_generation += 1
	_root.hide()
	_clear_choices()
	entry_completed.emit(choice_index)


func _clear_choices() -> void:
	_choice_panel.hide()
	for child in _choice_list.get_children():
		_choice_list.remove_child(child)
		child.queue_free()


func _update_portrait(character_id: int, expression_id: int) -> void:
	_portrait.show()
	match character_id:
		Dialogue.Character.NPC0:
			_portrait.position = Vector2(22.0, 210.0)
			_portrait.texture = (
				NPC0_NORMAL
				if expression_id == Dialogue.ExpressionState.NORMAL
				else NPC0_SPEAKING
			)
			_set_text_rect(150.0, 222.0, 445.0, 104.0)
		Dialogue.Character.NPC1:
			_portrait.position = Vector2(490.0, 210.0)
			_portrait.texture = (
				NPC1_NORMAL
				if expression_id == Dialogue.ExpressionState.NORMAL
				else NPC1_SPEAKING
			)
			_set_text_rect(42.0, 222.0, 438.0, 104.0)
		_:
			_portrait.hide()
			_set_text_rect(42.0, 222.0, 554.0, 104.0)


func _set_text_rect(x: float, y: float, width: float, height: float) -> void:
	_dialogue_text.position = Vector2(x, y)
	_dialogue_text.size = Vector2(width, height)
