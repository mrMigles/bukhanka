extends RefCounted
var world: Node
func _init(owner_world: Node): world = owner_world

func sample(p: Vector3) -> Dictionary:
	var ground = world.drive_height(p.x, p.z)
	var lake = world.director.lake_at(p.x, p.z, 1.1)
	if not lake.is_empty() and ground < lake.level:
		return {"present": true, "id": lake.id, "height": lake.level, "depth": maxf(0, float(lake.level) - ground), "flow": Vector3.ZERO, "fishable": true}
	if absf(p.x - world.river_x(p.z)) < 17.0:
		var height = world.water_y(p.z)
		var gradient = world.water_y(p.z + 1) - world.water_y(p.z - 1)
		var direction = -signf(gradient)
		return {"present": height > ground, "id": "river:%d" % int(floor(p.z / 288)), "height": height, "depth": maxf(0, height - ground), "flow": Vector3((world.river_x(p.z + 1) - world.river_x(p.z - 1)) * 0.5, 0, 1).normalized() * direction * minf(1.0, absf(gradient)), "fishable": absf(gradient) < 0.6}
	return {"present": false, "id": "", "height": ground - 1, "depth": 0.0, "flow": Vector3.ZERO, "fishable": false}

# Clip the actual terrain triangles at the water level. Every shore vertex
# lies on a terrain edge; rendering and wheel contact use the same triangles.
func add_terrain_water(river: SurfaceTool, lakes: SurfaceTool, points: Array) -> Vector2i:
	var center: Vector3 = (points[0] + points[1] + points[2]) / 3.0
	var lake = world.director.lake_at(center.x, center.z, 1.3)
	if not lake.is_empty():
		return Vector2i(0, wet_triangle(lakes, points, float(lake.level)))
	var near_river = false
	for p in points:
		if absf(p.x - world.river_x(p.z)) < 17.1: near_river = true
	return Vector2i(wet_triangle(river, points) if near_river else 0, 0)

func wet_triangle(st: SurfaceTool, points: Array, lake_level: float = INF) -> int:
	var polygon: Array = []
	for p in points:
		var height = world.water_y(p.z) if is_inf(lake_level) else lake_level
		polygon.append({"p": Vector3(p.x, height, p.z), "depth": height - p.y})
	var clipped: Array = []
	for i in range(3):
		var a = polygon[i]
		var b = polygon[(i + 1) % 3]
		if a.depth > 0: clipped.append(a)
		if (a.depth > 0) != (b.depth > 0):
			clipped.append({"p": a.p.lerp(b.p, a.depth / (a.depth - b.depth)), "depth": 0.0})
	for i in range(1, clipped.size() - 1):
		for v in [clipped[0], clipped[i], clipped[i + 1]]:
			st.set_color(Color(clampf(v.depth / 4.0, 0, 1), 0, 0, 1))
			st.set_uv(Vector2(v.p.x, v.p.z) * 0.15)
			st.add_vertex(v.p)
	return maxi(0, clipped.size() - 2)
