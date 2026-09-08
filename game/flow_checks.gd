extends SceneTree
## Bounded transition/persistence checks using the production game and UI actions.
## This complements a normal full-run replay; fixture victories do not prove A09.
## Run with an explicit --save=<repository>/work/flow-checks/check-save.json.

const Game = preload("res://game/arena_game.gd")
var game: Node3D
var save_file := ""
var output_directory := ""
var checks: Dictionary = {}
var details: Dictionary = {}
var started_usec := 0
var finished := false

func _initialize() -> void:
	started_usec = Time.get_ticks_usec()
	Engine.max_fps = 120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save="):
			save_file = ProjectSettings.globalize_path(argument.trim_prefix("--save=")).simplify_path()
	var allowed := ProjectSettings.globalize_path("res://work/flow-checks/").simplify_path().trim_suffix("/") + "/"
	if not save_file.begins_with(allowed) or save_file.get_file().is_empty():
		printerr("FLOW_CHECKS requires --save=<repository>/work/flow-checks/check-save.json; user preferences will not be touched.")
		quit(2)
		return
	output_directory = save_file.get_base_dir()
	DirAccess.make_dir_recursive_absolute(output_directory)
	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(save_file)
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if not finished and Time.get_ticks_usec() - started_usec > 30000000:
		_check("bounded_completion", false, {"reason":"30 second watchdog expired"})
		_finish()
	return false

func _run() -> void:
	await _new_game()
	_check("no_scenario_focus_bypass", not game.test_options.has("scenario"))
	_check("missing_save_defaults", game.settings == Game.DEFAULT_SETTINGS and game.best.is_empty())
	await _check_upgrades()
	await _check_pause_focus_navigation()
	await _check_lab()
	await _check_persistence()
	await _destroy_game()
	_finish()

func _new_game() -> void:
	paused = false
	game = Game.new()
	root.add_child(game)
	await _frames(3)
	_check("isolated_save_path_" + str(checks.size()), ProjectSettings.globalize_path(game.save_path).simplify_path() == save_file)

func _destroy_game() -> void:
	_release_inputs()
	paused = false
	if is_instance_valid(game):
		game.state = "verification_done"
		game._clear_combat()
		game.queue_free()
	await _frames(3)
	game = null

func _check_upgrades() -> void:
	game._on_action("start")
	var chosen: Array[String] = []
	for slot in 3:
		# Arrange an empty encounter through the production cleanup/transition API.
		# Enemy combat/progression is covered by the separate normal run scenario.
		game._clear_combat()
		game.health = 50.0 if slot == 0 else 95.0
		game.charge = 61.0
		game._complete_wave()
		_check("upgrade_%d_three_distinct_offers" % slot, game.choices.size() == 3 and _unique(game.choices) and not _intersects(game.choices, chosen))
		_check("upgrade_%d_healing_charge" % slot, game.health == (75.0 if slot == 0 else 100.0) and game.charge == 61.0)
		var casts_before: int = game.total_casts
		var position_before: Vector3 = game.player.position
		for input in ["lance", "crown", "cataclysm", "move_right", "dash"]:
			Input.action_press(input)
		await _physics_ticks(4)
		_check("upgrade_%d_combat_input_isolated" % slot, paused and game.state == "upgrade" and game.total_casts == casts_before and game.player.position == position_before)
		game._on_action("choose_modifier", "not_a_law")
		_check("upgrade_%d_invalid_choice_rejected" % slot, game.state == "upgrade" and game.modifiers == chosen)
		var selection: String = game.choices[0]
		chosen.append(selection)
		game._on_action("choose_modifier", selection)
		_check("upgrade_%d_choice_equipped" % slot, game.modifiers == chosen and game.wave == slot + 2 and game.state == "run" and not paused)
		await _physics_ticks(3)
		_check("upgrade_%d_held_cast_does_not_leak" % slot, game.total_casts == casts_before and not game.input_armed)
		_release_inputs()
		await _physics_ticks(2)
		_check("upgrade_%d_release_rearms_casting" % slot, game.input_armed)
	game._clear_combat()
	game._complete_wave()
	var replacement: String = game.choices[0]
	var old: Array = game.modifiers.duplicate()
	game._on_action("choose_modifier", replacement)
	_check("replacement_preview_preserves_build", paused and game.state == "upgrade" and game.modifiers == old and game.ui._screen_data.get("replace_id") == replacement and game.ui._screen_data.get("modifiers") == old)
	game._on_action("replace_modifier", -1)
	_check("replacement_invalid_slot_rejected", game.modifiers == old and game.state == "upgrade")
	var expected: Array = old.duplicate()
	expected[1] = replacement
	game._on_action("replace_modifier", 1)
	_check("replacement_applies_exactly_one_slot", game.modifiers == expected and game.modifiers.size() == 3 and _unique(game.modifiers) and game.pending_modifier.is_empty() and game.wave == 5)
	game._clear_combat()
	game._complete_wave()
	game._on_action("skip")
	_check("skip_keeps_build_enters_finale", game.modifiers == expected and game.wave == 6 and game.state == "run" and not paused)
	details["upgrade_fixture_final_build"] = expected

func _check_pause_focus_navigation() -> void:
	game.charge = 100.0
	game.request_lance()
	game.request_crown()
	game.request_cataclysm()
	game._on_action("pause")
	var before := _combat_clocks()
	await _physics_ticks(8)
	_check("pause_freezes_pending_spells_cooldowns_and_movement", paused and game.state == "pause" and _combat_clocks() == before, {"pending":game.pending.size(),"crown_shards":game.crown_shards.size()})
	game._on_action("settings")
	_check("settings_from_pause_preserves_pause", paused and game.state == "settings")
	game._on_action("back")
	_check("settings_back_returns_to_pause", paused and game.state == "pause")
	game._on_action("resume")
	_check("resume_restores_run", not paused and game.state == "run" and not game.input_armed)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check("focus_loss_pauses_run", paused and game.state == "pause" and not game.input_armed)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check("focus_return_does_not_auto_resume", paused and game.state == "pause" and not game.input_armed)
	Input.action_press("lance")
	game._on_action("resume")
	var casts_before: int = game.total_casts
	await _physics_ticks(4)
	_check("focus_resume_held_mouse_does_not_cast", game.total_casts == casts_before and not game.input_armed)
	_release_inputs()
	await _physics_ticks(2)
	_check("focus_resume_release_rearms", game.input_armed)
	game._on_action("pause")
	var mods: Array = game.modifiers.duplicate()
	game._on_action("restart")
	_check("active_restart_requests_confirmation", paused and game.state == "confirm" and game.modifiers == mods)
	game._on_action("cancel")
	_check("cancel_restart_keeps_run", paused and game.state == "pause" and game.modifiers == mods)
	game._on_action("restart")
	game._on_action("confirm")
	_check("confirmed_restart_cleans_run", game.state == "run" and game.wave == 1 and not paused and game.modifiers.is_empty() and game.health == 100.0 and game.charge == 35.0 and game.elapsed == 0.0 and game.kills == 0 and game.total_casts == 0 and _transients_empty() and game.enemies.is_empty())
	game._on_action("pause")
	game._on_action("title")
	_check("active_title_requests_confirmation", game.state == "confirm" and paused)
	game._on_action("confirm")
	_check("confirmed_title_cleans_combat", game.state == "title" and not paused and not game.lab_mode and game.modifiers.is_empty() and _transients_empty() and game.enemies.is_empty() and game.spawn_queue.is_empty())
	game._on_action("settings")
	game._on_action("back")
	_check("settings_from_title_returns_unpaused_title", game.state == "title" and not paused)

func _check_lab() -> void:
	game._on_action("lab")
	for id in ["fork", "chain", "resonance"]:
		game._on_action("lab_modifier", id)
	_check("lab_equips_three_unique_laws", game.modifiers == ["fork", "chain", "resonance"])
	game._on_action("lab_modifier", "pierce")
	_check("lab_fourth_law_rejected", game.modifiers == ["fork", "chain", "resonance"])
	game._on_action("lab_modifier", "fork")
	game._on_action("lab_modifier", "gravity")
	_check("lab_remove_and_add", game.modifiers == ["chain", "resonance", "gravity"])
	game.health = 24.0
	game.charge = 0.0
	game.crown_cd = 3.0
	game._on_action("lab_refill")
	_check("lab_refill_restores_resources", game.health == 100.0 and game.charge == 100.0 and game.crown_cd == 0.0)
	game.aim = Vector3(0, 0, -3)
	var accepted := [game.request_lance(), game.request_crown(), game.request_cataclysm()]
	_check("lab_uses_all_three_production_spells", accepted == [true, true, true] and game.total_casts == 3)
	await _physics_ticks(63)
	game._on_action("lab_refill")
	game.request_cataclysm()
	var mods: Array = game.modifiers.duplicate()
	var old_targets: Array = []
	for enemy in game.enemies: old_targets.append(weakref(enemy.root))
	var before := {"pending":game.pending.size(), "shards":game.crown_shards.size(), "projectiles":game.projectiles.size()}
	_check("lab_reset_fixture_has_live_spell_work", before.pending > 0 and before.shards > 0 and before.projectiles > 0, before)
	game._on_action("lab_reset")
	_check("lab_reset_cleans_transients_preserves_build", _transients_empty() and game.modifiers == mods and game.enemies.size() == 6 and game.health == 100.0 and game.charge == 100.0)
	await _frames(3)
	var old_freed := true
	for reference in old_targets:
		old_freed = old_freed and reference.get_ref() == null
	_check("lab_reset_reclaims_old_targets", old_freed)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check("focus_loss_pauses_lab", paused and game.state == "pause")
	game._on_action("resume")
	_check("lab_resume_restores_lab_controls", game.state == "lab" and game.ui._screen == "lab" and not paused)
	game._on_action("pause")
	game._on_action("title")
	game._on_action("confirm")
	_check("lab_title_clears_mode_and_build", game.state == "title" and not game.lab_mode and game.modifiers.is_empty() and game.enemies.is_empty() and _transients_empty())

func _check_persistence() -> void:
	var preferences := {"master":0.31,"effects":0.62,"ambience":0.17,"shake":0.0,"reduced_flash":true,"reduced_particles":true}
	game._on_action("settings")
	for key in preferences:
		game._on_action("setting", {"key":key,"value":preferences[key]})
	_check("settings_immediately_apply", game.settings == preferences and is_equal_approx(game.sound.get_audio_state().master, 0.31))
	_check("settings_write_file", FileAccess.file_exists(save_file))
	game._on_action("back")
	game._on_action("start")
	# Result fixtures exercise production win/lose/save transitions, not a combat win.
	game.wave = 4
	game.invulnerable = 0.0
	game._damage_player(500.0)
	_check("defeat_result_reports_actual_wave", game.state == "defeat" and game.ui._screen_data.get("wave") == 4)
	game._on_action("restart")
	_check("defeat_restart_is_clean", game.state == "run" and game.wave == 1 and game.health == 100.0 and game.modifiers.is_empty() and _transients_empty())
	for slot in 3:
		game._clear_combat()
		game._complete_wave()
		game._on_action("choose_modifier", game.choices[0])
	game.wave = 6
	game.elapsed = 612.5
	game.kills = 99
	game._finish_run(true)
	var record: Dictionary = game.best.duplicate(true)
	_check("first_victory_result_has_current_record", game.state == "victory" and game.ui._screen_data.get("best") == record and float(record.get("elapsed", 0)) == 612.5 and record.get("modifiers", []).size() == 3 and game.ui._screen_data.get("previous_best", {}).is_empty())
	game._on_action("restart")
	game.wave = 6
	game.elapsed = 700.0
	game._finish_run(true)
	_check("slower_victory_retains_best", game.best == record and game.ui._screen_data.get("previous_best") == record)
	var disk_before := FileAccess.get_file_as_string(save_file)
	game._on_action("title")
	game._on_action("lab")
	game.elapsed = 1.0
	game.kills = 900
	game._finish_run(true)
	_check("lab_cannot_replace_best_record", game.best == record)
	_check("lab_does_not_modify_save_file", FileAccess.get_file_as_string(save_file) == disk_before)
	await _destroy_game()
	await _new_game()
	_check("relaunch_loads_all_preferences", game.settings == preferences, game.settings)
	_check("relaunch_loads_best_summary", _same_record(game.best, record), game.best)
	_check("lab_did_not_write_record", FileAccess.get_file_as_string(save_file) == disk_before and _same_record(game.best, record))
	await _destroy_game()
	_write_save("{malformed save")
	await _new_game()
	_check("malformed_save_falls_back_and_launches", game.state == "title" and game.settings == Game.DEFAULT_SETTINGS and game.best.is_empty())
	game._on_action("start")
	_check("malformed_save_does_not_prevent_play", game.state == "run" and game.wave == 1)
	await _destroy_game()
	_write_save(JSON.stringify({"settings":{"master":"loud","effects":4,"ambience":-2,"reduced_flash":"yes"},"best":{"elapsed":"fast"}}))
	await _new_game()
	_check("invalid_save_types_fall_back_and_values_clamp", game.settings.master == Game.DEFAULT_SETTINGS.master and game.settings.effects == 1.0 and game.settings.ambience == 0.0 and game.settings.reduced_flash == false and game.best.is_empty(), game.settings)
	await _destroy_game()
	DirAccess.remove_absolute(save_file)
	await _new_game()
	_check("missing_save_relaunch_defaults", game.state == "title" and game.settings == Game.DEFAULT_SETTINGS and game.best.is_empty())
	details["persistence_record_fixture"] = record
	details["scope"] = "Production transitions and save/load re-instantiation. This is not normal-run victory, OS-driven focus, rendered UI, or performance evidence. Laboratory reset exercised live Crown projectiles and pending Cataclysm, not a guardian pulse hazard."

func _combat_clocks() -> Dictionary:
	var waiting: Array = []
	for event in game.pending: waiting.append([event.kind, event.time])
	var crown: Array = []
	for shard in game.crown_shards: crown.append([shard.age, shard.node.position])
	return {"elapsed":game.elapsed,"lance":game.lance_cd,"crown":game.crown_cd,"dash":game.dash_cd,"position":game.player.position,"waiting":waiting,"orbit":crown}

func _transients_empty() -> bool:
	return game.pending.is_empty() and game.projectiles.is_empty() and game.crown_shards.is_empty() and game.hazards.is_empty()

func _release_inputs() -> void:
	for input in ["lance", "crown", "cataclysm", "dash", "move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(input)

func _frames(count: int) -> void:
	for i in count: await process_frame

func _physics_ticks(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func _unique(values: Array) -> bool:
	var seen: Array = []
	for value in values:
		if value in seen: return false
		seen.append(value)
	return true

func _intersects(a: Array, b: Array) -> bool:
	for value in a:
		if value in b: return true
	return false

func _same_record(a: Dictionary, b: Dictionary) -> bool:
	# JSON's numeric representation is floating point; kills remain the same count.
	return is_equal_approx(float(a.get("elapsed", -1)), float(b.get("elapsed", -2))) and int(a.get("kills", -1)) == int(b.get("kills", -2)) and a.get("modifiers", []) == b.get("modifiers", [])

func _write_save(text: String) -> void:
	var file := FileAccess.open(save_file, FileAccess.WRITE)
	if file == null:
		_check("save_fixture_write", false, {"path":save_file})
		return
	file.store_string(text)
	file.close()

func _check(name: String, passed: bool, evidence: Dictionary = {}) -> void:
	checks[name] = passed
	if not evidence.is_empty(): details[name] = evidence.duplicate(true)
	print("FLOW_CHECK " + ("PASS " if passed else "FAIL ") + name)

func _finish() -> void:
	if finished: return
	finished = true
	var passed := not checks.is_empty()
	for value in checks.values(): passed = passed and bool(value)
	var result := {"passed":passed,"checks":checks,"details":details,"save_path":save_file,"elapsed_seconds":(Time.get_ticks_usec()-started_usec)/1000000.0}
	var file := FileAccess.open(output_directory.path_join("result.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result, "\t"))
	print("FLOW_RESULT " + JSON.stringify(result))
	quit(0 if passed else 1)
