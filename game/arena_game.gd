extends Node3D
## Combat authority. Art, effects, audio and interface observe this simulation.

const Art = preload("res://game/world_art.gd")
const FX = preload("res://game/spell_fx.gd")
const Sound = preload("res://game/game_audio.gd")
const UI = preload("res://game/game_ui.gd")
const Catalog = preload("res://game/modifier_catalog.gd")
const ARENA_RADIUS := 11.6
const CAST_RANGE := 18.0
const MAX_ENEMIES := 24
const MAX_PROJECTILES := 128
const WAVE_NAMES := ["The first inscription", "Voices in the stone", "Weight of the temple", "A divided storm", "Eye of the tempest", "The Tempest Warden"]
const DEFAULT_SETTINGS := {"master":0.8,"effects":0.8,"ambience":0.4,"shake":0.45,"reduced_flash":false,"reduced_particles":false}

var art: Node3D
var fx: Node3D
var sound: Node
var ui: CanvasLayer
var camera: Camera3D
var caster: Dictionary
var player: Node3D
var state := "title"
var previous_state := "title"
var menu_return := "title"
var confirmation := ""
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var best: Dictionary = {}
var save_path := "user://stormwright.json"
var modifiers: Array[String] = []
var choices: Array[String] = []
var pending_modifier := ""
var health := 100.0
var charge := 0.0
var lance_cd := 0.0
var crown_cd := 0.0
var dash_cd := 0.0
var dash_time := 0.0
var dash_direction := Vector3.ZERO
var invulnerable := 0.0
var cast_pose := 0.0
var motion_speed := 0.0
var elapsed := 0.0
var world_time := 0.0
var wave_time := 0.0
var wave := 0
var kills := 0
var total_casts := 0
var unique_id := 0
var shot_id := 0
var run_seed := 73
var rng := RandomNumberGenerator.new()
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var pending: Array[Dictionary] = []
var spawn_queue: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var crown_shards: Array[Dictionary] = []
var aim := Vector3(0,0,-5)
var camera_base := Vector3(0, 18, 21)
var camera_shake := 0.0
var marker: MeshInstance3D
var footstep_clock := 0.0
var input_armed := false
var lab_mode := false
var banner := ""
var banner_timer := 0.0
var test_options: Dictionary = {}
var test_driver: Node
var telemetry: Dictionary = {"direct_hits":0,"secondary_hits":0,"ultimate_spent":0,"children_omitted":0,"max_projectiles":0,"deaths":0,"waves_completed":0,"boss_phase_two":false}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and "=" in argument:
			var pair := argument.trim_prefix("--").split("=", true, 1)
			test_options[pair[0]] = pair[1]
	if test_options.has("save"):
		save_path = test_options.save
	if test_options.has("seed"):
		run_seed = int(test_options.seed)
	rng.seed = run_seed
	_setup_input()
	_load_save()
	art = Art.new()
	art.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(art)
	art.build_arena()
	fx = FX.new()
	fx.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(fx)
	sound = Sound.new()
	sound.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sound)
	caster = art.create_caster()
	player = caster.root
	add_child(player)
	player.position = Vector3(0,0,4)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 25.0
	camera.position = camera_base
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	marker = _ground_marker(0.32, Color("78fff0"))
	add_child(marker)
	ui = UI.new()
	add_child(ui)
	ui.set_modifier_catalog(Catalog.ALL)
	ui.action.connect(_on_action)
	_apply_settings()
	sound.start_ambience()
	ui.show_screen("title", {"best":best})
	print("GAME_READY " + JSON.stringify({"seed":run_seed,"renderer":RenderingServer.get_current_rendering_method()}))
	if test_options.has("scenario"):
		var driver_script = load("res://game/scenario_runner.gd")
		test_driver = driver_script.new()
		add_child(test_driver)
		test_driver.begin(self, test_options)

func _setup_input() -> void:
	var bindings := {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],"dash":[KEY_SPACE],"cataclysm":[KEY_Q],"pause_game":[KEY_ESCAPE]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)
	for item in [["lance",MOUSE_BUTTON_LEFT],["crown",MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(item[0]):
			InputMap.add_action(item[0])
		var mouse := InputEventMouseButton.new()
		mouse.button_index = item[1]
		InputMap.action_add_event(item[0], mouse)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(sound):
		_request_quit()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not test_options.has("scenario"):
		if state in ["run","lab"]:
			_pause()
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		input_armed = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if state in ["run","lab"]:
			_pause()
		elif state == "pause":
			_resume()
		elif state == "settings":
			_on_action("back",null)
		elif state == "confirm":
			_on_action("cancel",null)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not get_tree().paused:
		world_time += delta
		cast_pose = maxf(0, cast_pose - delta * 3.5)
		camera_shake = maxf(0, camera_shake - delta * 2.6)
		art.animate_caster(caster, world_time, motion_speed, cast_pose, dash_time / 0.18)
		var look_offset := player.position * 0.13
		var desired := camera_base + look_offset
		camera.position = camera.position.lerp(desired, 1.0-exp(-delta*5.0))
		if camera_shake > 0 and float(settings.shake) > 0:
			camera.position.x += sin(world_time*97.0)*camera_shake*0.18*float(settings.shake)
			camera.position.z += cos(world_time*83.0)*camera_shake*0.13*float(settings.shake)
		camera.look_at(look_offset)
	if state in ["run","lab"]:
		_update_aim()
		marker.visible = true
		marker.position = aim + Vector3(0,0.05,0)
	else:
		marker.visible = false
	_update_hud()

func _physics_process(delta: float) -> void:
	if not state in ["run","lab"] or get_tree().paused:
		motion_speed = 0
		return
	elapsed += delta
	wave_time += delta
	lance_cd = maxf(0,lance_cd-delta)
	crown_cd = maxf(0,crown_cd-delta)
	dash_cd = maxf(0,dash_cd-delta)
	invulnerable = maxf(0,invulnerable-delta)
	banner_timer = maxf(0,banner_timer-delta)
	if banner_timer <= 0:
		banner = ""
	if not Input.is_action_pressed("lance") and not Input.is_action_pressed("crown") and not Input.is_action_pressed("cataclysm"):
		input_armed = true
	var movement := Input.get_vector("move_left","move_right","move_up","move_down")
	var direction := Vector3(movement.x,0,movement.y)
	if Input.is_action_just_pressed("dash"):
		request_dash(direction)
	if dash_time > 0:
		dash_time -= delta
		player.position += dash_direction * 23.0 * delta
		if Engine.get_physics_frames() % 2 == 0:
			fx.trail(player.position+Vector3(0,0.65,0),player.position-dash_direction*1.2+Vector3(0,0.65,0))
	else:
		player.position += direction * (5.6 if cast_pose < 0.8 else 4.5) * delta
	player.position = _clamp_arena(player.position, ARENA_RADIUS)
	motion_speed = direction.length()
	var facing := aim-player.position
	facing.y = 0
	if facing.length_squared() > 0.01:
		player.rotation.y = lerp_angle(player.rotation.y,atan2(-facing.x,-facing.z),1.0-exp(-delta*22.0))
	footstep_clock -= delta
	if motion_speed > 0.2 and dash_time <= 0 and footstep_clock <= 0:
		sound.play_sound("step",0.35)
		footstep_clock = 0.3
	var over_ui := get_viewport().gui_get_hovered_control() != null
	if input_armed and not over_ui:
		if Input.is_action_pressed("lance"):
			request_lance()
		if Input.is_action_just_pressed("crown"):
			request_crown()
		if Input.is_action_just_pressed("cataclysm"):
			request_cataclysm()
	_update_pending(delta)
	_update_crown(delta)
	_update_projectiles(delta)
	_update_enemies(delta)
	_update_hazards(delta)
	_update_spawns()
	telemetry.max_projectiles = maxi(int(telemetry.max_projectiles),projectiles.size()+crown_shards.size())
	if not lab_mode and spawn_queue.is_empty() and enemies.is_empty() and state == "run":
		_complete_wave()

func _update_aim() -> void:
	if test_options.has("scenario") and test_driver != null and test_driver.get("override_aim") != null:
		aim = test_driver.override_aim
		return
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	if absf(direction.y) > 0.0001:
		var distance := -origin.y/direction.y
		aim = _clamp_arena(origin+direction*distance, ARENA_RADIUS)

func request_dash(direction: Vector3 = Vector3.ZERO) -> bool:
	if dash_cd > 0 or not state in ["run","lab"]:
		return false
	if direction.length_squared() < 0.01:
		direction = aim-player.position
	direction.y = 0
	dash_direction = direction.normalized() if direction.length_squared() > 0.01 else Vector3.FORWARD
	dash_time = 0.18
	dash_cd = 1.25
	invulnerable = 0.24
	sound.play_sound("dash")
	return true

func request_lance() -> bool:
	if lance_cd > 0 or not state in ["run","lab"]:
		return false
	lance_cd = 0.55
	cast_pose = 1.0
	total_casts += 1
	var context := _cast_context()
	pending.append({"time":0.14,"kind":"lance","context":context,"aim":aim,"power":1.0,"secondary":false})
	fx.charge(caster.staff_tip.global_position,0.45,caster.staff_tip)
	sound.play_sound("lance_charge",0.65)
	return true

func request_crown() -> bool:
	if crown_cd > 0 or not state in ["run","lab"]:
		if state in ["run","lab"]:
			ui.notify("The Crown is gathering strength")
		return false
	var count := 9 if "resonance" in modifiers else 7
	if projectiles.size()+crown_shards.size()+count > MAX_PROJECTILES:
		ui.notify("Let the current storm resolve")
		return false
	crown_cd = 6.0
	cast_pose = 1.0
	total_casts += 1
	var context := _cast_context()
	for index in range(count):
		var node: Node3D = fx.shard(player.position+Vector3(0,2,0),Vector3.FORWARD,0.85)
		add_child(node)
		crown_shards.append({"node":node,"index":index,"count":count,"age":0.0,"launch":0.9+index*0.11,"context":context,"aim":aim})
	fx.charge(player.position+Vector3(0,1.7,0),1.0)
	sound.play_sound("crown")
	return true

func request_cataclysm() -> bool:
	if charge < 100 or not state in ["run","lab"]:
		if state in ["run","lab"]:
			ui.notify("Land spell hits to charge Cataclysm")
		return false
	charge = 0
	telemetry.ultimate_spent += 1
	total_casts += 1
	cast_pose = 1.0
	var at := aim
	var context := _cast_context()
	var tell := _ground_marker(4.3,Color("64e9d3"))
	add_child(tell)
	tell.position = at+Vector3(0,0.06,0)
	pending.append({"time":0.65,"kind":"cataclysm","at":at,"context":context,"tell":tell})
	fx.charge(at+Vector3(0,1,0),2.0)
	sound.play_sound("cataclysm_charge")
	return true

func _cast_context() -> Dictionary:
	shot_id += 1
	return {"id":shot_id,"mods":modifiers.duplicate(),"children":0}

func _allow_child(context: Dictionary) -> bool:
	if int(context.children) >= 32 or projectiles.size()+crown_shards.size() >= MAX_PROJECTILES:
		telemetry.children_omitted += 1
		return false
	context.children += 1
	return true

func _update_pending(delta: float) -> void:
	var ready: Array[Dictionary] = []
	for event in pending:
		event.time -= delta
		if event.kind == "cataclysm":
			cast_pose = maxf(cast_pose,0.7+0.3*(1.0-clampf(event.time/0.65,0,1)))
		if event.kind == "cataclysm" and "gravity" in event.context.mods:
			for enemy in enemies:
				if enemy.kind != "warden" and enemy.hp > 0 and enemy.root.position.distance_to(event.at) < 6:
					enemy.root.position = enemy.root.position.move_toward(event.at,delta*4.0)
		if event.kind == "aftershock_wave":
			event.age += delta
			var radius := minf(4.8,float(event.age)*(4.8/0.7))
			var thickness := radius*0.025
			for enemy in _nearest_enemies(event.at,radius+thickness):
				var distance: float = enemy.root.position.distance_to(event.at)
				if not enemy.id in event.hit and distance >= float(event.previous)-thickness:
					event.hit.append(enemy.id)
					var direction: Vector3 = (enemy.root.position-event.at).normalized()
					_hit_enemy(enemy,65.0,direction,true)
					if enemy.hp > 0 and enemy.kind != "warden":
						_stagger_enemy(enemy,0.35)
						enemy.recoil = direction*4.5
			event.previous = radius
		if event.time <= 0:
			ready.append(event)
	for event in ready:
		pending.erase(event)
		match event.kind:
			"lance":
				var start: Vector3 = event.get("origin",caster.staff_tip.global_position)
				_fire_lance(start,event.aim,event.context,event.power,event.secondary)
				if not event.secondary and "echo" in event.context.mods and _allow_child(event.context):
					pending.append({"time":0.26,"kind":"lance","origin":start,"aim":event.aim,"context":event.context,"power":0.45,"secondary":true})
			"echo_shard":
				_spawn_shot(event.origin,event.direction,19.0,event.damage,event.context,true,event.pierce)
			"cataclysm":
				if is_instance_valid(event.tell):
					event.tell.queue_free()
				_detonate(event.at,event.context,false)
				if "aftershock" in event.context.mods and _allow_child(event.context):
					pending.append({"time":0.65,"kind":"aftershock","at":event.at,"context":event.context})
			"aftershock":
				_detonate(event.at,event.context,true)
			"aftershock_wave":
				if is_instance_valid(event.get("visual")):
					event.visual.queue_free()
	_update_cataclysm_marks()

func _fire_lance(start: Vector3, target: Vector3, context: Dictionary, power: float, secondary: bool) -> void:
	var direction := target-start
	direction.y = 0
	direction = direction.normalized() if direction.length_squared() > 0.01 else Vector3.FORWARD
	var angles := [0.0]
	var hit_ids: Array[int] = []
	if "fork" in context.mods:
		angles.append(-0.22)
		angles.append(0.22)
	for angle in angles:
		if angle != 0 and not _allow_child(context):
			continue
		var ray := direction.rotated(Vector3.UP,float(angle))
		var victims := _ray_victims(start,ray,CAST_RANGE,0.34)
		var limit := 3 if "pierce" in context.mods else 1
		var end := start+ray*CAST_RANGE
		end.y = 0.8
		var damage := 34.0*power*(1.0 if angle == 0 else 0.58)
		for index in range(mini(victims.size(),limit)):
			var enemy: Dictionary = victims[index].enemy
			var hit_at: Vector3 = enemy.root.position+Vector3(0,1.0,0)
			if not enemy.id in hit_ids:
				hit_ids.append(enemy.id)
				_direct_hit(enemy,damage,ray,context,secondary)
			if index == limit-1 or index == victims.size()-1:
				end = hit_at if limit == 1 else start+ray*minf(CAST_RANGE,float(victims[index].distance)+2.0)
				end.y = 1.0
		fx.beam(start,end,power*(1.0 if angle == 0 else 0.65))
	if not secondary:
		sound.play_sound("lance")
		camera_shake = maxf(camera_shake,0.25)

func _ray_victims(origin: Vector3, direction: Vector3, distance: float, width: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy in enemies:
		if enemy.hp <= 0 or enemy.state == "spawn":
			continue
		var offset: Vector3 = enemy.root.position-origin
		offset.y = 0
		var along := offset.dot(direction)
		if along >= 0 and along <= distance and (offset-direction*along).length() <= enemy.radius+width:
			result.append({"enemy":enemy,"distance":along})
	result.sort_custom(func(a,b): return a.distance < b.distance if a.distance != b.distance else a.enemy.id < b.enemy.id)
	return result

func _update_crown(delta: float) -> void:
	var launch: Array[Dictionary] = []
	for shard in crown_shards:
		shard.age += delta
		var angle: float = shard.index*TAU/shard.count+shard.age*2.0
		var radius := minf(shard.age*5.0,2.4)
		var at := player.position+Vector3(cos(angle)*radius,2.0+sin(angle*2.0)*0.5,sin(angle)*radius)
		shard.node.position = at
		shard.node.rotation = Vector3(0,-angle,0.15)
		if shard.age >= shard.launch:
			launch.append(shard)
	for shard in launch:
		crown_shards.erase(shard)
		cast_pose = maxf(cast_pose,0.6)
		var origin: Vector3 = shard.node.position
		shard.node.queue_free()
		var targets := _nearest_enemies(origin,18.0)
		var target: Vector3 = shard.aim+Vector3(0,1,0)
		if not targets.is_empty():
			target = targets[int(shard.index)%targets.size()].root.position+Vector3(0,1,0)
		var direction := (target-origin).normalized()
		var paired: bool = "fork" in shard.context.mods
		var count := 2 if paired else 1
		for index in range(count):
			if not _allow_child(shard.context):
				continue
			var dir := direction.rotated(Vector3.UP,(-0.10 if index == 0 else 0.10) if paired else 0.0)
			var damage := 27.0*(0.72 if paired else 1.0)
			_spawn_shot(origin,dir,17.0,damage,shard.context,false,3 if "pierce" in shard.context.mods else 1)
			if "echo" in shard.context.mods and _allow_child(shard.context):
				pending.append({"time":0.35,"kind":"echo_shard","origin":origin,"direction":dir,"damage":damage*0.45,"context":shard.context,"pierce":3 if "pierce" in shard.context.mods else 1})
		sound.play_sound("crown_fire",0.7)

func _spawn_shot(origin: Vector3, direction: Vector3, speed: float, damage: float, context: Dictionary, secondary: bool, pierce: int, hostile: bool = false, owner_id: int = -1) -> void:
	if projectiles.size()+crown_shards.size() >= MAX_PROJECTILES:
		return
	var node: Node3D = fx.shard(origin,direction,0.43 if hostile else 0.65,hostile)
	add_child(node)
	projectiles.append({"node":node,"position":origin,"direction":direction,"speed":speed,"damage":damage,"context":context,"secondary":secondary,"remaining":pierce,"hit":[],"life":2.0,"hostile":hostile,"owner_id":owner_id,"trail":0.0})

func _update_projectiles(delta: float) -> void:
	var removed: Array[Dictionary] = []
	for shot in projectiles:
		if shot.get("retired",false) or shot.life <= 0:
			removed.append(shot)
			continue
		var old: Vector3 = shot.position
		shot.position += shot.direction*shot.speed*delta
		shot.node.position = shot.position
		shot.life -= delta
		shot.trail -= delta
		if shot.trail <= 0:
			fx.trail(old-shot.direction*0.3,shot.position,shot.hostile)
			shot.trail = 0.045
		if shot.hostile:
			if _segment_distance(player.position,old,shot.position) < 0.55:
				_damage_player(shot.damage)
				shot.life = 0
		else:
			var direction: Vector3 = shot.direction
			direction.y = 0
			if direction.length_squared() > 0.01:
				var victims := _ray_victims(old,direction.normalized(),shot.speed*delta+0.1,0.3)
				for item in victims:
					var enemy: Dictionary = item.enemy
					if enemy.id in shot.hit:
						continue
					shot.hit.append(enemy.id)
					_direct_hit(enemy,shot.damage,shot.direction,shot.context,shot.secondary)
					shot.remaining -= 1
					if shot.remaining <= 0:
						shot.life = 0
						break
		if shot.life <= 0 or shot.position.length() > 35:
			removed.append(shot)
	for shot in removed:
		shot.node.queue_free()
		projectiles.erase(shot)

func _direct_hit(enemy: Dictionary, damage: float, direction: Vector3, context: Dictionary, secondary: bool) -> void:
	if enemy.hp <= 0:
		return
	var at: Vector3 = enemy.root.position
	_hit_enemy(enemy,damage,direction,secondary)
	if secondary:
		return
	charge = minf(100,charge+2.8)
	if "chain" in context.mods:
		var visited := [enemy.id]
		var previous := at
		for hop in range(2):
			var targets := _nearest_enemies(previous,4.6,visited)
			if targets.is_empty() or not _allow_child(context):
				break
			var victim: Dictionary = targets[0]
			visited.append(victim.id)
			fx.beam(previous+Vector3(0,1,0),victim.root.position+Vector3(0,1,0),0.48)
			previous = victim.root.position
			_hit_enemy(victim,damage*0.48,direction,true)
	if "overload" in context.mods:
		enemy.stacks += 1
		if enemy.stacks >= 3 and _allow_child(context):
			enemy.stacks = 0
			fx.burst(at+Vector3(0,0.9,0),1.5)
			fx.ring(at,2.4,0.5)
			for victim in _nearest_enemies(at,2.4):
				_hit_enemy(victim,30.0,(victim.root.position-at).normalized(),true)

func _hit_enemy(enemy: Dictionary, damage: float, direction: Vector3, secondary: bool) -> void:
	if enemy.hp <= 0 or enemy.state == "spawn":
		return
	# A missed heavy slam exposes the core: counterattacking beats circling
	# a large health pool, and all spell families share the opening.
	if enemy.kind == "bulwark" and enemy.state == "recover":
		damage *= 1.5
	enemy.hp -= damage
	enemy.hit = 1.0
	enemy.recoil = direction* (0.7 if enemy.kind == "warden" else 3.8)
	telemetry["secondary_hits" if secondary else "direct_hits"] += 1
	fx.burst(enemy.root.position+Vector3(0,1,0),0.6 if secondary else 0.9)
	sound.play_sound("hit",0.35 if secondary else 0.55)
	if enemy.hp <= 0:
		enemy.state = "dead"
		enemy.timer = 0.48
		_clear_enemy_tell(enemy)
		_retire_enemy_attacks(enemy.id)
		kills += 1
		sound.play_sound("death",0.7 if enemy.kind != "warden" else 1.0)
		fx.burst(enemy.root.position+Vector3(0,1,0),1.4 if enemy.kind != "warden" else 3.0)
	elif enemy.kind == "warden" and enemy.phase == 1 and enemy.hp <= enemy.max_hp*0.5:
		enemy.phase = 2
		enemy.state = "transition"
		enemy.timer = 1.8
		_clear_enemy_tell(enemy)
		telemetry.boss_phase_two = true
		_set_banner("THE WARDEN BREAKS ITS SEAL",3.0)
		fx.charge(enemy.root.position+Vector3(0,2,0),2.0)
		for index in range(4):
			spawn_queue.append({"time":wave_time+1.8+index*0.6,"kind":"channeler" if index%2 == 0 else "shardling"})
	elif enemy.kind == "channeler" and not secondary:
		_stagger_enemy(enemy,0.35)

func _detonate(at: Vector3, context: Dictionary, aftershock: bool) -> void:
	if aftershock:
		var visual: Node3D = fx.ring(at,4.8,0.7,false,4.8/0.7)
		fx.burst(at+Vector3(0,0.5,0),1.6)
		pending.append({"kind":"aftershock_wave","time":0.7,"age":0.0,"previous":0.0,"at":at,"context":context,"hit":[],"visual":visual})
		return
	fx.cataclysm(at,1.0)
	cast_pose = 1.0
	camera_shake = 1.0
	sound.play_sound("cataclysm")
	for enemy in _nearest_enemies(at,4.3):
		var direction: Vector3 = (enemy.root.position-at).normalized()
		_hit_enemy(enemy,145.0,direction,true)
		if enemy.hp > 0 and enemy.kind != "warden":
			_stagger_enemy(enemy,0.85)
			enemy.recoil = direction*6.5

func _update_cataclysm_marks() -> void:
	for enemy in enemies:
		if enemy.rig.has("charge_seams") and is_instance_valid(enemy.rig.charge_seams):
			enemy.rig.charge_seams.visible = false
	for event in pending:
		if event.kind != "cataclysm":
			continue
		var progress := clampf(1.0-float(event.time)/0.65,0.0,1.0)
		for enemy in _nearest_enemies(event.at,4.3):
			if not enemy.rig.has("charge_seams"):
				enemy.rig.charge_seams = _enemy_charge_seams(enemy)
			var seams: MeshInstance3D = enemy.rig.charge_seams
			seams.visible = true
			# This material belongs to one mark, so one charged enemy cannot
			# alter the palette or animation of another actor.
			seams.material_override.emission_energy_multiplier = 1.5+progress*3.0+sin(progress*23.0)*0.3

func _enemy_charge_seams(enemy: Dictionary) -> MeshInstance3D:
	var broad: bool = enemy.kind in ["bulwark","warden"]
	var width := 0.52 if broad else 0.25
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.32,0.95,1.0)
	material.emission_enabled = true
	material.emission = Color(0.08,0.67,1.0)
	material.emission_energy_multiplier = 2.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
	for side in [-1.0,1.0]:
		var points := [Vector3(side*width*0.83,0.46,-width*0.87),Vector3(side*width*0.27,0.23,-width*1.03),Vector3(side*width*0.55,-0.11,-width*0.82)]
		for index in range(2):
			var start: Vector3 = points[index]
			var end: Vector3 = points[index+1]
			var offset := (end-start).cross(Vector3.FORWARD).normalized()*(0.019 if broad else 0.014)
			for vertex in [start-offset,start+offset,end-offset,start+offset,end+offset,end-offset]:
				mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	var mark := MeshInstance3D.new()
	mark.name = "CataclysmChargeSeams"
	mark.mesh = mesh
	mark.material_override = material
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	enemy.rig.body.add_child(mark)
	return mark

func _nearest_enemies(at: Vector3, radius: float, exclude: Array = []) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for enemy in enemies:
		if enemy.hp > 0 and enemy.state != "spawn" and not enemy.id in exclude and enemy.root.position.distance_to(at) <= radius:
			found.append(enemy)
	found.sort_custom(func(a,b):
		var da: float = a.root.position.distance_squared_to(at)
		var db: float = b.root.position.distance_squared_to(at)
		return da < db if da != db else a.id < b.id)
	return found

func _damage_player(amount: float) -> void:
	if invulnerable > 0 or not state in ["run","lab"]:
		return
	health = maxf(0,health-amount)
	invulnerable = 0.5
	camera_shake = maxf(camera_shake,0.5)
	fx.burst(player.position+Vector3(0,0.8,0),0.7,true)
	sound.play_sound("hit",0.8)
	if health <= 0:
		telemetry.deaths += 1
		_finish_run(false)

func spawn_enemy(kind: String, at: Vector3) -> Dictionary:
	unique_id += 1
	var rig: Dictionary = art.create_enemy(kind)
	add_child(rig.root)
	rig.root.position = _clamp_arena(at,ARENA_RADIUS-0.5)
	var stats: Array = {"shardling":[50.0,4.2,0.48],"channeler":[68.0,2.8,0.65],"bulwark":[136.0,2.4,0.95],"warden":[1850.0,1.2,1.7]}[kind]
	var tell := _ground_marker(float(stats[2])+0.4,Color("e9b56b"))
	add_child(tell)
	tell.position = rig.root.position+Vector3(0,0.05,0)
	var enemy := {"id":unique_id,"kind":kind,"rig":rig,"root":rig.root,"base_scale":rig.root.scale,"hp":stats[0],"max_hp":stats[0],"speed":stats[1],"radius":stats[2],"state":"spawn","timer":0.9,"cooldown":0.6+rng.randf()*1.1,"hit":0.0,"recoil":Vector3.ZERO,"phase":1,"cycle":0,"target":Vector3.ZERO,"attack":"","tell":tell,"stacks":0}
	enemies.append(enemy)
	return enemy

func _update_enemies(delta: float) -> void:
	var removed: Array[Dictionary] = []
	for enemy in enemies:
		enemy.timer -= delta
		enemy.cooldown -= delta
		enemy.hit = maxf(0,enemy.hit-delta*4.0)
		var attack_pose := 0.0
		var speed_value := 0.0
		if enemy.state == "dead":
			enemy.root.position = _clamp_arena(enemy.root.position + Vector3(enemy.recoil.x,0,enemy.recoil.z)*delta,ARENA_RADIUS-enemy.radius)
			enemy.recoil = Vector3(enemy.recoil).move_toward(Vector3.ZERO,delta*8.0)
			enemy.root.scale = enemy.base_scale*maxf(0.02,enemy.timer/0.48)
			if enemy.timer <= 0:
				removed.append(enemy)
		elif enemy.state == "spawn":
			enemy.root.scale = enemy.base_scale*clampf(1.0-enemy.timer/0.9,0.05,1)
			if enemy.timer <= 0:
				enemy.state = "idle"
				_clear_enemy_tell(enemy)
		elif enemy.state == "transition":
			attack_pose = 0.8
			if enemy.timer <= 0:
				enemy.state = "idle"
				enemy.cooldown = 0.9
		elif enemy.state == "stagger":
			enemy.hit = maxf(enemy.hit,clampf(enemy.timer/0.4,0,1))
			if enemy.timer <= 0:
				enemy.state = "idle"
		elif enemy.state == "windup":
			attack_pose = 0.4+0.6*(1.0-maxf(enemy.timer,0)/enemy.windup)
			if enemy.timer <= 0:
				_execute_enemy_attack(enemy)
		elif enemy.state == "recover":
			if enemy.timer < 0.45:
				_clear_enemy_tell(enemy)
			attack_pose = maxf(0,enemy.timer/0.65)*0.7
			if enemy.timer <= 0:
				enemy.state = "idle"
		elif enemy.state == "lunge":
			attack_pose = 1.0
			enemy.root.position = enemy.root.position.move_toward(enemy.target,delta*16.0)
			if enemy.timer <= 0:
				_clear_enemy_tell(enemy)
				# Duration was derived from this committed endpoint; the actor,
				# warned circle and damage share the same final position.
				enemy.root.position = enemy.target
				fx.ring(enemy.root.position,1.05,0.25,true)
				fx.burst(enemy.root.position+Vector3(0,0.35,0),0.65,true)
				if player.position.distance_to(enemy.root.position) < 1.05: _damage_player(12)
				enemy.state = "recover"
				enemy.timer = 0.38
		elif not lab_mode:
			var to_player: Vector3 = player.position-enemy.root.position
			var distance := to_player.length()
			var direction := to_player.normalized()
			var preferred := 6.5 if enemy.kind == "channeler" else (4.0 if enemy.kind == "warden" else 2.4 if enemy.kind == "shardling" else 2.8)
			var travel := Vector3.ZERO
			var tangent := direction.cross(Vector3.UP) * (1.0 if int(enemy.id)%2 == 0 else -1.0)
			if enemy.kind == "channeler":
				# Circle between shots; retreat when rushed. Wind-ups still commit
				# to one visible lane, so lateral movement remains a safe answer.
				travel = tangent*0.8
				if distance > preferred: travel += direction
				elif distance < 4.5: travel -= direction
			elif distance > preferred:
				travel = direction
				if enemy.kind == "shardling" and distance > 3.5:
					travel += tangent*0.45
			if travel.length_squared() > 0.01:
				enemy.root.position += travel.normalized()*enemy.speed*delta
				speed_value = 1.0
			if distance > 0.05:
				enemy.root.rotation.y = lerp_angle(enemy.root.rotation.y,atan2(-direction.x,-direction.z),1.0-exp(-delta*8))
			if enemy.cooldown <= 0 and distance <= (18.0 if enemy.kind == "warden" else preferred+0.9):
				_begin_enemy_attack(enemy)
		if enemy.hp > 0:
			var recoil: Vector3 = enemy.recoil
			recoil.y = 0
			if enemy.state != "lunge":
				enemy.root.position += recoil*delta
			enemy.recoil = recoil.move_toward(Vector3.ZERO,delta*13)
			for other in enemies:
				if other.id <= enemy.id or other.hp <= 0 or enemy.state == "lunge" or other.state == "lunge":
					continue
				var offset: Vector3 = enemy.root.position-other.root.position
				var required: float = (enemy.radius+other.radius)*0.8
				if offset.length() < required and offset.length() > 0.01:
					var push := offset.normalized()*(required-offset.length())*0.35
					enemy.root.position += push
					other.root.position -= push
			enemy.root.position = _clamp_arena(enemy.root.position,ARENA_RADIUS-enemy.radius)
		art.animate_enemy(enemy.rig,world_time+enemy.id,speed_value,attack_pose,enemy.hit,enemy.phase,enemy.kind == "bulwark" and enemy.state == "recover")
	for enemy in removed:
		enemy.root.queue_free()
		enemies.erase(enemy)

func _begin_enemy_attack(enemy: Dictionary) -> void:
	enemy.state = "windup"
	enemy.target = player.position
	enemy.attack_origin = enemy.root.position
	var direction: Vector3 = enemy.target-enemy.attack_origin
	direction.y = 0
	enemy.attack_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD
	enemy.root.rotation.y = atan2(-enemy.attack_direction.x,-enemy.attack_direction.z)
	var kind: String = enemy.kind
	enemy.attack = "lunge" if kind == "shardling" else "bolt" if kind == "channeler" else "slam"
	enemy.slam_radius = 5.8 if kind == "warden" else 4.1
	enemy.slam_half_angle = PI*0.26
	if kind == "warden":
		enemy.attack = ["slam","fan","pulse"][int(enemy.cycle)%(3 if enemy.phase == 2 else 2)]
		enemy.cycle += 1
		# A distant player receives a readable projectile pattern, never a
		# fist impact disconnected from the guardian's reach.
		if enemy.attack == "slam" and direction.length() > enemy.slam_radius:
			enemy.attack = "fan"
	enemy.windup = 0.5 if kind == "shardling" else 0.9 if kind == "warden" else 0.65 if kind == "channeler" else 0.75
	enemy.timer = enemy.windup
	if enemy.attack == "slam":
		enemy.tell = _sector_marker(enemy.slam_radius,enemy.slam_half_angle,Color("ff765e"))
		enemy.tell.rotation.y = atan2(-enemy.attack_direction.x,-enemy.attack_direction.z)
		enemy.tell.position = enemy.attack_origin+Vector3(0,0.065,0)
	elif enemy.attack in ["bolt","fan"]:
		# Narrow lane for a bolt; the complete fan's outer lanes are marked.
		enemy.tell = _sector_marker(9.0,0.47 if enemy.attack == "fan" else 0.065,Color("ff765e"))
		enemy.tell.rotation.y = atan2(-enemy.attack_direction.x,-enemy.attack_direction.z)
		enemy.tell.position = enemy.attack_origin+Vector3(0,0.065,0)
	else:
		if enemy.attack == "lunge":
			enemy.target = _clamp_arena(Vector3(enemy.attack_origin).move_toward(enemy.target,3.2),ARENA_RADIUS-enemy.radius)
		var radius := 1.05 if enemy.attack == "lunge" else 2.0
		enemy.tell = _ground_marker(radius,Color("ff765e"))
		enemy.tell.position = (enemy.target if enemy.attack == "lunge" else enemy.attack_origin)+Vector3(0,0.065,0)
	add_child(enemy.tell)
	sound.play_sound("enemy_charge",0.5)

func _execute_enemy_attack(enemy: Dictionary) -> void:
	if enemy.attack != "lunge":
		_clear_enemy_tell(enemy)
	var at: Vector3 = enemy.root.position
	match enemy.attack:
		"lunge":
			enemy.state = "lunge"
			enemy.timer = maxf(at.distance_to(enemy.target)/16.0,0.08)
			enemy.recoil = Vector3.ZERO
			enemy.cooldown = 0.85
			sound.play_sound("enemy_attack",0.5)
			return
		"slam":
			var origin: Vector3 = enemy.attack_origin
			var direction: Vector3 = enemy.attack_direction
			# Impact briefly retains the exact committed warning shape.
			enemy.tell = _sector_marker(enemy.slam_radius,enemy.slam_half_angle,Color("ffb17d"))
			enemy.tell.position = origin+Vector3(0,0.075,0)
			enemy.tell.rotation.y = atan2(-direction.x,-direction.z)
			add_child(enemy.tell)
			for angle in [-0.4,0.0,0.4]:
				var impact: Vector3 = origin+direction.rotated(Vector3.UP,angle)*enemy.slam_radius*0.66
				fx.burst(impact+Vector3(0,0.12,0),0.85 if enemy.kind == "warden" else 0.6,true)
			if _inside_sector(player.position,origin,direction,enemy.slam_radius,enemy.slam_half_angle):
				_damage_player(23 if enemy.kind == "warden" else 18)
		"bolt", "fan":
			var count := 5 if enemy.attack == "fan" else 1
			for index in range(count):
				var dir: Vector3 = Vector3(enemy.attack_direction).rotated(Vector3.UP,(index-(count-1)*0.5)*0.22)
				_spawn_shot(at+Vector3(0,0.75,0),dir,9.5 if enemy.kind == "channeler" else 7.8,13.0,{},true,1,true,enemy.id)
		"pulse":
			var origin: Vector3 = enemy.attack_origin
			var visual: Node3D = fx.ring(origin,12.0,2.0,true,6.0)
			hazards.append({"at":origin,"age":0.0,"previous":0.0,"hit":false,"owner_id":enemy.id,"visual":visual})
	sound.play_sound("enemy_attack",0.6)
	enemy.state = "recover"
	enemy.timer = 0.85 if enemy.kind == "bulwark" else 0.4 if enemy.kind == "channeler" else 0.65
	enemy.cooldown = 1.1 if enemy.kind == "channeler" else 1.3 if enemy.kind == "bulwark" else 1.5

func _update_hazards(delta: float) -> void:
	var removed: Array[Dictionary] = []
	for hazard in hazards:
		if hazard.get("retired",false):
			removed.append(hazard)
			continue
		hazard.age += delta
		var radius: float = hazard.age*6.0
		var distance: float = player.position.distance_to(hazard.at)
		if not hazard.hit and distance >= hazard.previous-0.4 and distance <= radius+0.4:
			hazard.hit = true
			_damage_player(20)
		hazard.previous = radius
		if hazard.age > 2.0:
			removed.append(hazard)
	for hazard in removed:
		if is_instance_valid(hazard.get("visual")):
			hazard.visual.queue_free()
		hazards.erase(hazard)

func _stagger_enemy(enemy: Dictionary, duration: float) -> void:
	if enemy.hp <= 0 or enemy.kind == "warden":
		return
	var remaining: float = enemy.timer if enemy.state == "stagger" else 0.0
	_clear_enemy_tell(enemy)
	enemy.state = "stagger"
	enemy.timer = maxf(remaining,duration)
	enemy.cooldown = maxf(enemy.cooldown,duration+0.4)

func _retire_enemy_attacks(owner_id: int) -> void:
	# Mark for retirement instead of erasing while a friendly projectile may be
	# iterating this same collection to deliver the killing hit.
	for shot in projectiles:
		if shot.hostile and shot.get("owner_id",-1) == owner_id:
			shot.retired = true
			shot.life = 0.0
			shot.node.visible = false
	for hazard in hazards:
		if hazard.get("owner_id",-1) == owner_id:
			hazard.retired = true
			if is_instance_valid(hazard.get("visual")):
				hazard.visual.queue_free()

func _inside_sector(point: Vector3, origin: Vector3, direction: Vector3, radius: float, half_angle: float) -> bool:
	var offset := point-origin
	offset.y = 0
	var distance := offset.length()
	return distance <= radius and (distance < 0.001 or offset.dot(direction)/distance >= cos(half_angle))

func _sector_marker(radius: float, half_angle: float, color: Color) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	var border := StandardMaterial3D.new()
	border.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	border.albedo_color = color
	border.emission_enabled = true
	border.emission = color
	border.emission_energy_multiplier = 1.05
	border.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,border)
	var segments := 28
	for index in range(segments):
		var a := lerpf(-half_angle,half_angle,float(index)/segments)
		var b := lerpf(-half_angle,half_angle,float(index+1)/segments)
		var p := Vector3(sin(a),0,-cos(a))
		var q := Vector3(sin(b),0,-cos(b))
		for vertex in [p*radius,q*radius,p*(radius-0.055),q*radius,q*(radius-0.055),p*(radius-0.055)]:
			mesh.surface_add_vertex(vertex)
	for angle in [-half_angle,half_angle]:
		var end := Vector3(sin(angle),0,-cos(angle))*radius
		var side := Vector3(-end.z,0,end.x).normalized()*0.028
		for vertex in [-side,side,end-side,side,end+side,end-side]:
			mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	var fill := border.duplicate() as StandardMaterial3D
	fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill.albedo_color = Color(color,0.055)
	fill.emission_energy_multiplier = 0.25
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,fill)
	for index in range(segments):
		var a := lerpf(-half_angle,half_angle,float(index)/segments)
		var b := lerpf(-half_angle,half_angle,float(index+1)/segments)
		for vertex in [Vector3.ZERO,Vector3(sin(a),0,-cos(a))*radius,Vector3(sin(b),0,-cos(b))*radius]:
			mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	var marker_node := MeshInstance3D.new()
	marker_node.mesh = mesh
	marker_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return marker_node

func _clear_enemy_tell(enemy: Dictionary) -> void:
	if is_instance_valid(enemy.get("tell")):
		enemy.tell.queue_free()
	enemy.tell = null

func start_run(laboratory: bool = false) -> void:
	_clear_combat()
	get_tree().paused = false
	lab_mode = laboratory
	state = "lab" if laboratory else "run"
	health = 100
	charge = 100 if laboratory else 35
	elapsed = 0
	kills = 0
	total_casts = 0
	wave = 0
	modifiers.clear()
	player.position = Vector3(0,0,5)
	player.rotation = Vector3.ZERO
	input_armed = false
	rng.seed = run_seed
	telemetry = {"direct_hits":0,"secondary_hits":0,"ultimate_spent":0,"children_omitted":0,"max_projectiles":0,"deaths":0,"waves_completed":0,"boss_phase_two":false}
	ui.show_screen("lab" if laboratory else "hud",{"modifiers":modifiers})
	if laboratory:
		_reset_lab()
		_set_banner("THE SPELL LABORATORY",3)
	else:
		_start_wave()

func _start_wave() -> void:
	wave += 1
	wave_time = 0
	state = "run"
	get_tree().paused = false
	input_armed = false
	ui.show_screen("hud")
	_set_banner("%02d  /  %s" % [wave,WAVE_NAMES[wave-1].to_upper()],3)
	var sequence: Array[String] = []
	match wave:
		1: sequence.assign(["shardling","shardling","shardling","shardling","shardling","shardling","shardling","shardling","shardling","shardling"])
		2:
			for index in range(16): sequence.append("channeler" if index%3 == 0 else "shardling")
		3:
			for index in range(16): sequence.append("bulwark" if index%3 == 0 else "shardling")
		4:
			for index in range(24): sequence.append(["shardling","channeler","bulwark"][index%3])
		5:
			for index in range(30): sequence.append(["shardling","channeler","shardling","bulwark"][index%4])
		6: sequence.assign(["warden"])
	for index in range(sequence.size()):
		var delay := 0.5+index*0.5
		if wave == 4 and index >= 12:
			delay += 12.0
		spawn_queue.append({"time":delay,"kind":sequence[index]})

func _update_spawns() -> void:
	if spawn_queue.is_empty() or enemies.size() >= MAX_ENEMIES:
		return
	var ready: Array[Dictionary] = []
	for item in spawn_queue:
		if item.time <= wave_time and enemies.size()+ready.size() < MAX_ENEMIES:
			ready.append(item)
	for item in ready:
		spawn_queue.erase(item)
		var angle := rng.randf()*TAU
		var at := Vector3(cos(angle)*9.5,0,sin(angle)*9.5)
		if at.distance_to(player.position) < 4:
			at = -at
		if item.kind == "warden": at = Vector3(0,0,-5)
		spawn_enemy(item.kind,at)

func _complete_wave() -> void:
	telemetry.waves_completed += 1
	if wave == 6:
		_finish_run(true)
		return
	health = minf(100,health+25)
	state = "upgrade"
	get_tree().paused = true
	choices.clear()
	var available: Array[String] = []
	for entry in Catalog.ALL:
		if not entry.id in modifiers: available.append(entry.id)
	while choices.size() < 3 and not available.is_empty():
		var index := rng.randi_range(0,available.size()-1)
		choices.append(available[index])
		available.remove_at(index)
	ui.show_screen("upgrade",{"choices":choices,"modifiers":modifiers,"wave":wave})
	sound.play_sound("upgrade")

func _finish_run(won: bool) -> void:
	state = "victory" if won else "defeat"
	get_tree().paused = true
	var old_best := best.duplicate()
	if won and not lab_mode and (best.is_empty() or elapsed < float(best.get("elapsed",INF))):
		best = {"elapsed":elapsed,"kills":kills,"modifiers":modifiers.duplicate()}
		_save()
	ui.show_screen(state,{"elapsed":elapsed,"kills":kills,"modifiers":modifiers,"wave":wave,"best":best,"previous_best":old_best})
	sound.play_sound("victory" if won else "defeat")

func _reset_lab() -> void:
	_clear_combat()
	for index in range(6):
		spawn_enemy(["shardling","channeler","bulwark"][index%3],Vector3((index%3-1)*3.0,0,-1.5-float(index/3)*3.2))
	health = 100
	charge = 100
	crown_cd = 0

func _clear_combat() -> void:
	for enemy in enemies:
		_clear_enemy_tell(enemy)
		enemy.root.queue_free()
	for shot in projectiles: shot.node.queue_free()
	for shard in crown_shards: shard.node.queue_free()
	for event in pending:
		if is_instance_valid(event.get("tell")): event.tell.queue_free()
	enemies.clear()
	projectiles.clear()
	crown_shards.clear()
	pending.clear()
	spawn_queue.clear()
	hazards.clear()
	fx.clear_all()
	lance_cd = 0
	crown_cd = 0
	dash_cd = 0
	dash_time = 0
	invulnerable = 0
	cast_pose = 0

func _pause() -> void:
	previous_state = state
	state = "pause"
	get_tree().paused = true
	input_armed = false
	ui.show_screen("pause")

func _resume() -> void:
	state = previous_state
	get_tree().paused = false
	input_armed = false
	ui.show_screen("lab" if lab_mode else "hud",{"modifiers":modifiers})

func _on_action(action: String, payload: Variant = null) -> void:
	match action:
		"start": start_run(false)
		"pause":
			if state in ["run","lab"]: _pause()
		"lab": start_run(true)
		"quit": _request_quit()
		"resume": _resume()
		"settings":
			menu_return = state
			state = "settings"
			get_tree().paused = true
			ui.show_screen("settings",{"settings":settings})
		"back":
			state = menu_return
			get_tree().paused = state != "title"
			ui.show_screen(state,{"best":best})
		"setting":
			if payload is Dictionary and DEFAULT_SETTINGS.has(payload.get("key","")):
				settings[payload.key] = payload.value
				_apply_settings()
				_save()
		"restart", "title":
			if state in ["victory","defeat","title"]:
				_execute_navigation(action)
			else:
				confirmation = action
				state = "confirm"
				ui.show_screen("confirm",{"confirm_text":"Abandon this run and " + ("start again?" if action == "restart" else "return to the title?")})
		"confirm": _execute_navigation(confirmation)
		"cancel":
			state = "pause"
			ui.show_screen("pause")
		"choose_modifier":
			if state != "upgrade" or not str(payload) in choices: return
			if modifiers.size() < 3:
				modifiers.append(str(payload))
				sound.play_sound("upgrade")
				_start_wave()
			else:
				pending_modifier = str(payload)
				ui.show_screen("upgrade",{"choices":choices,"modifiers":modifiers,"replace_id":pending_modifier})
		"replace_modifier":
			if state == "upgrade" and not pending_modifier.is_empty() and int(payload) >= 0 and int(payload) < modifiers.size():
				modifiers[int(payload)] = pending_modifier
				pending_modifier = ""
				_start_wave()
		"skip":
			if state == "upgrade":
				pending_modifier = ""
				_start_wave()
		"lab_modifier":
			var id := str(payload)
			if not lab_mode or not Catalog.valid_id(id): return
			if id in modifiers: modifiers.erase(id)
			elif modifiers.size() < 3: modifiers.append(id)
			else: ui.notify("Remove an inscription before adding another")
			ui.show_screen("lab",{"modifiers":modifiers})
			input_armed = false
		"lab_refill":
			if lab_mode:
				health = 100
				charge = 100
				crown_cd = 0
				ui.notify("The storm is restored")
		"lab_reset":
			if lab_mode: _reset_lab()

func _execute_navigation(action: String) -> void:
	if action == "restart":
		start_run(lab_mode)
	else:
		_clear_combat()
		get_tree().paused = false
		lab_mode = false
		modifiers.clear()
		state = "title"
		player.position = Vector3(0,0,4)
		ui.show_screen("title",{"best":best})

func _request_quit() -> void:
	if state == "quitting": return
	state = "quitting"
	get_tree().paused = false
	_clear_combat()
	if sound.has_method("shutdown"): sound.shutdown()
	await get_tree().create_timer(0.2,true,false,true).timeout
	get_tree().quit()

func _update_hud() -> void:
	var boss_hp := 0.0
	var boss_max := 0.0
	var phase := 1
	for enemy in enemies:
		if enemy.kind == "warden" and enemy.hp > 0:
			boss_hp = enemy.hp
			boss_max = enemy.max_hp
			phase = enemy.phase
	ui.update_hud({"health":health,"max_health":100.0,"wave":wave,"wave_name":WAVE_NAMES[maxi(0,wave-1)],"enemy_count":enemies.filter(func(e): return e.hp>0).size()+spawn_queue.size(),"crown_cd":crown_cd,"dash_cd":dash_cd,"charge":charge,"modifiers":modifiers,"elapsed":elapsed,"boss_health":boss_hp,"boss_max_health":boss_max,"boss_phase":phase,"lab":lab_mode,"banner":banner})

func _set_banner(text: String, duration: float) -> void:
	banner = text
	banner_timer = duration

func _load_save() -> void:
	if not FileAccess.file_exists(save_path): return
	var file := FileAccess.open(save_path,FileAccess.READ)
	if file == null: return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return
	var parsed = parser.data
	if not parsed is Dictionary: return
	if parsed.get("settings") is Dictionary:
		for key in DEFAULT_SETTINGS:
			var value = parsed.settings.get(key,DEFAULT_SETTINGS[key])
			if DEFAULT_SETTINGS[key] is bool:
				settings[key] = value if value is bool else DEFAULT_SETTINGS[key]
			elif value is float or value is int:
				settings[key] = clampf(float(value),0,1)
	if parsed.get("best") is Dictionary and parsed.best.get("elapsed") is float and parsed.best.elapsed > 0:
		best = parsed.best

func _save() -> void:
	var file := FileAccess.open(save_path,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"settings":settings,"best":best},"\t"))

func _apply_settings() -> void:
	fx.set_quality(bool(settings.reduced_particles),bool(settings.reduced_flash))
	sound.set_levels(float(settings.master),float(settings.effects),float(settings.ambience))

func _ground_marker(radius: float, color: Color) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,mat)
	for index in range(80):
		var a := float(index)*TAU/80
		var b := float(index+1)*TAU/80
		var p := Vector3(cos(a),0,sin(a))
		var q := Vector3(cos(b),0,sin(b))
		for point in [p*radius,q*radius,p*(radius-0.045),q*radius,q*(radius-0.045),p*(radius-0.045)]:
			mesh.surface_add_vertex(point)
	mesh.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _clamp_arena(at: Vector3, radius: float) -> Vector3:
	var flat := Vector2(at.x,at.z).limit_length(radius)
	return Vector3(flat.x,0,flat.y)

func _segment_distance(point: Vector3, start: Vector3, end: Vector3) -> float:
	var a := Vector2(start.x,start.z)
	var b := Vector2(end.x,end.z)
	var p := Vector2(point.x,point.z)
	var segment := b-a
	var t := clampf((p-a).dot(segment)/maxf(segment.length_squared(),0.00001),0,1)
	return p.distance_to(a+segment*t)

func snapshot() -> Dictionary:
	var enemy_state: Array[Dictionary] = []
	for enemy in enemies:
		enemy_state.append({"id":enemy.id,"kind":enemy.kind,"hp":enemy.hp,"state":enemy.state,"phase":enemy.phase,"position":[enemy.root.position.x,enemy.root.position.z]})
	return {"state":state,"wave":wave,"elapsed":elapsed,"health":health,"charge":charge,"modifiers":modifiers,"kills":kills,"casts":total_casts,"enemies":enemy_state,"projectiles":projectiles.size(),"pending":pending.size(),"crown_shards":crown_shards.size(),"telemetry":telemetry,"player":[player.position.x,player.position.z]}
