extends Node

## Global dialogue entry point.
##
## Call with `await Dialogue.entree(...)`. The returned integer is the selected
## option index, or -1 when the entry has no options.

signal became_available
signal choice_focused(choice_index: int)

enum Character {
	NPC0,
	NPC1,
	NARRATOR,
}

enum ExpressionState {
	NORMAL,
	SPEAKING,
}

const DIALOGUE_BOX_SCENE := preload("res://Stories/Shared/Dialogue/dialogue_box.tscn")

var _dialogue_box
var _busy := false


func _ready() -> void:
	_dialogue_box = DIALOGUE_BOX_SCENE.instantiate()
	add_child(_dialogue_box)
	_dialogue_box.choice_focused.connect(_on_choice_focused)


func _on_choice_focused(choice_index: int) -> void:
	choice_focused.emit(choice_index)


func entree(
	character_id: int,
	expression_id: int,
	dialogue_text: String,
	options: Array[String] = [],
) -> int:
	# Sequential calls normally use await. The loop also makes accidental
	# concurrent calls wait instead of replacing the dialogue currently shown.
	while _busy:
		await became_available

	_busy = true
	var selected_option: int = await _dialogue_box.show_entry(
		character_id,
		expression_id,
		dialogue_text,
		options,
	)
	_busy = false
	became_available.emit()
	return selected_option
