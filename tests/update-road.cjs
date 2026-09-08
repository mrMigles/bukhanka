const fs = require('fs');
let s=fs.readFileSync('scripts/world.gd','utf8');
const begin=s.indexOf('func drive_height('),end=s.indexOf('\nfunc triangle(',begin);
s=s.slice(0,begin)+`func road_vertex(offset: float, z: float) -> float:
	if is_bridge(z): return road_y(z) + 0.13
	var rough = 0.22 if is_mud(z) else 0.075
	return road_y(z) + 0.22 + (sin(z * 0.61 + offset * 1.1) + sin(z * 1.2 - offset * 0.8) * 0.5) * rough

func drive_height(x: float, z: float) -> float:
	var z0 = floor(z / 3.0) * 3.0
	var v = (z - z0) / 3.0
	var center = lerpf(road_x(z0), road_x(z0 + 3), v)
	var offset = x - center
	if abs(offset) < 5.2:
		var edges = [-5.2, -3.1, -1.8, 1.8, 3.1, 5.2]
		for i in range(5):
			if offset <= edges[i + 1]:
				var u = (offset - edges[i]) / (edges[i + 1] - edges[i])
				var a = road_vertex(edges[i], z0)
				var b = road_vertex(edges[i + 1], z0)
				var c = road_vertex(edges[i + 1], z0 + 3)
				var d = road_vertex(edges[i], z0 + 3)
				return a + (b - a) * u + (c - b) * v if v <= u else a + (c - d) * u + (d - a) * v
	# Exact barycentric interpolation of the visible terrain triangles.
	var x0 = floor(x / STEP) * STEP
	z0 = floor(z / STEP) * STEP
	var u = (x - x0) / STEP
	v = (z - z0) / STEP
	var a = ground(x0, z0)
	var b = ground(x0 + STEP, z0)
	var c = ground(x0 + STEP, z0 + STEP)
	var d = ground(x0, z0 + STEP)
	return a + (b - a) * u + (c - b) * v if v <= u else a + (c - d) * u + (d - a) * v
`+s.slice(end);
s=s.replace('Vector3(road_x(z) + x1, road_y(z) + 0.13, z)', 'Vector3(road_x(z) + x1, road_vertex(x1, z), z)').replace('Vector3(road_x(z) + x2, road_y(z) + 0.13, z)', 'Vector3(road_x(z) + x2, road_vertex(x2, z), z)').replace('Vector3(road_x(z + 3) + x2, road_y(z + 3) + 0.13, z + 3)', 'Vector3(road_x(z + 3) + x2, road_vertex(x2, z + 3), z + 3)').replace('Vector3(road_x(z + 3) + x1, road_y(z + 3) + 0.13, z + 3)', 'Vector3(road_x(z + 3) + x1, road_vertex(x1, z + 3), z + 3)');
fs.writeFileSync('scripts/world.gd',s);
