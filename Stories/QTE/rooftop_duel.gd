extends CanvasLayer
class_name RooftopDuel

signal completed

const FONT := preload("res://Assets/Theme/像素字体.ttf")
const HIT_SOUND := preload("res://Assets/Sound Effects/mixkit-impact-of-a-strong-punch-2155.mp3")
const STANDING_SHEET := preload("res://Assets/caracter/npc standing.png")
const WOMAN_ATTACK_FRAMES: Array[Texture2D] = [
	preload("res://Assets/caracter/attack_frames/attack_woman_1.png"),
	preload("res://Assets/caracter/attack_frames/attack_woman_2.png"),
	preload("res://Assets/caracter/attack_frames/attack_woman_3.png"),
	preload("res://Assets/caracter/attack_frames/attack_woman_4.png"),
]
const MAN_ATTACK_FRAMES: Array[Texture2D] = [
	preload("res://Assets/caracter/attack_frames/attack_man_1.png"),
	preload("res://Assets/caracter/attack_frames/attack_man_2.png"),
	preload("res://Assets/caracter/attack_frames/attack_man_3.png"),
	preload("res://Assets/caracter/attack_frames/attack_man_4.png"),
]
const EARLY_ROUND_TIME := 5.0
const FINAL_ROUND_TIME := 10.0
const COUNTDOWN_TIME := 3.0
const RULE_READ_TIME := 3.0
const RULE_FADE_TIME := 0.6
const BAR_HEIGHT := 62.0
const BAR_SLIDE_TIME := 0.9
const ROUNDS: Array[Array] = [
	[KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT],
	[KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT],
	[KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A, KEY_B, KEY_A],
]
const FINAL_RETRY: Array = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]

var woman: AnimatedSprite2D
var man: AnimatedSprite2D
var camera: Camera2D
var round_index := 0
var final_retry := false
var sequence: Array = []
var input_index := 0
var time_left := EARLY_ROUND_TIME
var countdown_left := COUNTDOWN_TIME
var running := false
var bar_progress := 0.0
var rule_alpha := 0.0
var showing_rule := false
var message := ""
var _woman_home := Vector2.ZERO
var _man_home := Vector2.ZERO
var _camera_home := Vector2.ZERO
var _busy := false
var _visual: Control
var _woman_idle_frames: SpriteFrames
var _man_idle_frames: SpriteFrames
var _woman_attack_frames: SpriteFrames
var _man_attack_frames: SpriteFrames
var _strike_tween: Tween


func _ready() -> void:
	layer = 94
	_visual = Control.new()
	_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.draw.connect(_draw_ui)
	add_child(_visual)
	set_process(false)


func play(target_woman: AnimatedSprite2D, target_man: AnimatedSprite2D, target_camera: Camera2D) -> void:
	begin(target_woman, target_man, target_camera)
	await completed


func begin(target_woman: AnimatedSprite2D, target_man: AnimatedSprite2D, target_camera: Camera2D) -> void:
	woman = target_woman
	man = target_man
	camera = target_camera
	_woman_home = woman.position
	_man_home = man.position
	_camera_home = camera.global_position
	_woman_idle_frames = _standing_frames(1)
	_man_idle_frames = _standing_frames(0)
	_woman_attack_frames = _attack_frames(WOMAN_ATTACK_FRAMES)
	_man_attack_frames = _attack_frames(MAN_ATTACK_FRAMES)
	man.scale.x = -absf(man.scale.x)
	_set_idle(woman, _woman_idle_frames)
	_set_idle(man, _man_idle_frames)
	round_index = 0
	final_retry = false
	running = false
	_busy = true
	message = "必须要在时间内敲击正确的方向键"
	bar_progress = 0.0
	rule_alpha = 1.0
	showing_rule = true
	_set_sequence()
	set_process(true)
	var entrance := create_tween()
	entrance.tween_property(self, "bar_progress", 1.0, BAR_SLIDE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await entrance.finished
	await get_tree().create_timer(RULE_READ_TIME).timeout
	var fade := create_tween()
	fade.tween_property(self, "rule_alpha", 0.0, RULE_FADE_TIME)
	await fade.finished
	showing_rule = false
	message = ""
	countdown_left = COUNTDOWN_TIME
	_busy = false


func _process(delta: float) -> void:
	if bar_progress > 0.0:
		_visual.queue_redraw()
	if _busy:
		return
	if not running:
		countdown_left -= delta
		if countdown_left <= 0.0:
			countdown_left = 0.0
			running = true
			time_left = _round_time()
			message = ""
		return
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		_fail()


func _unhandled_input(event: InputEvent) -> void:
	if not running or _busy or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.keycode
	if key not in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_A, KEY_B]:
		return
	get_viewport().set_input_as_handled()
	press_key(key)


func press_key(key: Key) -> void:
	if not running or _busy:
		return
	if key != sequence[input_index]:
		_fail()
		return
	input_index += 1
	if input_index >= sequence.size():
		_succeed()


func _set_sequence() -> void:
	sequence = FINAL_RETRY.duplicate() if round_index == 2 and final_retry else ROUNDS[round_index].duplicate()
	input_index = 0
	time_left = _round_time()


func _round_time() -> float:
	return EARLY_ROUND_TIME if round_index < 2 else FINAL_ROUND_TIME


func _standing_frames(row: int) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 6.0)
	frames.set_animation_loop(&"default", true)
	for index in 4:
		var tile := AtlasTexture.new()
		tile.atlas = STANDING_SHEET
		tile.region = Rect2(index * 256, row * 256, 256, 256)
		frames.add_frame(&"default", tile)
	return frames


func _attack_frames(textures: Array[Texture2D]) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"attack")
	frames.set_animation_loop(&"attack", false)
	frames.set_animation_speed(&"attack", 10.0)
	for texture in textures:
		frames.add_frame(&"attack", texture)
	return frames


func _set_idle(character: AnimatedSprite2D, frames: SpriteFrames) -> void:
	character.sprite_frames = frames
	character.play(&"default")


func _succeed() -> void:
	var final_round := round_index == ROUNDS.size() - 1
	if final_round:
		running = false
		_busy = true
		message = "命中！"
	else:
		round_index += 1
		_set_sequence()
		message = ""
	var strike := _play_success_animation()
	if final_round:
		await strike.finished
		await _finish()


func _play_success_animation() -> Tween:
	_cancel_success_animation()
	woman.sprite_frames = _woman_attack_frames
	woman.play(&"attack")
	_play_attack_sound("WomanAttackSound")
	var strike := create_tween()
	_strike_tween = strike
	strike.tween_property(woman, "position:x", _woman_home.x + 12.0, 0.1)
	strike.tween_property(man, "position:x", _man_home.x + 14.0, 0.16)
	strike.parallel().tween_property(man, "modulate", Color(1.0, 0.28, 0.3), 0.06)
	strike.tween_property(woman, "position", _woman_home, 0.2)
	strike.parallel().tween_property(man, "position", _man_home, 0.2)
	strike.parallel().tween_property(man, "modulate", Color.WHITE, 0.2)
	strike.finished.connect(_on_strike_finished.bind(strike))
	return strike


func _on_strike_finished(strike: Tween) -> void:
	if _strike_tween != strike:
		return
	_strike_tween = null
	_set_idle(woman, _woman_idle_frames)
	_set_idle(man, _man_idle_frames)


func _cancel_success_animation() -> void:
	if _strike_tween != null and _strike_tween.is_valid():
		_strike_tween.kill()
	_strike_tween = null
	woman.position = _woman_home
	man.position = _man_home
	man.modulate = Color.WHITE
	_set_idle(woman, _woman_idle_frames)
	_set_idle(man, _man_idle_frames)


func _fail() -> void:
	running = false
	_busy = true
	_cancel_success_animation()
	message = "失误！男人反击"
	man.sprite_frames = _man_attack_frames
	man.play(&"attack")
	_play_attack_sound("ManAttackSound")
	var counter := create_tween()
	counter.tween_property(man, "position:x", _woman_home.x + 18.0, 0.13)
	counter.tween_property(woman, "position:x", _woman_home.x - 10.0, 0.08)
	counter.parallel().tween_property(woman, "modulate", Color(1.0, 0.25, 0.25), 0.06)
	counter.parallel().tween_property(camera, "global_position:x", _camera_home.x - 3.0, 0.06)
	counter.tween_interval(0.17)
	counter.tween_property(man, "position", _man_home, 0.25)
	counter.parallel().tween_property(woman, "position", _woman_home, 0.25)
	counter.parallel().tween_property(woman, "modulate", Color.WHITE, 0.25)
	counter.parallel().tween_property(camera, "global_position", _camera_home, 0.25)
	await counter.finished
	_set_idle(woman, _woman_idle_frames)
	_set_idle(man, _man_idle_frames)
	if round_index == 2:
		final_retry = not final_retry
	_set_sequence()
	message = "再来！"
	await get_tree().create_timer(0.5).timeout
	message = ""
	running = true
	_busy = false


func _play_attack_sound(sound_name: String) -> void:
	var hit := AudioStreamPlayer.new()
	hit.name = sound_name
	hit.stream = HIT_SOUND
	hit.volume_db = -10.0
	add_child(hit)
	hit.finished.connect(hit.queue_free)
	hit.play()


func _finish() -> void:
	var exit_tween := create_tween()
	exit_tween.tween_property(self, "bar_progress", 0.0, BAR_SLIDE_TIME * 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await exit_tween.finished
	set_process(false)
	completed.emit()


func _glyph(key: Key) -> String:
	match key:
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		KEY_A: return "A"
		KEY_B: return "B"
	return "?"


func _glyph_color(index: int) -> Color:
	return Color(1.0, 0.2, 0.29) if index < input_index else Color.WHITE


func _draw_ui() -> void:
	var width := _visual.size.x
	var height := _visual.size.y
	var top_y := -BAR_HEIGHT * (1.0 - bar_progress)
	var bottom_y := height - BAR_HEIGHT * bar_progress
	_visual.draw_rect(Rect2(0, top_y, width, BAR_HEIGHT), Color.BLACK)
	_visual.draw_rect(Rect2(0, bottom_y, width, BAR_HEIGHT), Color.BLACK)
	if bar_progress < 0.98:
		return
	var scale_x := width / 640.0
	var title := "决战"
	_visual.draw_string(FONT, Vector2(18 * scale_x, top_y + 25), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	var timer_text := "%02d" % ceili(time_left) if running else "%02d" % ceili(_round_time())
	_visual.draw_string(FONT, Vector2(width - 94 * scale_x, top_y + 27), timer_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.3, 0.3) if time_left <= 3.0 and running else Color.WHITE)
	_visual.draw_string(FONT, Vector2(width - 56 * scale_x, top_y + 26), "秒", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if not running and not _busy and countdown_left > 0.0:
		_visual.draw_string(FONT, Vector2(width * 0.5 - 15, height * 0.5 + 17), str(ceili(countdown_left)), HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color.WHITE)
	elif message != "":
		var message_width := FONT.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		_visual.draw_string(FONT, Vector2((width - message_width) * 0.5, height * 0.5 + 5), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, rule_alpha) if showing_rule else Color.WHITE)
	var count := sequence.size()
	var step := minf(46.0 * scale_x, (width - 36.0 * scale_x) / maxf(float(count), 1.0))
	var start_x := (width - step * count) * 0.5
	for index in count:
		var x := start_x + (index + 0.5) * step
		_visual.draw_string(FONT, Vector2(x - 9 * scale_x, bottom_y + 39), _glyph(sequence[index]), HORIZONTAL_ALIGNMENT_LEFT, -1, 23, _glyph_color(index))
