const fs=require('fs');let s=fs.readFileSync('scripts/world.gd','utf8');
s=s.replace('const STEP = 12.0','const STEP = 6.0\nconst ROAD_STEP = 1.5\nconst EDGES = [-3.4, -2.0, -1.55, -0.85, 0.85, 1.55, 2.0, 3.4]\nvar road_material = ShaderMaterial.new()');
s=s.replace('water_material.shader = load("res://shaders/water.gdshader")','water_material.shader = load("res://shaders/water.gdshader")\n\troad_material.shader = load("res://shaders/gravel.gdshader")');
const a=s.indexOf('func road_x('),b=s.indexOf('\nfunc triangle(',a);
s=s.slice(0,a)+`func road_x(z: float) -> float:
	return sin(z * 0.0028) * 100.0 + sin(z * 0.009) * 40.0 + sin(z * 0.018) * 12.0

func road_y(z: float) -> float:
	return 96.0 + sin(z * 0.0015 - 0.8) * 75.0 + sin(z * 0.0055) * 28.0

func branch_amount(z: float) -> float:
	var phase = fposmod(z, 960.0)
	if phase < 180 or phase > 800: return 0.0
	return pow(sin((phase - 180) / 620.0 * PI), 2)

func branch_x(z: float) -> float:
	return road_x(z) - branch_amount(z) * 60.0

func branch_y(z: float) -> float:
	return road_y(z) + branch_amount(z) * 34.0

func nearest_route(x: float, z: float) -> int:
	return 1 if branch_amount(z) > 0.02 and abs(x - branch_x(z)) < abs(x - road_x(z)) else 0

func route_x(z: float, route: int) -> float:
	return branch_x(z) if route == 1 else road_x(z)

func river_x(z: float) -> float:
	return road_x(z) + 45.0 + 69.0 * sin(z * 0.0055 + 0.5)

func is_bridge(z: float) -> bool:
	return abs(river_x(z) - road_x(z)) < 18.0 and posmod(int(floor(z / 950)), 2) == 0

func ford_amount(z: float) -> float:
	if posmod(int(floor(z / 950)), 2) == 0: return 0.0
	return 1.0 - smoothstep(8.0, 28.0, abs(river_x(z) - road_x(z)))

func water_y(z: float) -> float:
	return road_y(z) - 3.0 + ford_amount(z) * 3.0

func is_mud(z: float) -> bool:
	return sin(z * 0.019) > 0.70 and not is_bridge(z) and ford_amount(z) < 0.1

func mud_at(x: float, z: float) -> bool:
	return is_mud(z) and nearest_route(x, z) == 0 and abs(x - road_x(z)) < 4.0

func ground(x: float, z: float) -> float:
	var d = abs(x - road_x(z))
	var ridge = maxf(0.0, d - 14.0)
	var mountain = pow(ridge * 0.014, 1.24) * (42.0 + 43.0 * (noise.get_noise_2d(x, z) + 1.0))
	var slope_side = 1.0 if x < road_x(z) else 0.60
	var base = road_y(z) - 2.0 + mountain * slope_side + noise.get_noise_2d(x * 3, z * 3) * minf(d * 0.3, 12.0)
	base = lerpf(road_y(z) - 0.25, base, smoothstep(3.5, 13, d))
	if branch_amount(z) > 0.01:
		var bd = abs(x - branch_x(z))
		base = lerpf(branch_y(z) - 0.25, base, smoothstep(3.5, 12, bd))
	var rd = abs(x - river_x(z))
	return lerpf(base, water_y(z) - 2.0, 1.0 - smoothstep(7.0, 17.0, rd))

func road_vertex(offset: float, z: float, route = 0) -> float:
	var center_height = branch_y(z) if route == 1 else road_y(z)
	if route == 0 and is_bridge(z): return center_height + 0.15
	var muddy = is_mud(z) and route == 0
	var rough = 0.17 if muddy else 0.095
	var rut = exp(-pow((abs(offset) - 1.18) * 2.5, 2)) * (0.25 if muddy else 0.055)
	var crown = 0.12 * (1.0 - abs(offset) / 3.4)
	var dip = ford_amount(z) * 0.5 if route == 0 else 0.0
	return center_height + 0.20 + crown - rut - dip + (sin(z * 0.77 + offset * 1.1) + sin(z * 1.6 - offset * 0.8) * 0.5) * rough

func triangle_height(a: float, b: float, c: float, d: float, u: float, v: float) -> float:
	return a + (b - a) * u + (c - b) * v if v <= u else a + (c - d) * u + (d - a) * v

func drive_height(x: float, z: float) -> float:
	var z0 = floor(z / ROAD_STEP) * ROAD_STEP
	var v = (z - z0) / ROAD_STEP
	var route = nearest_route(x, z)
	var center = lerpf(route_x(z0, route), route_x(z0 + ROAD_STEP, route), v)
	var offset = x - center
	if abs(offset) < 3.4:
		for i in range(EDGES.size() - 1):
			if offset <= EDGES[i + 1]:
				var u = (offset - EDGES[i]) / (EDGES[i + 1] - EDGES[i])
				return triangle_height(road_vertex(EDGES[i], z0, route), road_vertex(EDGES[i + 1], z0, route), road_vertex(EDGES[i + 1], z0 + ROAD_STEP, route), road_vertex(EDGES[i], z0 + ROAD_STEP, route), u, v)
	var x0 = floor(x / STEP) * STEP
	z0 = floor(z / STEP) * STEP
	return triangle_height(ground(x0, z0), ground(x0 + STEP, z0), ground(x0 + STEP, z0 + STEP), ground(x0, z0 + STEP), (x - x0) / STEP, (z - z0) / STEP)
`+s.slice(b);
s=s.replace('for iz in range(12):','for iz in range(24):').replace('for ix in range(-48, 48):','for ix in range(-96, 96):');
s=s.replace('var altitude = (a.y + b.y + c.y + d.y) * 0.25 - road_y(z)', 'var altitude = (a.y + b.y + c.y + d.y) * 0.25');
s=s.replace('if altitude > 170.0:', 'if altitude > 330.0 + noise.get_noise_2d(x * 2, z * 2) * 25:').replace('elif altitude > 85.0:', 'elif altitude > 260.0:').replace('elif altitude > 35.0:', 'elif altitude > 175.0:');
const c=s.indexOf('\tfor j in range(48):'),d=s.indexOf('\tvar transforms:',c);
s=s.slice(0,c)+`\tfor j in range(96):
		var z = start + j * ROAD_STEP
		for route in range(2):
			if route == 1 and branch_amount(z) < 0.004: continue
			var col = Color("8f8f7e") if not (is_mud(z) and route == 0) else Color("4b3d2f")
			if route == 0 and is_bridge(z): col = Color("8b7660")
			for strip in range(EDGES.size() - 1):
				var x1 = EDGES[strip]
				var x2 = EDGES[strip + 1]
				var color = col.darkened(0.17) if strip == 2 or strip == 4 else col
				color = color.lightened(rng.randf_range(-0.045, 0.045))
				quad(road, Vector3(route_x(z, route) + x1, road_vertex(x1, z, route), z), Vector3(route_x(z, route) + x2, road_vertex(x2, z, route), z), Vector3(route_x(z + ROAD_STEP, route) + x2, road_vertex(x2, z + ROAD_STEP, route), z + ROAD_STEP), Vector3(route_x(z + ROAD_STEP, route) + x1, road_vertex(x1, z + ROAD_STEP, route), z + ROAD_STEP), color)
		quad(river, Vector3(river_x(z) - 9, water_y(z), z), Vector3(river_x(z) + 9, water_y(z), z), Vector3(river_x(z + ROAD_STEP) + 9, water_y(z + ROAD_STEP), z + ROAD_STEP), Vector3(river_x(z + ROAD_STEP) - 9, water_y(z + ROAD_STEP), z + ROAD_STEP), Color.WHITE)
		if is_bridge(z) and j % 4 == 0:
			for side in [-1, 1]:
				box(root, Vector3(road_x(z) + side * 3.6, road_y(z) + 0.7, z), Vector3(0.2, 1.4, 0.2), wood)
				box(root, Vector3(road_x(z) + side * 3.6, road_y(z) + 1.25, z + 3), Vector3(0.17, 0.16, 6.2), wood)
	finish(road, root, road_material)
	finish(river, root, water_material)
`+s.slice(d);
s=s.replace('abs(x - road_x(z)) < 10.0 or abs(x - river_x(z)) < 19.0', 'abs(x - road_x(z)) < 7.0 or abs(x - branch_x(z)) < 7.0 or abs(x - river_x(z)) < 19.0');
s=s.replace('if h - road_y(z) > 120:', 'if h > 295:');
s=s.replace('if abs(x - road_x(z)) < 8:', 'if abs(x - road_x(z)) < 6 or abs(x - branch_x(z)) < 6:');
s=s.replace('var pz = start + 70.0','decorate_chunk(root, index, rng)\n\tvar pz = start + 70.0');
s+=`
func decorate_chunk(root: Node3D, index: int, rng: RandomNumberGenerator):
	var z = index * LENGTH + 72
	if posmod(index, 5) == 2:
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
	for j in range(38):
		var rz = index * LENGTH + rng.randf_range(0, LENGTH)
		var rx = route_x(rz, j % 2) + rng.randf_range(4.5, 10.0) * (-1 if j % 3 == 0 else 1)
		if abs(rx - road_x(rz)) < 4 or abs(rx - branch_x(rz)) < 4: continue
		var rock = MeshInstance3D.new()
		rock.mesh = rock_mesh
		rock.material_override = marker if j % 3 else wood
		root.add_child(rock)
		rock.position = Vector3(rx, drive_height(rx, rz), rz)
		rock.scale = Vector3.ONE * rng.randf_range(0.3, 1.6)
	var phase = fposmod(index * LENGTH, 960.0)
	if phase < 220 and phase + LENGTH > 190:
		var sign_z = floor(index * LENGTH / 960.0) * 960 + 190
		var sign_x = road_x(sign_z) + 4.8
		box(root, Vector3(sign_x, road_y(sign_z) + 1.0, sign_z), Vector3(0.18, 2, 0.18), wood)
		var sign_label = Label3D.new()
		sign_label.text = "← ПЕРЕВАЛ / ВИД\nДОЛИНА / БРОД →"
		sign_label.font_size = 38
		sign_label.pixel_size = 0.023
		sign_label.modulate = Color("f0d9ad")
		sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign_label.position = Vector3(sign_x, road_y(sign_z) + 2.3, sign_z)
		root.add_child(sign_label)
`;
fs.writeFileSync('scripts/world.gd',s);
