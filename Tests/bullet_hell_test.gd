extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var encounter = load("res://Stories/BulletHell/bullet_hell.tscn").instantiate()
	root.add_child(encounter)
	encounter.set_process(false)
	assert(encounter.phase == encounter.Phase.BLACK)
	assert(encounter.woman.modulate.a == 0.0)
	encounter._process(0.8)
	assert(encounter.woman.is_playing())
	encounter._process(2.0)
	assert(not encounter.woman.is_playing())
	encounter._process(0.7)
	encounter._process(1.19)
	assert(encounter.woman.visible and not encounter.heart.visible)
	encounter._process(0.02)
	assert(not encounter.woman.visible and encounter.heart.visible)
	assert(encounter.sparks.size() == 36)
	encounter._process(0.7)
	assert(encounter.phase == encounter.Phase.PLAY)
	encounter.stage = 0
	encounter.wave_time = 999.0
	encounter.hazards.append({"kind": 1, "position": encounter.heart.position, "velocity": Vector2.ZERO})
	encounter._process(0.01)
	assert(encounter.hits == 1)
	encounter._process(0.01)
	assert(encounter.hits == 1, "Repeated overlap must not bypass immunity")
	for i in 2:
		encounter.immunity = 0.0
		encounter._take_hit()
	assert(encounter.phase == encounter.Phase.BREAK)
	encounter._process(1.99)
	assert(encounter.heart.visible)
	encounter._process(0.02)
	assert(not encounter.heart.visible)
	assert(encounter.phase == encounter.Phase.LOST and encounter.sparks.size() == 36)
	assert(encounter.ending_text.text == "你的智商低低的，还蛮可爱")
	assert(encounter.ending_text.visible_characters == 0)
	assert(encounter.restart_prompt.modulate.a == 0.0)
	encounter._restart()
	assert(encounter.ending_black.modulate.a == 0.0 and encounter.ending_text.modulate.a == 0.0 and encounter.restart_prompt.modulate.a == 0.0)
	assert(encounter.hits == 0 and encounter.elapsed == 0 and encounter.hazards.is_empty())
	encounter._change(encounter.Phase.PLAY)
	encounter._begin_stage(0)
	encounter.stage_time = 9.99
	encounter.hazards.append({"kind": 1, "position": Vector2(300, 100), "velocity": Vector2(50, 0)})
	encounter.immunity = 100.0
	encounter._process(0.1)
	assert(encounter.stage == 0 and encounter.hazards.size() == 1, "Do not clear lingering obstacles")
	encounter._process(6.0)
	assert(encounter.stage == 1 and encounter.hazards.is_empty())
	encounter.stage_time = 8.0
	encounter.wave_time = 0.0
	encounter._process(0.1)
	assert(encounter.hazards.is_empty(), "Stop spawning at eight seconds")
	encounter._begin_stage(2)
	encounter.wave_time = 999.0
	encounter._spawn_ram()
	var ram = encounter.hazards[0]
	assert(is_equal_approx(ram["warning"].position.x, encounter.ARENA.position.x))
	encounter._process(0.49)
	assert(ram["position"] == ram["origin"])
	encounter._process(0.66)
	assert(ram["position"].distance_to(ram["target"]) < 0.01)
	encounter._process(0.66)
	assert(encounter.hazards.is_empty())
	for last_wave in [2, 3]:
		encounter.wave = last_wave
		encounter._spawn_ram()
		assert(encounter.hazards.size() >= 6)
		for hazard in encounter.hazards:
			assert(hazard["through"])
		encounter._process(3.0)
		assert(encounter.hazards.is_empty(), "Offscreen through-blocks must be removed")
	encounter._restart()
	encounter._change(encounter.Phase.PLAY)
	encounter.rng.seed = 12345
	for i in 4800:
		encounter.immunity = 100.0
		encounter._process(1.0 / 60.0)
		if encounter.phase == encounter.Phase.WON:
			break
	assert(encounter.phase == encounter.Phase.WON)
	assert(encounter.ending_text.modulate.a == 0.0, "Victory must fade to black without text")
	assert(encounter.hazards.is_empty())
	assert(encounter.woman_head.position.is_equal_approx(encounter.man_head.position))
	encounter._restart()
	encounter._change(encounter.Phase.PLAY)
	encounter._begin_stage(0)
	encounter.wave_time = 999.0
	encounter.immunity = 100.0
	encounter._process(0.25)
	var first_sway: float = encounter.woman_head.rotation
	var fixed_progress: float = encounter.elapsed
	encounter.stage_time = 10.0
	encounter.hazards.append({"kind": 1, "position": Vector2(300, 100), "velocity": Vector2.ZERO})
	encounter._process(0.25)
	assert(encounter.elapsed == fixed_progress or encounter.elapsed == 9.9)
	var waiting_sway: float = encounter.woman_head.rotation
	encounter._process(0.25)
	assert(encounter.woman_head.rotation != waiting_sway and first_sway != waiting_sway)
	# A meteor just beyond the wall remains alive but has no visible outline.
	encounter._restart()
	encounter._change(encounter.Phase.PLAY)
	encounter._begin_stage(0)
	encounter.wave_time = 999.0
	encounter.immunity = 100.0
	encounter.hazards.append({"kind": 1, "position": Vector2(505, 180), "velocity": Vector2(50, 0), "radius": encounter.METEOR_RADIUS})
	encounter._process(0.6)
	assert(encounter.hazards.size() == 1)
	assert(encounter._clip_to_arena(Vector2(535, 170), Vector2(550, 170)).is_empty())
	encounter._process(0.6)
	assert(encounter.hazards.is_empty())
	# The last two rising gates are narrow, while earlier gates keep their gap.
	encounter.hazards.clear()
	for gate_wave in [3, 4, 5]:
		encounter.wave = gate_wave
		encounter._spawn_gate(true)
		var left_gate: Dictionary = encounter.hazards[0]
		var right_gate: Dictionary = encounter.hazards[1]
		var opening: float = right_gate["position"].x - (left_gate["position"].x + left_gate["size"].x)
		assert(is_equal_approx(opening, 58.0 if gate_wave == 3 else 18.0))
		encounter.hazards.clear()
	print("PASS: intro, damage, natural stage drain, eight-second cutoff, edge warning, returning ram, dense through-wave cleanup, full encounter victory")
	encounter.queue_free()
	await process_frame
	quit()





