extends CanvasLayer

signal entry_completed(choice_index: int)
signal choice_focused(choice_index: int)

const NPC0_NORMAL := preload("res://Assets/ROMART/npc0.png")
const NPC0_SPEAKING := preload("res://Assets/ROMART/npc0说话.png")
const NPC1_NORMAL := preload("res://Assets/ROMART/npc1.png")
const NPC1_SPEAKING := preload("res://Assets/ROMART/npc1说话.png")
const NPC0_TALK_SOUND := preload("res://Assets/Sound Effects/女生_5.wav")
const NPC1_TALK_SOUND := preload("res://Assets/Sound Effects/男生_11.wav")
const PIXEL_FONT := preload("res://Assets/Theme/像素字体.ttf")
const TALK_DIRECTIONS: Array[Vector2] = [
	Vector2.LEFT,
	Vector2.RIGHT,
	Vector2.UP,
	Vector2.DOWN,
]

@export_range(0.001, 0.2, 0.001) var character_delay := 0.06
@export_range(0.02, 0.3, 0.01) var talk_frame_delay := 0.08
@export_range(0.0, 4.0, 1.0) var talk_move_distance := 2.0

@onready var _root: Control = $Root
@onready var _portrait: TextureRect = $Root/Portrait
@onready var _dialogue_text: RichTextLabel = $Root/DialogueText
@onready var _choice_panel: PanelContainer = $Root/ChoicePanel
@onready var _choice_list: VBoxContainer = $Root/ChoicePanel/Margin/Choices
@onready var _talk_sound: AudioStreamPlayer = $TalkSound

var _active := false
var _typing := false
var _generation := 0
var _options: Array[String] = []
var _disabled: Array[int] = []
var _portrait_home := Vector2.ZERO
var _portrait_closed: Texture2D
var _portrait_open: Texture2D
var _talking_visuals_enabled := false
var _mouth_open := false
var _advance_action_held := false


func _ready() -> void:
	_root.hide()
	_choice_panel.hide()


func show_entry(
	character_id: int,
	expression_id: int,
	dialogue_text: String,
	options: Array[String],
	disabled_options: Array[int] = [],
) -> int:
	_generation += 1
	_active = true
	_typing = true
	_options = options.duplicate()
	_disabled = disabled_options.duplicate()
	_clear_choices()
	_update_portrait(character_id, expression_id)

	_dialogue_text.text = dialogue_text
	_dialogue_text.visible_characters = 0
	_root.show()

	_type_text(_generation)
	_run_talking_visuals(_generation)
	var selected_option: int = await entry_completed
	return selected_option


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_released("ui_accept"):
		_advance_action_held = false
		return
	if not _active:
		return

	var advance_pressed := event.is_action_pressed("ui_accept")
	if advance_pressed:
		if _advance_action_held:
			return
		_advance_action_held = true
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
		if generation != _generation or not _active or not _typing:
			return
		_dialogue_text.visible_characters += 1

	if generation == _generation and _active:
		_finish_typing()


func _run_talking_visuals(generation: int) -> void:
	if not _talking_visuals_enabled:
		return

	while _typing and generation == _generation and _active:
		_mouth_open = not _mouth_open
		_portrait.texture = _portrait_open if _mouth_open else _portrait_closed
		var direction: Vector2 = TALK_DIRECTIONS.pick_random()
		_portrait.position = _portrait_home + direction * talk_move_distance
		if _mouth_open:
			_play_talk_sound()
		await get_tree().create_timer(talk_frame_delay).timeout


func _play_talk_sound() -> void:
	if _talk_sound.stream != null:
		_talk_sound.play()


func _reset_talking_visuals() -> void:
	_mouth_open = false
	_talk_sound.stop()
	if _portrait_closed != null:
		_portrait.texture = _portrait_closed
	_portrait.position = _portrait_home


func _finish_typing() -> void:
	if not _typing:
		return
	_typing = false
	_generation += 1
	_reset_talking_visuals()
	_dialogue_text.visible_characters = -1
	if not _options.is_empty():
		_show_choices()


func _show_choices() -> void:
	for index in _options.size():
		var button := Button.new()
		button.text = _options[index]
		button.custom_minimum_size = Vector2(0.0, 32.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_override("font", PIXEL_FONT)
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", Color(0.68, 0.68, 0.72, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.78, 1.0))
		button.add_theme_color_override("font_focus_color", Color(1.0, 0.96, 0.78, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.58, 1.0))
		button.add_theme_stylebox_override("normal", _choice_style(Color.TRANSPARENT))
		button.add_theme_stylebox_override("hover", _choice_style(Color.TRANSPARENT))
		button.add_theme_stylebox_override("focus", _choice_style(Color(0.18, 0.18, 0.2, 0.839)))
		button.add_theme_stylebox_override("pressed", _choice_style(Color(0.22, 0.21, 0.18, 0.839)))
		if _disabled.has(index):
			# 灰掉：看得见、点不了、光标也跳不上去
			button.disabled = true
			button.focus_mode = Control.FOCUS_NONE
			button.mouse_default_cursor_shape = Control.CURSOR_ARROW
			button.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.34, 1.0))
			button.add_theme_stylebox_override("disabled", _choice_style(Color.TRANSPARENT))
		else:
			button.mouse_entered.connect(button.grab_focus)
			button.focus_entered.connect(_on_choice_focused.bind(index))
			button.pressed.connect(_on_choice_pressed.bind(index))
		_choice_list.add_child(button)

	_choice_panel.show()
	for child in _choice_list.get_children():
		if not child.disabled:
			child.grab_focus()
			break


func _choice_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_right = 1
	style.corner_radius_bottom_left = 1
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	return style


func _on_choice_pressed(index: int) -> void:
	if not _active or _typing:
		return
	_finish_entry(index)


func _on_choice_focused(index: int) -> void:
	if not _active or _typing:
		return
	choice_focused.emit(index)


func _finish_entry(choice_index: int) -> void:
	_active = false
	_generation += 1
	_reset_talking_visuals()
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
	_talking_visuals_enabled = expression_id == Dialogue.ExpressionState.SPEAKING
	match character_id:
		Dialogue.Character.NPC0:
			_portrait_home = Vector2(22.0, 210.0)
			_portrait_closed = NPC0_NORMAL
			_portrait_open = NPC0_SPEAKING
			_talk_sound.stream = NPC0_TALK_SOUND
			_set_text_rect(150.0, 222.0, 445.0, 104.0)
		Dialogue.Character.NPC1:
			_portrait_home = Vector2(490.0, 210.0)
			_portrait_closed = NPC1_NORMAL
			_portrait_open = NPC1_SPEAKING
			_talk_sound.stream = NPC1_TALK_SOUND
			_set_text_rect(42.0, 222.0, 438.0, 104.0)
		_:
			_talking_visuals_enabled = false
			_portrait_closed = null
			_portrait_open = null
			_talk_sound.stream = null
			_portrait.hide()
			_set_text_rect(42.0, 222.0, 554.0, 104.0)
	_reset_talking_visuals()


func _set_text_rect(x: float, y: float, width: float, height: float) -> void:
	_dialogue_text.position = Vector2(x, y)
	_dialogue_text.size = Vector2(width, height)
