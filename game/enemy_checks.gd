extends SceneTree
## Production enemy timing/damage fixtures. Not a rendered counterplay review.
const Main = preload("res://scenes/main.tscn")
var game: Node3D
var checks: Dictionary = {}
func _initialize() -> void:
	call_deferred("run")
func reset() -> void:
	game._clear_combat()
	game.state = "lab"
	game.lab_mode = true
	game.player.position = Vector3(0,0,-3)
	game.health = 100
	game.invulnerable = 0
	game.charge = 0
	await process_frame
	await process_frame
func enemy(kind: String, at: Vector3 = Vector3.ZERO) -> Dictionary:
	var e: Dictionary = game.spawn_enemy(kind,at)
	e.state = "idle"
	e.hp = 1000
	e.max_hp = 1000
	game._clear_enemy_tell(e)
	return e
func note(id: String, passed: bool) -> void:
	checks[id] = passed
	print("ENEMY_CHECK ", id, " ", "PASS" if passed else "FAIL")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work/enemy-checks"))
	game = Main.instantiate()
	game.save_path = "res://work/enemy-checks/preferences.json"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.fx.set_process(false)
	game.sound.set_levels(0,0,0)
	await reset()
	var e := enemy("bulwark")
	game._begin_enemy_attack(e)
	var committed: Vector3 = e.attack_direction
	game.player.position = Vector3(4,0,0)
	game._execute_enemy_attack(e)
	note("slam_safe_outside_committed_sector", game.health == 100 and committed == Vector3.FORWARD)
	game.player.position = Vector3(0,0,-3)
	game._execute_enemy_attack(e)
	note("slam_damage_inside_same_sector", game.health == 82)
	await reset()
	e = enemy("warden")
	game.player.position = Vector3(0,0,-9)
	game._begin_enemy_attack(e)
	note("distant_warden_uses_fan", e.attack == "fan")
	game._execute_enemy_attack(e)
	note("fan_has_five_owned_shots", game.projectiles.size() == 5 and game.projectiles[0].owner_id == e.id)
	game._hit_enemy(e,1200,Vector3.FORWARD,false)
	game._update_projectiles(1.0/60)
	note("dead_owner_shots_retire", game.projectiles.is_empty())
	var previous: Vector3 = e.root.position
	game._update_enemies(1.0/60)
	note("death_has_directional_travel", e.root.position.distance_to(previous) > 0.001)
	await reset()
	e = enemy("channeler")
	game._begin_enemy_attack(e)
	game._hit_enemy(e,10,Vector3.RIGHT,false)
	note("channeler_hit_cancels_windup", e.state == "stagger" and e.tell == null and e.timer <= 0.351)
	for _i in range(30): game._update_enemies(1.0/60)
	note("interrupted_channeler_does_not_emit", game.projectiles.is_empty() and e.state == "idle")
	await reset()
	e = enemy("bulwark",Vector3(1,0,0))
	var boss := enemy("warden",Vector3(-2,0,0))
	game._begin_enemy_attack(e)
	game._begin_enemy_attack(boss)
	game._detonate(Vector3.ZERO,game._cast_context(),false)
	note("cataclysm_staggers_regular_not_warden", e.state == "stagger" and e.timer >= 0.8 and boss.state == "windup")
	game._hit_enemy(boss,400,Vector3.ZERO,true)
	note("warden_phase_transition_remains_safe", boss.phase == 2 and boss.state == "transition" and boss.timer >= 1.8 and boss.tell == null)
	await reset()
	e = enemy("shardling")
	game.player.position = Vector3(0,0,-2.4)
	game._begin_enemy_attack(e)
	e.root.position = Vector3(0,0,0.8)
	game._execute_enemy_attack(e)
	for _i in range(14): game._update_enemies(1.0/60)
	note("lunge_reaches_committed_damage_endpoint", e.root.position.distance_to(e.target) < 0.01 and game.health == 88)
	await reset()
	e = enemy("warden")
	game.player.position = Vector3(4,0,0)
	game._begin_enemy_attack(e)
	e.attack = "pulse"
	game._execute_enemy_attack(e)
	var visual: Node3D = game.hazards[0].visual
	game._update_hazards(0.5)
	game.fx._process(0.5)
	note("pulse_visual_and_damage_share_linear_radius", is_equal_approx(visual.scale.x,3.0) and game.health == 100)
	game._hit_enemy(e,1200,Vector3.ZERO,true)
	game._update_hazards(0.2)
	note("dead_owner_pulse_retires", game.hazards.is_empty() and game.health == 100 and visual.is_queued_for_deletion())
	await reset()
	e = enemy("bulwark",Vector3(1,0,0))
	game.aim = Vector3.ZERO
	game.charge = 100
	game.request_cataclysm()
	game._update_pending(0.1)
	note("cataclysm_marks_armor_during_windup", e.rig.has("charge_seams") and e.rig.charge_seams.visible and e.hp == 1000)
	game._update_pending(0.56)
	note("charge_seams_end_at_rupture", not e.rig.charge_seams.visible and e.hp == 855)
	await reset()
	var near := enemy("bulwark",Vector3(1,0,0))
	var far := enemy("bulwark",Vector3(4,0,0))
	game._detonate(Vector3.ZERO,game._cast_context(),true)
	for _i in range(12): game._update_pending(1.0/60)
	note("aftershock_hits_near_before_far", near.hp == 935 and far.hp == 1000)
	for _i in range(30): game._update_pending(1.0/60)
	note("aftershock_sweeps_far_once_without_charge", near.hp == 935 and far.hp == 935 and game.charge == 0)
	await reset()
	e = game.spawn_enemy("shardling",Vector3.ZERO)
	e.state = "idle"
	game._hit_enemy(e,34,Vector3.ZERO,false)
	game._hit_enemy(e,34,Vector3.ZERO,false)
	note("unmodified_lance_breaks_shardling_in_two_hits", e.hp <= 0)
	await reset()
	e = enemy("bulwark")
	e.state = "recover"
	game._hit_enemy(e,34,Vector3.ZERO,false)
	note("missed_slam_exposes_core_for_counterattack", e.hp == 949)
	await reset()
	e = enemy("channeler",Vector3(0,0,3))
	game.lab_mode = false
	e.cooldown = 10
	game._update_enemies(0.2)
	note("channeler_strafes_between_shots", absf(e.root.position.x) > 0.4)
	await reset()
	e = enemy("shardling",Vector3(0,0,5))
	game.lab_mode = false
	e.cooldown = 10
	game._update_enemies(0.2)
	note("shardling_flanks_while_closing_fast", absf(e.root.position.x) > 0.2 and e.root.position.z < 4.3)
	var passed := true
	for value in checks.values(): passed = passed and value
	var file := FileAccess.open("res://work/enemy-checks/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks},"\t"))
	game._clear_combat()
	await process_frame
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if passed else 1)
