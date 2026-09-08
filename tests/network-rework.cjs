const fs=require('fs');let p='scripts/world.gd',s=fs.readFileSync(p,'utf8');
s=s.replace('const STEP = 6.0','const STEP = 3.0');
let a=s.indexOf('func road_x('),b=s.indexOf('func river_x(',a);
s=s.slice(0,a)+`func road_x(z: float) -> float:
	return sin(z * 0.0035) * 105.0 + sin(z * 0.012) * 48.0 + sin(z * 0.029) * 15.0

func road_y(z: float) -> float:
	return 110.0 + sin(z * 0.0017 - 0.8) * 85.0 + sin(z * 0.007) * 24.0

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

`+s.slice(b);
s=s.replace('return abs(river_x(z) - road_x(z)) < 18.0 and posmod(int(floor(z / 950)), 2) == 0','return false');s=s.replace('\tif posmod(int(floor(z / 950)), 2) == 0: return 0.0\n','');s=s.replace('return is_mud(z) and nearest_route(x, z) == 0 and abs(x - road_x(z)) < 4.0','return (is_mud(z) or noise.get_noise_2d(x * 2, z * 2) > 0.25) and drive_height(x, z) < 225');
a=s.indexOf('func ground(');b=s.indexOf('func triangle(',a);
s=s.slice(0,a)+`func ground(x: float, z: float) -> float:
	var d = abs(x - road_x(z))
	var mountain = pow(maxf(0, d - 10) * 0.014, 1.18) * (65 + 34 * (noise.get_noise_2d(x, z) + 1))
	var base = road_y(z) - 1 + mountain + noise.get_noise_2d(x * 3, z * 3) * minf(d * 0.35, 18)
	var rd = abs(x - river_x(z))
	base = lerpf(base, water_y(z) - 1.8, 1 - smoothstep(6, 17, rd))
	var height_sum = 0.0
	var weight_sum = 0.0
	var influence = 0.0
	for route in range(4):
		var offset = x - route_x(z, route)
		var distance = abs(offset)
		if distance > 20: continue
		var weight = exp(-distance * distance / 28.0)
		var rough = (sin(z * 0.59 + x * 0.7) + sin(z * 1.1 - x * 0.9) * 0.5) * (0.18 if route == 0 else 0.28)
		var rut = exp(-pow((abs(offset) - 1.18) * 2.5, 2)) * (0.3 if is_mud(z) else 0.12)
		var bed = route_height(z, route) + rough - rut
		if rd < 17: bed = lerpf(bed, water_y(z) - 0.45, 1 - smoothstep(6, 17, rd))
		height_sum += bed * weight
		weight_sum += weight
		influence = maxf(influence, 1 - smoothstep(3.4, 20, distance))
	if weight_sum > 0.00001: base = lerpf(base, height_sum / weight_sum, influence)
	return base

func terrain_columns(z: float) -> Array:
	var columns: Array = []
	for x in range(-600, 601, 24): columns.append(float(x))
	for route in range(4):
		for offset in [-20, -12, -6, -3.4, -2, -1.2, 0, 1.2, 2, 3.4, 6, 12, 20]:
			columns.append(route_x(z + STEP * 0.5, route) + offset)
	for offset in [-18, -9, 0, 9, 18]: columns.append(river_x(z + STEP * 0.5) + offset)
	columns.sort()
	return columns

func triangle_height(a: float, b: float, c: float, d: float, u: float, v: float) -> float:
	return a + (b - a) * u + (c - b) * v if v <= u else a + (c - d) * u + (d - a) * v

var column_cache: Dictionary = {}
func drive_height(x: float, z: float) -> float:
	var z0 = floor(z / STEP) * STEP
	if not column_cache.has(z0):
		if column_cache.size() > 1200: column_cache.clear()
		column_cache[z0] = terrain_columns(z0)
	var columns: Array = column_cache[z0]
	var i = clampi(columns.bsearch(x) - 1, 0, columns.size() - 2)
	var x0: float = columns[i]
	var x1: float = columns[i + 1]
	var u = clampf((x - x0) / maxf(0.0001, x1 - x0), 0, 1)
	return triangle_height(ground(x0, z0), ground(x1, z0), ground(x1, z0 + STEP), ground(x0, z0 + STEP), u, (z - z0) / STEP)

`+s.slice(b);
s=s.replace('for iz in range(24):','for iz in range(int(LENGTH / STEP)):').replace('for ix in range(-96, 96):\n\t\t\tvar x = ix * STEP','var columns = terrain_columns(z)\n\t\tfor ix in range(columns.size() - 1):\n\t\t\tvar x: float = columns[ix]\n\t\t\tvar width: float = columns[ix + 1] - x').replaceAll('x + STEP, ground(x + STEP','x + width, ground(x + width');
s=s.replace('col = col.lightened(rng.randf_range(-0.075, 0.075))',`var mid_x = x + width * 0.5
			var mid_z = z + STEP * 0.5
			var route = nearest_route(mid_x, mid_z)
			var trail_d = abs(mid_x - route_x(mid_z, route))
			if trail_d < 3.0 + noise.get_noise_2d(mid_x * 8, mid_z * 8) * 1.2:
				var trail = Color("8a8870") if not is_mud(mid_z) else Color("514331")
				if altitude > 235: trail = Color("c4cec8")
				col = col.lerp(trail, 0.9 if trail_d < 2 else 0.5)
			col = col.lightened(rng.randf_range(-0.035, 0.035))`);
a=s.indexOf('\tvar road = SurfaceTool.new()');b=s.indexOf('\tvar transforms:',a);
s=s.slice(0,a)+`\tvar river = SurfaceTool.new()
	river.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(96):
		var z = start + j * ROAD_STEP
		quad(river, Vector3(river_x(z) - 7, water_y(z), z), Vector3(river_x(z) + 7, water_y(z), z), Vector3(river_x(z + ROAD_STEP) + 7, water_y(z + ROAD_STEP), z + ROAD_STEP), Vector3(river_x(z + ROAD_STEP) - 7, water_y(z + ROAD_STEP), z + ROAD_STEP), Color.WHITE)
	finish(river, root, water_material)
`+s.slice(b);
s=s.replace('if abs(x - road_x(z)) < 7.0 or abs(x - branch_x(z)) < 7.0 or abs(x - river_x(z)) < 19.0:', 'if abs(x - route_x(z, nearest_route(x, z))) < 6.0 or abs(x - river_x(z)) < 19.0:');
s=s.replace(/\tbox\(root, Vector3\(road_x\(pz\) - 6\.7[^\n]+\n/g,'');
a=s.indexOf('\tvar phase = fposmod(index * LENGTH, 960.0)');b=s.indexOf('func camera_blocked(',a);if(a>=0)s=s.slice(0,a)+s.slice(b);
s=s.replace(/\t\tvar sign_z = k \* LENGTH \+ 70\.0\n\t\tif Vector2[^\n]+\n/,'');fs.writeFileSync(p,s);
p='scripts/vehicle_physics.gd';s=fs.readFileSync(p,'utf8').replace('var drive_force = 7.0','var drive_force = 5.2').replace('if game.low_range: drive_force *= 1.65','if game.low_range: drive_force *= 2.15');s=s.replace('if game.low_range and abs(longitudinal) > 5.5: engine_force *= maxf(0, 1 - (abs(longitudinal) - 5.5) / 2)','var cruise_limit = 2.8 if game.low_range else 7.0\n\tif abs(longitudinal) > cruise_limit: engine_force *= maxf(0, 1 - (abs(longitudinal) - cruise_limit) / 1.5)\n\tif abs(longitudinal) > cruise_limit + 1.5: engine_force -= signf(longitudinal) * (abs(longitudinal) - cruise_limit - 1.5) * 4.0');fs.writeFileSync(p,s);
p='scripts/game.gd';s=fs.readFileSync(p,'utf8').replace('else 11','else 5.5').replace('6.0 if','4.0 if');fs.writeFileSync(p,s);
