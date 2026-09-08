extends Node3D
## Development instrumentation only: geometry, input, collision and capture.

var probe: CharacterBody3D
var status_label: Label
var tick: int = 0
var mode: String = "interactive"
var output_dir: String = ""
var seed_value: int = 73
var initial_position := Vector3(-3.0, 0.5, 0.0)
var completed: bool = false
var checks: Dictionary = {}
var history: Array[Dictionary] = []

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--output="):
			output_dir = argument.trim_prefix("--output=")
		elif argument.begins_with("--seed="):
			seed_value = int(argument.trim_prefix("--seed="))
	seed(seed_value)
	for binding in [["probe_left", KEY_A], ["probe_right", KEY_D], ["probe_up", KEY_W], ["probe_down", KEY_S]]:
		InputMap.add_action(binding[0])
		var event := InputEventKey.new()
		event.physical_keycode = binding[1]
		InputMap.action_add_event(binding[0], event)
	build_scene()
	print("DEV_READY " + JSON.stringify({"mode": mode, "seed": seed_value, "renderer": RenderingServer.get_current_rendering_method()}))
	if mode != "interactive":
		Input.action_press("probe_right")

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
	return result

func box(parent: Node3D, size: Vector3, position_value: Vector3, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = material(color)
	mesh_node.position = position_value
	parent.add_child(mesh_node)
	return mesh_node

func build_scene() -> void:
	box(self, Vector3(14, 0.2, 10), Vector3(0, -0.1, 0), Color("1b2a3a"))
	for x in range(-7, 8):
		box(self, Vector3(0.018, 0.01, 10), Vector3(x, 0.01, 0), Color("344a5d"))
	for z in range(-5, 6):
		box(self, Vector3(14, 0.01, 0.018), Vector3(0, 0.01, z), Color("344a5d"))
	var wall := StaticBody3D.new()
	wall.name = "CollisionWall"
	wall.position = Vector3(1, 0.5, 0)
	add_child(wall)
	box(wall, Vector3(1, 1, 3), Vector3.ZERO, Color("ed8d6d"))
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(1, 1, 3)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	probe = CharacterBody3D.new()
	probe.name = "InputProbe"
	probe.position = initial_position
	probe.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(probe)
	box(probe, Vector3(0.7, 0.7, 0.7), Vector3.ZERO, Color("69ead5"))
	var probe_shape := CollisionShape3D.new()
	var probe_box := BoxShape3D.new()
	probe_box.size = Vector3(0.7, 0.7, 0.7)
	probe_shape.shape = probe_box
	probe.add_child(probe_shape)
	for index in range(4):
		var height := randf_range(0.4, 1.2)
		box(self, Vector3(0.6, height, 0.6), Vector3(-4.5 + index * 1.1, height / 2, -3), Color("7786a0"))
	var camera := Camera3D.new()
	camera.position = Vector3(10, 12, 14)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, -25, 0)
	light.light_energy = 1.3
	light.shadow_enabled = true
	add_child(light)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("091321")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("abc1da")
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.position = Vector2(36, 24)
	title.text = "GODOT / DEVELOPMENT PLAYGROUND"
	title.add_theme_font_size_override("font_size", 27)
	ui.add_child(title)
	var subtitle := Label.new()
	subtitle.position = Vector2(36, 63)
	subtitle.text = "Diagnostic scene • Input / Collision / Rendering / Telemetry • No game implementation"
	subtitle.add_theme_color_override("font_color", Color("9db4c7"))
	ui.add_child(subtitle)
	status_label = Label.new()
	status_label.position = Vector2(36, 615)
	status_label.add_theme_font_size_override("font_size", 20)
	ui.add_child(status_label)
	var hint := Label.new()
	hint.position = Vector2(36, 665)
	hint.text = "WASD move probe     R reset     F12 capture + state     Esc close"
	hint.add_theme_color_override("font_color", Color("9db4c7"))
	ui.add_child(hint)

func _physics_process(_delta: float) -> void:
	if completed:
		return
	tick += 1
	var direction := Input.get_vector("probe_left", "probe_right", "probe_up", "probe_down")
	probe.velocity = Vector3(direction.x, 0, direction.y) * 3.0
	probe.move_and_slide()
	status_label.text = "SEED %d     FRAME %d     PROBE (%.2f, %.2f)     MODE %s" % [seed_value, tick, probe.position.x, probe.position.z, mode.to_upper()]
	if mode == "interactive":
		return
	if tick == 20:
		checks["input_moves_probe"] = probe.position.x > initial_position.x + 0.5
		history.append({"frame": tick, "x": probe.position.x})
	if tick == 120:
		checks["wall_blocks_probe"] = probe.position.x > -0.1 and probe.position.x < 0.2 and probe.get_slide_collision_count() > 0
		history.append({"frame": tick, "x": probe.position.x})
		Input.action_release("probe_right")
		Input.action_press("probe_left")
	if tick == 140:
		checks["input_reverses_probe"] = probe.position.x < -0.5
		Input.action_release("probe_left")
		probe.position = initial_position
		probe.velocity = Vector3.ZERO
	if tick == 145:
		checks["reset_restores_position"] = probe.position.is_equal_approx(initial_position)
		completed = true
		finish.call_deferred()

func snapshot() -> Dictionary:
	return {"seed": seed_value, "frame": tick, "mode": mode, "probe_position": [probe.position.x, probe.position.y, probe.position.z], "checks": checks, "history": history, "renderer": RenderingServer.get_current_rendering_method(), "fps": Engine.get_frames_per_second(), "node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "physics_seconds": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)}

func write_state(filename: String) -> bool:
	var file := FileAccess.open(output_dir.path_join(filename), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write diagnostic state: " + output_dir)
		return false
	file.store_string(JSON.stringify(snapshot(), "\t"))
	return true

func capture(filename: String) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	return picture.save_png(output_dir.path_join(filename)) == OK

func finish() -> void:
	if mode == "capture":
		checks["screenshot_saved"] = await capture("playground.png")
	var passed := true
	for value in checks.values():
		passed = passed and bool(value)
	passed = write_state("state.json") and passed
	print("DEV_RESULT " + JSON.stringify({"passed": passed, "checks": checks}))
	get_tree().quit(0 if passed else 1)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_tree().quit()
	elif event.keycode == KEY_R:
		probe.position = initial_position
	elif event.keycode == KEY_F12 and not output_dir.is_empty():
		var saved := await capture("manual.png")
		write_state("manual-state.json")
		print("DEV_CAPTURE " + str(saved))
