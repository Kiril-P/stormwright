extends SceneTree
## A 25-second laboratory motion study using the production scene, request methods,
## physics, actor animation, collision and damage. Only fixtures and inputs are staged.
## This is visual evidence, never a normal-run or performance benchmark.
##
## Create the destination directory before starting MovieWriter, then use:
## Godot --path . --script game/visual_reel.gd --write-movie work/visual-reel/reel.avi
##   --fixed-fps 60 --disable-vsync --resolution 1920x1080
##   -- --reel-out=res://work/visual-reel --seed=7331
## Without --write-movie it is a normal-speed visual walkthrough with PNG captures.
## --headless --fixed-fps 60 checks the same staged damage; it cannot verify graphics.

const MAIN = preload("res://scenes/main.tscn")
const INPUTS := ["lance", "crown", "cataclysm", "dash", "move_left", "move_right", "move_up", "move_down"]
const SEGMENTS := [
	{"id": "01-lance", "title": "STORM LANCE", "detail": "Gather → discharge → fracture → recovery", "duration": 3.0, "mods": []},
	{"id": "02-crown", "title": "STORM CROWN", "detail": "Seven shards gather, follow the caster and launch in sequence", "duration": 3.5, "mods": []},
	{"id": "03-cataclysm", "title": "CATACLYSM", "detail": "Committed ground mark → rupture → expanding rings → settling dust", "duration": 3.5, "mods": []},
	{"id": "04-fork-chain", "title": "FORK + CHAIN", "detail": "Three primary paths; bounded arcs connect nearby targets", "duration": 3.25, "mods": ["fork", "chain"]},
	{"id": "05-pierce-overload", "title": "PIERCE + OVERLOAD", "detail": "Three aligned victims; the third direct hit releases stored charge", "duration": 3.75, "mods": ["pierce", "overload"]},
	{"id": "06-gravity-aftershock", "title": "GRAVITY WELL + AFTERSHOCK", "detail": "The wind-up draws enemies inward; a delayed second rupture follows", "duration": 4.0, "mods": ["gravity", "aftershock"]},
	{"id": "07-empty-misses", "title": "THE EMPTY ARENA", "detail": "Lance, Crown and Cataclysm retain their form when every cast misses", "duration": 4.0, "mods": []},
]

class AimDriver extends Node:
	var override_aim := Vector3(0, 0, -3)

var game: Node3D
var driver: AimDriver
var overlay: CanvasLayer
var headline: Label
var detail: Label
var provenance: Label
var stage_index := -1
var stage_time := 0.0
var sequence_time := 0.0
var active := false
var finished := false
var rendered := false
var output := "res://work/visual-reel"
var triggered: Dictionary = {}
var stages: Array[Dictionary] = []
var current: Dictionary = {}
var captures_pending := 0
var capture_failures: Array[String] = []
var options: Dictionary = {}


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and "=" in argument:
			var pair := argument.trim_prefix("--").split("=", true, 1)
			options[pair[0]] = pair[1]
	output = str(options.get("reel-out", output))
	rendered = DisplayServer.get_name() != "headless"
	call_deferred("_setup")


func _setup() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	game = MAIN.instantiate()
	game.save_path = output.path_join("reel-preferences.json")
	game.run_seed = int(options.get("seed", 7331))
	root.add_child(game)
	await process_frame
	# Install only the existing narrow aim override after production initialization;
	# no scenario runner is launched and the production update methods remain active.
	driver = AimDriver.new()
	game.add_child(driver)
	game.test_driver = driver
	game.test_options["scenario"] = "visual_reel"
	game.ui.visible = false
	game.settings.shake = 0.30
	game.settings.reduced_flash = false
	game.settings.reduced_particles = false
	game._apply_settings()
	_build_labels()
	_start_stage(0)
	active = true


func _physics_process(delta: float) -> bool:
	if not active or finished:
		return false
	stage_time += delta
	sequence_time += delta
	_direct_stage()
	if stage_time >= float(SEGMENTS[stage_index].duration):
		_end_stage()
		if stage_index + 1 >= SEGMENTS.size():
			_finish.call_deferred()
			finished = true
		else:
			_start_stage(stage_index + 1)
	return false


func _start_stage(index: int) -> void:
	_release_input()
	paused = false
	game._clear_combat()
	game.sound.stop_effects()
	game.state = "lab"
	game.lab_mode = true
	game.health = 100.0
	game.charge = 100.0 if index in [2, 5, 6] else 0.0
	game.elapsed = 0.0
	game.wave_time = 0.0
	game.wave = 0
	game.kills = 0
	game.total_casts = 0
	game.modifiers.assign(SEGMENTS[index].mods)
	game.telemetry = {"direct_hits": 0, "secondary_hits": 0, "ultimate_spent": 0, "children_omitted": 0, "max_projectiles": 0, "deaths": 0, "waves_completed": 0, "boss_phase_two": false}
	game.player.position = Vector3(0, 0, 4.5)
	game.player.rotation = Vector3.ZERO
	game.motion_speed = 0.0
	game.camera_shake = 0.0
	game.banner = ""
	game.banner_timer = 0.0
	driver.override_aim = Vector3(0, 0, -3)
	game.aim = driver.override_aim
	game.art.animate_caster(game.caster, game.world_time, 0.0, 0.0, 0.0)
	stage_index = index
	stage_time = 0.0
	triggered.clear()
	headline.text = "%02d  /  %s" % [index + 1, SEGMENTS[index].title]
	detail.text = SEGMENTS[index].detail
	provenance.text = "STAGED LABORATORY  •  LIVE CASTS, COLLISION AND DAMAGE  •  %s" % ("REFILLED ULTIMATE CHARGE" if index in [2, 5, 6] else "STANDARD SPELL COOLDOWNS")
	match index:
		0:
			_fixture("shardling", Vector3(0, 0, -3))
		1:
			for i in range(6):
				var angle := i * TAU / 6.0
				_fixture("channeler" if i % 2 else "shardling", Vector3(cos(angle) * 3.5, 0, -2.2 + sin(angle) * 2.0))
		2:
			for i in range(7):
				var angle := i * TAU / 7.0
				_fixture("bulwark" if i % 3 == 0 else "shardling", Vector3(cos(angle) * 2.9, 0, -3 + sin(angle) * 2.6))
		3:
			for x in [-3.6, -1.8, 0.0, 1.8, 3.6]:
				_fixture("bulwark" if x == 0.0 else "channeler", Vector3(x, 0, -3))
			_fixture("shardling", Vector3(-3.7, 0, -0.6))
			_fixture("shardling", Vector3(3.7, 0, -0.6))
		4:
			for z in [1.0, -2.0, -5.0]:
				_fixture("bulwark", Vector3(0, 0, z))
			driver.override_aim = Vector3(0, 0, -7)
		5:
			for at in [Vector3(-4.5, 0, -3), Vector3(4.5, 0, -3), Vector3(0, 0, -7.5)]:
				_fixture("bulwark", at)
			_fixture("channeler", Vector3(-1.8, 0, -2))
			_fixture("channeler", Vector3(1.8, 0, -2))
		6:
			driver.override_aim = Vector3(0, 0, -5)
	game.aim = driver.override_aim
	current = {"id": SEGMENTS[index].id, "title": SEGMENTS[index].title, "start_seconds": sequence_time, "duration": SEGMENTS[index].duration, "modifiers": game.modifiers.duplicate(), "initial": game.snapshot().duplicate(true), "requests": [], "captures": [], "observations": []}
	print("REEL_STAGE " + str(SEGMENTS[index].id))


func _fixture(kind: String, at: Vector3) -> void:
	var enemy: Dictionary = game.spawn_enemy(kind, at)
	# These are the same stationary actors as the player-facing laboratory. Standard
	# HP/radius and real recoil/death remain intact; only the spawn delay is bypassed.
	enemy.state = "idle"
	enemy.timer = 0.0
	enemy.cooldown = 9999.0
	enemy.root.scale = enemy.base_scale
	enemy.root.rotation.y = PI
	game._clear_enemy_tell(enemy)


func _direct_stage() -> void:
	match stage_index:
		0:
			_cast_at("lance", 0.50, "first")
			_cast_at("lance", 1.25, "second")
			_cast_at("lance", 2.00, "third")
			_capture_at("charge", 0.57)
			_capture_at("discharge", 0.71)
			_capture_at("impact", 1.47)
			_capture_at("aftermath", 2.78)
		1:
			_cast_at("crown", 0.25)
			_move_window("move_right", 0.46, 0.73)
			_move_window("move_left", 0.91, 1.18)
			_capture_at("gather", 0.63)
			_capture_at("orbit-moving-caster", 1.02)
			_capture_at("volley", 1.64)
			_capture_at("fracture", 2.15)
			_capture_at("aftermath", 3.18)
		2:
			_cast_at("cataclysm", 0.50)
			_capture_at("mark", 0.91)
			_capture_at("rupture", 1.34)
			_capture_at("rings-and-debris", 1.77)
			_capture_at("aftermath", 3.21)
		3:
			_cast_at("lance", 0.50, "first")
			_cast_at("lance", 1.55, "second")
			_capture_at("three-paths-and-arcs", 0.72)
			_capture_at("second-cast", 1.77)
			_capture_at("aftermath", 2.95)
		4:
			_cast_at("lance", 0.35, "first")
			_cast_at("lance", 1.05, "second")
			_cast_at("lance", 1.75, "third")
			_capture_at("first-pierce", 0.57)
			_capture_at("second-charge", 1.27)
			_capture_at("third-hit-overload", 1.97)
			_capture_at("aftermath", 3.30)
		5:
			_cast_at("cataclysm", 0.50)
			_capture_at("gravity-pull", 0.99)
			_capture_at("first-rupture", 1.34)
			_capture_at("aftershock", 2.00)
			_capture_at("aftermath", 3.68)
		6:
			_cast_at("crown", 0.10)
			_cast_at("lance", 0.25, "first")
			_cast_at("cataclysm", 1.30)
			_cast_at("lance", 2.95, "second")
			_capture_at("lance-miss", 0.44)
			_capture_at("crown-empty-orbit", 0.77)
			_capture_at("crown-empty-volley", 1.47)
			_capture_at("cataclysm-miss", 2.15)
			_capture_at("no-victims-no-hits", 3.88)


func _once(key: String, time: float) -> bool:
	if stage_time < time or triggered.has(key):
		return false
	triggered[key] = true
	return true


func _cast_at(spell: String, time: float, suffix: String = "") -> void:
	if not _once("cast-" + spell + suffix, time):
		return
	game.aim = driver.override_aim
	var accepted := false
	match spell:
		"lance": accepted = game.request_lance()
		"crown": accepted = game.request_crown()
		"cataclysm": accepted = game.request_cataclysm()
	current.requests.append({"spell": spell, "at_seconds": stage_time, "accepted": accepted, "charge_after_request": game.charge})


func _move_window(action: String, start: float, end: float) -> void:
	if _once(action + "-press", start):
		Input.action_press(action)
	if _once(action + "-release", end):
		Input.action_release(action)


func _capture_at(phase: String, time: float) -> void:
	if not _once("capture-" + phase, time):
		return
	current.observations.append({"phase": phase, "stage_seconds": stage_time, "game": game.snapshot().duplicate(true)})
	if rendered:
		captures_pending += 1
		_capture.call_deferred(str(SEGMENTS[stage_index].id) + "-" + phase, current)


func _capture(label: String, record: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	var path := output.path_join(label + ".png")
	var result := root.get_texture().get_image().save_png(path)
	record.captures.append({"label": label, "path": path, "written": result == OK})
	if result != OK:
		capture_failures.append(label)
	captures_pending -= 1


func _end_stage() -> void:
	current.final = game.snapshot().duplicate(true)
	var stats: Dictionary = game.telemetry
	var all_requests_accepted := true
	for request in current.requests:
		all_requests_accepted = all_requests_accepted and bool(request.accepted)
	var outcome := false
	match stage_index:
		0: outcome = stats.direct_hits >= 3 and game.kills >= 1
		1: outcome = stats.direct_hits > 0 and game.crown_shards.is_empty()
		2: outcome = stats.ultimate_spent == 1 and stats.secondary_hits > 0
		3: outcome = stats.direct_hits >= 3 and stats.secondary_hits >= 2
		4: outcome = stats.direct_hits >= 9 and stats.secondary_hits >= 3
		5: outcome = stats.ultimate_spent == 1 and stats.secondary_hits >= 8
		6: outcome = stats.direct_hits == 0 and stats.secondary_hits == 0 and game.kills == 0 and stats.ultimate_spent == 1
	current.assertions = {"all_requests_accepted": all_requests_accepted, "intended_damage_observed": outcome}
	stages.append(current)


func _finish() -> void:
	_release_input()
	active = false
	while captures_pending > 0:
		await process_frame
	var passed := capture_failures.is_empty()
	for stage in stages:
		for check in stage.assertions.values():
			passed = passed and bool(check)
	var report := {
		"passed": passed, "rendered": rendered, "sequence_seconds": sequence_time,
		"scope": "Staged production laboratory spell requests, normal update loops, real collision/damage/recoil/death. Stationary target placement and ultimate refills are fixtures. Production HUD is hidden for this visual study. Does not prove normal-run progression, performance, UI layout or artistic quality.",
		"movie_fps_warning": "MovieWriter forces a fixed frame rate. Do not use this recording as performance evidence.",
		"seed": game.run_seed, "viewport": [root.size.x, root.size.y], "stages": stages,
		"capture_failures": capture_failures,
	}
	var file := FileAccess.open(output.path_join("reel-state.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
	else:
		passed = false
	print("VISUAL_REEL_RESULT " + JSON.stringify({"passed": passed, "rendered": rendered, "segments": stages.size(), "seconds": sequence_time, "capture_failures": capture_failures}))
	game.state = "verification_done"
	paused = false
	game._clear_combat()
	game.sound.shutdown()
	await process_frame
	await process_frame
	# MovieWriter can advance simulated time faster than native audio callbacks.
	# A short real wall-clock drain prevents a queued WAV playback surviving quit.
	if rendered:
		OS.delay_msec(220)
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if passed else 1)


func _release_input() -> void:
	for action in INPUTS:
		if InputMap.has_action(action):
			Input.action_release(action)


func _build_labels() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 80
	root.add_child(overlay)
	var layout := Control.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(layout)
	var eyebrow := Label.new()
	eyebrow.position = Vector2(38, 27)
	eyebrow.text = "STORMWRIGHT    /    IN-ENGINE MOTION STUDY"
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color("c1a66b"))
	layout.add_child(eyebrow)
	headline = Label.new()
	headline.position = Vector2(36, 48)
	headline.add_theme_font_size_override("font_size", 28)
	headline.add_theme_color_override("font_color", Color("e8f5ed"))
	layout.add_child(headline)
	detail = Label.new()
	detail.position = Vector2(38, 87)
	detail.add_theme_font_size_override("font_size", 15)
	detail.add_theme_color_override("font_color", Color("b2cad0"))
	layout.add_child(detail)
	provenance = Label.new()
	provenance.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	provenance.offset_left = 38
	provenance.offset_top = -35
	provenance.offset_right = 1100
	provenance.offset_bottom = -12
	provenance.add_theme_font_size_override("font_size", 11)
	provenance.add_theme_color_override("font_color", Color("98afb8"))
	layout.add_child(provenance)
	for label in [eyebrow, headline, detail, provenance]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
