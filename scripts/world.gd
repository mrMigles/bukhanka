extends Node3D
## Deterministic streamed landscape. Rendering and driving share the height field.
const LENGTH = 144.0
var STEP = 3.0
const ROAD_STEP = 1.5
const EDGES = [-3.4, -2.0, -1.55, -0.85, 0.85, 1.55, 2.0, 3.4]
var road_material = ShaderMaterial.new()
var chunks: Dictionary = {}
var obstacles: Dictionary = {}
var noise = FastNoiseLite.new()
var terrain_material = ShaderMaterial.new()
var surface_effects: Node
var wildlife: Array[Node3D] = []
var grass_material = ShaderMaterial.new()
var water_material = ShaderMaterial.new()
var tree_mesh: ArrayMesh
var rock_mesh: SphereMesh
var wood: StandardMaterial3D
var marker: StandardMaterial3D
var seed_value = 7429
var director = preload("res://scripts/world_director.gd").new(self)
var water_system = preload("res://scripts/water_system.gd").new(self)
var lake_material = ShaderMaterial.new()
var water_materials: Array = []
var exposure_cache = {}
var waterfall_emitters: Array[CPUParticles3D] = []
var building_chunk = false
var birds: Array[Node3D] = []

func _ready():
	if OS.has_feature("web"): STEP = 6.0
	noise.seed = seed_value
	noise.frequency = 0.006
	noise.fractal_octaves = 4
	terrain_material.shader = load("res://shaders/terrain.gdshader")
	terrain_material.set_shader_parameter("web_lite", OS.has_feature("web"))
	grass_material.shader = load("res://shaders/grass.gdshader")
	water_material.shader = load("res://shaders/river.gdshader")
	lake_material.shader = load("res://shaders/lake.gdshader")
	water_materials = [water_material, lake_material]
	road_material.shader = load("res://shaders/gravel.gdshader")
	road_material.set_shader_parameter("web_lite", OS.has_feature("web"))
	wood = material(Color("82705b"))
	marker = material(Color("e7d8ad"))
	rock_mesh = SphereMesh.new()
	rock_mesh.radial_segments = 5
	rock_mesh.rings = 2
	build_tree_mesh()

func material(c: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m

func road_x(z: float) -> float:
	return sin(z * 0.0035) * 105.0 + sin(z * 0.012) * 48.0 + sin(z * 0.029) * 15.0

func road_y(z: float) -> float:
	var natural = 110.0 + sin(z * 0.0017 - 0.8) * 85.0 + sin(z * 0.007) * 24.0
	return lerpf(80.16, natural, smoothstep(24.0, 90.0, absf(z - 120.0)))

func start_clearing(x: float, z: float) -> float:
	return (1.0 - smoothstep(10.0, 20.0, absf(x - road_x(z)))) * (1.0 - smoothstep(18.0, 30.0, absf(z - 120.0)))

func branch_amount(z: float) -> float:
	return pow(sin(PI * fposmod(z, 1500.0) / 1500.0), 2)

func branch_x(z: float) -> float:
	return road_x(z) - branch_amount(z) * (180.0 + sin(z * 0.022) * 35.0)

func branch_y(z: float) -> float:
	return road_y(z) + pow(branch_amount(z), 2) * 155.0

func route_x(z: float, route: int) -> float:
	match route:
		1: return branch_x(z)
		2: return road_x(z) + pow(sin(z * PI / 1100.0), 2) * (140.0 + 32.0 * sin(z * 0.025))
		3: return road_x(z) - sin(z * PI / 1500.0) * sin(z * PI / 750.0) * 145.0
	return road_x(z)

func route_height(z: float, route: int) -> float:
	match route:
		1: return branch_y(z)
		2: return road_y(z) + pow(sin(z * PI / 1100.0), 4) * 105.0
		3: return road_y(z) + pow(abs(sin(z * PI / 1500.0) * sin(z * PI / 750.0)), 2) * 105.0
	return road_y(z)

func nearest_route(x: float, z: float) -> int:
	var best = 0
	var distance = INF
	for route in range(4):
		var d = abs(x - route_x(z, route))
		if d < distance:
			distance = d
			best = route
	return best

func river_x(z: float) -> float:
	return road_x(z) + 45.0 + 69.0 * sin(z * 0.0055 + 0.5)

func is_bridge(z: float) -> bool:
	return false

func ford_amount(z: float) -> float:
	return 1.0 - smoothstep(8.0, 28.0, abs(river_x(z) - road_x(z)))

func water_y(z: float) -> float:
	var z0 = floorf(z / STEP) * STEP
	return lerpf(river_level(z0), river_level(z0 + STEP), (z - z0) / STEP)

func river_level(z: float) -> float:
	return road_y(z) - 3.0 + ford_amount(z) * 3.0

func is_mud(z: float) -> bool:
	return sin(z * 0.019) > 0.70 and not is_bridge(z) and ford_amount(z) < 0.1

func mud_at(x: float, z: float) -> bool:
	if start_clearing(x, z) > 0.1: return false
	return (is_mud(z) or noise.get_noise_2d(x * 2, z * 2) > 0.25) and drive_height(x, z) < 225

func ground(x: float, z: float) -> float:
	var d = abs(x - road_x(z))
	var gorge = pow(maxf(0, sin(z * 0.0037 + 1.4)), 10)
	var valley_width = lerpf(105.0, 12.0, gorge)
	var mountain = pow(maxf(0, d - valley_width) * 0.012, 1.18) * (65 + 34 * (noise.get_noise_2d(x, z) + 1))
	var base = road_y(z) - 1 + mountain + noise.get_noise_2d(x * 3, z * 3) * minf(d * 0.35, 18)
	var rd = abs(x - river_x(z))
	base = lerpf(base, water_y(z) - 1.8, 1 - smoothstep(6, 17, rd))
	var height_sum = 0.0
	var weight_sum = 0.0
	var influence = 0.0
	var nearest_distance = abs(x - route_x(z, nearest_route(x, z)))
	for route in range(4):
		var offset = x - route_x(z, route)
		var distance = abs(offset)
		var shoulder = lerpf(60.0, 18.0, gorge)
		if distance > shoulder: continue
		# Subtract the nearest distance before exponentiation: no abrupt cliffs
		# caused by weights underflowing to zero at the edge of the shoulder.
		var weight = exp(-(distance * distance - nearest_distance * nearest_distance) / 28.0)
		var rough = (sin(z * 0.59 + x * 0.7) + sin(z * 1.1 - x * 0.9) * 0.5) * (0.18 if route == 0 else 0.28)
		var rut = exp(-pow((abs(offset) - 1.18) * 2.5, 2)) * (0.3 if is_mud(z) else 0.12)
		var bed = route_height(z, route) + rough - rut
		if rd < 17: bed = lerpf(bed, water_y(z) - 0.45, 1 - smoothstep(6, 17, rd))
		height_sum += bed * weight
		weight_sum += weight
		influence = maxf(influence, 1 - smoothstep(7.0, shoulder, distance))
	if weight_sum > 0.00001: base = lerpf(base, height_sum / weight_sum, influence)
	# A continuous bank contains the water, including where roads cross the river.
	var bank = smoothstep(7.0, 17.0, rd) * (1.0 - smoothstep(17.0, 25.0, rd))
	base = lerpf(base, maxf(base, water_y(z) + 0.35), bank)
	return lerpf(director.modify_ground(x, z, base), 80.16, start_clearing(x, z))

func terrain_columns(z: float) -> Array:
	var columns: Array = []
	for x in range(-600, 601, 24): columns.append(float(x))
	for route in range(4):
		for offset in [-20, -12, -6, -3.4, -2, -1.2, 0, 1.2, 2, 3.4, 6, 12, 20]:
			columns.append(route_x(z + STEP * 0.5, route) + offset)
	for offset in [-25, -17, -12, -7, 0, 7, 12, 17, 25]: columns.append(river_x(z) + offset)
	var lake = director.sector(int(floor(z / 2304.0)))[12]
	# Keep the same number of columns on every row for shared terrain triangles.
	for offset in [-1.3, -1.1, -0.9, -0.6, -0.3, 0.0, 0.3, 0.6, 0.9, 1.1, 1.3]:
		columns.append(lake.x + lake.radius.x * offset)
	columns.sort()
	return columns

func triangle_height(a: float, b: float, c: float, d: float, u: float, v: float) -> float:
	return a + (b - a) * u + (c - b) * v if v <= u else a + (c - d) * u + (d - a) * v

var column_cache: Dictionary = {}
func cached_columns(z: float) -> Array:
	if not column_cache.has(z):
		if column_cache.size() > 1200: column_cache.clear()
		column_cache[z] = terrain_columns(z)
	return column_cache[z]

func drive_height(x: float, z: float) -> float:
	var z0 = floor(z / STEP) * STEP
	var v = (z - z0) / STEP
	var row0 = cached_columns(z0)
	var row1 = cached_columns(z0 + STEP)
	var lo = 0
	var hi = row0.size() - 1
	while hi - lo > 1:
		var mid = int((lo + hi) / 2)
		if x < lerpf(row0[mid], row1[mid], v): hi = mid
		else: lo = mid
	var a: float = contact_ground(row0[lo], z0)
	var b: float = contact_ground(row0[hi], z0)
	var c: float = contact_ground(row1[hi], z0 + STEP)
	var d: float = contact_ground(row1[lo], z0 + STEP)
	var diagonal = lerpf(row0[lo], row1[hi], v)
	if x >= diagonal:
		var u = (x - diagonal) / maxf(0.00001, row0[hi] - row0[lo])
		return a + (b - a) * u + (c - a) * v
	var u = (x - lerpf(row0[lo], row1[lo], v)) / maxf(0.00001, row1[hi] - row1[lo])
	return a + (c - d) * u + (d - a) * v

func contact_ground(x: float, z: float) -> float:
	return ground(x, z) - (surface_effects.depth_at(x, z) if is_instance_valid(surface_effects) else 0.0)

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color):
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color):
	triangle(st, a, b, c, color)
	triangle(st, a, c, d, color)

func finish(st: SurfaceTool, parent: Node3D, mat: Material) -> MeshInstance3D:
	st.generate_normals()
	var m = MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat
	parent.add_child(m)
	return m

func update_chunks(z: float, immediate = false):
	director.prune(z)
	var center = int(floor(z / LENGTH))
	var behind = 1 if OS.has_feature("web") else 3
	var ahead = 5 if OS.has_feature("web") else 9
	for key in chunks.keys():
		if key < center - behind or key > center + ahead:
			chunks[key].queue_free()
			chunks.erase(key)
			obstacles.erase(key)
	if building_chunk and not immediate: return
	# Fill the road around the player first; distant scenery can arrive later.
	var order: Array[int] = [center]
	for distance in range(1, ahead + 1):
		if center + distance <= center + ahead: order.append(center + distance)
		if center - distance >= center - behind: order.append(center - distance)
	for i in order:
		if not chunks.has(i):
			build_chunk(i, immediate)
			if not immediate:
				break

func build_chunk(index: int, immediate: bool = true):
	building_chunk = true
	var root = Node3D.new()
	root.name = "Alpine_%d" % index
	add_child(root)
	chunks[index] = root
	obstacles[index] = []
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value + index * 7919
	var start = index * LENGTH
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var road_surface = SurfaceTool.new()
	road_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_road = false
	var river = SurfaceTool.new()
	river.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lakes = SurfaceTool.new()
	lakes.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wet_counts = Vector2i.ZERO
	var batch_start = Time.get_ticks_usec()
	var columns = terrain_columns(start)
	var heights: Array[float] = []
	for x in columns: heights.append(ground(x, start))
	for iz in range(int(LENGTH / STEP)):
		if not immediate and Time.get_ticks_usec() - batch_start > 1800:
			await get_tree().process_frame
			if not is_instance_valid(root) or root.is_queued_for_deletion():
				building_chunk = false
				return
			batch_start = Time.get_ticks_usec()
		var z = start + iz * STEP
		var next_columns = terrain_columns(z + STEP)
		var next_heights: Array[float] = []
		for x in next_columns: next_heights.append(ground(x, z + STEP))
		for ix in range(columns.size() - 1):
			var x: float = columns[ix]
			var width: float = columns[ix + 1] - x
			var a = Vector3(x, heights[ix], z)
			var b = Vector3(x + width, heights[ix + 1], z)
			var nx: float = next_columns[ix]
			var nx1: float = next_columns[ix + 1]
			var c = Vector3(nx1, next_heights[ix + 1], z + STEP)
			var d = Vector3(nx, next_heights[ix], z + STEP)
			wet_counts += water_system.add_terrain_water(river, lakes, [a, b, c])
			wet_counts += water_system.add_terrain_water(river, lakes, [a, c, d])
			var altitude = (a.y + b.y + c.y + d.y) * 0.25
			var col = Color("7f9365")
			if altitude > 215.0 + noise.get_noise_2d(x * 2, z * 2) * 25:
				col = Color("e3e9de")
			elif altitude > 190.0:
				col = Color("8c9991")
			elif altitude > 155.0:
				col = Color("647e69")
			elif abs(x - river_x(z)) < 22.0:
				col = Color("aaa58a")
			var mid_x = x + width * 0.5
			var mid_z = z + STEP * 0.5
			var route = nearest_route(mid_x, mid_z)
			var trail_d = abs(mid_x - route_x(mid_z, route))
			if trail_d < 3.0 + noise.get_noise_2d(mid_x * 8, mid_z * 8) * 1.2:
				var trail = Color("8a8870") if not is_mud(mid_z) else Color("514331")
				if altitude > 235: trail = Color("c4cec8")
				col = col.lerp(trail, 0.9 if trail_d < 2 else 0.5)
			col = col.lightened(rng.randf_range(-0.035, 0.035))
			if trail_d < 2.6:
				quad(road_surface, a, b, c, d, col)
				has_road = true
			else: quad(st, a, b, c, d, col)
		columns = next_columns
		heights = next_heights
	finish(st, root, terrain_material)
	if has_road: finish(road_surface, root, road_material)
	if wet_counts.x > 0:
		var surface = finish(river, root, water_material)
		surface.name = "RiverSurface"
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if wet_counts.y > 0:
		var surface = finish(lakes, root, lake_material)
		surface.name = "LakeSurface"
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var transforms: Array[Transform3D] = []
	for j in range(110):
		var z = rng.randf_range(start, start + LENGTH)
		var x = road_x(z) + rng.randf_range(-230, 230)
		if start_clearing(x, z) > 0.05: continue
		if abs(x - route_x(z, nearest_route(x, z))) < 6.0 or abs(x - river_x(z)) < 19.0:
			continue
		var h = ground(x, z)
		if h > 220:
			continue
		var size = rng.randf_range(0.7, 1.7)
		transforms.append(Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(x, h - 0.3, z)))
		if abs(x - road_x(z)) < 45:
			obstacles[index].append(Vector3(x, size * 0.65, z))
	var trees = MultiMeshInstance3D.new()
	trees.multimesh = MultiMesh.new()
	trees.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	trees.multimesh.mesh = tree_mesh
	trees.multimesh.instance_count = transforms.size()
	for i in transforms.size():
		trees.multimesh.set_instance_transform(i, transforms[i])
	trees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(trees)
	var river_rocks: Array[Transform3D] = []
	for j in range(16):
		var z = rng.randf_range(start, start + LENGTH)
		var x = river_x(z) + rng.randf_range(-19, 19)
		if abs(x - road_x(z)) < 6 or abs(x - branch_x(z)) < 6:
			continue
		var size = Vector3(rng.randf_range(1.4, 3.5), rng.randf_range(1.2, 3.0), rng.randf_range(1.5, 4))
		river_rocks.append(Transform3D(Basis().scaled(size), Vector3(x, ground(x, z), z)))
	add_rock_batch(root, river_rocks, wood)
	decorate_chunk(root, index, rng)
	preload("res://scripts/scenery.gd").populate(self, root, index, rng)
	building_chunk = false
	root.set_meta("ready", true)
	var pz = start + 70.0
	if posmod(index, 4) == 1:
		var cx = road_x(pz) - 16
		var cy = ground(cx, pz)
		for dx in [-3, 3]:
			for dz in [-2, 2]:
				box(root, Vector3(cx + dx, cy + 1.7, pz + dz), Vector3(0.24, 3.4, 0.24), wood)
		box(root, Vector3(cx, cy + 3.5, pz), Vector3(7.5, 0.4, 5.5), material(Color("466d69")))
		box(root, Vector3(cx, cy + 0.8, pz), Vector3(3.5, 0.2, 1.5), wood)

func build_tree_mesh():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in range(4):
		var y = 1.6 + layer * 1.65
		var radius = 2.4 - layer * 0.47
		for s in range(7):
			var a = TAU * s / 7.0
			var b = TAU * (s + 1) / 7.0
			triangle(st, Vector3(cos(a) * radius, y, sin(a) * radius), Vector3(0, y + 3.2, 0), Vector3(cos(b) * radius, y, sin(b) * radius), Color("315d50").lightened(s * 0.014 + layer * 0.023))
	for s in range(6):
		var a = TAU * s / 6.0
		var b = TAU * (s + 1) / 6.0
		quad(st, Vector3(cos(a) * 0.22, 0, sin(a) * 0.22), Vector3(cos(a) * 0.22, 3, sin(a) * 0.22), Vector3(cos(b) * 0.22, 3, sin(b) * 0.22), Vector3(cos(b) * 0.22, 0, sin(b) * 0.22), Color("6b5341"))
	st.generate_normals()
	tree_mesh = st.commit()
	tree_mesh.surface_set_material(0, terrain_material)

func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	if OS.has_feature("web"): node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = pos
	parent.add_child(node)
	return node

func add_rock_batch(parent: Node3D, transforms: Array[Transform3D], mat: Material):
	if transforms.is_empty(): return
	var batch = MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = rock_mesh
	batch.multimesh.instance_count = transforms.size()
	for i in range(transforms.size()): batch.multimesh.set_instance_transform(i, transforms[i])
	batch.material_override = mat
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(batch)

func collides(pos: Vector3) -> bool:
	if director.shell_blocked(pos, true): return true
	var index = int(floor(pos.z / LENGTH))
	for k in range(index - 1, index + 2):
		for p in obstacles.get(k, []):
			if Vector2(pos.x - p.x, pos.z - p.z).length() < p.y + 1.15:
				return true
	return false


func decorate_chunk(root: Node3D, index: int, rng: RandomNumberGenerator):
	var z = index * LENGTH + 72
	if posmod(index, 29) == 16:
		var x = branch_x(z) - 9
		var h = drive_height(x, z)
		var timber = material(Color("69523f"))
		for dx in [-3, 3]:
			for dz in [-2.5, 2.5]: box(root, Vector3(x + dx, h + 0.3, z + dz), Vector3(0.32, 2, 0.32), wood)
		box(root, Vector3(x, h + 2, z), Vector3(6.6, 3.4, 5.6), timber)
		for j in range(8): box(root, Vector3(x, h + 0.6 + j * 0.4, z - 2.84), Vector3(6.7, 0.11, 0.12), wood)
		for side in [-1, 1]:
			var roof = box(root, Vector3(x + side * 1.85, h + 4.5, z), Vector3(4.2, 0.22, 6.5), material(Color("526764") if h < 290 else Color("e2e6df")))
			roof.rotation.z = side * -0.4
		box(root, Vector3(x, h + 1.4, z - 2.87), Vector3(1.1, 2.3, 0.1), timber)
		var glow = material(Color("efbc72"))
		glow.emission_enabled = true
		glow.emission = Color("b97f42")
		for dx in [-2.1, 2.1]: box(root, Vector3(x + dx, h + 2.2, z - 2.9), Vector3(1.0, 1.05, 0.1), glow)
		box(root, Vector3(x + 1.8, h + 5, z + 1), Vector3(0.65, 2, 0.65), wood)
		obstacles[index].append(Vector3(x, 4.5, z))
	if branch_amount(z) > 0.7:
		var x = branch_x(z) + 5
		var h = drive_height(x, z)
		box(root, Vector3(x, h + 0.5, z), Vector3(2.3, 0.18, 0.65), wood)
		box(root, Vector3(x, h + 0.2, z), Vector3(0.4, 0.5, 0.5), wood)
	# Clusters of low boulders, coarse gravel and alpine shrubs.
	var pale_rocks: Array[Transform3D] = []
	var dark_rocks: Array[Transform3D] = []
	for j in range(38):
		var rz = index * LENGTH + rng.randf_range(0, LENGTH)
		var rx = route_x(rz, j % 2) + rng.randf_range(4.5, 10.0) * (-1 if j % 3 == 0 else 1)
		if abs(rx - road_x(rz)) < 4 or abs(rx - branch_x(rz)) < 4: continue
		var transform = Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.3, 1.6)), Vector3(rx, drive_height(rx, rz), rz))
		if j % 3: pale_rocks.append(transform)
		else: dark_rocks.append(transform)
	add_rock_batch(root, pale_rocks, marker)
	add_rock_batch(root, dark_rocks, wood)
func camera_blocked(point: Vector3) -> bool:
	if director.shell_blocked(point): return true
	if point.y < drive_height(point.x, point.z) + 0.45: return true
	var index = int(floor(point.z / LENGTH))
	for k in range(index - 1, index + 2):
		for p in obstacles.get(k, []):
			if Vector2(point.x - p.x, point.z - p.z).length() < p.y + 1.5:
				if point.y < ground(p.x, p.z) + maxf(8.0, p.y * 2.0): return true
	return false

func animate_wildlife(player: Vector3, time: float, delta: float):
	grass_material.set_shader_parameter("vehicle", player)
	var live_falls = 0
	for i in range(waterfall_emitters.size() - 1, -1, -1):
		var emitter = waterfall_emitters[i]
		if not is_instance_valid(emitter):
			waterfall_emitters.remove_at(i)
			continue
		emitter.emitting = emitter.global_position.distance_to(player) < 90 and live_falls < 2
		if emitter.emitting: live_falls += 1
	for i in range(birds.size() - 1, -1, -1):
		var bird = birds[i]
		if not is_instance_valid(bird):
			birds.remove_at(i)
			continue
		var home: Vector3 = bird.get_meta("home")
		if home.distance_to(player) > 180: continue
		var phase = time * 0.35 + float(bird.get_meta("phase"))
		bird.position = home + Vector3(sin(phase) * 18, sin(phase * 0.7) * 2, cos(phase) * 13)
		bird.rotation.y = -phase
		for wing in bird.get_children(): wing.rotation.z = signf(wing.position.x) * sin(time * 5) * 0.35
	for i in range(wildlife.size() - 1, -1, -1):
		var animal = wildlife[i]
		if not is_instance_valid(animal):
			wildlife.remove_at(i)
			continue
		if animal.position.distance_to(player) > 100: continue
		var home: Vector3 = animal.get_meta("home")
		var phase: float = animal.get_meta("phase")
		var alarm = animal.position.distance_to(player) < 13
		var target = home + Vector3(sin(time * 0.09 + phase) * 4, 0, cos(time * 0.12 + phase) * 3)
		if alarm: target = animal.position + (animal.position - player).normalized() * 7
		var direction = target - animal.position
		direction.y = 0
		var walking = direction.length() > 0.3
		if walking:
			var next = animal.position + direction.normalized() * delta * (3.2 if alarm else 0.55)
			if not sample_water(next).present and absf(drive_height(next.x, next.z) - animal.position.y) < 0.6 and not collides(next):
				animal.position = next
			animal.rotation.y = lerp_angle(animal.rotation.y, atan2(direction.x, direction.z), minf(delta * 3, 1))
		animal.position.y = drive_height(animal.position.x, animal.position.z)
		for leg in animal.get_meta("legs"):
			leg.rotation.x = sin(time * (12 if alarm else 5) + leg.position.x * 10 + leg.position.z * 8) * (0.35 if walking else 0.0)

func safe_camera(look: Vector3, target: Vector3) -> Vector3:
	var steps = maxi(5, int(ceil(look.distance_to(target) / 3.0))) if OS.has_feature("web") else maxi(12, int(ceil(look.distance_to(target))))
	for i in range(2, steps + 1):
		var t = float(i) / steps
		var point = look.lerp(target, t)
		if camera_blocked(point):
			return look.lerp(target, maxf(0.1, t - 0.07))
	return target

func sample_water(position: Vector3) -> Dictionary:
	return water_system.sample(position)

func solar_exposure(position: Vector3, phase: float) -> float:
	if not director.tunnel_at(position).is_empty(): return 0.0
	var key = Vector3i(int(position.x / 8), int(position.z / 8), int(phase * 1200))
	if exposure_cache.has(key): return exposure_cache[key]
	var elevation = maxf(0.05, sin(phase / 0.7 * PI))
	var direction = Vector3(cos(phase * TAU), elevation * 1.4, sin(phase * TAU)).normalized()
	var factor = 1.0
	for distance in [8.0, 18.0, 35.0, 60.0]:
		var q = position + Vector3(0, 3.5, 0) + direction * distance
		if ground(q.x, q.z) > q.y:
			factor = 0.2
			break
	if exposure_cache.size() > 32: exposure_cache.clear()
	exposure_cache[key] = factor
	return factor

func near_village(position: Vector3) -> bool:
	for item in director.near_z(position.z):
		if item.kind == "village" and Vector2(position.x - item.x, position.z - item.z).length() < 70: return true
	return false
