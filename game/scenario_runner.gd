extends Node
## Development-only, bounded scenarios through the production game interface.

var game: Node3D
var options: Dictionary
var scenario := "lance"
var output := ""
var elapsed := 0.0
var wall_start := 0
var frame_start := 0
var monitor_samples: Array[Dictionary] = []
var frame_spikes: Array[Dictionary] = []
var frame_times: Array[float] = []
var override_aim: Variant = Vector3(0,0,-3)
var fired: Dictionary = {}
var checks: Dictionary = {}
var finished := false
var rendered := false
var initial_direct := 0
var last_wave := 0
var upgrade_wait_until := 0.0
var samples: Array[Dictionary] = []
var final_result: Dictionary = {}

func begin(host: Node3D, config: Dictionary) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = host
	options = config
	scenario = str(options.get("scenario","lance"))
	output = str(options.get("output",""))
	rendered = DisplayServer.get_name() != "headless"
	if output.is_empty():
		push_error("Scenario needs --output=<directory>")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	wall_start = Time.get_ticks_usec()
	frame_start = wall_start
	if scenario in ["run","performance","boss","boss_performance"]:
		game.start_run(false)
		if scenario == "performance":
			game.spawn_queue.clear()
			game.modifiers.assign(["fork","chain","resonance"])
			for index in range(24):
				var angle := index*TAU/24.0
				var enemy: Dictionary = game.spawn_enemy(["shardling","channeler","bulwark"][index%3],Vector3(cos(angle)*9,0,sin(angle)*9))
				enemy.hp = 100000
				enemy.max_hp = enemy.hp
			game.health = 100000
		elif scenario in ["boss","boss_performance"]:
			game._clear_combat()
			game.wave = 5
			game._start_wave()
			game.modifiers.assign(["pierce","chain","aftershock"])
			if scenario == "boss_performance":
				game.spawn_queue.clear()
				var guardian: Dictionary = game.spawn_enemy("warden",Vector3(0,0,-4))
				guardian.hp = 100000
				guardian.max_hp = guardian.hp
				game.health = 100000
	else:
		game.start_run(true)
		game._clear_combat()
		game.ui.show_screen("hud")
		game.player.position = Vector3(0,0,5)
		for index in range(5):
			var enemy: Dictionary = game.spawn_enemy(["shardling","bulwark","channeler"][index%3],Vector3((index%3-1)*2.8,0,-1.0-float(index/3)*3.0))
			enemy.hp = 1200
			enemy.max_hp = 1200
		game.charge = 100
		if scenario == "cataclysm": game.modifiers.assign(["gravity","aftershock"])
		if scenario == "crown": game.modifiers.assign(["resonance"])
		if scenario == "combinations": game.modifiers.assign(["fork","chain","overload"])
	print("SCENARIO_BEGIN " + scenario)

func _process(delta: float) -> void:
	if game == null or finished: return
	elapsed += delta
	var now := Time.get_ticks_usec()
	var raw_frame_ms := (now-frame_start)/1000.0
	frame_start = now
	var wall_elapsed := (now-wall_start)/1000000.0
	if wall_elapsed > 5.0 and not get_tree().paused:
		frame_times.append(raw_frame_ms)
		if raw_frame_ms > 20.0:
			frame_spikes.append({"wall_seconds":wall_elapsed,"frame_ms":raw_frame_ms,"fx":game.fx.get_budget_state(),"casts":game.total_casts,"ultimate_spent":game.telemetry.ultimate_spent})
	if scenario in ["run","performance","boss","boss_performance"]:
		_bot(delta)
		if scenario == "run" and game.wave_time >= 5.0 and _once("wave_capture_"+str(game.wave),0):
			_capture("wave-%02d-combat" % game.wave)
		if scenario in ["performance","boss_performance"]:
			if _once("phase2",25.0) and scenario == "boss_performance":
				for enemy in game.enemies:
					if enemy.kind == "warden": enemy.hp = enemy.max_hp*0.49
			if _once("warmup_ultimate",3.0) or _once("ultimate1",7.0) or _once("ultimate2",25.0) or _once("ultimate3",45.0):
				game.charge = 100
				game.request_cataclysm()
			if monitor_samples.is_empty() or wall_elapsed-float(monitor_samples.back().time) >= 2.0:
				monitor_samples.append({"time":wall_elapsed,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"nodes":get_tree().get_node_count(),"fx":game.fx.get_budget_state(),"projectiles":game.projectiles.size(),"enemies":game.enemies.size()})
			if wall_elapsed > 65.0:
				checks["population_24" if scenario == "performance" else "guardian_two_phases"] = game.enemies.size() == 24 if scenario == "performance" else game.telemetry.boss_phase_two
				checks["at_least_two_ultimates"] = game.telemetry.ultimate_spent >= 2
				checks["rendered_realtime"] = rendered and not "--fixed-fps" in OS.get_cmdline_args() and not "--write-movie" in OS.get_cmdline_args()
				checks["sixty_seconds_after_warmup"] = wall_elapsed >= 65.0
				_capture("combat-after-measurement")
				_finish()
		elif game.state in ["victory","defeat"]:
			checks["victory"] = game.state == "victory"
			checks["phase_two"] = game.telemetry.boss_phase_two
			if scenario == "run": checks["six_waves"] = game.telemetry.waves_completed == 6
			_capture("result")
			_finish()
		elif elapsed > 1100:
			checks["finished_in_time"] = false
			_finish()
		return
	match scenario:
		"lance":
			if _once("cast",1.0):
				override_aim = game.enemies[1].root.position
				game.request_lance()
			if _once("charge",1.07): _capture("01-charge")
			if _once("release",1.20): _capture("02-release")
			if _once("decay",1.65): _capture("03-aftermath")
			if _once("hit_check",1.9):
				checks["lance_hits"] = game.telemetry.direct_hits > 0
				initial_direct = game.telemetry.direct_hits
				override_aim = Vector3(10,0,7)
			if _once("miss",2.0): game.request_lance()
			if _once("miss_frame",2.2): _capture("04-miss")
			if elapsed > 3.0:
				checks["miss_does_not_damage"] = game.telemetry.direct_hits == initial_direct
				_finish()
		"crown":
			if _once("cast",1.0): game.request_crown()
			if _once("gather",1.25): _capture("01-gather")
			if _once("orbit",1.8): _capture("02-orbit")
			if _once("volley",2.4): _capture("03-volley")
			if elapsed > 5.0:
				checks["crown_hits"] = game.telemetry.direct_hits > 0
				checks["shards_released"] = game.crown_shards.is_empty()
				checks["cooldown_active"] = game.crown_cd > 0
				_finish()
		"cataclysm":
			if _once("cast",1.0):
				override_aim = Vector3(0,0,-2)
				game.aim = override_aim
				game.request_cataclysm()
			if _once("mark",1.4): _capture("01-mark")
			if _once("rupture",1.82): _capture("02-rupture")
			if _once("echo",2.5): _capture("03-echo")
			if elapsed > 4.0:
				checks["ultimate_spent_once"] = game.telemetry.ultimate_spent == 1 and game.charge == 0
				checks["area_damage"] = game.telemetry.secondary_hits >= 2
				checks["events_cleaned"] = game.pending.is_empty()
				_finish()
		"combinations":
			if elapsed > 1 and elapsed < 5:
				override_aim = game.enemies[1].root.position
				game.aim = override_aim
				game.request_lance()
			if _once("crown",1.2): game.request_crown()
			if _once("first",2.4): _capture("01-fork-chain")
			if _once("replace",5.0):
				checks["chain_and_overload_secondary_hits"] = game.telemetry.secondary_hits > 0
				game.modifiers.assign(["pierce","overload","echo"])
			if elapsed > 5.5 and elapsed < 9:
				game.request_lance()
			if _once("second",6.9): _capture("02-pierce-overload")
			if elapsed > 12:
				checks["projectiles_cleaned"] = game.projectiles.is_empty() and game.crown_shards.is_empty()
				checks["children_bounded"] = game.telemetry.max_projectiles <= 128
				_finish()
		"flow":
			_flow()
		_:
			checks["known_scenario"] = false
			_finish()

func _once(id: String, at: float) -> bool:
	if not fired.has(id) and elapsed >= at:
		fired[id] = true
		return true
	return false

func _bot(_delta: float) -> void:
	if game.state == "upgrade":
		if upgrade_wait_until == 0.0:
			upgrade_wait_until = elapsed+0.6
			_capture("upgrade-%02d" % game.wave)
			return
		if elapsed < upgrade_wait_until: return
		upgrade_wait_until = 0.0
		var priority := ["chain","overload","pierce","fork","aftershock","resonance","echo","gravity"]
		var selected: String = game.choices[0]
		for id in priority:
			if id in game.choices:
				selected = id
				break
		if game.modifiers.size() < 3:
			game._on_action("choose_modifier",selected)
		else:
			game._on_action("skip",null)
		return
	if game.state != "run": return
	if game.wave != last_wave:
		last_wave = game.wave
		samples.append(game.snapshot())
		print("SCENARIO_WAVE " + str(last_wave))
	var live: Array[Dictionary] = game._nearest_enemies(game.player.position,40)
	if live.is_empty():
		Input.action_release("lance")
		return
	var target: Dictionary = live[0]
	override_aim = target.root.position
	game.aim = override_aim
	var radial: Vector3 = game.player.position.normalized()
	var tangent := Vector3(-radial.z,0,radial.x)
	if radial.length_squared() < 0.1: tangent = Vector3.RIGHT
	var move: Vector3 = tangent
	var distance: float = game.player.position.distance_to(target.root.position)
	if distance < 4.5:
		move += (game.player.position-target.root.position).normalized()*1.7
	if game.player.position.length() > 9.0:
		move -= radial*1.5
	if distance > 11:
		move += (target.root.position-game.player.position).normalized()
	move = move.normalized()
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
	if move.x < -0.2: Input.action_press("move_left",absf(move.x))
	if move.x > 0.2: Input.action_press("move_right",absf(move.x))
	if move.z < -0.2: Input.action_press("move_up",absf(move.z))
	if move.z > 0.2: Input.action_press("move_down",absf(move.z))
	game.input_armed = true
	Input.action_press("lance")
	if game.crown_cd <= 0: game.request_crown()
	if game.charge >= 100: game.request_cataclysm()
	for enemy in live:
		if enemy.state == "windup" and game.player.position.distance_to(enemy.target) < 3.3 and enemy.timer < 0.25:
			game.request_dash(move)
	if distance < 1.7: game.request_dash(move)

func _flow() -> void:
	if _once("movement",1.0): Input.action_press("move_right")
	if _once("movement_check",1.3):
		Input.action_release("move_right")
		checks["input_moves_player"] = game.player.position.x > 0.8
		game.request_dash(Vector3.ZERO)
		checks["stationary_dash"] = game.dash_time > 0
	if _once("pause",1.6):
		game._pause()
		samples.append(game.snapshot())
	if _once("pause_check",2.0):
		checks["pause_freezes_combat"] = is_equal_approx(game.elapsed,float(samples[0].elapsed))
		game._resume()
	if _once("modifiers",2.3):
		for id in ["fork","chain","echo"]: game._on_action("lab_modifier",id)
		checks["three_slots"] = game.modifiers.size() == 3
		game._on_action("lab_modifier","pierce")
		checks["fourth_rejected"] = game.modifiers.size() == 3
		game._on_action("lab_modifier","echo")
		checks["remove_modifier"] = not "echo" in game.modifiers
		game.health = 30
		game.charge = 0
		game._on_action("lab_refill",null)
		checks["refill"] = game.health == 100 and game.charge == 100
		game._on_action("setting",{"key":"shake","value":0.2})
	if _once("defeat",2.8):
		game.invulnerable = 0
		game._damage_player(500)
		checks["defeat"] = game.state == "defeat"
		game._on_action("restart",null)
		checks["restart_clean"] = game.health == 100 and game.kills == 0 and game.modifiers.is_empty()
	if elapsed > 3.5:
		_finish()

func _capture(name: String) -> void:
	samples.append({"label":name,"game":game.snapshot()})
	if not rendered: return
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var result := picture.save_png(output.path_join(name+".png"))
	if result != OK: checks["capture_"+name] = false

func _finish() -> void:
	if finished: return
	finished = true
	for action in ["lance","move_left","move_right","move_up","move_down"]: Input.action_release(action)
	var passed := true
	for value in checks.values(): passed = passed and bool(value)
	frame_times.sort()
	var performance := {"frames":frame_times.size(),"median_ms":0.0,"p95_ms":0.0,"p99_ms":0.0,"max_ms":0.0,"frames_over_20ms":0,"wall_seconds":(Time.get_ticks_usec()-wall_start)/1000000.0,"renderer":RenderingServer.get_current_rendering_method(),"window_size":str(DisplayServer.window_get_size()),"viewport_size":str(get_viewport().get_visible_rect().size),"settings":game.settings.duplicate(),"measurement":"monotonic wall-clock intervals after 5s warmup; recording/fixed-FPS runs are not performance evidence","monitor_samples":monitor_samples}
	if not frame_times.is_empty():
		performance.median_ms = frame_times[frame_times.size()/2]
		performance.p95_ms = frame_times[mini(frame_times.size()-1,int(frame_times.size()*0.95))]
		performance.p99_ms = frame_times[mini(frame_times.size()-1,int(frame_times.size()*0.99))]
		performance.max_ms = frame_times.back()
		performance.frames_over_20ms = frame_times.filter(func(ms): return ms>20.0).size()
	final_result = {"scenario":scenario,"passed":passed,"checks":checks,"game":game.snapshot(),"samples":samples,"performance":performance,"rendered":rendered}
	performance.frame_spikes = frame_spikes
	var file := FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(final_result,"\t"))
	print("SCENARIO_RESULT " + JSON.stringify({"scenario":scenario,"passed":passed,"checks":checks,"performance":performance}))
	game.state = "verification_done"
	get_tree().paused = false
	game._clear_combat()
	game.sound.shutdown()
	# Drain audio callbacks and pending post-draw captures before engine teardown.
	await get_tree().create_timer(0.2,true,false,true).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if passed else 1)
