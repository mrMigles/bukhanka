extends RefCounted
## Immutable descriptors, independent of the order in which chunks are loaded.
var world: Node
var cache: Dictionary = {}

func _init(owner_world: Node): world = owner_world

func sector(index: int) -> Array:
	if cache.has(index): return cache[index]
	var result: Array = []
	var base = index * 2304.0
	var rng = RandomNumberGenerator.new()
	rng.seed = world.seed_value + index * 104729
	var side = 1.0 if posmod(index, 2) == 0 else -1.0
	for slot in [1, 4, 7, 10, 13]:
		var z = base + slot * 144.0 + 72.0
		result.append(descriptor("animals", index, slot, world.road_x(z) + side * 12.0, z))
	for slot in [2, 5, 8, 11, 14]:
		var z = base + slot * 144.0 + 72.0
		result.append(descriptor("food", index, slot, world.road_x(z) - side * 10.0, z))
	for slot in [4, 11]:
		var z = base + slot * 144.0 + 72.0
		result.append(descriptor("waterfall", index, slot, world.river_x(z), z))
	var lake_z = base + 936.0
	var lake = descriptor("lake", index, 6, world.road_x(lake_z) - 48.0, lake_z)
	lake.radius = Vector2(26, 35)
	lake.level = world.road_y(lake_z) - 1.0
	result.append(lake)
	var village_z = base + 1368.0
	result.append(descriptor("village", index, 9, world.road_x(village_z) + 16.0, village_z))
	for i in range(4):
		var z = village_z - 25 + i * 17
		var apple = descriptor("food", index, 20 + i, world.road_x(z) + (18.0 if i % 2 == 0 else -10.0), z)
		apple.apple = true
		apple.maximum = 12.0
		result.append(apple)
	var tunnel_z = base + 1944.0
	# Never place a tunnel through a ford. Deterministic bounded search.
	for offset in [0.0, 48.0, -48.0, 96.0, -96.0, 144.0, -144.0, 240.0, -240.0, 320.0, -320.0]:
		var z = tunnel_z + offset
		if absf(world.river_x(z) - world.road_x(z)) > 24.0 and absf(world.river_x(z + 30) - world.road_x(z + 30)) > 24.0:
			var tunnel = descriptor("tunnel", index, 13, world.road_x(z), z)
			tunnel.length = 48.0
			tunnel.gallery = posmod(index, 2) == 1
			result.append(tunnel)
			break
	var manul_z = base + 504.0
	result.append(descriptor("manul", index, 30, world.branch_x(manul_z) - 11.0, manul_z))
	cache[index] = result
	return result

func descriptor(kind: String, region: int, slot: int, x: float, z: float) -> Dictionary:
	return {"id": "%s:%d:%d" % [kind, region, slot], "kind": kind, "x": x, "z": z, "region": region, "slot": slot, "owner": int(floor(z / 144.0))}

func near_z(z: float) -> Array:
	var region = int(floor(z / 2304.0))
	var result: Array = []
	for i in range(region - 1, region + 2): result.append_array(sector(i))
	return result

func forest_density(z: float) -> float:
	# One short belt in each 2.3 km region; about 10% of the main route.
	var region = int(floor(z / 2304.0))
	var center = region * 2304.0 + 650.0 + sin(float(world.seed_value + region * 7919)) * 55.0
	return 1.0 - smoothstep(70.0, 135.0, absf(z - center))

func for_chunk(index: int) -> Array:
	var result: Array = []
	for item in near_z(index * 144.0):
		if item.owner == index: result.append(item)
	return result

func lake_at(x: float, z: float, margin: float = 1.0) -> Dictionary:
	var item = sector(int(floor(z / 2304.0)))[12]
	if absf(z - item.z) > 45: return {}
	var r = Vector2((x - item.x) / item.radius.x, (z - item.z) / item.radius.y).length()
	if r < margin: return item
	return {}

func modify_ground(x: float, z: float, original: float) -> float:
	var lake = lake_at(x, z, 1.22)
	if not lake.is_empty():
		var r = Vector2((x - lake.x) / lake.radius.x, (z - lake.z) / lake.radius.y).length()
		var bed = float(lake.level) - 4.0 * (1.0 - pow(minf(r, 1.22), 2))
		var mask = 1.0 - smoothstep(0.96, 1.22, r)
		var road_protection = smoothstep(4.0, 8.0, absf(x - world.route_x(z, world.nearest_route(x, z))))
		var shore = smoothstep(0.85, 1.0, r) * (1.0 - smoothstep(1.1, 1.22, r))
		return lerpf(lerpf(original, bed, mask * road_protection), maxf(original, float(lake.level) + 0.45), shore)
	return original

func tunnel_at(p: Vector3) -> Dictionary:
	for item in near_z(p.z):
		if item.kind == "tunnel" and absf(p.z - item.z) < item.length * 0.5 and absf(p.x - world.road_x(p.z)) < 4.0:
			return item
	return {}

func shell_blocked(p: Vector3, vehicle: bool = false) -> bool:
	for item in near_z(p.z):
		if item.kind != "tunnel" or absf(p.z - item.z) > item.length * 0.5 + 0.5: continue
		var lateral = absf(p.x - world.road_x(p.z))
		var y = p.y - world.drive_height(world.road_x(p.z), p.z)
		if vehicle:
			if lateral > 2.5 and lateral < 6.0 and y < 8: return true
		else:
			if lateral > 3.7 and lateral < 5.5 and y < 7.8: return true
			if lateral < 5.5 and y > 6.1 and y < 8.1: return true
	return false

func nearby_sources(p: Vector3, radius: float = 45.0) -> Array:
	var result: Array = []
	for item in near_z(p.z):
		if item.kind == "food" and Vector2(p.x - item.x, p.z - item.z).length() < radius:
			result.append({"id": item.id, "kind": "food", "label": "Яблоки" if item.get("apple", false) else "Ягоды", "position": Vector3(item.x, world.drive_height(item.x, item.z), item.z), "maximum": item.get("maximum", 8.0)})
	# Trace dry-to-wet transitions at one-metre intervals. Keep alternative
	# banks: the nearest one can be separated from camp by a cliff or rocks.
	var bank_cells: Dictionary = {}
	for i in range(32):
		var direction = Vector3(cos(i * TAU / 32), 0, sin(i * TAU / 32))
		var previous = p
		for distance in range(1, int(radius)):
			var q = p + direction * distance
			var sample = world.sample_water(q)
			if sample.present and sample.depth > 0.15:
				var bank = previous - direction
				bank.y = world.drive_height(bank.x, bank.z)
				var key = Vector2i(roundi(bank.x / 4), roundi(bank.z / 4))
				if world.sample_water(bank).depth <= 0.15 and not bank_cells.has(key):
					bank_cells[key] = true
					q.y = sample.height
					result.append({"id": sample.id, "kind": "water", "position": bank, "water_position": q, "maximum": 1e6})
					if sample.fishable: result.append({"id": sample.id + ":fish", "kind": "fishing", "position": bank, "water_position": q, "maximum": 8.0})
				break
			previous = q
	return result
func prune(z: float):
	var region = int(floor(z / 2304.0))
	for key in cache.keys():
		if abs(key - region) > 3: cache.erase(key)
