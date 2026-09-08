extends SceneTree
## Native-play observation only. No scenario, replay, auto-aim, or combat mutation.
## F12 captures a viewport + alignment state; F11 flushes the bounded session log.

const Main = preload("res://scenes/main.tscn")

class ReviewObserver extends Node:
	const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "lance", "crown", "cataclysm", "dash", "pause_game"]
	const MAX_SECONDS := 1800.0
	const MAX_EVENTS := 60000
	const MAX_SAMPLES := 3601
	var game: Node3D
	var destination := ""
	var started := 0
	var recording := true
	var capture_pending := false
	var capture_count := 0
	var omitted_events := 0
	var last_sample := -0.5
	var last_motion := -1.0
	var events: Array[Dictionary] = []
	var samples: Array[Dictionary] = []
	var captures: Array[Dictionary] = []
	var action_states: Dictionary = {}
	var latest_state: Dictionary = {}
	var last_flush_reason := ""

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = 1000
		started = Time.get_ticks_usec()
		for action_name in ACTIONS:
			action_states[action_name] = Input.is_action_pressed(action_name)
		game.ui.action.connect(_ui_action)
		_record({"type":"observer_start", "actions":action_states.duplicate(), "display_server":DisplayServer.get_name()})
		print("MANUAL_REVIEW_READY " + JSON.stringify({"output":destination,"capture":"F12","flush":"F11","limit_minutes":30,"scenario_enabled":game.test_options.has("scenario")}))

	func _process(_delta: float) -> void:
		if not recording:
			return
		for action_name in ACTIONS:
			var pressed := Input.is_action_pressed(action_name)
			if pressed != bool(action_states[action_name]):
				action_states[action_name] = pressed
				_record({"type":"action_transition","action":action_name,"pressed":pressed,"strength":Input.get_action_strength(action_name)})
		var now := _time()
		if now - last_sample >= 0.5 and samples.size() < MAX_SAMPLES:
			latest_state = _observation()
			samples.append(latest_state.duplicate(true))
			last_sample = now
		if now >= MAX_SECONDS:
			_record({"type":"recording_limit","seconds":MAX_SECONDS})
			recording = false
			flush("30_minute_limit")
			print("MANUAL_REVIEW_LIMIT: observation stopped after 30 minutes; gameplay continues.")

	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_F12 or event.physical_keycode == KEY_F12:
				_record({"type":"capture_requested"})
				capture()
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_F11 or event.physical_keycode == KEY_F11:
				_record({"type":"flush_requested"})
				flush("F11")
				get_viewport().set_input_as_handled()
				return
		if not recording:
			return
		var entry: Dictionary = {}
		if event is InputEventMouseMotion:
			# Motion is sampled at up to 20 Hz; key/button transitions are not thinned.
			if _time() - last_motion < 0.05:
				return
			last_motion = _time()
			entry = {"type":"mouse_motion","position":_v2(event.position),"relative":_v2(event.relative),"buttons":event.button_mask}
		elif event is InputEventMouseButton:
			entry = {"type":"mouse_button","button":event.button_index,"pressed":event.pressed,"position":_v2(event.position),"double_click":event.double_click}
		elif event is InputEventKey:
			if event.echo:
				return
			entry = {"type":"key","keycode":event.keycode,"physical_keycode":event.physical_keycode,"pressed":event.pressed,"shift":event.shift_pressed,"ctrl":event.ctrl_pressed,"alt":event.alt_pressed,"meta":event.meta_pressed}
		elif event is InputEventAction:
			entry = {"type":"action_event","action":event.action,"pressed":event.pressed,"strength":event.strength}
		if entry.is_empty():
			return
		entry["device"] = event.device
		var matching: Array[String] = []
		for action_name in ACTIONS:
			if event.is_action(action_name):
				matching.append(action_name)
		if not matching.is_empty():
			entry["matched_actions"] = matching
		_record(entry)

	func _notification(what: int) -> void:
		if started == 0:
			return
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			_record({"type":"application_focus","focused":false})
		elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
			_record({"type":"application_focus","focused":true})
		elif what == NOTIFICATION_WM_CLOSE_REQUEST:
			_record({"type":"window_close_requested"})
			flush("window_close_requested")

	func _exit_tree() -> void:
		if not destination.is_empty() and started != 0:
			flush("exit_tree")

	func _ui_action(name_value: String, payload: Variant) -> void:
		_record({"type":"ui_action","action":name_value,"payload":payload})

	func capture() -> void:
		if capture_pending or not recording:
			return
		if DisplayServer.get_name() == "headless":
			_record({"type":"capture_unavailable","reason":"headless"})
			flush("headless_capture_request")
			return
		capture_pending = true
		await RenderingServer.frame_post_draw
		if not is_inside_tree():
			return
		capture_count += 1
		var stem := "capture-%04d" % capture_count
		var viewport := get_viewport()
		var picture := viewport.get_texture().get_image()
		var image_error := picture.save_png(destination.path_join(stem + ".png"))
		var observation := _observation()
		observation["image_size"] = [picture.get_width(), picture.get_height()]
		observation["image_file"] = stem + ".png"
		observation["image_error"] = image_error
		_write_json(destination.path_join(stem + ".json"), observation)
		captures.append({"t":_time(),"stem":stem,"image_error":image_error})
		_record({"type":"capture_complete","stem":stem,"image_error":image_error})
		capture_pending = false
		flush("F12")
		print("MANUAL_CAPTURE " + JSON.stringify({"file":destination.path_join(stem + ".png"),"image_error":image_error,"mouse":observation.get("mouse_viewport"),"aim_projected":observation.get("aim_projected_viewport")}))

	func flush(reason: String) -> void:
		last_flush_reason = reason
		var current := _observation() if is_inside_tree() else latest_state
		var result := {"recording":recording,"reason":reason,"elapsed_seconds":_time(),"bounds":{"seconds":MAX_SECONDS,"events":MAX_EVENTS,"samples":MAX_SAMPLES,"mouse_motion_hz":20},"omitted_events":omitted_events,"events":events,"samples":samples,"captures":captures,"latest":current,"notes":"Observation only. Mouse positions and projected aim are reported without modifying aim. Arena clamping and camera projection can explain a projected aim differing from the pointer. Focus behavior is production behavior; no scenario flag is active."}
		_write_json(destination.path_join("session.json"), result)
		print("MANUAL_FLUSH " + JSON.stringify({"reason":reason,"events":events.size(),"samples":samples.size(),"captures":captures.size(),"path":destination.path_join("session.json")}))

	func _observation() -> Dictionary:
		if not is_instance_valid(game) or not game.is_inside_tree() or not is_instance_valid(game.camera) or not game.camera.is_inside_tree():
			return latest_state.duplicate(true)
		var viewport := get_viewport()
		var window := get_window()
		var mouse := viewport.get_mouse_position()
		var aim_point: Vector3 = game.aim
		var projected: Vector2 = game.camera.unproject_position(aim_point)
		var ray_origin: Vector3 = game.camera.project_ray_origin(mouse)
		var ray_direction: Vector3 = game.camera.project_ray_normal(mouse)
		var raw_hit: Variant = null
		if absf(ray_direction.y) > 0.0001:
			raw_hit = ray_origin + ray_direction * (-ray_origin.y / ray_direction.y)
		var result := {"t":_time(),"physics_frame":Engine.get_physics_frames(),"process_frame":Engine.get_process_frames(),"paused":get_tree().paused,"focused":window.has_focus(),"game":game.snapshot().duplicate(true),"mouse_viewport":_v2(mouse),"aim_projected_viewport":_v2(projected),"aim_minus_mouse_viewport":_v2(projected-mouse),"viewport_size":_v2(viewport.get_visible_rect().size),"render_target_size":_v2(viewport.get_texture().get_size()),"window_size":_v2(DisplayServer.window_get_size()),"window_position":_v2(DisplayServer.window_get_position()),"screen_mouse_position":_v2(DisplayServer.mouse_get_position()),"content_scale_size":_v2(window.content_scale_size),"content_scale_factor":window.content_scale_factor,"viewport_stretch_transform":_transform(viewport.get_stretch_transform()),"viewport_screen_transform":_transform(viewport.get_screen_transform()),"game_aim":_v3(aim_point),"player":_v3(game.player.global_position),"camera_position":_v3(game.camera.global_position),"camera_rotation":_v3(game.camera.global_rotation),"input_armed":game.input_armed}
		if raw_hit != null:
			result["pointer_ground_intersection"] = _v3(raw_hit)
			result["aim_distance_from_pointer_ground"] = aim_point.distance_to(raw_hit)
		return result

	func _record(entry: Dictionary) -> void:
		if not recording:
			return
		if events.size() >= MAX_EVENTS:
			omitted_events += 1
			return
		entry["t"] = _time()
		events.append(entry.duplicate(true))

	func _time() -> float:
		return float(Time.get_ticks_usec() - started) / 1000000.0

	func _write_json(path: String, data: Dictionary) -> void:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("Cannot write manual review evidence: " + path)
			return
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

	func _v2(value: Vector2) -> Array:
		return [value.x, value.y]

	func _v3(value: Vector3) -> Array:
		return [value.x, value.y, value.z]

	func _transform(value: Transform2D) -> Array:
		return [value.x.x, value.x.y, value.y.x, value.y.y, value.origin.x, value.origin.y]

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var output := ProjectSettings.globalize_path("res://work/manual-review")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scenario"):
			printerr("manual_review.gd refuses --scenario; use genuine native input.")
			quit(2)
			return
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
			if not output.is_absolute_path():
				printerr("manual_review.gd --output must be an absolute directory.")
				quit(2)
				return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		printerr("Cannot create manual review output directory: " + output)
		quit(2)
		return
	var game: Node3D = Main.instantiate()
	root.add_child(game)
	current_scene = game
	var observer := ReviewObserver.new()
	observer.game = game
	observer.destination = output
	root.add_child(observer)
