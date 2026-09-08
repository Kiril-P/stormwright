extends SceneTree
## Application-level, agent-directed review. Each file command is one explicit,
## bounded input chunk. There is no bot, auto-aim, target selection, or stat boost.
## Example launch:
## godot --path . --script res://game/guided_review.gd -- --review-dir=/absolute/repo/work/review
## Commands are atomically written to <review-dir>/command.json with increasing id.

const Main = preload("res://scenes/main.tscn")
const Catalog = preload("res://game/modifier_catalog.gd")
const HELD_ACTIONS := ["move_left","move_right","move_up","move_down","lance","crown","cataclysm","dash"]
const UI_ACTIONS := ["start","lab","pause","resume","restart","title","settings","back","choose_modifier","replace_modifier","skip","lab_modifier","lab_refill","lab_reset","confirm","cancel","setting","quit"]

class FixedAim extends Node:
	var override_aim := Vector3(0,0,-5)

var game: Node3D
var fixed_aim: FixedAim
var review_directory := ""
var mode := "normal"
var boss_modifiers: Array[String] = ["pierce","chain","aftershock"]
var rendered := false
var ready_for_commands := false
var capturing := false
var running_chunk := false
var pending_inputs := false
var release_one_shots_at := -1
var apply_inputs_at := -1
var last_id := -1
var elapsed := 0.0
var poll_clock := 0.0
var duration := 0.1
var command: Dictionary = {}
var input_events: Array[Dictionary] = []
var quit_after_capture := false
var chunk_started_usec := 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--review-dir="):
			review_directory = argument.trim_prefix("--review-dir=").simplify_path()
		elif argument.begins_with("--review-mode="):
			mode = argument.trim_prefix("--review-mode=")
		elif argument.begins_with("--review-mods="):
			boss_modifiers.assign(argument.trim_prefix("--review-mods=").split(",",false))
	var project_root := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")+"/"
	if not review_directory.is_absolute_path() or not review_directory.begins_with(project_root):
		printerr("GUIDED_REVIEW requires --review-dir=<absolute directory inside this repository>.")
		quit(2)
		return
	if mode not in ["normal","boss"]:
		printerr("GUIDED_REVIEW --review-mode must be normal or boss.")
		quit(2)
		return
	if mode == "boss":
		var unique: Array[String] = []
		for id in boss_modifiers:
			if not Catalog.valid_id(id) or id in unique:
				printerr("GUIDED_REVIEW boss fixture requires three distinct valid --review-mods IDs.")
				quit(2)
				return
			unique.append(id)
		if unique.size() != 3:
			printerr("GUIDED_REVIEW boss fixture requires exactly three modifiers.")
			quit(2)
			return
	DirAccess.make_dir_recursive_absolute(review_directory.path_join("chunks"))
	var old_status := review_directory.path_join("status.json")
	if FileAccess.file_exists(old_status):
		var old_file := FileAccess.open(old_status,FileAccess.READ)
		if old_file:
			var old: Variant = JSON.parse_string(old_file.get_as_text())
			if old is Dictionary:
				last_id = int(old.get("last_command_id",old.get("id",-1)))
	rendered = DisplayServer.get_name() != "headless"
	_setup.call_deferred()

func _setup() -> void:
	game = Main.instantiate()
	game.save_path = review_directory.path_join("preferences.json")
	root.add_child(game)
	fixed_aim = FixedAim.new()
	game.add_child(fixed_aim)
	# Reuse the game's existing development aim adapter, with a fixed manually
	# supplied point. No autonomous scenario driver is instantiated.
	game.test_options["scenario"] = "guided_review"
	game.test_driver = fixed_aim
	if mode == "boss":
		game.start_run(false)
		game._clear_combat()
		game.wave = 5
		game._start_wave()
		game.spawn_queue.clear()
		game.spawn_enemy("warden",Vector3(0,0,-5))
		game.modifiers.assign(boss_modifiers)
	paused = true
	_release_inputs()
	await process_frame
	await process_frame
	await _capture(-1,"initial")
	ready_for_commands = true
	print("GUIDED_REVIEW_READY "+JSON.stringify({"directory":review_directory,"mode":mode,"rendered":rendered,"command_file":review_directory.path_join("command.json")}))

func _process(delta: float) -> bool:
	if not ready_for_commands or not is_instance_valid(game) or capturing:
		return false
	if running_chunk:
		if pending_inputs and Engine.get_physics_frames() >= apply_inputs_at:
			_apply_inputs()
		if release_one_shots_at >= 0 and Engine.get_physics_frames() >= release_one_shots_at:
			for action in ["crown","cataclysm","dash"]:
				Input.action_release(action)
			release_one_shots_at = -1
			_log_input("release_one_shots",{})
		if not pending_inputs:
			elapsed += delta
		# A production menu transition ends the input chunk early so the next
		# decision can use the actual upgrade/result screen immediately.
		if elapsed >= duration or game.state in ["upgrade","victory","defeat"] or Time.get_ticks_usec()-chunk_started_usec > 10000000:
			_finish_chunk.call_deferred()
			running_chunk = false
		return false
	poll_clock += delta
	if poll_clock >= 0.1:
		poll_clock = 0.0
		_poll_command()
	return false

func _poll_command() -> void:
	var path := review_directory.path_join("command.json")
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("id") is float and not parsed.get("id") is int:
		return
	var id := int(parsed.id)
	if float(id) != float(parsed.id) or id <= last_id:
		return
	last_id = id
	var error := _validate_command(parsed)
	if not error.is_empty():
		_write_json(review_directory.path_join("command-error.json"),{"id":id,"error":error})
		print("GUIDED_REVIEW_COMMAND_REJECTED "+JSON.stringify({"id":id,"error":error}))
		return
	_start_chunk(parsed)

func _validate_command(value: Dictionary) -> String:
	for key in value:
		if str(key) not in ["id","duration","move","hold_lance","crown","cat","dash","aim","ui_action","payload"]:
			return "Unknown command field: "+str(key)
	if value.has("duration") and not (value.duration is float or value.duration is int):
		return "duration must be numeric"
	if value.has("duration") and (not is_finite(float(value.duration)) or float(value.duration) < 0.1 or float(value.duration) > 6.0):
		return "duration must be between 0.1 and 6 seconds"
	for key in ["move","aim"]:
		if not value.has(key):
			continue
		if not value[key] is Array or value[key].size() != 2:
			return key+" must be [x,z]"
		for number in value[key]:
			if not (number is float or number is int) or not is_finite(float(number)):
				return key+" must contain finite numbers"
	for key in ["hold_lance","crown","cat","dash"]:
		if value.has(key) and not value[key] is bool:
			return key+" must be boolean"
	var action := str(value.get("ui_action",""))
	if action in ["start_run","start_lab"]:
		action = "start" if action == "start_run" else "lab"
	if not action.is_empty() and action not in UI_ACTIONS:
		return "Unsupported production UI action: "+action
	return ""

func _start_chunk(value: Dictionary) -> void:
	command = value.duplicate(true)
	input_events.clear()
	_release_inputs()
	quit_after_capture = false
	elapsed = 0.0
	duration = float(command.get("duration",0.1))
	chunk_started_usec = Time.get_ticks_usec()
	if command.has("aim"):
		fixed_aim.override_aim = game._clamp_arena(Vector3(float(command.aim[0]),0,float(command.aim[1])),game.ARENA_RADIUS)
	game.aim = fixed_aim.override_aim
	var action := str(command.get("ui_action",""))
	if action == "start_run": action = "start"
	if action == "start_lab": action = "lab"
	if action == "quit":
		quit_after_capture = true
	elif not action.is_empty():
		game._on_action(action,command.get("payload"))
		_log_input("production_ui_action",{"action":action,"payload":command.get("payload")})
	# Review holds are distinct from in-game pause/settings screens. Only an
	# active run/laboratory resumes automatically between bounded chunks.
	if game.state in ["run","lab"]:
		paused = false
		pending_inputs = true
		apply_inputs_at = Engine.get_physics_frames()+2
	else:
		pending_inputs = false
		_log_input("menu_chunk",{"state":game.state})
	running_chunk = true
	_log_input("begin",{"state":game.state,"duration":duration,"aim":[fixed_aim.override_aim.x,fixed_aim.override_aim.z]})
	print("GUIDED_REVIEW_CHUNK_BEGIN "+str(command.id))

func _apply_inputs() -> void:
	pending_inputs = false
	var raw: Array = command.get("move",[0,0])
	var movement := Vector2(float(raw[0]),float(raw[1])).limit_length(1.0)
	if movement.x < 0: Input.action_press("move_left",-movement.x)
	if movement.x > 0: Input.action_press("move_right",movement.x)
	if movement.y < 0: Input.action_press("move_up",-movement.y)
	if movement.y > 0: Input.action_press("move_down",movement.y)
	if bool(command.get("hold_lance",false)):
		Input.action_press("lance")
	var one_shots: Array[String] = []
	for pair in [["crown","crown"],["cat","cataclysm"],["dash","dash"]]:
		if bool(command.get(pair[0],false)):
			Input.action_press(pair[1])
			one_shots.append(pair[1])
	release_one_shots_at = Engine.get_physics_frames()+2
	_log_input("named_inputs",{"movement":[movement.x,movement.y],"lance":bool(command.get("hold_lance",false)),"one_shots":one_shots})

func _finish_chunk() -> void:
	_release_inputs()
	pending_inputs = false
	release_one_shots_at = -1
	paused = true
	_log_input("end",{"state":game.state,"elapsed":elapsed})
	await _capture(int(command.id),"chunk")
	print("GUIDED_REVIEW_CHUNK_END "+JSON.stringify({"id":command.id,"state":game.state,"snapshot":_chunk_base(int(command.id))+".json","png":_chunk_base(int(command.id))+".png" if rendered else ""}))
	if quit_after_capture:
		game.state = "verification_done"
		game._clear_combat()
		paused = false
		game.queue_free()
		await process_frame
		await process_frame
		quit()

func _release_inputs() -> void:
	for action in HELD_ACTIONS:
		Input.action_release(action)

func _log_input(kind: String, data: Dictionary) -> void:
	input_events.append({"event":kind,"at_seconds":elapsed,"physics_frame":Engine.get_physics_frames(),"data":data.duplicate(true)})

func _chunk_base(id: int) -> String:
	return review_directory.path_join("initial" if id < 0 else "chunks/%06d" % id)

func _capture(id: int, label: String) -> void:
	capturing = true
	var base := _chunk_base(id)
	if rendered:
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png(base+".png")
		if result != OK:
			printerr("GUIDED_REVIEW_CAPTURE_ERROR "+str(result))
	var detail: Dictionary = game.snapshot()
	var actor_details: Array[Dictionary] = []
	for e in game.enemies:
		actor_details.append({"id":e.id,"kind":e.kind,"hp":e.hp,"state":e.state,"phase":e.phase,"position":[e.root.position.x,e.root.position.z],"attack":e.attack,"attack_target":[e.target.x,e.target.z],"attack_origin":str(e.get("attack_origin",e.root.position)),"attack_direction":str(e.get("attack_direction",Vector3.ZERO)),"timer":e.timer,"cooldown":e.cooldown})
	var hazard_details: Array[Dictionary] = []
	for hazard in game.hazards:
		hazard_details.append({"origin":str(hazard.at),"radius":hazard.age*6.0,"age":hazard.age,"already_hit":hazard.hit})
	detail["enemy_details"] = actor_details
	detail["hazard_details"] = hazard_details
	detail["crown_cooldown"] = game.crown_cd
	detail["dash_cooldown"] = game.dash_cd
	detail["lance_cooldown"] = game.lance_cd
	detail["aim"] = [fixed_aim.override_aim.x,fixed_aim.override_aim.z]
	detail["choices"] = game.choices.duplicate()
	detail["pending_modifier"] = game.pending_modifier
	detail["spawn_queue"] = game.spawn_queue.duplicate(true)
	var report := {"id":id,"last_command_id":last_id,"label":label,"mode":mode,"boss_fixture_modifiers":boss_modifiers if mode == "boss" else [],"command":command.duplicate(true),"input_log":input_events.duplicate(true),"duration_seconds":elapsed,"review_paused":paused,"rendered":rendered,"game":detail,"png":base+".png" if rendered else "","scope":"Agent-directed application-level review, with fixed manually supplied aim and bounded named inputs. No autonomous target selection, combat stat overrides, or human-playtest claim. OS focus behavior is not exercised by this adapter."}
	_write_json(base+".json",report)
	_write_json(review_directory.path_join("status.json"),report)
	capturing = false

func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(value,"\t"))
