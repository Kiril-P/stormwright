extends Node3D
## Shared procedural sculpture and animation. All gameplay belongs to ArenaGame.
## Forward is -Z; actor roots and their lifetime belong to the caller.

var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _static_batches: Dictionary = {}
var _built := false

func _palette() -> void:
	if not _materials.is_empty():
		return
	_mat("stone", Color(0.115, 0.155, 0.19), 0.88)
	_mat("edge", Color(0.20, 0.24, 0.265), 0.72)
	_mat("dark", Color(0.025, 0.042, 0.059), 0.94)
	_mat("brass", Color(0.48, 0.36, 0.19), 0.48, 0.38)
	_mat("ivory", Color(0.82, 0.81, 0.68), 0.91)
	_mat("cloth", Color(0.068, 0.15, 0.18), 0.92)
	_mat("leather", Color(0.13, 0.09, 0.068), 0.85)
	_mat("armor", Color(0.24, 0.285, 0.31), 0.45, 0.63)
	_mat("armor_light", Color(0.34, 0.375, 0.37), 0.43, 0.58)
	_mat("hostile", Color(1.0, 0.22, 0.11), 0.35, 0.2, 2.0)
	_mat("cyan", Color(0.12, 0.74, 0.92), 0.3, 0.2, 2.5)
	_mat("amber", Color(1.0, 0.48, 0.12), 0.45, 0.0, 2.4)
	_mat("floor", Color.WHITE, 0.88)
	_materials.floor.vertex_color_use_as_albedo = true
	_materials.floor.vertex_color_is_srgb = true
	_materials.floor.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials.ivory.cull_mode = BaseMaterial3D.CULL_DISABLED
	var noise := FastNoiseLite.new()
	noise.seed = 419
	noise.frequency = 0.055
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.64, 0.65, 0.68))
	gradient.set_color(1, Color(1.0, 1.0, 1.0))
	texture.color_ramp = gradient
	_materials.floor.albedo_texture = texture
	var normal := NoiseTexture2D.new()
	normal.width = 512
	normal.height = 512
	normal.seamless = true
	normal.as_normal_map = true
	normal.bump_strength = 2.3
	normal.noise = noise
	_materials.floor.normal_enabled = true
	_materials.floor.normal_texture = normal
	_materials.floor.normal_scale = 0.62


func _mat(id: String, color: Color, rough: float, metal: float = 0.0, glow: float = 0.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	_materials[id] = mat

func build_arena() -> void:
	if _built:
		return
	_built = true
	_palette()
	_lighting()
	_floor()
	# Three stepped strata give the platform a readable mass above the abyss.
	_static(_cylinder(13.1, 13.3, 0.55, 64), "dark", Vector3(0, -0.60, 0))
	_static(_cylinder(12.8, 13.05, 0.27, 64), "stone", Vector3(0, -0.21, 0))
	_static(_ring_mesh(12.62, 12.69, 80), "brass", Vector3(0, 0.016, 0))
	_static(_ring_mesh(11.45, 11.49, 96), "brass", Vector3(0, 0.014, 0))
	_static(_ring_mesh(6.0, 6.028, 96), "brass", Vector3(0, 0.014, 0))
	_static(_ring_mesh(2.0, 2.035, 64), "brass", Vector3(0, 0.015, 0))
	_static(_ring_mesh(2.18, 2.20, 64), "brass", Vector3(0, 0.015, 0))
	for i in range(8):
		var angle := float(i) * TAU / 8.0
		# Star rays are deliberately low-contrast; spell warnings own the floor.
		var pts := PackedVector3Array([Vector3(-0.15, 0, 0.28), Vector3(0, 0, 1.85), Vector3(0.15, 0, 0.28)])
		_static(_polygon(pts), "brass", Vector3(0, 0.017, 0), Vector3(0, angle, 0))
		for radius in [6.15, 11.68]:
			var pos := Vector3(sin(angle) * radius, 0.018, cos(angle) * radius)
			_static(_box(Vector3(0.07, 0.014, 0.28)), "brass", pos, Vector3(0, angle, 0))
	# Full perimeter low curb, with tall architecture only on the far semicircle.
	for i in range(20):
		var angle := float(i) * TAU / 20.0
		var pos := Vector3(sin(angle), 0, cos(angle)) * 13.0
		var far_side := pos.z < -1.0
		_static(_box(Vector3(3.65, 0.33, 0.48)), "stone", pos + Vector3(0, 0.16, 0), Vector3(0, angle, 0))
		_static(_box(Vector3(3.7, 0.11, 0.56)), "edge", pos + Vector3(0, 0.37, 0), Vector3(0, angle, 0))
		if i % 2 == 0:
			_column(pos, 4.9 if far_side else (1.4 if absf(pos.x) > 9 else 0.55), angle)
		if far_side and i % 2 == 0:
			var next_a := angle + TAU / 10.0
			var other := Vector3(sin(next_a), 0, cos(next_a)) * 13.0
			if other.z < -1.0:
				_arch(pos + Vector3(0, 3.15, 0), other + Vector3(0, 3.15, 0))
	# Braziers share geometry; four low local lights supply restrained warmth.
	for pos in [Vector3(-10.2, 0, -7.9), Vector3(10.2, 0, -7.9), Vector3(-12.6, 0, 1.9), Vector3(12.6, 0, 1.9)]:
		_brazier(pos)
	# Tall broken spires beyond the arena create depth without gameplay occlusion.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7819
	for i in range(17):
		var angle := PI * 0.51 + float(i) / 16.0 * PI * 0.98
		var radius := rng.randf_range(18.0, 24.0)
		var pos := Vector3(sin(angle) * radius, -5.5, cos(angle) * radius)
		var h := rng.randf_range(6.0, 15.0)
		_static(_box(Vector3(1.45, h, 1.65)), "dark", pos + Vector3(0, h * 0.5, 0), Vector3(0, angle, 0))
		_static(_cylinder(1.4, 0.35, 1.8, 4), "stone", pos + Vector3(0, h + 0.6, 0), Vector3(0, angle + PI / 4.0, 0))
	_flush_static()

func _lighting() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.018, 0.028, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.60, 0.65, 0.72)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.3
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.7
	env.ssao_power = 1.25
	env.fog_enabled = true
	env.fog_density = 0.004
	env.fog_light_color = Color(0.085, 0.14, 0.20)
	env.fog_light_energy = 0.5
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-54, -31, -8)
	key.light_color = Color(0.86, 0.91, 1.0)
	key.light_energy = 1.7
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 70.0
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	key.shadow_bias = 0.035
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-30, 145, 0)
	rim.light_color = Color(0.34, 0.55, 0.69)
	rim.light_energy = 0.75
	add_child(rim)

func _floor() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 473211
	var radii := [0.0, 2.7, 5.15, 7.6, 10.0, 12.7]
	for ring in range(5):
		var count := 12 if ring < 2 else 24
		for segment in range(count):
			var a := float(segment) * TAU / float(count)
			var b := float(segment + 1) * TAU / float(count)
			var skew := (0.05 if ring % 2 == 1 else -0.035)
			var r0: float = radii[ring]
			var r1: float = radii[ring + 1]
			var pts: Array[Vector3] = [Vector3(sin(a + skew) * r0, 0, cos(a + skew) * r0), Vector3(sin(b + skew) * r0, 0, cos(b + skew) * r0), Vector3(sin(b) * r1, 0, cos(b) * r1), Vector3(sin(a) * r1, 0, cos(a) * r1)]
			var center := (pts[0] + pts[1] + pts[2] + pts[3]) * 0.25
			var shade := rng.randf_range(0.88, 1.12)
			var col := Color(0.115, 0.155, 0.184) * shade
			col.a = 1.0
			for k in range(4):
				pts[k] = pts[k].move_toward(center, 0.021)
			for inds in [[0, 1, 2], [0, 2, 3]]:
				for k in inds:
					st.set_color(col)
					st.set_normal(Vector3.UP)
					st.set_uv(Vector2(pts[k].x, pts[k].z) * 0.12)
					st.add_vertex(pts[k])
			# Beveled seams catch the grazing light without cluttering the floor.
			for k in range(4):
				var p: Vector3 = pts[k]
				var q: Vector3 = pts[(k + 1) % 4]
				var out_p := p.move_toward(center, -0.025) - Vector3(0, 0.035, 0)
				var out_q := q.move_toward(center, -0.025) - Vector3(0, 0.035, 0)
				for v in [p, out_q, q, p, out_p, out_q]:
					st.set_color(col * 0.65)
					st.set_normal(Vector3.UP)
					st.set_uv(Vector2(v.x, v.z) * 0.12)
					st.add_vertex(v)
	st.generate_tangents()
	var floor_mesh := st.commit()
	var instance := MeshInstance3D.new()
	instance.mesh = floor_mesh
	instance.material_override = _materials.floor
	add_child(instance)

func _column(pos: Vector3, height: float, yaw: float) -> void:
	_static(_box(Vector3(1.42, 0.32, 1.32)), "dark", pos + Vector3(0, 0.25, 0), Vector3(0, yaw, 0))
	_static(_box(Vector3(1.13, 0.20, 1.08)), "edge", pos + Vector3(0, 0.48, 0), Vector3(0, yaw, 0))
	if height < 1.0:
		return
	_static(_cylinder(0.49, 0.40, height - 0.55, 8), "stone", pos + Vector3(0, height * 0.5 + 0.28, 0), Vector3(0, yaw + PI / 8.0, 0))
	for y in [0.68, height - 0.18]:
		_static(_cylinder(0.59, 0.59, 0.14, 8), "brass", pos + Vector3(0, y, 0))
	_static(_box(Vector3(1.1, 0.22, 1.05)), "edge", pos + Vector3(0, height, 0), Vector3(0, yaw, 0))
	if height > 3.0:
		_static(_cylinder(0.62, 0.06, 1.1, 4), "stone", pos + Vector3(0, height + 0.65, 0), Vector3(0, yaw + PI / 4, 0))
		# Central inset rib and a sparse brass clasp show a built structure.
		var front := Vector3(sin(yaw), 0, cos(yaw)) * -0.42
		_static(_box(Vector3(0.13, height - 1.3, 0.09)), "dark", pos + front + Vector3(0, height * 0.5 + 0.22, 0), Vector3(0, yaw, 0))

func _arch(a: Vector3, b: Vector3) -> void:
	var mid := (a + b) * 0.5 + Vector3(0, 2.5, 0)
	for pair in [[a, mid], [mid, b]]:
		var p: Vector3 = pair[0]
		var q: Vector3 = pair[1]
		var span := q - p
		var basis_value := Basis.looking_at(span.normalized(), Vector3.FORWARD)
		_static_transform(_box(Vector3(0.46, 0.50, span.length())), "stone", Transform3D(basis_value, (p + q) * 0.5))
		_static_transform(_box(Vector3(0.05, 0.53, span.length())), "brass", Transform3D(basis_value, (p + q) * 0.5))
	_static(_cylinder(0.42, 0.16, 0.60, 4), "edge", mid + Vector3(0, 0.12, 0), Vector3(0, PI / 4, 0))

func _brazier(pos: Vector3) -> void:
	_static(_cylinder(0.57, 0.38, 0.9, 6), "dark", pos + Vector3(0, 0.65, 0))
	_static(_cylinder(0.39, 0.64, 0.25, 8), "brass", pos + Vector3(0, 1.2, 0))
	_static(_cylinder(0.18, 0.03, 0.68, 5), "amber", pos + Vector3(0, 1.52, 0), Vector3(0.11, 0, 0.17))
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 1.8, 0)
	light.light_color = Color(1.0, 0.43, 0.14)
	light.light_energy = 2.2
	light.omni_range = 5.3
	add_child(light)

func create_caster() -> Dictionary:
	_palette()
	var root := Node3D.new()
	root.name = "StormwrightCaster"
	root.scale = Vector3.ONE * 1.16
	var body := _pivot(root, Vector3(0, 0.82, 0))
	_part(body, _cylinder(0.29, 0.25, 0.64, 7), "cloth", Vector3(0, 0.27, 0))
	_part(body, _cylinder(0.31, 0.31, 0.09, 8), "brass", Vector3(0, 0.13, 0))
	_part(body, _box(Vector3(0.17, 0.19, 0.05)), "brass", Vector3(0, 0.17, -0.285))
	# Separate hanging tabards leave the legs visible during the run.
	var tabard := _pivot(body, Vector3(0, 0.07, -0.23))
	_part(tabard, _cloth_panel(0.31, 0.39, 0.57, 0.12), "ivory")
	_part(tabard, _box(Vector3(0.04, 0.48, 0.025)), "brass", Vector3(0, -0.29, -0.02))
	_part(body, _cylinder(0.34, 0.42, 0.14, 7), "ivory", Vector3(0, 0.55, 0))
	var head := _pivot(body, Vector3(0, 0.77, -0.025))
	_part(head, _hood(), "ivory", Vector3(0, 0.04, 0.015))
	_part(head, _sphere(), "dark", Vector3(0, 0.0, -0.238), Vector3(0.215, 0.235, 0.06))
	_part(head, _box(Vector3(0.14, 0.026, 0.012)), "cyan", Vector3(0, 0.045, -0.292))
	# Crest seam and mantle collar emphasize the hood without facial detail.
	_part(head, _box(Vector3(0.036, 0.34, 0.025)), "brass", Vector3(0, 0.17, 0.285), Vector3.ONE, Vector3(-0.2, 0, 0))
	var cape := _pivot(body, Vector3(0, 0.6, 0.19))
	_part(cape, _cloth_panel(0.7, 0.90, 0.59, 0.20), "ivory")
	var cape_tail := _pivot(cape, Vector3(0, -0.57, 0.19))
	_part(cape_tail, _cloth_panel(0.90, 1.10, 0.53, 0.16), "ivory")
	for side in [-1.0, 1.0]:
		var strip := _part(cape, _cloth_panel(0.045, 0.05, 0.58, 0.20), "brass", Vector3(side * 0.32, 0, -0.016))
		strip.rotation.z = side * -0.16
		var tail_strip := _part(cape_tail, _cloth_panel(0.045, 0.05, 0.51, 0.16), "brass", Vector3(side * 0.42, 0, 0.009))
		tail_strip.rotation.z = side * -0.16
	var left := _arm(body, Vector3(-0.34, 0.48, 0), 0.31, 0.29, "ivory", 0.10)
	var right := _arm(body, Vector3(0.34, 0.48, 0), 0.31, 0.29, "ivory", 0.10)
	var staff := _pivot(right.hand, Vector3(0, 0.02, -0.03))
	staff.rotation.x = -0.30
	_part(staff, _cylinder(0.037, 0.03, 1.91, 8), "leather", Vector3(0, 0.32, 0))
	for y in [-0.42, 0.38, 0.88]:
		_part(staff, _cylinder(0.048, 0.048, 0.11, 8), "brass", Vector3(0, y, 0))
	var staff_tip := _pivot(staff, Vector3(0, 1.41, 0))
	staff_tip.name = "StaffTip"
	_part(staff_tip, _crystal(), "cyan", Vector3.ZERO, Vector3(0.19, 0.39, 0.19))
	for side in [-1.0, 1.0]:
		_part(staff_tip, _cylinder(0.024, 0.014, 0.47, 6), "brass", Vector3(side * 0.21, -0.10, 0), Vector3.ONE, Vector3(0, 0, side * -0.45))
	var legs := [_leg(root, -0.16, 0.76, 0.35, 0.35, "cloth", "leather", 0.105), _leg(root, 0.16, 0.76, 0.35, 0.35, "cloth", "leather", 0.105)]
	return {"root": root, "body": body, "head": head, "left": left, "right": right, "legs": legs, "cape": cape, "cape_tail": cape_tail, "tabard": tabard, "staff": staff, "staff_tip": staff_tip, "last_position": Vector3.ZERO, "stride": 0.0, "initialized": false, "body_y": 0.82}

func create_enemy(kind: String) -> Dictionary:
	_palette()
	var root := Node3D.new()
	root.name = kind.capitalize()
	root.scale = Vector3.ONE * 1.16
	var is_warden := kind == "warden"
	var channeler := kind == "channeler"
	var broad := kind == "bulwark" or is_warden
	var body_height := 1.08 if broad else (1.30 if channeler else 0.68)
	var body := _pivot(root, Vector3(0, body_height, 0))
	var width := 0.52 if broad else 0.25
	_part(body, _armor_torso(), "armor", Vector3(0, 0.19, 0), Vector3(width, 0.73 if broad else 0.5, width * 0.67))
	for side in [-1.0, 1.0]:
		_part(body, _box(Vector3(width * 0.67, 0.30 if broad else 0.19, 0.11)), "armor_light", Vector3(side * width * 0.57, 0.32, -width * 0.56), Vector3.ONE, Vector3(-0.12, side * 0.34, side * 0.24))
	_part(body, _sphere(), "dark", Vector3(0, 0.23, -width * 0.65), Vector3(width * 0.59, width * 0.59, width * 0.25))
	var core := _part(body, _crystal(), "hostile", Vector3(0, 0.23, -width * 0.99), Vector3(width * 0.32, width * 0.45, width * 0.20))
	var head := _pivot(body, Vector3(0, 0.68 if broad else 0.52, 0))
	_part(head, _armor_torso(), "armor_light", Vector3(0, 0.05, -0.055), Vector3(0.22 if broad else 0.16, 0.36 if broad else 0.29, 0.18), Vector3(-0.17, 0, 0))
	_part(head, _cylinder(0.075, 0.0, 0.21, 4), "armor", Vector3(0, 0.30, 0.015))
	_part(head, _box(Vector3(0.24 if broad else 0.15, 0.036, 0.04)), "hostile", Vector3(0, 0.07, -0.18))
	# Armor is divided at joints; shoulder slabs open away from the Warden core.
	var shoulder_nodes: Array[Node3D] = []
	var upper_len := 0.43 if broad else 0.35
	var lower_len := 0.41 if broad else 0.34
	var arms: Array[Dictionary] = []
	for side in [-1.0, 1.0]:
		var shoulder := _pivot(body, Vector3(side * (width + 0.12), 0.44, 0))
		shoulder_nodes.append(shoulder)
		_part(shoulder, _box(Vector3(0.40 if broad else 0.23, 0.31 if broad else 0.20, 0.43 if broad else 0.25)), "armor_light", Vector3(side * 0.06, 0, 0), Vector3.ONE, Vector3(0, 0, side * -0.20))
		if broad:
			_part(shoulder, _cylinder(0.15, 0.0, 0.38, 4), "armor", Vector3(side * 0.19, 0.23, 0), Vector3.ONE, Vector3(0, 0, side * -0.45))
		var arm := _arm(shoulder, Vector3(0, -0.04, 0), upper_len, lower_len, "armor", 0.16 if broad else 0.095)
		arms.append(arm)
		if broad:
			_part(arm.lower, _box(Vector3(0.32, 0.41, 0.32)), "armor_light", Vector3(0, -lower_len * 0.5, -0.025))
		else:
			_part(arm.hand, _crystal(), "armor_light", Vector3(0, -0.18, -0.03), Vector3(0.09, 0.29, 0.14))
	var legs: Array[Dictionary] = []
	if channeler:
		_part(body, _cylinder(0.08, 0.30, 0.74, 5), "dark", Vector3(0, -0.40, 0))
		for i in range(3):
			var a := float(i) * TAU / 3.0
			_part(body, _crystal(), "armor", Vector3(sin(a) * 0.32, -0.33, cos(a) * 0.32), Vector3(0.12, 0.56, 0.15), Vector3(0.15 * cos(a), a, 0.15 * sin(a)))
		# Floating broken halo is geometry, so it remains visible without bloom.
		for i in range(5):
			var a := float(i) * TAU / 5.0
			_part(head, _crystal(), "brass", Vector3(cos(a) * 0.37, sin(a) * 0.37 + 0.08, 0.12), Vector3(0.045, 0.12, 0.045), Vector3(0, 0, a - PI * 0.5))
	else:
		var length := 0.51 if broad else 0.31
		legs = [_leg(root, -0.30 if broad else -0.18, body_height, length, length, "armor", "dark", 0.16 if broad else 0.09), _leg(root, 0.30 if broad else 0.18, body_height, length, length, "armor", "dark", 0.16 if broad else 0.09)]
		_part(body, _box(Vector3(width * 1.5, 0.19, 0.37)), "dark", Vector3(0, -0.25, 0))
	if is_warden:
		root.scale = Vector3.ONE * 1.6
		for side in [-1.0, 1.0]:
			_part(head, _cylinder(0.095, 0.025, 0.63, 5), "brass", Vector3(side * 0.22, 0.28, 0.06), Vector3.ONE, Vector3(0.15, 0, side * -0.42))
		_part(body, _cloth_panel(0.88, 1.2, 1.1, 0.32), "dark", Vector3(0, 0.4, 0.31))
		_part(body, _cylinder(0.11, 0.05, 0.6, 6), "hostile", Vector3(0, 0.92, 0.23))
	return {"root": root, "body": body, "head": head, "core": core, "arms": arms, "shoulders": shoulder_nodes, "legs": legs, "kind": kind, "body_y": body_height, "last_position": Vector3.ZERO, "stride": 0.0, "initialized": false}

func animate_caster(rig: Dictionary, time: float, speed: float, cast: float, dash: float) -> void:
	var stride: float = _animate_legs(rig, time, speed)
	var body: Node3D = rig.body
	body.position.y = float(rig.body_y) + absf(sin(stride * TAU)) * 0.045 * speed - dash * 0.16
	body.rotation = Vector3(-speed * 0.12 - dash * 0.32 + cast * 0.13, sin(stride * TAU) * 0.025 * speed, sin(stride * TAU) * 0.035 * speed)
	rig.head.rotation.x = -cast * 0.14 + dash * 0.12
	# The right hand brings the staff forward; its socket remains a true child.
	rig.right.root.rotation = Vector3(0.15 + cast * 1.05 + dash * 0.3, -cast * 0.1, -0.12 - cast * 0.12)
	rig.right.lower.rotation.x = -0.55 + cast * 0.18
	rig.left.root.rotation = Vector3(sin(stride * TAU) * 0.45 * speed + cast * 1.1, -cast * 0.22, 0.15 + cast * 0.25)
	rig.left.lower.rotation.x = -0.40 - cast * 0.32
	rig.staff.rotation.x = 0.28 - cast * 2.5
	rig.cape.rotation = Vector3(-0.12 - speed * 0.28 - dash * 0.42 + sin(time * 3.5) * 0.025, sin(time * 2.4) * 0.025, sin(stride * TAU) * 0.05 * speed)
	rig.cape_tail.rotation.x = -0.08 - speed * 0.15 + sin(time * 6.0 - 0.6) * (0.025 + speed * 0.06)
	rig.tabard.rotation.x = speed * 0.27 + dash * 0.25

func animate_enemy(rig: Dictionary, time: float, speed: float, attack: float, hit: float, phase: int, exposed: bool = false) -> void:
	var kind: String = rig.kind
	var stride: float = _animate_legs(rig, time, speed)
	var body: Node3D = rig.body
	var broad := kind == "bulwark" or kind == "warden"
	var floating := kind == "channeler"
	body.position.y = float(rig.body_y) + (sin(time * 2.3) * 0.10 if floating else absf(sin(stride * TAU)) * speed * 0.05) - attack * 0.08
	body.rotation = Vector3((-0.20 if kind == "shardling" else 0.0) - speed * 0.13 + attack * 0.24 + hit * 0.34, sin(stride * TAU) * speed * 0.06, hit * 0.15 + sin(stride * TAU) * speed * 0.03)
	rig.head.rotation.x = -attack * 0.3 + hit * 0.3
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var arm: Dictionary = rig.arms[i]
		var swing := sin(stride * TAU + float(i) * PI) * speed
		arm.root.rotation.x = (-0.4 if floating else 0.0) + swing * (0.2 if broad else 0.5) - attack * (2.1 if broad else 1.4) + hit * 0.6
		arm.root.rotation.z = side * (-0.18 - attack * 0.24 - (0.4 if floating else 0.0))
		arm.lower.rotation.x = -0.12 - attack * 0.7 - (0.4 if floating else 0.0)
		if kind == "warden":
			rig.shoulders[i].rotation.z = side * (-0.38 if phase == 2 else 0.0)
			rig.shoulders[i].position.x = side * (0.64 + (0.18 if phase == 2 else 0.0))
		elif kind == "bulwark":
			rig.shoulders[i].rotation.z = side * (-0.48 if exposed else 0.0)
	var pulse := 1.0 + sin(time * (7.0 if phase == 2 else 3.0)) * 0.06 + attack * 0.20 + (1.0 if exposed else 0.0)
	rig.core.scale = Vector3(0.52 * 0.32, 0.52 * 0.45, 0.52 * 0.20) * pulse if broad else Vector3(0.25 * 0.32, 0.25 * 0.45, 0.25 * 0.20) * pulse

func _animate_legs(rig: Dictionary, _time: float, speed: float) -> float:
	var root: Node3D = rig.root
	if not root.is_inside_tree():
		return float(rig.stride)
	var pos := root.global_position
	if not bool(rig.initialized):
		rig.last_position = pos
		rig.initialized = true
	var moved: Vector3 = pos - Vector3(rig.last_position)
	moved.y = 0
	rig.last_position = pos
	var actor_scale := root.global_basis.get_scale().x
	var distance := minf(moved.length() / maxf(actor_scale, 0.1), 0.18)
	var stride_length := 0.85 if rig.get("kind", "caster") != "shardling" else 0.60
	rig.stride = float(rig.stride) + distance / stride_length
	var stride: float = rig.stride
	var moving := speed > 0.02 and moved.length() > 0.0001
	var forward := moved.normalized() if moving else -root.global_basis.z.normalized()
	var legs: Array = rig.legs
	for i in range(legs.size()):
		var leg: Dictionary = legs[i]
		var cycle := fposmod(stride + float(i) * 0.5, 1.0)
		var hip: Node3D = leg.root
		var rest := root.to_global(Vector3(hip.position.x, 0.08, 0))
		if not leg.has("target"):
			leg.target = rest
			leg.start = rest
			leg.end = rest
			leg.was_swing = false
		var swing := cycle > 0.58 and moving
		if swing and not bool(leg.was_swing):
			leg.start = leg.target
			leg.end = rest + forward * stride_length * actor_scale * 0.33
		if swing:
			var t := (cycle - 0.58) / 0.42
			leg.target = Vector3(leg.start).lerp(Vector3(leg.end), smoothstep(0.0, 1.0, t)) + Vector3.UP * sin(t * PI) * 0.15 * actor_scale
		elif not moving:
			leg.target = Vector3(leg.target).lerp(rest, 0.17)
		leg.was_swing = swing
		var local_target := root.to_local(leg.target) - hip.position
		# A hip swivel aligns a two-bone sagittal solve with strafe/backward motion.
		var horizontal := Vector2(local_target.x, local_target.z)
		var swing_yaw := atan2(-horizontal.x, -horizontal.y) if horizontal.length() > 0.01 else 0.0
		hip.rotation.y = swing_yaw
		var down := -local_target.y
		var reach := clampf(sqrt(horizontal.length_squared() + down * down), 0.1, float(leg.upper_len) + float(leg.lower_len) - 0.015)
		var upper: float = leg.upper_len
		var lower: float = leg.lower_len
		var bend := acos(clampf((upper * upper + reach * reach - lower * lower) / (2.0 * upper * reach), -1, 1))
		var base := atan2(horizontal.length(), maxf(down, 0.01))
		hip.rotation.x = base - bend
		leg.lower.rotation.x = PI - acos(clampf((upper * upper + lower * lower - reach * reach) / (2.0 * upper * lower), -1, 1))
		leg.foot.rotation.x = -hip.rotation.x - leg.lower.rotation.x
	return stride

func _arm(parent: Node3D, at: Vector3, upper_len: float, lower_len: float, material: String, width: float) -> Dictionary:
	var shoulder := _pivot(parent, at)
	_part(shoulder, _sphere(), "dark", Vector3.ZERO, Vector3.ONE * width * 1.05)
	_part(shoulder, _cylinder(width, width * 1.14, upper_len - 0.025, 6), material, Vector3(0, -upper_len * 0.5, 0))
	var lower := _pivot(shoulder, Vector3(0, -upper_len, 0))
	_part(lower, _sphere(), "brass", Vector3.ZERO, Vector3.ONE * width * 0.79)
	_part(lower, _cylinder(width * 0.70, width * 0.90, lower_len - 0.03, 6), material, Vector3(0, -lower_len * 0.5, 0))
	var hand := _pivot(lower, Vector3(0, -lower_len, 0))
	_part(hand, _box(Vector3(width * 1.5, width * 1.45, width * 1.45)), "leather" if material == "ivory" else "dark")
	return {"root": shoulder, "lower": lower, "hand": hand}

func _leg(parent: Node3D, x: float, height: float, upper_len: float, lower_len: float, material: String, boot_material: String, width: float) -> Dictionary:
	var hip := _pivot(parent, Vector3(x, height, 0))
	_part(hip, _cylinder(width, width * 1.12, upper_len - 0.025, 6), material, Vector3(0, -upper_len * 0.5, 0))
	var knee := _pivot(hip, Vector3(0, -upper_len, 0))
	_part(knee, _sphere(), "brass" if material == "cloth" else "dark", Vector3.ZERO, Vector3.ONE * width * 0.8)
	_part(knee, _cylinder(width * 0.8, width, lower_len - 0.025, 6), material, Vector3(0, -lower_len * 0.5, 0))
	var foot := _pivot(knee, Vector3(0, -lower_len, 0))
	_part(foot, _box(Vector3(width * 1.65, 0.12, width * 3.0)), boot_material, Vector3(0, 0, -width * 0.55))
	return {"root": hip, "lower": knee, "foot": foot, "upper_len": upper_len, "lower_len": lower_len}

func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var result := Node3D.new()
	result.position = at
	parent.add_child(result)
	return result

func _part(parent: Node3D, mesh: Mesh, material: String, at: Vector3 = Vector3.ZERO, size: Vector3 = Vector3.ONE, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = _materials[material]
	part.position = at
	part.scale = size
	part.rotation = rotation_value
	parent.add_child(part)
	return part

func _static(mesh: Mesh, material: String, at: Vector3, rotation_value: Vector3 = Vector3.ZERO) -> void:
	_static_transform(mesh, material, Transform3D(Basis.from_euler(rotation_value), at))

func _static_transform(mesh: Mesh, material: String, transform_value: Transform3D) -> void:
	var key := "%s:%s" % [mesh.get_instance_id(), material]
	if not _static_batches.has(key):
		_static_batches[key] = {"mesh": mesh, "material": material, "transforms": []}
	_static_batches[key].transforms.append(transform_value)

func _flush_static() -> void:
	for batch in _static_batches.values():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = batch.mesh
		mm.instance_count = batch.transforms.size()
		for i in range(mm.instance_count):
			mm.set_instance_transform(i, batch.transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = mm
		instance.material_override = _materials[batch.material]
		add_child(instance)
	_static_batches.clear()

func _box(size: Vector3) -> Mesh:
	var key := "box:%s" % size
	if _meshes.has(key):
		return _meshes[key]
	# Chamfered boxes catch narrow highlights and avoid raw primitive silhouettes.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size * 0.5
	var bevel := minf(minf(h.x, h.y), h.z) * 0.16
	var faces := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for normal in faces:
		var u := Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
		var v: Vector3 = normal.cross(u)
		var un := u.abs().dot(h) - bevel
		var vn: float = v.abs().dot(h) - bevel
		var n: Vector3 = normal * normal.abs().dot(h)
		var points := [n - u * un - v * vn, n + u * un - v * vn, n + u * un + v * vn, n - u * un + v * vn]
		for ids in [[0, 1, 2], [0, 2, 3]]:
			for id in ids:
				st.set_normal(normal)
				st.add_vertex(points[id])
	# A small bevelled core closes the diagonal edges. An eight-corner hull with
	# edge strips gives an intentional silhouette while keeping construction cheap.
	for axis in range(3):
		var along := Vector3.ZERO
		along[axis] = 1.0
		var axis_b := (axis + 1) % 3
		var axis_c := (axis + 2) % 3
		for sb in [-1.0, 1.0]:
			for sc in [-1.0, 1.0]:
				var p := Vector3.ZERO
				p[axis_b] = sb * h[axis_b]
				p[axis_c] = sc * (h[axis_c] - bevel)
				var q := Vector3.ZERO
				q[axis_b] = sb * (h[axis_b] - bevel)
				q[axis_c] = sc * h[axis_c]
				var pts := [p - along * (h[axis] - bevel), p + along * (h[axis] - bevel), q + along * (h[axis] - bevel), q - along * (h[axis] - bevel)]
				var norm := (p + q).normalized()
				for ids in [[0, 1, 2], [0, 2, 3]]:
					for id in ids:
						st.set_normal(norm)
						st.add_vertex(pts[id])
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var corner := Vector3(sx, sy, sz) * h
				var norm := Vector3(sx, sy, sz).normalized()
				for p in [corner - Vector3(0, sy * bevel, sz * bevel), corner - Vector3(sx * bevel, 0, sz * bevel), corner - Vector3(sx * bevel, sy * bevel, 0)]:
					st.set_normal(norm)
					st.add_vertex(p)
	var mesh := st.commit()
	_meshed_double_sided(mesh)
	_meshes[key] = mesh
	return mesh

func _meshed_double_sided(_mesh: Mesh) -> void:
	# Construction meshes share materials. Cull disabled avoids mirrored bevel
	# winding differences while solid surfaces still write depth normally.
	for id in ["stone", "dark", "edge", "brass", "armor", "armor_light", "cloth", "leather"]:
		_materials[id].cull_mode = BaseMaterial3D.CULL_DISABLED

func _cylinder(bottom: float, top: float, height: float, sides: int = 8) -> Mesh:
	var key := "cylinder:%s:%s:%s:%s" % [bottom, top, height, sides]
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = bottom
		mesh.top_radius = top
		mesh.height = height
		mesh.radial_segments = sides
		mesh.rings = 1
		_meshes[key] = mesh
	return _meshes[key]

func _sphere() -> Mesh:
	if not _meshes.has("sphere"):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 10
		mesh.rings = 5
		_meshes.sphere = mesh
	return _meshes.sphere

func _crystal() -> Mesh:
	if not _meshes.has("crystal"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(5):
			var a := float(i) * TAU / 5.0
			var b := float(i + 1) * TAU / 5.0
			var p := Vector3(sin(a), 0.0, cos(a))
			var q := Vector3(sin(b), 0.0, cos(b))
			for tri in [[Vector3(0, 1, 0), q, p], [Vector3(0, -1, 0), p, q]]:
				var norm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
				for v in tri:
					st.set_normal(norm)
					st.add_vertex(v)
		_meshes.crystal = st.commit()
	return _meshes.crystal

func _cloth_panel(top_width: float, bottom_width: float, height: float, trail: float) -> Mesh:
	var key := "cloth:%s:%s:%s:%s" % [top_width, bottom_width, height, trail]
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(4):
		for x in range(6):
			var pts: Array[Vector3] = []
			for cell in [Vector2(x, y), Vector2(x + 1, y), Vector2(x + 1, y + 1), Vector2(x, y + 1)]:
				var v: float = cell.y / 4.0
				var u: float = cell.x / 6.0
				var width := lerpf(top_width, bottom_width, v)
				pts.append(Vector3((u - 0.5) * width, -v * height + absf(u - 0.5) * 0.08 * v, trail * v * v + sin(u * PI * 5.0) * v * 0.055))
			for ids in [[0, 1, 2], [0, 2, 3]]:
				var norm := (pts[ids[1]] - pts[ids[0]]).cross(pts[ids[2]] - pts[ids[0]]).normalized()
				for id in ids:
					st.set_normal(norm)
					st.add_vertex(pts[id])
	_meshes[key] = st.commit()
	return _meshes[key]

func _ring_mesh(inner: float, outer: float, segments: int) -> Mesh:
	var key := "ring:%s:%s:%s" % [inner, outer, segments]
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a := float(i) * TAU / float(segments)
		var b := float(i + 1) * TAU / float(segments)
		var pts := [Vector3(sin(a) * inner, 0, cos(a) * inner), Vector3(sin(a) * outer, 0, cos(a) * outer), Vector3(sin(b) * outer, 0, cos(b) * outer), Vector3(sin(b) * inner, 0, cos(b) * inner)]
		for ids in [[0, 1, 2], [0, 2, 3]]:
			for id in ids:
				st.set_normal(Vector3.UP)
				st.add_vertex(pts[id])
	_meshes[key] = st.commit()
	return _meshes[key]

func _polygon(points: PackedVector3Array) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in points:
		st.set_normal(Vector3.UP)
		st.add_vertex(p)
	return st.commit()

func _armor_torso() -> Mesh:
	if _meshes.has("torso"):
		return _meshes.torso
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := [Vector2(-0.65, -1), Vector2(0.65, -1), Vector2(1, -0.5), Vector2(1, 0.5), Vector2(0.65, 1), Vector2(-0.65, 1), Vector2(-1, 0.5), Vector2(-1, -0.5)]
	var rings := [Vector3(0.66, -0.5, 0.74), Vector3(1.0, 0.13, 1.0), Vector3(0.83, 0.5, 0.81)]
	for j in range(2):
		for i in range(8):
			var pts: Array[Vector3] = []
			for cell in [Vector2i(i, j), Vector2i((i + 1) % 8, j), Vector2i((i + 1) % 8, j + 1), Vector2i(i, j + 1)]:
				var o: Vector2 = outline[cell.x]
				var r: Vector3 = rings[cell.y]
				pts.append(Vector3(o.x * r.x, r.y, o.y * r.z))
			for ids in [[0, 1, 2], [0, 2, 3]]:
				var normal := -(pts[ids[1]] - pts[ids[0]]).cross(pts[ids[2]] - pts[ids[0]]).normalized()
				for k in ids:
					st.set_normal(normal)
					st.add_vertex(pts[k])
	for j in [0, 2]:
		var r: Vector3 = rings[j]
		for i in range(8):
			for o in [Vector2.ZERO, outline[i], outline[(i + 1) % 8]]:
				st.set_normal(Vector3.UP if j == 2 else Vector3.DOWN)
				st.add_vertex(Vector3(o.x * r.x, r.y, o.y * r.z))
	_meshes.torso = st.commit()
	return _meshes.torso

func _hood() -> Mesh:
	if _meshes.has("hood"):
		return _meshes.hood
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := [Vector3(0.26, -0.27, 0.21), Vector3(0.31, 0.05, 0.29), Vector3(0.19, 0.30, 0.21), Vector3(0.015, 0.43, 0.015)]
	for j in range(3):
		for i in range(12):
			var pts: Array[Vector3] = []
			for cell in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				var a: float = float(cell.x) * TAU / 12.0
				var r: Vector3 = rings[cell.y]
				pts.append(Vector3(sin(a) * r.x, r.y, cos(a) * r.z + float(cell.y) * 0.035))
			for ids in [[0, 1, 2], [0, 2, 3]]:
				var normal := (pts[ids[1]] - pts[ids[0]]).cross(pts[ids[2]] - pts[ids[0]]).normalized()
				for k in ids:
					st.set_normal(normal)
					st.add_vertex(pts[k])
	_meshes.hood = st.commit()
	return _meshes.hood
