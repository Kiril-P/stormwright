extends SceneTree
## Staged production AI review: normal stats, fixed spawn, sidestep on warning,
## then aim-assisted named spell inputs. No health or enemy-state overrides.
const MAIN = preload("res://scenes/main.tscn")
const KINDS = ["shardling","channeler","bulwark"]
class Aim extends Node:
	var override_aim := Vector3.ZERO
var game: Node3D
var driver: Aim
var index := -1
var age := 0.0
var enemy: Dictionary
var previous := ""
var events: Array = []
var active := false
var killing := false
var dodging := 0.0
var output := "res://work/enemy-final/reel"
func _initialize() -> void:
	setup.call_deferred()
func setup() -> void:
	game = MAIN.instantiate()
	game.save_path = output.path_join("save.json")
	root.add_child(game)
	driver = Aim.new()
	game.add_child(driver)
	game.test_driver = driver
	game.test_options["scenario"] = "enemy_reel"
	game.start_run(false)
	start_stage()
	active = true
func start_stage() -> void:
	for action in ["lance","crown","move_right"]: Input.action_release(action)
	index += 1
	age = 0
	previous = ""
	killing = false
	dodging = 0
	game._clear_combat()
	game.state = "run"
	game.lab_mode = false
	game.health = 100
	game.player.position = Vector3(0,0,3)
	game.spawn_queue.append({"time":9999.0,"kind":"shardling"})
	game.crown_cd = 0
	game.lance_cd = 0
	enemy = game.spawn_enemy(KINDS[index],Vector3(0,0,-4))
	game._set_banner(KINDS[index].to_upper()+" / APPROACH → TELEGRAPH → DODGE → BREAK",8)
func _physics_process(delta: float) -> bool:
	if not active: return false
	age += delta
	if is_instance_valid(enemy.root):
		driver.override_aim = enemy.root.position
		if enemy.state != previous:
			previous = enemy.state
			events.append({"kind":KINDS[index],"time":age,"state":previous,"hp":enemy.hp,"player_health":game.health})
			capture.call_deferred("%s-%02d-%s" % [KINDS[index],events.size(),previous])
			if previous == "windup" and not killing:
				Input.action_press("move_right")
				dodging = 0.45
	if dodging > 0:
		dodging -= delta
		if dodging <= 0: Input.action_release("move_right")
	if age >= 5.5 and not killing:
		killing = true
		Input.action_press("lance")
		game.request_crown()
	if age >= 9:
		if index < 2: start_stage()
		else:
			active = false
			finish.call_deferred()
	return false
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func finish() -> void:
	var passed := true
	for kind in KINDS:
		for state in ["spawn","idle","windup","recover","dead"]:
			passed = passed and events.any(func(e): return e.kind == kind and e.state == state)
	var file := FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"fixture":"normal stats; staged spawn, reactive sidestep and aim-assisted spells","events":events},"\t"))
	game.state = "verification_done"
	game._clear_combat()
	game.sound.shutdown()
	await create_timer(0.2).timeout
	quit(0 if passed else 1)
