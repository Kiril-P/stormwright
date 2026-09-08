extends Node3D
## Bounded, mesh-batched spell choreography. Gameplay owns hit queries and timing.
## All animation advances on delta; pausing the tree suspends every transient.

const ENERGY_SHADER = preload("res://game/shaders/storm_energy.gdshader")
const CRYSTAL_SHADER = preload("res://game/shaders/storm_crystal.gdshader")
const DUST_SHADER = preload("res://game/shaders/storm_dust.gdshader")
const CYAN := Color(0.075, 0.63, 1.0, 0.7)
const ICE := Color(0.54, 0.93, 1.0, 0.9)
const WHITE := Color(0.83, 1.0, 1.0, 0.96)
const CORAL := Color(1.0, 0.14, 0.065, 0.82)
const MAX_TRANSIENTS := 130
const MAX_LIGHTS := 6

var _effects: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _energy: ShaderMaterial
var _crystal: ShaderMaterial
var _hostile_crystal: ShaderMaterial
var _stone: StandardMaterial3D
var _diamond: ArrayMesh
var _small_diamond: ArrayMesh
var _shard_seams: ArrayMesh
var _hostile_seams: ArrayMesh
var _dust_sphere: SphereMesh
var _dust_material: ShaderMaterial
var _reduced_particles := false
var _reduced_flash := false
var _light_count := 0
var _sequence := 0


func _ready() -> void:
	_rng.seed = 834421
	_prepare_materials()


func _prepare_materials() -> void:
	if _energy != null:
		return
	_energy = ShaderMaterial.new()
	_energy.shader = ENERGY_SHADER
	_crystal = ShaderMaterial.new()
	_crystal.shader = CRYSTAL_SHADER
	_hostile_crystal = ShaderMaterial.new()
	_hostile_crystal.shader = CRYSTAL_SHADER
	_hostile_crystal.set_shader_parameter("hostile", true)
	_stone = StandardMaterial3D.new()
	_stone.albedo_color = Color(0.10, 0.15, 0.18)
	_stone.metallic = 0.25
	_stone.roughness = 0.72
	_stone.cull_mode = BaseMaterial3D.CULL_DISABLED
	_diamond = _crystal_mesh(1.0)
	_small_diamond = _crystal_mesh(0.6, true)
	_dust_sphere = SphereMesh.new()
	_dust_sphere.radius = 1.0
	_dust_sphere.height = 2.0
	_dust_sphere.radial_segments = 12
	_dust_sphere.rings = 6
	_dust_material = ShaderMaterial.new()
	_dust_material.shader = DUST_SHADER


func set_quality(reduced_particles: bool, reduced_flash: bool) -> void:
	_reduced_particles = reduced_particles
	_reduced_flash = reduced_flash
	if _energy:
		_energy.set_shader_parameter("radiance", 0.75 if reduced_flash else 1.8)


func beam(start: Vector3, end: Vector3, power: float = 1.0) -> void:
	if start.distance_squared_to(end) < 0.0004:
		return
	var effect := _begin("beam", 0.38, start)
	if effect.is_empty():
		return
	var displacement := end - start
	var length := displacement.length()
	var axis := displacement / length
	var right := axis.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	var up := right.cross(axis).normalized()
	var strength := clampf(power, 0.25, 2.5)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var main := PackedVector3Array()
	var count := clampi(int(length * 2.4), 14, 38)
	for index in range(count + 1):
		var t := float(index) / count
		var envelope := sin(t * PI)
		var noise := right * _rng.randf_range(-0.20, 0.20) + up * _rng.randf_range(-0.13, 0.13)
		main.append(displacement * t + noise * envelope * strength)
	_append_tube(vertices, colors, main, 0.093 * sqrt(strength), WHITE, 6)
	_append_tube(vertices, colors, main, 0.23 * sqrt(strength), Color(0.07, 0.48, 0.95, 0.18), 6)
	# Unequal helices wrap the core and peel away: a turbulent volume, not parallel lines.
	for strand in range(4 if _reduced_particles else 6):
		var path := PackedVector3Array()
		var phase := float(strand) * 1.79
		for index in range(count + 1):
			var t := float(index) / count
			var envelope := pow(sin(t * PI), 0.65)
			var spin := t * (15.0 + strand * 1.7) + phase
			var radius := (0.25 + strand * 0.045) * envelope * sqrt(strength)
			path.append(displacement * t + (right * cos(spin) + up * sin(spin)) * radius + right * _rng.randf_range(-0.13, 0.13))
		_append_tube(vertices, colors, path, (0.026 + (strand % 2) * 0.026) * sqrt(strength), ICE if strand % 2 == 0 else CYAN, 4)
	# Fine forked offshoots finish in dark gaps to preserve the main discharge silhouette.
	for branch in range(3 if _reduced_particles else 7):
		var t := _rng.randf_range(0.20, 0.90)
		var origin := displacement * t
		var lateral := (right * _rng.randf_range(-1.3, 1.3) + up * _rng.randf_range(-0.8, 1.0)) * strength
		var branch_end := origin + axis * _rng.randf_range(0.7, 1.7) + lateral
		var points := _jagged(origin, branch_end, 7, 0.12)
		_append_tube(vertices, colors, points, 0.018 * strength, Color(0.27, 0.77, 1.0, 0.6), 3)
	var root: Node3D = effect.root
	_add_mesh(root, _mesh(vertices, colors), _energy, effect)
	effect.axis = axis
	_flash(effect, Vector3.ZERO, 2.4 * strength, 4.5)
	# Muzzle petals and falling residual motes are distinct from a hit burst.
	_sparks(effect, Vector3.ZERO, axis, 7 if _reduced_particles else 13, strength * 0.6, true)
	_effects.append(effect)


func burst(at: Vector3, power: float = 1.0, hostile: bool = false) -> void:
	var effect := _begin("burst", 0.65, at)
	if effect.is_empty():
		return
	var strength := clampf(power, 0.3, 2.7)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var tint := CORAL if hostile else ICE
	var rays := 7 if _reduced_particles else 11
	for index in range(rays):
		var angle := index * TAU / rays + _rng.randf_range(-0.2, 0.2)
		var end := Vector3(cos(angle), _rng.randf_range(0.1, 1.0), sin(angle)) * _rng.randf_range(0.65, 1.55) * strength
		_append_tube(vertices, colors, _jagged(Vector3.ZERO, end, 5, 0.10 * strength), 0.035 * strength, tint, 4)
	_append_star(vertices, colors, Vector3.ZERO, 0.58 * strength, 7, tint)
	_add_mesh(effect.root, _mesh(vertices, colors), _energy, effect)
	_sparks(effect, Vector3.ZERO, Vector3.UP, 8 if _reduced_particles else 18, strength, false, hostile)
	if power >= 0.85:
		_debris(effect, strength * 0.60, 3 if _reduced_particles else 7)
		_dust(effect, strength * 0.65, 3 if _reduced_particles else 5)
	_flash(effect, Vector3(0, 0.2, 0), 3.8 * strength, 4.5 + strength, hostile)
	effect.expand = true
	_effects.append(effect)
	if not hostile and power > 0.65:
		_scar(Vector3(at.x, 0.035, at.z), strength)


func ring(at: Vector3, radius: float, duration: float, hostile: bool = false, linear_speed: float = 0.0) -> Node3D:
	var effect := _begin("ring", maxf(duration, 0.12), Vector3(at.x, maxf(at.y, 0.055), at.z))
	if effect.is_empty():
		return null
	var tint := CORAL if hostile else CYAN
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	_append_ring(vertices, colors, 1.0, 0.025, tint, 80)
	_append_ring(vertices, colors, 0.945, 0.009, Color(tint, 0.3), 80)
	for index in range(16):
		var a := index * TAU / 16.0
		var direction := Vector3(cos(a), 0, sin(a))
		_append_tube(vertices, colors, PackedVector3Array([direction * 0.87, direction]), 0.006, Color(tint, 0.5), 3)
	_add_mesh(effect.root, _mesh(vertices, colors), _energy, effect)
	effect.radius = maxf(radius, 0.1)
	effect.linear_speed = maxf(linear_speed, 0.0)
	effect.root.scale = Vector3.ONE * radius * 0.06
	_effects.append(effect)
	return effect.root


func charge(at: Vector3, power: float = 1.0, follow: Node3D = null) -> void:
	var effect := _begin("charge", 0.27, at)
	if effect.is_empty():
		return
	if is_instance_valid(follow):
		effect.follow = weakref(follow)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var strength := clampf(power, 0.3, 2.5)
	for strand in range(3):
		var points := PackedVector3Array()
		for index in range(17):
			var t := index / 16.0
			var angle := strand * TAU / 3.0 + t * 4.7
			var radius := (0.1 + t * 0.7) * strength
			points.append(Vector3(cos(angle) * radius, (t - 0.5) * 0.6 * strength, sin(angle) * radius))
		_append_tube(vertices, colors, points, 0.022 * strength, ICE, 4)
	_append_star(vertices, colors, Vector3.ZERO, 0.14 * strength, 5, WHITE)
	_add_mesh(effect.root, _mesh(vertices, colors), _energy, effect)
	_flash(effect, Vector3.ZERO, strength * 0.8, 2.5)
	_effects.append(effect)


func trail(start: Vector3, end: Vector3, hostile: bool = false) -> void:
	if start.distance_squared_to(end) < 0.0001:
		return
	var effect := _begin("trail", 0.24 if hostile else 0.34, start)
	if effect.is_empty():
		return
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var vector := end - start
	var perpendicular := vector.cross(Vector3.UP).normalized()
	var tint := CORAL if hostile else ICE
	var points := PackedVector3Array([Vector3.ZERO, vector * 0.5 + Vector3.UP * 0.045, vector])
	_append_tube(vertices, colors, points, 0.045 if hostile else 0.037, tint, 4)
	if not _reduced_particles:
		_append_tube(vertices, colors, PackedVector3Array([perpendicular * 0.09, vector + perpendicular * 0.06]), 0.011, Color(tint, 0.38), 3)
	_add_mesh(effect.root, _mesh(vertices, colors), _energy, effect)
	_effects.append(effect)


func shard(at: Vector3, direction: Vector3, scale_value: float = 1.0, hostile: bool = false) -> Node3D:
	_prepare_materials()
	var root := Node3D.new()
	root.name = "HostileShard" if hostile else "StormShard"
	root.position = at
	root.scale = Vector3.ONE * scale_value
	if direction.length_squared() > 0.001:
		root.basis = Basis.looking_at(direction.normalized(), Vector3.UP if absf(direction.normalized().y) < 0.99 else Vector3.RIGHT).scaled(Vector3.ONE * scale_value)
	var shell := MeshInstance3D.new()
	shell.mesh = _diamond
	shell.material_override = _hostile_crystal if hostile else _crystal
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shell)
	if _shard_seams == null:
		_shard_seams = _make_shard_seams(false)
	if hostile and _hostile_seams == null:
		_hostile_seams = _make_shard_seams(true)
	var seams := MeshInstance3D.new()
	seams.mesh = _hostile_seams if hostile else _shard_seams
	seams.material_override = _energy
	seams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(seams)
	return root


func _make_shard_seams(hostile: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var edge_tint := CORAL if hostile else ICE
	# These geometry resources are shared by all projectiles of the same allegiance.
	for index in range(5):
		var angle := index * TAU / 5.0
		var waist := Vector3(cos(angle) * 0.34, sin(angle) * 0.34, 0.03)
		_append_tube(vertices, colors, PackedVector3Array([Vector3(0, 0, -0.98), waist, Vector3(0, 0, 0.7)]), 0.014, edge_tint, 3)
	_append_tube(vertices, colors, PackedVector3Array([Vector3(0, 0, -1.02), Vector3(0, 0, 0.85)]), 0.038, Color(1.0, 0.58, 0.30, 0.94) if hostile else WHITE, 4)
	for index in range(4):
		var angle := index * TAU / 4.0 + 0.5
		var center := Vector3(cos(angle) * 0.40, sin(angle) * 0.40, 0.12 + (index % 2) * 0.24)
		_append_star(vertices, colors, center, 0.105, 4, Color(1.0, 0.21, 0.08, 0.7) if hostile else Color(0.14, 0.81, 1.0, 0.7))
	return _mesh(vertices, colors)


func cataclysm(at: Vector3, power: float = 1.0) -> void:
	var effect := _begin("cataclysm", 1.85, Vector3(at.x, 0.08, at.z))
	if effect.is_empty():
		return
	var strength := clampf(power, 0.55, 2.2)
	var root: Node3D = effect.root
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	_append_star(vertices, colors, Vector3(0, 0.1, 0), 1.35 * strength, 9, WHITE)
	for index in range(9):
		var angle := index * TAU / 9.0
		var end := Vector3(cos(angle), 0.015, sin(angle)) * (3.5 + (index % 3) * 0.45) * strength
		_append_tube(vertices, colors, _jagged(Vector3(0, 0.05, 0), end, 13, 0.17), 0.045, ICE, 4)
	var star := _add_mesh(root, _mesh(vertices, colors), _energy, effect)
	effect.star = star
	vertices = PackedVector3Array()
	colors = PackedColorArray()
	# Twisting, separated vertical blades; the spaces between them keep targets visible.
	for index in range(5):
		var points := PackedVector3Array()
		for step in range(27):
			var t := step / 26.0
			var angle := index * TAU / 5.0 + t * 3.2
			var radius := (0.3 + sin(t * PI) * 1.25) * strength
			points.append(Vector3(cos(angle) * radius, t * (4.7 + (index % 2) * 1.2) * sqrt(strength), sin(angle) * radius))
		_append_tube(vertices, colors, points, 0.13 * strength, Color(0.065, 0.62, 1.0, 0.48), 5)
		_append_tube(vertices, colors, points, 0.029 * strength, WHITE, 4)
	var column := _add_mesh(root, _mesh(vertices, colors), _energy, effect)
	effect.column = column
	_sparks(effect, Vector3(0, 0.35, 0), Vector3.UP, 20 if _reduced_particles else 44, strength * 2.3, false)
	_debris(effect, strength)
	_dust(effect, strength * 1.6, 6 if _reduced_particles else 13)
	_flash(effect, Vector3(0, 2.1, 0), 16.0 * strength, 9.5 * sqrt(strength))
	_effects.append(effect)
	# Rings have separate launch moments, widths and settling times, not one white disk.
	for index in range(3):
		var ripple := _begin("ripple", 1.30 + index * 0.14, Vector3(at.x, 0.065 + index * 0.03, at.z))
		if ripple.is_empty():
			continue
		vertices = PackedVector3Array()
		colors = PackedColorArray()
		_append_ring(vertices, colors, 1.0, 0.032 - index * 0.006, Color(0.29, 0.86, 1.0, 0.9 - index * 0.12), 100)
		_append_ring(vertices, colors, 0.97, 0.006, Color(0.60, 0.95, 1.0, 0.68), 100)
		_add_mesh(ripple.root, _mesh(vertices, colors), _energy, ripple)
		ripple.radius = (5.3 - index * 0.65) * strength
		ripple.delay = index * 0.11
		ripple.root.scale = Vector3.ONE * 0.04
		_effects.append(ripple)
	_scar(Vector3(at.x, 0.038, at.z), strength * 3.1)


func clear_all() -> void:
	for effect in _effects:
		if is_instance_valid(effect.root):
			effect.root.queue_free()
	_effects.clear()
	_light_count = 0


func _exit_tree() -> void:
	# Queued scene destruction can happen before another process tick; release the
	# resource-bearing dictionaries now rather than waiting for the next fade pass.
	_effects.clear()
	_light_count = 0
	_energy = null
	_crystal = null
	_hostile_crystal = null
	_stone = null
	_diamond = null
	_small_diamond = null
	_shard_seams = null
	_hostile_seams = null
	_dust_sphere = null
	_dust_material = null


func get_budget_state() -> Dictionary:
	return {"effects": _effects.size(), "limit": MAX_TRANSIENTS, "lights": _light_count, "light_limit": MAX_LIGHTS}


func _process(delta: float) -> void:
	for index in range(_effects.size() - 1, -1, -1):
		var effect := _effects[index]
		effect.age += delta
		var age: float = effect.age
		var t: float = clampf(age / effect.life, 0.0, 1.0)
		if t >= 1.0 or not is_instance_valid(effect.root) or effect.root.is_queued_for_deletion():
			if effect.has("light"):
				_light_count = maxi(0, _light_count - 1)
			if is_instance_valid(effect.root):
				effect.root.queue_free()
			_effects.remove_at(index)
			continue
		var opacity := pow(1.0 - t, 1.4)
		var root: Node3D = effect.root
		match effect.kind:
			"beam":
				opacity = (1.0 - smoothstep(0.12, 1.0, t)) * (0.83 + 0.17 * sin(t * 45.0))
			"charge":
				if effect.has("follow"):
					var attachment: Node3D = effect.follow.get_ref() as Node3D
					if is_instance_valid(attachment) and attachment.is_inside_tree():
						root.global_position = attachment.global_position
				root.scale = Vector3.ONE * lerpf(1.0, 0.24, t)
				root.rotation.y += delta * 7.0
				opacity = sin(t * PI) * 0.85
			"burst":
				root.scale = Vector3.ONE * (0.65 + 0.70 * (1.0 - pow(1.0 - t, 3)))
				opacity = pow(1.0 - t, 2.6)
			"ring":
				var delay: float = effect.get("delay", 0.0)
				var progress := clampf((age - delay) / maxf(effect.life - delay, 0.1), 0.0, 1.0)
				root.scale = Vector3.ONE * maxf(0.025, effect.radius * (1.0 - pow(1.0 - progress, 3.0)))
				opacity = 0.0 if age < delay else (1.0 - progress) * minf(progress * 12.0, 1.0)
				if effect.linear_speed > 0.0:
					root.scale = Vector3.ONE * maxf(0.025, minf(effect.radius, age * effect.linear_speed))
					opacity = 1.0 - smoothstep(0.86, 1.0, t)
			"ripple":
				var delay: float = effect.get("delay", 0.0)
				var local_age := maxf(age - delay, 0.0)
				var expansion := clampf(local_age / 0.39, 0.0, 1.0)
				var progress := clampf(local_age / maxf(effect.life - delay, 0.1), 0.0, 1.0)
				root.scale = Vector3.ONE * maxf(0.025, effect.radius * (1.0 - pow(1.0 - expansion, 2.0)))
				opacity = 0.0 if age < delay else pow(1.0 - progress, 1.7) * minf(local_age * 35.0, 1.0)
			"cataclysm":
				var column: MeshInstance3D = effect.column
				column.scale = Vector3(1.0 + t * 0.8, minf(1.0, age * 5.0), 1.0 + t * 0.8)
				column.rotation.y = age * 1.8
				var star: MeshInstance3D = effect.star
				star.scale = Vector3.ONE * (0.5 + minf(age * 5.0, 1.0) * 0.9)
				opacity = pow(1.0 - t, 1.8) * minf(age * 25.0, 1.0)
			"scar":
				opacity = pow(1.0 - t, 2.1) * 0.30
		for mesh in effect.meshes:
			if is_instance_valid(mesh):
				mesh.set_instance_shader_parameter("opacity", opacity)
		if effect.has("light") and is_instance_valid(effect.light):
			effect.light.light_energy = effect.light_energy * pow(1.0 - t, 4.0) * (0.23 if _reduced_flash else 1.0)
		if effect.has("particles"):
			_animate_particles(effect, age, t)
		if effect.has("debris"):
			_animate_debris(effect, age, t)
		if effect.has("dust"):
			_animate_dust(effect, age, t)


func _begin(kind: String, life: float, at: Vector3) -> Dictionary:
	_prepare_materials()
	var limit := 85 if _reduced_particles else MAX_TRANSIENTS
	# Reserve room for cast silhouettes. A dense trail field may lose a few newest
	# fragments, but must never make a real Cataclysm detonation invisible.
	if kind in ["trail", "scar"] and _effects.size() >= limit - 24:
		return {}
	if _effects.size() >= limit:
		if kind not in ["cataclysm", "ripple", "beam", "charge"]:
			return {}
		var retire := -1
		for index in range(_effects.size()):
			if _effects[index].kind in ["trail", "scar", "burst"]:
				retire = index
				break
		if retire < 0:
			return {}
		var old := _effects[retire]
		if old.has("light"):
			_light_count = maxi(0, _light_count - 1)
		if is_instance_valid(old.root):
			old.root.queue_free()
		_effects.remove_at(retire)
	_sequence += 1
	var root := Node3D.new()
	root.name = "FX_%s_%d" % [kind, _sequence]
	root.position = at
	add_child(root)
	return {"root": root, "kind": kind, "age": 0.0, "life": life, "meshes": []}


func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, effect: Dictionary) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	if not effect.is_empty():
		effect.meshes.append(instance)
	return instance


func _flash(effect: Dictionary, at: Vector3, energy: float, reach: float, hostile: bool = false) -> void:
	if _light_count >= MAX_LIGHTS:
		# A new ultimate must illuminate the floor even when older hit flashes fill
		# the light budget. Retire the dimmest existing light, preserving the cap.
		var weakest: Dictionary = {}
		var weakest_energy := energy
		for active in _effects:
			if active.has("light") and is_instance_valid(active.light) and active.light.light_energy < weakest_energy:
				weakest = active
				weakest_energy = active.light.light_energy
		if weakest.is_empty():
			return
		weakest.light.queue_free()
		weakest.erase("light")
		weakest.erase("light_energy")
		_light_count = maxi(0, _light_count - 1)
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color(1.0, 0.15, 0.06) if hostile else Color(0.13, 0.66, 1.0)
	light.light_energy = energy * (0.23 if _reduced_flash else 1.0)
	light.omni_range = reach
	light.omni_attenuation = 1.0
	light.shadow_enabled = false
	effect.root.add_child(light)
	effect.light = light
	effect.light_energy = energy
	_light_count += 1


func _sparks(effect: Dictionary, at: Vector3, axis: Vector3, count: int, power: float, directional: bool, hostile: bool = false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _small_diamond
	mm.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = _energy
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.root.add_child(instance)
	effect.meshes.append(instance)
	var velocities: Array[Vector3] = []
	var sizes: Array[float] = []
	for index in range(count):
		var outward := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.25, 1.35), _rng.randf_range(-1.0, 1.0)).normalized()
		var velocity := (axis * _rng.randf_range(2.0, 6.0) + outward * 2.5 if directional else outward * _rng.randf_range(2.0, 6.5)) * power
		velocities.append(velocity)
		sizes.append(_rng.randf_range(0.045, 0.13) * sqrt(power))
		mm.set_instance_color(index, CORAL if hostile else Color(0.3, 0.87, 1.0, _rng.randf_range(0.6, 1.0)))
		mm.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.01), at))
	effect.particles = mm
	effect.particle_origin = at
	effect.velocities = velocities
	effect.sizes = sizes


func _animate_particles(effect: Dictionary, age: float, t: float) -> void:
	var mm: MultiMesh = effect.particles
	for index in range(mm.instance_count):
		var velocity: Vector3 = effect.velocities[index]
		var position: Vector3 = effect.particle_origin + velocity * age * (1.0 - t * 0.45) + Vector3.DOWN * age * age * 2.5
		var size: float = effect.sizes[index] * (1.0 - t)
		var basis := Basis.looking_at(velocity.normalized(), Vector3.UP).scaled(Vector3(size, size, size * 3.4))
		mm.set_instance_transform(index, Transform3D(basis, position))


func _debris(effect: Dictionary, power: float, count_override: int = 0) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _small_diamond
	var count := count_override if count_override > 0 else (12 if _reduced_particles else 28)
	mm.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = _stone
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.root.add_child(instance)
	var launch: Array[Vector3] = []
	var offsets: Array[Vector3] = []
	var sizes: Array[Vector3] = []
	for index in range(count):
		var angle := _rng.randf() * TAU
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		offsets.append(radial * _rng.randf_range(0.25, 2.5) * power)
		launch.append(radial * _rng.randf_range(0.5, 2.0) * power + Vector3.UP * _rng.randf_range(4.0, 8.8) * sqrt(power))
		var size := _rng.randf_range(0.24, 0.62) * sqrt(power)
		sizes.append(Vector3(size, size * _rng.randf_range(0.5, 1.5), size * 0.8))
		mm.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.01), offsets[index]))
	effect.debris = mm
	effect.debris_offsets = offsets
	effect.debris_launch = launch
	effect.debris_sizes = sizes


func _animate_debris(effect: Dictionary, age: float, t: float) -> void:
	var mm: MultiMesh = effect.debris
	for index in range(mm.instance_count):
		var position: Vector3 = effect.debris_offsets[index] + effect.debris_launch[index] * age + Vector3.DOWN * 5.4 * age * age
		position.y = maxf(0.01, position.y)
		var size: Vector3 = effect.debris_sizes[index] * (1.0 - smoothstep(0.55, 1.0, t))
		var basis := Basis.from_euler(Vector3(age * (index % 3 + 1), age * 2.2, index * 0.77)).scaled(size)
		mm.set_instance_transform(index, Transform3D(basis, position))


func _dust(effect: Dictionary, strength: float, count: int) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _dust_sphere
	mm.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = _dust_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.root.add_child(instance)
	effect.meshes.append(instance)
	var directions: Array[Vector3] = []
	var sizes: Array[float] = []
	for index in range(count):
		var angle := index * TAU / count + _rng.randf_range(-0.15, 0.15)
		directions.append(Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(1.2, 2.8) * strength)
		sizes.append(_rng.randf_range(0.4, 0.8) * sqrt(strength))
		mm.set_instance_color(index, Color(0.26, 0.37, 0.41, 0.28))
		mm.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.01), Vector3.ZERO))
	effect.dust = mm
	effect.dust_directions = directions
	effect.dust_sizes = sizes
	effect.dust_ground = 0.2 - effect.root.position.y


func _animate_dust(effect: Dictionary, age: float, t: float) -> void:
	var mm: MultiMesh = effect.dust
	for index in range(mm.instance_count):
		var position: Vector3 = effect.dust_directions[index] * (0.40 + age * 3.0 * (1.0 - t * 0.5))
		position.y = effect.dust_ground + age * 0.24
		var size: float = effect.dust_sizes[index] * (0.5 + t * 1.5)
		mm.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3(size, size * 0.38, size)), position))


func _scar(at: Vector3, strength: float) -> void:
	var effect := _begin("scar", 2.6, at)
	if effect.is_empty():
		return
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for index in range(6):
		var angle := index * TAU / 6.0 + _rng.randf_range(-0.2, 0.2)
		var end := Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(0.4, 0.85) * strength
		var path := _jagged(Vector3.ZERO, end, 7, 0.1)
		for point in range(path.size()):
			path[point].y = 0.0
		_append_tube(vertices, colors, path, 0.014, Color(0.06, 0.45, 0.75, 0.5), 3)
	_add_mesh(effect.root, _mesh(vertices, colors), _energy, effect)
	_effects.append(effect)


func _jagged(start: Vector3, end: Vector3, segments: int, jitter: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for index in range(segments + 1):
		var t := float(index) / segments
		var offset := Vector3(_rng.randf_range(-jitter, jitter), _rng.randf_range(-jitter, jitter), _rng.randf_range(-jitter, jitter)) * sin(t * PI)
		points.append(start.lerp(end, t) + offset)
	return points


func _append_tube(vertices: PackedVector3Array, colors: PackedColorArray, path: PackedVector3Array, width: float, tint: Color, sides: int = 4) -> void:
	for index in range(path.size() - 1):
		var direction := (path[index + 1] - path[index]).normalized()
		if direction.length_squared() < 0.1:
			continue
		var right := direction.cross(Vector3.UP).normalized()
		if right.length_squared() < 0.1:
			right = direction.cross(Vector3.RIGHT).normalized()
		var up := right.cross(direction).normalized()
		var t := float(index) / maxf(path.size() - 1, 1)
		var thickness := width * (0.18 + pow(sin(PI * (0.08 + t * 0.84)), 0.6) * 0.82)
		for side in range(sides):
			var a := side * TAU / sides
			var b := (side + 1) * TAU / sides
			var edge_a := (right * cos(a) + up * sin(a)) * thickness
			var edge_b := (right * cos(b) + up * sin(b)) * thickness
			_triangle(vertices, colors, path[index] + edge_a, path[index + 1] + edge_a, path[index + 1] + edge_b, tint)
			_triangle(vertices, colors, path[index] + edge_a, path[index + 1] + edge_b, path[index] + edge_b, tint)


func _append_ring(vertices: PackedVector3Array, colors: PackedColorArray, radius: float, width: float, tint: Color, segments: int) -> void:
	for index in range(segments):
		var angle_a := index * TAU / segments
		var angle_b := (index + 1) * TAU / segments
		var a := Vector3(cos(angle_a), 0.0, sin(angle_a))
		var b := Vector3(cos(angle_b), 0.0, sin(angle_b))
		_triangle(vertices, colors, a * (radius - width), a * (radius + width), b * (radius + width), tint)
		_triangle(vertices, colors, a * (radius - width), b * (radius + width), b * (radius - width), tint)


func _append_star(vertices: PackedVector3Array, colors: PackedColorArray, center: Vector3, radius: float, points: int, tint: Color) -> void:
	for index in range(points * 2):
		var a := index * TAU / (points * 2)
		var b := (index + 1) * TAU / (points * 2)
		var ra := radius if index % 2 == 0 else radius * 0.18
		var rb := radius * 0.18 if index % 2 == 0 else radius
		_triangle(vertices, colors, center, center + Vector3(cos(a) * ra, 0, sin(a) * ra), center + Vector3(cos(b) * rb, 0, sin(b) * rb), tint)
		_triangle(vertices, colors, center, center + Vector3(cos(a) * ra, sin(a) * ra, 0), center + Vector3(cos(b) * rb, sin(b) * rb, 0), tint)


func _triangle(vertices: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	colors.append(tint)
	colors.append(tint)
	colors.append(tint)


func _mesh(vertices: PackedVector3Array, colors: PackedColorArray) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var normals := PackedVector3Array()
	for index in range(0, vertices.size(), 3):
		var normal := (vertices[index + 1] - vertices[index]).cross(vertices[index + 2] - vertices[index]).normalized()
		normals.append(normal)
		normals.append(normal)
		normals.append(normal)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _crystal_mesh(scale_value: float, bright: bool = false) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var palette: Array[Color] = [Color(0.02, 0.12, 0.20), Color(0.11, 0.49, 0.63), Color(0.30, 0.71, 0.80), Color(0.025, 0.21, 0.32), Color(0.08, 0.42, 0.57)]
	for side in range(5):
		var a := side * TAU / 5.0
		var b := (side + 1) * TAU / 5.0
		var waist_a := Vector3(cos(a) * 0.34, sin(a) * 0.34, 0.03) * scale_value
		var waist_b := Vector3(cos(b) * 0.34, sin(b) * 0.34, 0.03) * scale_value
		var tint := Color.WHITE if bright else palette[side]
		if bright:
			_triangle(vertices, colors, Vector3(0, 0, -0.98) * scale_value, waist_b, waist_a, tint)
		else:
			var shoulder_a := Vector3(cos(a + 0.1) * 0.22, sin(a + 0.1) * 0.22, -0.40) * scale_value
			var shoulder_b := Vector3(cos(b + 0.1) * 0.22, sin(b + 0.1) * 0.22, -0.40) * scale_value
			_triangle(vertices, colors, Vector3(0, 0, -0.98) * scale_value, shoulder_b, shoulder_a, tint.lightened(0.10))
			_triangle(vertices, colors, shoulder_a, shoulder_b, waist_b, tint)
			_triangle(vertices, colors, shoulder_a, waist_b, waist_a, palette[(side + 1) % 5].darkened(0.15))
		_triangle(vertices, colors, Vector3(0, 0, 0.70) * scale_value, waist_a, waist_b, tint.lightened(0.09))
	return _mesh(vertices, colors)
