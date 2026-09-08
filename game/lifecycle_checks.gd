extends SceneTree
## Repeated production actor/spell/reset workloads with stable-cache baselines.
## Counts Godot Resources/Nodes and audio voices; this is not GPU memory or FPS evidence.

const Main = preload("res://scenes/main.tscn")
const STEP := 1.0 / 60.0
const LOADOUTS := [["fork","chain","resonance"],["pierce","overload","echo"],["gravity","aftershock","resonance"]]
var game: Node3D
var output := "res://work/lifecycle-checks"
var checks: Dictionary = {}
var warmup: Array[Dictionary] = []
var cycles: Array[Dictionary] = []
var baseline: Dictionary = {}
var started_usec := 0
var done := false
var tracked_resources: Dictionary = {}

func _initialize() -> void:
	started_usec = Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if not done and Time.get_ticks_usec() - started_usec > 60000000:
		_note("bounded_completion", false)
		_finish()
	return false

func _run() -> void:
	game = Main.instantiate()
	game.save_path = output.path_join("preferences.json")
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.fx.set_process(false)
	game._on_action("lab")
	await _settle()
	var initial := _counts()
	# First pass loads any lazy spell meshes/materials, actor variants and font glyphs.
	# A second identical pass must settle at the same count, before measured cycles.
	for index in 2:
		var exercise := await _exercise(index)
		await _settle()
		var snapshot := _counts()
		warmup.append({"label":"load_cache_stabilization_%d" % (index+1),"exercise":exercise,"settled":snapshot})
		print("LIFECYCLE_WARMUP " + JSON.stringify(warmup.back()))
	baseline = warmup.back().settled.duplicate(true)
	_note("load_cache_stabilizes_before_measurement", _same_counts(warmup[0].settled, baseline))
	_note("warmup_returns_to_live_lab_fixture", _clean_fixture())
	for index in 3:
		var exercise := await _exercise(index+2)
		await _settle()
		var snapshot := _counts()
		var retention := _retention()
		var record := {"cycle":index+1,"exercise":exercise,"settled":snapshot,"retention":retention,"resource_delta":int(snapshot.resources)-int(baseline.resources),"node_delta":int(snapshot.nodes)-int(baseline.nodes),"orphan_delta":int(snapshot.orphan_nodes)-int(baseline.orphan_nodes)}
		cycles.append(record)
		_note("cycle_%d_resources_return_to_warm_baseline" % (index+1), snapshot.resources == baseline.resources and snapshot.owned_resources == baseline.owned_resources)
		_note("cycle_%d_sampled_transient_resources_reclaimed" % (index+1), retention.released > 200 and retention.alive_unowned == 0)
		_note("cycle_%d_nodes_and_orphans_return" % (index+1), snapshot.nodes == baseline.nodes and snapshot.orphan_nodes == baseline.orphan_nodes)
		_note("cycle_%d_actor_fx_audio_reset" % (index+1), _clean_fixture())
		_note("cycle_%d_exercised_real_load" % (index+1), exercise.peak_owned_resources > baseline.owned_resources and exercise.peak_nodes > baseline.nodes and exercise.direct_hits > 0 and exercise.secondary_hits > 0 and exercise.ultimates >= 3 and exercise.max_fx > 0 and exercise.max_damaging_entities > 0)
		_note("cycle_%d_effect_budgets_respected" % (index+1), exercise.max_fx <= 130 and exercise.max_damaging_entities <= 128 and exercise.max_audio_voices <= 20)
		print("LIFECYCLE_CYCLE " + JSON.stringify(record))
	await _teardown()
	_finish(initial)

func _exercise(index: int) -> Dictionary:
	tracked_resources.clear()
	game._clear_combat()
	game.state = "lab"
	game.lab_mode = true
	game.player.position = Vector3(0, 0, 6)
	# All four actor silhouettes and their materials participate in every cycle.
	for actor_index in 24:
		var kind: String = "warden" if actor_index == 23 else ["shardling","channeler","bulwark"][actor_index % 3]
		var at := Vector3((actor_index % 6 - 2.5) * 1.4, 0, -1.0 - floorf(actor_index / 6.0) * 1.5)
		var actor: Dictionary = game.spawn_enemy(kind, at)
		actor.hp = 20000.0
		actor.max_hp = 20000.0
	var before_direct: int = game.telemetry.direct_hits
	var before_secondary: int = game.telemetry.secondary_hits
	var before_ultimate: int = game.telemetry.ultimate_spent
	var metrics := {"seeded_cycle":index,"actors_created":24,"loadouts":LOADOUTS,"peak_resources":0,"peak_owned_resources":0,"peak_nodes":0,"max_fx":0,"max_damaging_entities":0,"max_audio_voices":0,"direct_hits":0,"secondary_hits":0,"ultimates":0}
	for audio_id in game.sound.SOUND_IDS:
		game.sound.play_sound(audio_id, 0.2)
	_update_peak(metrics)
	metrics.peak_owned_resources = _resource_census().size()
	# Complete real spawn tells first; lab targets then remain stationary fixtures.
	for frame in 60:
		_step()
		if frame % 15 == 0: await process_frame
	for loadout in LOADOUTS:
		for id in game.modifiers.duplicate(): game._on_action("lab_modifier", id)
		for id in loadout: game._on_action("lab_modifier", id)
		game._on_action("lab_refill")
		game.aim = Vector3(0, 0, -3)
		game.request_crown()
		game.request_cataclysm()
		for frame in 240:
			game.aim = Vector3(sin(frame * 0.03) * 1.8, 0, -3)
			game.request_lance()
			_step()
			_update_peak(metrics)
			if frame % 30 == 0: metrics.peak_owned_resources = maxi(metrics.peak_owned_resources, _resource_census().size())
			if frame % 15 == 0: await process_frame
	# Include the real directional death/cleanup path for every archetype.
	for actor in game.enemies.duplicate():
		game._hit_enemy(actor, 100000.0, Vector3.RIGHT, true)
	for frame in 42:
		_step()
		_update_peak(metrics)
		if frame % 15 == 0: await process_frame
	metrics.direct_hits = int(game.telemetry.direct_hits) - before_direct
	metrics.secondary_hits = int(game.telemetry.secondary_hits) - before_secondary
	metrics.ultimates = int(game.telemetry.ultimate_spent) - before_ultimate
	return metrics

func _step() -> void:
	game._physics_process(STEP)
	game.fx._process(STEP)
	game.sound._process(STEP)
	# Cast rigs, reactive marks and HUD are included, with no automated user input.
	game._process(STEP)

func _settle() -> void:
	game._on_action("lab_reset")
	game.sound.stop_effects()
	# Let queued actor/mesh deletion, UI layout and audio playback retirement finish.
	for frame in 8: await process_frame
	await create_timer(0.12, true, false, true).timeout
	for frame in 4: await process_frame

func _counts() -> Dictionary:
	return {"owned_resources":_resource_census().size(),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"orphan_nodes":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"world_mesh_cache":game.art._meshes.size(),"world_material_cache":game.art._materials.size(),"audio_voice_nodes":game.sound.get_child_count(),"actors":game.enemies.size(),"fx":game.fx.get_budget_state(),"audio":game.sound.get_audio_state()}

func _same_counts(a: Dictionary, b: Dictionary) -> bool:
	return a.resources == b.resources and a.owned_resources == b.owned_resources and a.nodes == b.nodes and a.orphan_nodes == b.orphan_nodes

func _clean_fixture() -> bool:
	var audio: Dictionary = game.sound.get_audio_state()
	return game.enemies.size() == 6 and game.pending.is_empty() and game.projectiles.is_empty() and game.crown_shards.is_empty() and game.hazards.is_empty() and game.fx.get_budget_state().effects == 0 and audio.active_voices == 0 and audio.loaded_sounds == 15 and audio.voice_limit == 20 and game.sound.get_child_count() == 21 and audio.ambience == (DisplayServer.get_name() != "headless")

func _update_peak(metrics: Dictionary) -> void:
	metrics.peak_resources = maxi(metrics.peak_resources, int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)))
	metrics.peak_nodes = maxi(metrics.peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	metrics.max_fx = maxi(metrics.max_fx, int(game.fx.get_budget_state().effects))
	metrics.max_damaging_entities = maxi(metrics.max_damaging_entities, game.projectiles.size() + game.crown_shards.size())
	metrics.max_audio_voices = maxi(metrics.max_audio_voices, int(game.sound.get_audio_state().active_voices))


func _resource_census() -> Dictionary:
	# The engine's resource monitor does not reveal every transient procedural resource.
	# Observe resources used by actual mesh/material/audio nodes without owning them.
	var owned: Dictionary = {}
	var todo: Array[Node] = [game]
	while not todo.is_empty():
		var node: Node = todo.pop_back()
		if node is MeshInstance3D: _track_resource(node.mesh, owned)
		if node is MultiMeshInstance3D: _track_resource(node.multimesh, owned)
		if node is GeometryInstance3D:
			_track_resource(node.material_override, owned)
			_track_resource(node.material_overlay, owned)
		if node is AudioStreamPlayer: _track_resource(node.stream, owned)
		for child in node.get_children(): todo.append(child)
	for stream in game.sound._streams.values(): _track_resource(stream, owned)
	for resource in game.art._meshes.values(): _track_resource(resource, owned)
	for resource in game.art._materials.values(): _track_resource(resource, owned)
	# Explicitly include the FX module's stable procedural caches, even between casts.
	for property in game.fx.get_property_list():
		if property.type == TYPE_OBJECT:
			var value = game.fx.get(property.name)
			if value is Mesh or value is Material: _track_resource(value, owned)
	return owned

func _track_resource(resource: Resource, owned: Dictionary) -> void:
	if resource == null: return
	var id := resource.get_instance_id()
	if owned.has(id): return
	owned[id] = true
	tracked_resources[id] = weakref(resource)
	if resource is Mesh:
		for surface in resource.get_surface_count(): _track_resource(resource.surface_get_material(surface), owned)
	if resource is MultiMesh: _track_resource(resource.mesh, owned)
	if resource is Material: _track_resource(resource.next_pass, owned)
	if resource is ShaderMaterial: _track_resource(resource.shader, owned)

func _retention() -> Dictionary:
	var owned := _resource_census()
	var report := {"sampled":tracked_resources.size(),"released":0,"alive_owned":0,"alive_unowned":0,"unowned_types":[]}
	for id in tracked_resources:
		if tracked_resources[id].get_ref() == null: report.released += 1
		elif owned.has(id): report.alive_owned += 1
		else:
			report.alive_unowned += 1
			report.unowned_types.append(tracked_resources[id].get_ref().get_class())
	return report

func _teardown() -> void:
	game.state = "verification_done"
	game._clear_combat()
	game.sound.shutdown()
	await create_timer(0.2, true, false, true).timeout
	game.queue_free()
	for frame in 3: await process_frame

func _note(id: String, passed: bool) -> void:
	checks[id] = passed
	print("LIFECYCLE_CHECK " + ("PASS " if passed else "FAIL ") + id)

func _finish(initial: Dictionary = {}) -> void:
	if done: return
	done = true
	var passed := not checks.is_empty()
	for value in checks.values(): passed = passed and bool(value)
	var result := {"passed":passed,"checks":checks,"initial":initial,"warmup":warmup,"baseline":baseline,"cycles":cycles,"seconds":float(Time.get_ticks_usec()-started_usec)/1000000.0,"scope":"Two identical full-load warm-up/reset cycles establish stable lazy-load caches; three further cycles compare Godot OBJECT_RESOURCE_COUNT, OBJECT_NODE_COUNT and OBJECT_ORPHAN_NODE_COUNT plus a unique procedural mesh/material/shader/audio-stream census and sampled WeakRef retirement. Every cycle creates 24 actors of all four archetypes, uses all three spell families and three three-modifier loadouts, drives death, then resets to six live lab targets. All 15 event sounds are requested through the production audio module; headless execution intentionally suppresses playback, so this harness verifies allocated streams/voice nodes and cleanup, not mixed audio or active voice behavior. This is fixed-step lifecycle evidence, not GPU memory reclamation, render quality, normal gameplay or frame-time performance."}
	var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result, "\t"))
	print("LIFECYCLE_RESULT " + JSON.stringify({"passed":passed,"checks":checks,"baseline":baseline,"cycles":cycles}))
	quit(0 if passed else 1)
