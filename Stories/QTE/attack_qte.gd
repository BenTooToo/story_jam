extends CanvasLayer
class_name AttackQTE

signal completed

enum State { IDLE, MASH, READY, STRIKE, IMPACT, DONE }
const MAN_FRAMES: Array[Texture2D] = [
	preload("res://Assets/caracter/attack_frames/attack_man_1.png"),
	preload("res://Assets/caracter/attack_frames/attack_man_2.png"),
	preload("res://Assets/caracter/attack_frames/attack_man_3.png"),
	preload("res://Assets/caracter/attack_frames/attack_man_4.png"),
]
const WOMAN_FRAMES: Array[Texture2D] = [
	preload("res://Assets/caracter/attack_frames/attack_woman_1.png"),
	preload("res://Assets/caracter/attack_frames/attack_woman_2.png"),
	preload("res://Assets/caracter/attack_frames/attack_woman_3.png"),
	preload("res://Assets/caracter/attack_frames/attack_woman_4.png"),
]
const UI_SCRIPT = preload("res://Stories/QTE/attack_qte_ui.gd")
const AIR_HIT_SOUND = preload("res://Assets/Sound Effects/mixkit-air-in-a-hit-2161.wav")
const STRONG_PUNCH_SOUND = preload("res://Assets/Sound Effects/mixkit-impact-of-a-strong-punch-2155.mp3")
const REQUIRED_PRESSES := 20
const ZOOM_PER_SECOND := 0.8
const FINAL_ZOOM := 1.85
const IMPACT_ZOOM := 2.25
const IMPACT_TIME_SCALE := 0.15
const IMPACT_DURATION := 3.0
const IMPACT_PULLBACK_DURATION := 0.16

var state := State.IDLE
var progress := 0
var target_zoom := 1.35
var camera: Camera2D
var woman: AnimatedSprite2D
var man: AnimatedSprite2D
var ui: AttackQTEUI
var _start_zoom := 1.35
var _focus := Vector2.ZERO
var _impact_focus := Vector2.ZERO
var _impact_time := 0.0
var _impact_start_position := Vector2.ZERO
var _impact_start_zoom := 1.0
var _previous_time_scale := 1.0
var _slow_motion_active := false
var _hit_tween: Tween
var _whoosh_player: AudioStreamPlayer
var _impact_player: AudioStreamPlayer
var _woman_home := Vector2.ZERO
var _shake_left := 0.0
var _woman_saved: Dictionary
var _man_saved: Dictionary

func _ready() -> void:
	layer = 94
	ui = UI_SCRIPT.new()
	add_child(ui)
	set_process(false)

func _exit_tree() -> void:
	_end_slow_motion()

func play(target_woman: AnimatedSprite2D, target_man: AnimatedSprite2D, target_camera: Camera2D) -> void:
	begin(target_woman, target_man, target_camera)
	await completed

func begin(target_woman: AnimatedSprite2D, target_man: AnimatedSprite2D, target_camera: Camera2D) -> void:
	_end_slow_motion()
	woman = target_woman
	man = target_man
	camera = target_camera
	_woman_saved = _remember(woman)
	_man_saved = _remember(man)
	_woman_home = woman.position
	_focus = woman.global_position + Vector2(0, -26)
	_impact_focus = woman.global_position.lerp(man.global_position, 0.57) + Vector2(0, -38)
	_impact_time = 0.0
	_start_zoom = camera.zoom.x
	target_zoom = _start_zoom
	progress = 0
	state = State.MASH
	woman.stop()
	man.stop()
	woman.sprite_frames = _frames(1)
	man.sprite_frames = _frames(0)
	woman.frame = 0
	man.frame = 0
	woman.modulate = Color.WHITE
	man.modulate = Color.WHITE
	ui.ready_for_q = false
	ui.active = true
	ui.impact_mode = false
	ui.impact_progress = 0.0
	set_process(true)

func _remember(character: AnimatedSprite2D) -> Dictionary:
	return {"frames": character.sprite_frames, "animation": character.animation, "frame": character.frame, "progress": character.frame_progress, "playing": character.is_playing(), "modulate": character.modulate}

func _frames(row: int) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_loop(&"default", false)
	var textures := WOMAN_FRAMES if row == 1 else MAN_FRAMES
	for texture in textures:
		frames.add_frame(&"default", texture)
	return frames

func _process(delta: float) -> void:
	if state == State.IMPACT:
		var real_delta := delta / maxf(Engine.time_scale, 0.01)
		_impact_time += real_delta
		var push := clampf(_impact_time / IMPACT_DURATION, 0.0, 1.0)
		camera.zoom = Vector2.ONE * lerpf(_impact_start_zoom, IMPACT_ZOOM, push)
		camera.global_position = _impact_start_position.lerp(_impact_focus, push)
		var bars_in := smoothstep(0.0, 0.2, _impact_time)
		var bars_out := 1.0 - smoothstep(IMPACT_DURATION - 0.2, IMPACT_DURATION, _impact_time)
		ui.impact_progress = minf(bars_in, bars_out)
		return
	if state != State.MASH and state != State.READY:
		return
	var zoom := move_toward(camera.zoom.x, target_zoom, ZOOM_PER_SECOND * delta)
	camera.zoom = Vector2.ONE * zoom
	camera.global_position = camera.global_position.move_toward(_focus, 200.0 * delta)
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		woman.position.x = _woman_home.x + sin((0.14 - _shake_left) / 0.14 * TAU * 2.5) * 2.6
	else:
		woman.position.x = _woman_home.x
	if state == State.MASH and progress >= REQUIRED_PRESSES and is_equal_approx(zoom, FINAL_ZOOM):
		state = State.READY
		ui.ready_for_q = true

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_E and state == State.MASH:
		press_e()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_Q and state == State.READY:
		press_q()
		get_viewport().set_input_as_handled()

func press_e() -> void:
	if state != State.MASH or progress >= REQUIRED_PRESSES:
		return
	progress += 1
	ui.register_press()
	_shake_left = 0.14
	# The target rises on presses 3, 6, ... 18, with the final step at 20.
	var zoom_steps := progress / 3
	if progress == REQUIRED_PRESSES:
		zoom_steps = 7
	target_zoom = lerpf(_start_zoom, FINAL_ZOOM, float(zoom_steps) / 7.0)
	if progress == 10:
		woman.frame = 1

func press_q() -> void:
	if state != State.READY:
		return
	state = State.STRIKE
	ui.active = false
	_whoosh_player = _play_sound(AIR_HIT_SOUND, "QTEWhoosh", -12.0, 1.0)
	_play_strike()

func _play_strike() -> void:
	woman.position = _woman_home
	woman.frame = 2
	await get_tree().create_timer(0.12, true, false, true).timeout
	if not is_instance_valid(woman) or not is_instance_valid(man):
		return
	state = State.IMPACT
	_impact_time = 0.0
	_impact_start_position = camera.global_position
	_impact_start_zoom = camera.zoom.x
	ui.impact_mode = true
	_previous_time_scale = Engine.time_scale
	_slow_motion_active = true
	Engine.time_scale = _previous_time_scale * IMPACT_TIME_SCALE
	woman.frame = 3
	man.frame = 2
	_impact_player = _play_sound(STRONG_PUNCH_SOUND, "QTEImpact", -4.0, 0.9)
	_play_impact_echoes()
	_flash_man()
	await get_tree().create_timer(IMPACT_DURATION * 0.42, true, false, true).timeout
	if not is_instance_valid(woman) or not is_instance_valid(man):
		_end_slow_motion()
		return
	man.frame = 3
	_flash_man()
	await get_tree().create_timer(IMPACT_DURATION * 0.58, true, false, true).timeout
	_end_slow_motion()
	if not is_instance_valid(woman) or not is_instance_valid(man):
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	state = State.STRIKE
	ui.impact_mode = false
	ui.impact_progress = 0.0
	var pullback := create_tween().set_parallel(true)
	pullback.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pullback.tween_property(camera, "global_position", _impact_start_position, IMPACT_PULLBACK_DURATION)
	pullback.tween_property(camera, "zoom", Vector2.ONE * _start_zoom, IMPACT_PULLBACK_DURATION)
	await pullback.finished
	if not is_instance_valid(woman) or not is_instance_valid(man):
		return
	_restore(woman, _woman_saved)
	_restore(man, _man_saved)
	woman.position = _woman_home
	state = State.DONE
	set_process(false)
	completed.emit()

func _end_slow_motion() -> void:
	if _slow_motion_active:
		Engine.time_scale = _previous_time_scale
		_slow_motion_active = false

func _play_impact_echoes() -> void:
	await get_tree().create_timer(0.16, true, false, true).timeout
	if not is_inside_tree():
		return
	_play_sound(STRONG_PUNCH_SOUND, "QTEImpactEcho1", -15.0, 0.78)
	await get_tree().create_timer(0.2, true, false, true).timeout
	if not is_inside_tree():
		return
	_play_sound(STRONG_PUNCH_SOUND, "QTEImpactEcho2", -23.0, 0.66)

func _play_sound(stream: AudioStream, sound_name: String, volume: float, pitch: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = sound_name
	player.stream = stream
	player.volume_db = volume
	player.pitch_scale = pitch
	get_parent().add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player

func _flash_man() -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	man.modulate = Color(1.0, 0.13, 0.13)
	_hit_tween = create_tween()
	_hit_tween.tween_property(man, "modulate", Color.WHITE, 0.15)

func _restore(character: AnimatedSprite2D, saved: Dictionary) -> void:
	character.stop()
	character.sprite_frames = saved["frames"]
	character.animation = saved["animation"]
	character.set_frame_and_progress(saved["frame"], saved["progress"])
	character.modulate = saved["modulate"]
	if saved["playing"]:
		character.play()
