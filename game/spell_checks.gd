extends SceneTree
## Deterministic contract fixtures against the production scene and spell methods.
## These checks establish damage/lifecycle rules, not art quality or manual play.
const MAIN = preload("res://scenes/main.tscn")
const STEP := 1.0 / 60.0
var game: Node3D
var results: Array[Dictionary] = []
var started := 0
var output := "res://work/spell-checks/result.json"

func _initialize() -> void:
	started = Time.get_ticks_msec()
	call_deferred("_run")

func _run() -> void:
	game = MAIN.instantiate()
	game.save_path = "res://work/spell-checks/preferences.json"
	root.add_child(game)
	await process_frame
	# Keep the fixtures fixed. Individual tests advance the real event, projectile
	# or complete physics update function explicitly in bounded 60 Hz steps.
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.set_levels(0.0, 0.0, 0.0)
	for action in ["lance", "crown", "cataclysm", "move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	await _ray_contract()
	await _cast_timing()
	await _crown_shapes()
	await _projectile_contract()
	await _secondary_contract()
	await _snapshot_and_echo()
	await _ultimate_contract()
	await _modifier_actions()
	await _caps_and_cleanup()
	var passed := true
	for check in results:
		passed = passed and bool(check.passed)
	var result := {"passed": passed, "checks": results, "count": results.size(), "seconds": (Time.get_ticks_msec() - started) / 1000.0, "scope": "Production scene and spell methods with fixed fixtures; not visual, performance, or complete-run evidence."}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result, "\t"))
	print("SPELL_CHECKS_RESULT " + JSON.stringify(result))
	game.state = "verification_done"
	game._clear_combat()
	await process_frame
	await process_frame
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if passed else 1)

func _reset() -> void:
	paused = false
	game.state = "lab"
	game.lab_mode = true
	game._clear_combat()
	game.modifiers.clear()
	game.player.position = Vector3.ZERO
	game.player.rotation = Vector3.ZERO
	game.health = 100.0
	game.charge = 0.0
	game.kills = 0
	game.wave = 0
	game.art.animate_caster(game.caster, 0.0, 0.0, 0.0, 0.0)
	game.telemetry = {"direct_hits": 0, "secondary_hits": 0, "ultimate_spent": 0, "children_omitted": 0, "max_projectiles": 0, "deaths": 0, "waves_completed": 0, "boss_phase_two": false}
	await process_frame
	await process_frame

func _enemy(at: Vector3, hp: float = 1000.0, kind: String = "shardling") -> Dictionary:
	var enemy: Dictionary = game.spawn_enemy(kind, at)
	enemy.root.position = at
	enemy.hp = hp
	enemy.max_hp = hp
	enemy.state = "idle"
	enemy.cooldown = 9999.0
	game._clear_enemy_tell(enemy)
	return enemy

func _check(id: String, passed: bool, evidence: Dictionary = {}) -> void:
	results.append({"id": id, "passed": passed, "evidence": evidence.duplicate(true)})
	print("SPELL_CHECK " + id + " " + ("PASS" if passed else "FAIL") + " " + JSON.stringify(evidence))

func _events(frames: int, with_crown: bool = false, with_projectiles: bool = false) -> void:
	for _frame in range(frames):
		game._update_pending(STEP)
		if with_crown:
			game._update_crown(STEP)
		if with_projectiles:
			game._update_projectiles(STEP)

func _ray_contract() -> void:
	await _reset()
	var far := _enemy(Vector3(0, 0, 0))
	var near := _enemy(Vector3(0, 0, 6))
	var beyond := _enemy(Vector3(0, 0, -9))
	var behind := _enemy(Vector3(0, 0, 11))
	game._fire_lance(Vector3(0, 1, 10), Vector3(0, 0, -10), game._cast_context(), 1.0, false)
	_check("lance_first_visible_victim", near.hp < 1000 and far.hp == 1000, {"near_hp": near.hp, "far_hp": far.hp, "array_order": "far created first"})
	_check("lance_range_and_direction", beyond.hp == 1000 and behind.hp == 1000, {"beyond_19m_hp": beyond.hp, "behind_origin_hp": behind.hp})
	await _reset()
	var outside := _enemy(Vector3(0, 0, -9))
	game._fire_lance(Vector3(0, 1, 10), Vector3(0, 0, -10), game._cast_context(), 1.0, false)
	_check("lance_miss_cannot_damage_or_charge", outside.hp == 1000 and game.charge == 0, {"outside_hp": outside.hp, "charge": game.charge})
	await _reset()
	game.modifiers.assign(["pierce"])
	var victims: Array[Dictionary] = []
	for z in [-2.0, 2.0, 6.0, 8.0]:
		victims.append(_enemy(Vector3(0, 0, z)))
	game._fire_lance(Vector3(0, 1, 10), Vector3(0, 0, -10), game._cast_context(), 1.0, false)
	_check("pierce_three_in_travel_order", victims[0].hp == 1000 and victims[1].hp < 1000 and victims[2].hp < 1000 and victims[3].hp < 1000, {"hp_far_to_near": [victims[0].hp, victims[1].hp, victims[2].hp, victims[3].hp]})
	await _reset()
	game.modifiers.assign(["fork"])
	var close_target := _enemy(Vector3(0, 0, -0.8), 1000.0, "bulwark")
	game._fire_lance(Vector3(0, 1, 0), Vector3(0, 0, -10), game._cast_context(), 1.0, false)
	_check("fork_overlap_does_not_duplicate_direct_hit", is_equal_approx(1000.0 - close_target.hp, 34.0) and game.telemetry.direct_hits == 1, {"damage": 1000.0 - close_target.hp, "direct_hits": game.telemetry.direct_hits})

func _cast_timing() -> void:
	await _reset()
	var origin: Vector3 = game.caster.staff_tip.global_position
	var victim := _enemy(origin + Vector3(0, -origin.y, -5))
	game.aim = victim.root.position
	var accepted: bool = game.request_lance()
	var duplicate: bool = game.request_lance()
	_events(7)
	_check("lance_has_windup_and_cooldown", accepted and not duplicate and victim.hp == 1000 and game.pending.size() == 1, {"accepted": accepted, "repeat_accepted": duplicate, "hp_at_116ms": victim.hp, "queued": game.pending.size()})
	_events(2)
	_check("lance_damage_at_discharge", victim.hp < 1000 and game.pending.is_empty(), {"hp_at_150ms": victim.hp, "charge": game.charge})
	for _frame in range(34):
		game._physics_process(STEP)
	var elapsed_cooldown: float = game.lance_cd
	_check("lance_reopens_after_cooldown", game.request_lance(), {"cooldown_after_566ms": elapsed_cooldown})

func _crown_shapes() -> void:
	for combination in [[], ["resonance"], ["fork"]]:
		await _reset()
		game.modifiers.assign(combination)
		game.aim = Vector3(0, 0, -10)
		var accepted: bool = game.request_crown()
		var initial: int = game.crown_shards.size()
		var repeated: bool = game.request_crown()
		_events(130, true)
		var expected := 9 if "resonance" in combination else 7
		var expected_shots := expected * (2 if "fork" in combination else 1)
		_check("crown_shape_" + ("base" if combination.is_empty() else str(combination[0])), accepted and initial == expected and not repeated and game.crown_shards.is_empty() and game.projectiles.size() == expected_shots, {"gathered": initial, "launched": game.projectiles.size(), "cooldown_rejected": not repeated})
	await _reset()
	game.modifiers.assign(["fork", "resonance"])
	game.request_crown()
	game.modifiers.clear()
	game.player.position = Vector3(3, 0, 2)
	_events(30, true)
	var follows := true
	for shard in game.crown_shards:
		var planar: Vector3 = shard.node.position - game.player.position
		planar.y = 0
		follows = follows and planar.length() <= 2.41
	_events(100, true)
	_check("crown_snapshots_loadout_and_follows_caster", follows and game.projectiles.size() == 18, {"orbit_followed": follows, "shots_after_modifier_removal": game.projectiles.size()})

func _projectile_contract() -> void:
	await _reset()
	var victims: Array[Dictionary] = []
	for z in [-7.0, -5.0, -3.0, -1.5]:
		victims.append(_enemy(Vector3(0, 0, z)))
	game._spawn_shot(Vector3(0, 1, 0), Vector3.FORWARD, 17.0, 27.0, game._cast_context(), false, 3)
	_events(36, false, true)
	_check("crown_projectile_pierces_three_unique_in_order", victims[0].hp == 1000 and victims[1].hp == 973 and victims[2].hp == 973 and victims[3].hp == 973 and game.projectiles.is_empty() and game.telemetry.direct_hits == 3, {"hp_far_to_near": [victims[0].hp, victims[1].hp, victims[2].hp, victims[3].hp], "hits": game.telemetry.direct_hits, "shots_remaining": game.projectiles.size()})
	await _reset()
	var repeated := _enemy(Vector3(0, 0, -2), 1000.0, "bulwark")
	game._spawn_shot(Vector3(0, 1, 0), Vector3.FORWARD, 4.0, 27.0, game._cast_context(), false, 3)
	_events(80, false, true)
	_check("projectile_cannot_rehit_while_inside_one_victim", repeated.hp == 973 and game.telemetry.direct_hits == 1, {"target_hp": repeated.hp, "hits": game.telemetry.direct_hits, "time_inside_volume": "multiple fixed physics segments"})
	await _reset()
	var doomed := _enemy(Vector3(0, 0, -3))
	var survivor := _enemy(Vector3(2, 0, -5))
	game.aim = doomed.root.position
	game.request_crown()
	_events(35, true, true)
	doomed.hp = 0
	game.enemies.erase(doomed)
	doomed.root.queue_free()
	await process_frame
	_events(200, true, true)
	_check("crown_target_death_retargets_without_invalid_reference", survivor.hp < 1000 and game.crown_shards.is_empty() and game.projectiles.is_empty(), {"surviving_target_hp": survivor.hp, "orbiting": game.crown_shards.size(), "projectiles": game.projectiles.size()})

func _secondary_contract() -> void:
	await _reset()
	game.modifiers.assign(["chain", "overload", "echo"])
	var primary := _enemy(Vector3(0, 0, -4))
	var neighbor := _enemy(Vector3(1, 0, -4))
	primary.stacks = 2
	game._direct_hit(primary, 20.0, Vector3.FORWARD, game._cast_context(), true)
	_check("secondary_does_not_charge_recurse_or_stack", primary.hp == 980 and neighbor.hp == 1000 and game.charge == 0 and primary.stacks == 2 and game.pending.is_empty(), {"primary_hp": primary.hp, "neighbor_hp": neighbor.hp, "charge": game.charge, "stacks": primary.stacks, "pending": game.pending.size()})
	await _reset()
	game.modifiers.assign(["chain"])
	primary = _enemy(Vector3(0, 0, -4))
	var first := _enemy(Vector3(1.5, 0, -4))
	var second := _enemy(Vector3(-1.5, 0, -4))
	var unvisited := _enemy(Vector3(4, 0, -4))
	game._direct_hit(primary, 34.0, Vector3.FORWARD, game._cast_context(), false)
	# Stable nearest ordering selects +1.5 first (lower ID), then +4, which is
	# nearer from +1.5 than -1.5. The source and first hop must not be revisited.
	_check("chain_two_unique_nearest_hops", primary.hp == 966 and first.hp < 1000 and unvisited.hp < 1000 and second.hp == 1000 and game.telemetry.secondary_hits == 2 and is_equal_approx(game.charge, 2.8), {"hp": [primary.hp, first.hp, unvisited.hp, second.hp], "secondary_hits": game.telemetry.secondary_hits, "charge": game.charge})
	await _reset()
	game.modifiers.assign(["pierce", "overload"])
	var row: Array[Dictionary] = []
	for z in [6.0, 2.0, -2.0]:
		row.append(_enemy(Vector3(0, 0, z)))
	for _cast in range(3):
		game._fire_lance(Vector3(0, 1, 10), Vector3(0, 0, -10), game._cast_context(), 1.0, false)
	var correct := true
	for enemy in row:
		correct = correct and is_equal_approx(enemy.hp, 868.0) and enemy.stacks == 0
	_check("pierce_overload_third_hit_and_secondary_charge", correct and game.telemetry.direct_hits == 9 and game.telemetry.secondary_hits == 3 and is_equal_approx(game.charge, 25.2), {"hp": [row[0].hp, row[1].hp, row[2].hp], "direct_hits": game.telemetry.direct_hits, "secondary_hits": game.telemetry.secondary_hits, "charge": game.charge})

func _snapshot_and_echo() -> void:
	await _reset()
	game.modifiers.assign(["fork", "echo"])
	var origin: Vector3 = game.caster.staff_tip.global_position
	var targets: Array[Dictionary] = []
	for angle in [0.0, -0.22, 0.22]:
		var at := origin + Vector3.FORWARD.rotated(Vector3.UP, angle) * 7.0
		at.y = 0
		targets.append(_enemy(at))
	game.aim = origin + Vector3.FORWARD * 9
	game.request_lance()
	game.modifiers.clear()
	_events(9)
	var shape_pass: bool = targets[0].hp < 1000 and targets[1].hp < 1000 and targets[2].hp < 1000
	var hp_before: Array[float] = [targets[0].hp, targets[1].hp, targets[2].hp]
	var recorded_origin: Vector3 = game.pending[0].origin if not game.pending.is_empty() else Vector3.INF
	game.player.position = Vector3(7, 0, 5)
	game.aim = Vector3(10, 0, 10)
	var elsewhere := _enemy(Vector3(10, 0, 8))
	_events(16)
	var echo_pass := true
	for index in range(targets.size()):
		echo_pass = echo_pass and targets[index].hp < hp_before[index]
	_check("lance_snapshots_modifiers_at_request", shape_pass, {"direct_hp": hp_before, "current_modifiers": game.modifiers})
	_check("echo_uses_recorded_origin_aim_and_shape", echo_pass and elsewhere.hp == 1000 and game.pending.is_empty() and recorded_origin.distance_to(origin) < 0.01 and game.telemetry.secondary_hits == 3, {"recorded_origin": str(recorded_origin), "original_origin": str(origin), "hp_after_echo": [targets[0].hp, targets[1].hp, targets[2].hp], "new_aim_victim_hp": elsewhere.hp, "secondary_hits": game.telemetry.secondary_hits, "charge": game.charge})

func _ultimate_contract() -> void:
	await _reset()
	var center := _enemy(Vector3(0, 0, -3))
	var elsewhere := _enemy(Vector3(9, 0, 4))
	game.aim = Vector3(0, 0, -3)
	game.charge = 100
	var first: bool = game.request_cataclysm()
	var duplicate: bool = game.request_cataclysm()
	game.aim = Vector3(9, 0, 4)
	_events(38)
	_check("cataclysm_single_spend_and_delayed_damage", first and not duplicate and game.charge == 0 and game.telemetry.ultimate_spent == 1 and center.hp == 1000, {"first": first, "repeat": duplicate, "charge": game.charge, "spent": game.telemetry.ultimate_spent, "hp_at_633ms": center.hp})
	_events(2)
	var hp_after: float = center.hp
	_events(90)
	_check("cataclysm_committed_area_once", hp_after == 855 and center.hp == hp_after and elsewhere.hp == 1000, {"center_hp": center.hp, "new_aim_hp": elsewhere.hp, "secondary_hits": game.telemetry.secondary_hits})
	await _reset()
	game.modifiers.assign(["gravity", "aftershock"])
	var regular := _enemy(Vector3(4, 0, 0))
	var guardian := _enemy(Vector3(-3, 0, 0), 1000.0, "warden")
	game.charge = 100
	game.aim = Vector3.ZERO
	game.request_cataclysm()
	_events(30)
	_check("gravity_pulls_regular_guardian_resists", regular.root.position.x < 3 and guardian.root.position == Vector3(-3, 0, 0), {"regular_position": str(regular.root.position), "guardian_position": str(guardian.root.position)})
	_events(10)
	var first_hp: float = regular.hp
	_events(30)
	var before_echo: float = regular.hp
	_events(12)
	var before_arrival: float = regular.hp
	_events(14)
	_check("aftershock_has_separate_delayed_damage", first_hp == 855 and before_echo == first_hp and before_arrival == first_hp and regular.hp == 790 and game.charge == 0, {"after_main": first_hp, "before_echo": before_echo, "before_ring_arrives": before_arrival, "after_echo": regular.hp, "charge": game.charge})

func _modifier_actions() -> void:
	await _reset()
	var all_toggle := true
	for id in ["fork", "chain", "pierce", "echo", "overload", "gravity", "aftershock", "resonance"]:
		game._on_action("lab_modifier", id)
		all_toggle = all_toggle and id in game.modifiers
		game._on_action("lab_modifier", id)
		all_toggle = all_toggle and not id in game.modifiers
	_check("all_eight_modifiers_equip_remove", all_toggle, {"final_modifiers": game.modifiers})
	for id in ["fork", "pierce", "chain"]:
		game._on_action("lab_modifier", id)
	game._on_action("lab_modifier", "echo")
	game._on_action("lab_modifier", "unknown_inscription")
	_check("three_unique_slots_reject_fourth_invalid", game.modifiers == ["fork", "pierce", "chain"], {"loadout": game.modifiers.duplicate()})
	game.state = "upgrade"
	game.choices.assign(["echo", "gravity", "aftershock"])
	game._on_action("choose_modifier", "echo")
	var before_confirm: Array = game.modifiers.duplicate()
	game._on_action("replace_modifier", 0)
	_check("replacement_keeps_old_until_slot_selected", before_confirm == ["fork", "pierce", "chain"] and game.modifiers == ["echo", "pierce", "chain"], {"before_slot": before_confirm, "after_slot": game.modifiers.duplicate()})
	game.state = "lab"
	game.spawn_queue.clear()
	game._on_action("lab_modifier", "echo")
	game._on_action("lab_modifier", "pierce")
	game._on_action("lab_modifier", "chain")
	var main := _enemy(Vector3(0, 0, -6))
	var side := _enemy(Vector3(1.8, 0, -6))
	game._fire_lance(Vector3(0, 1, 0), Vector3(0, 0, -8), game._cast_context(), 1.0, false)
	_check("removed_modifiers_restore_plain_lance", game.modifiers.is_empty() and main.hp == 966 and side.hp == 1000 and game.telemetry.secondary_hits == 0, {"loadout": game.modifiers, "main_hp": main.hp, "side_hp": side.hp})

func _caps_and_cleanup() -> void:
	await _reset()
	game.modifiers.assign(["fork"])
	var main := _enemy(Vector3(0, 0, -7))
	var left := _enemy(Vector3.FORWARD.rotated(Vector3.UP, -0.22) * 7)
	var right := _enemy(Vector3.FORWARD.rotated(Vector3.UP, 0.22) * 7)
	var context: Dictionary = game._cast_context()
	# A seeded context represents a late child of an already busy cast; the next
	# two real damaging fork branches must admit one and omit the newest one.
	context.children = 31
	game._fire_lance(Vector3(0, 1, 0), Vector3(0, 0, -9), context, 1.0, false)
	_check("child32_omits_newest_damaging_branch", main.hp < 1000 and left.hp < 1000 and right.hp == 1000 and context.children == 32 and game.telemetry.children_omitted > 0, {"hp": [main.hp, left.hp, right.hp], "children": context.children, "omitted": game.telemetry.children_omitted})
	await _reset()
	for _shot in range(125):
		game._spawn_shot(Vector3(0, 1, 0), Vector3.FORWARD, 17.0, 27.0, game._cast_context(), false, 1)
	var accepted: bool = game.request_crown()
	_check("crown_admission_respects_combined128", game.projectiles.size() + game.crown_shards.size() <= 128, {"accepted": accepted, "shots": game.projectiles.size(), "orbiting": game.crown_shards.size(), "cooldown": game.crown_cd})
	await _reset()
	game.request_crown()
	for _shot in range(130):
		game._spawn_shot(Vector3(0, 1, 0), Vector3.FORWARD, 17.0, 27.0, game._cast_context(), false, 1)
	_check("shot_spawn_respects_orbiting_capacity", game.projectiles.size() + game.crown_shards.size() <= 128, {"shots": game.projectiles.size(), "orbiting": game.crown_shards.size()})
	await _reset()
	var baseline: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for cycle in range(3):
		game.modifiers.assign(["fork", "echo", "resonance"])
		game.crown_cd = 0
		game.request_crown()
		_events(260, true, true)
		game._clear_combat()
		await process_frame
		await process_frame
	var final_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_check("effects_and_projectiles_return_to_baseline", game.projectiles.is_empty() and game.crown_shards.is_empty() and game.pending.is_empty() and game.fx._effects.is_empty() and final_nodes == baseline, {"before_nodes": baseline, "after_nodes": final_nodes, "projectiles": game.projectiles.size(), "orbiting": game.crown_shards.size(), "pending": game.pending.size(), "effects": game.fx._effects.size()})
