extends RefCounted
var sites: Dictionary = {}
var selected: Dictionary = {}
var rotation = 0.0
var quality: Dictionary = {}

func evaluate(game: Node, center: Vector3, angle: float = 0.0, include_sources: bool = true) -> Dictionary:
	center.y = game.world.drive_height(center.x, center.z)
	var variation = 0.0
	var valid = center.distance_to(game.van.position) <= 36
	for footprint in [Vector3.ZERO, Vector3(-3.7, 0, 4.4), Vector3(3.7, 0, 4.4), Vector3(-7, 0, 6), Vector3(3.6, 0, -2.8), Vector3(-2, 0, -4.2)]:
		var p = center + footprint.rotated(Vector3.UP, angle)
		var base = game.world.drive_height(p.x, p.z)
		for offset in [Vector3(-1.2, 0, -1.2), Vector3(1.2, 0, -1.2), Vector3(-1.2, 0, 1.2), Vector3(1.2, 0, 1.2)]:
			var q = p + offset.rotated(Vector3.UP, angle)
			q.y = game.world.drive_height(q.x, q.z)
			var delta = absf(q.y - base)
			variation += delta
			if delta > 1.8 or game.world.sample_water(q).depth > 0.05 or game.world.collides(q) or not game.world.director.tunnel_at(q).is_empty(): valid = false
	var sources = game.world.director.nearby_sources(center) if include_sources else []
	var water_distance = 60.0
	for source in sources:
		if source.kind == "water": water_distance = minf(water_distance, center.distance_to(source.position))
	var sunlight = game.world.solar_exposure(center, 0.35)
	var flatness = clampf(100 - variation * 3, 0, 100)
	var shelter = clampf(45 + variation * 1.5 - game.weather.intensity * 20, 15, 85)
	return {"position": center, "valid": valid, "angle": angle, "sources": sources, "flatness": flatness, "shelter": shelter, "sun": sunlight * 100, "water": clampf(100 - water_distance * 2, 0, 100), "access": clampf(100 - absf(center.x - game.world.road_x(center.z)) * 2, 0, 100), "work_bonus": flatness * 0.0015, "rest_bonus": shelter * 0.002}

func find_site(game: Node, position: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_score = INF
	for i in range(24):
		var a = i * TAU / 24
		var center = position + Vector3(sin(a) * 9, 0, cos(a) * 9)
		center.y = game.world.drive_height(center.x, center.z)
		var variation = 0.0
		var valid = true
		for j in range(8):
			var q = center + Vector3(sin(j * TAU / 8), 0, cos(j * TAU / 8)) * 4.5
			q.y = game.world.drive_height(q.x, q.z)
			variation += absf(q.y - center.y)
			if game.world.sample_water(q).depth > 0.05 or game.world.collides(q) or not game.world.director.tunnel_at(q).is_empty(): valid = false
		if not valid or variation > 10: continue
		if not evaluate(game, center, rotation, false).valid: continue
		var score = variation + absf(center.y - position.y) * 0.3
		if score < best_score:
			best_score = score
			best = {"valid": true, "position": center, "compact": variation > 5.0, "sources": []}
	if not best.is_empty(): best.sources = game.world.director.nearby_sources(best.position)
	return best

func point(game: Node, root: Node3D, offset: Vector3) -> Vector3:
	var p = root.to_global(offset)
	return Vector3(offset.x, game.world.drive_height(p.x, p.z) - root.position.y, offset.z)

func build(game: Node):
	var v = game.van
	var root = Node3D.new()
	game.add_child(root)
	root.position = game.camp_location
	root.rotation.y = rotation
	game.camp = root
	game.camp_people.clear()
	var center = Vector3.ZERO
	root.set_meta("focus", center + Vector3(0, 1.0, 0))
	root.set_meta("fire", center)
	var cloth = v.mat(Color("9f7853"))
	for i in range(9):
		var a = i * TAU / 9
		v.cylinder(root, center + Vector3(cos(a) * 0.8, 0.1, sin(a) * 0.8), 0.22, 0.23, v.dark)
	for i in range(3):
		var log_mesh = v.box(root, center + Vector3(0, 0.17, 0), Vector3(1.1, 0.17, 0.17), v.wood)
		log_mesh.rotation.y = i * PI / 3
	var flame_mat = ShaderMaterial.new()
	flame_mat.shader = load("res://shaders/fire.gdshader")
	var flame = v.cylinder(root, center + Vector3(0, 0.55, 0), 0.36, 0.95, v.wood, 0.015)
	flame.material_override = flame_mat
	game.fire = OmniLight3D.new()
	game.fire.position = center + Vector3(0, 1.0, 0)
	game.fire.light_color = Color("ffab60")
	game.fire.omni_range = 11
	root.add_child(game.fire)
	var seats: Array = []
	for i in range(4):
		var a = i * TAU / 4 + 0.25
		var seat = point(game, root, center + Vector3(cos(a) * 2.4, 0, sin(a) * 2.4))
		v.box(root, seat + Vector3(0, 0.4, 0), Vector3(1.15 if game.camp_level > 0 else 0.65, 0.13, 0.48), v.wood)
		for dx in [-0.22, 0.22]: v.box(root, seat + Vector3(dx, 0.2, 0), Vector3(0.10, 0.4, 0.36), v.dark)
		seats.append(seat)
	var game_table = point(game, root, center + Vector3(2.8, 0, 0.9))
	root.set_meta("game_table", game_table)
	v.box(root, game_table + Vector3(0, 0.48, 0), Vector3(0.9, 0.10, 0.68), v.wood)
	for x in [-0.32, 0.32]:
		for z in [-0.22, 0.22]: v.box(root, game_table + Vector3(x, 0.23, z), Vector3(0.07, 0.46, 0.07), v.dark)
	v.box(root, game_table + Vector3(0, 0.55, 0), Vector3(0.48, 0.025, 0.40), v.teal)
	for i in range(6): v.cylinder(root, game_table + Vector3(-0.18 + (i % 3) * 0.18, 0.60, -0.12 + int(i / 3) * 0.24), 0.035, 0.06, v.chrome if i < 3 else v.cream)
	var tent_positions: Array = []
	for side in [-1, 1]:
		var p = point(game, root, center + Vector3(side * 3.7, 0, 4.4))
		tent_positions.append(p)
		for roof_side in [-1, 1]:
			var roof = v.box(root, p + Vector3(roof_side * 0.62, 0.85, 0), Vector3(1.85, 0.06, 2.5), cloth if game.camp_level == 0 else v.teal)
			roof.rotation.z = roof_side * 0.9
		v.box(root, p + Vector3(0, 0.08, 0), Vector3(2.4, 0.1, 2.5), v.dark)
		v.box(root, p + Vector3(0, 0.55, 1.2), Vector3(1.25, 1.1, 0.05), cloth)
		if game.camp_level >= 2:
			v.box(root, p + Vector3(0, 0.4, -1.15), Vector3(1.2, 0.8, 0.05), cloth)
	game.camp_shelter = tent_positions[0]
	root.set_meta("tents", tent_positions)
	var toilet = point(game, root, center + Vector3(-7.0, 0, 6.0))
	root.set_meta("toilet", toilet)
	if game.camp_level > 0:
		for side in [-1, 1]: v.box(root, toilet + Vector3(side * 0.55, 0.95, 0), Vector3(0.04, 1.9, 1.1), cloth)
		v.box(root, toilet + Vector3(0, 0.95, 0.55), Vector3(1.1, 1.9, 0.04), cloth)
		v.box(root, toilet + Vector3(0, 1.9, 0), Vector3(1.1, 0.06, 1.1), cloth)
	var kitchen = point(game, root, center + Vector3(3.6, 0, -2.8))
	root.set_meta("kitchen", kitchen)
	v.box(root, kitchen + Vector3(0, 0.75, 0), Vector3(1.7, 0.12, 0.8), v.wood)
	for dx in [-0.65, 0.65]: v.box(root, kitchen + Vector3(dx, 0.37, 0), Vector3(0.1, 0.74, 0.65), v.dark)
	v.cylinder(root, kitchen + Vector3(0.4, 0.98, 0), 0.2, 0.32, v.chrome)
	if game.camp_level > 0:
		# Small covered workspace beside the kitchen; the fire stays in the open.
		var canopy = v.box(root, kitchen + Vector3(0, 2.35, 0), Vector3(3.4, 0.07, 2.7), v.teal)
		canopy.name = "WorkCanopy"
		canopy.rotation.z = 0.06
		for x in [-1.5, 1.5]:
			for z in [-1.1, 1.1]: v.box(root, kitchen + Vector3(x, 1.12, z), Vector3(0.06, 2.24, 0.06), v.chrome)
		game.camp_shelter = kitchen + Vector3(-0.7, 0, -0.9)
	if game.model.upgrades.kitchen > 0: v.box(root, kitchen + Vector3(-0.4, 0.9, 0), Vector3(0.55, 0.18, 0.45), v.dark)
	for i in range(2 + int(game.model.upgrades.panels)):
		var p = point(game, root, center + Vector3(-3.2 + i * 1.0, 0, -4.2))
		var panel = v.box(root, p + Vector3(0, 0.5, 0), Vector3(0.9, 0.07, 1.6), v.mat(Color("28485d"), 0.25))
		panel.rotation.x = -0.35
		for j in range(5): v.box(panel, Vector3(0, 0.046, -0.64 + j * 0.32), Vector3(0.86, 0.008, 0.012), v.chrome)
		v.box(root, p + Vector3(0, 0.25, 0.4), Vector3(0.07, 0.5, 0.06), v.dark)
	for i in range(4):
		var person = preload("res://scripts/crew_visual.gd").create(v, root, game.model.crew[i])
		person.position = seats[i] + Vector3(0, 0.05, 0)
		person.set_meta("seat", person.position)
		person.rotation.y = atan2(center.x - person.position.x, center.z - person.position.z)
		game.camp_people.append(person)
	if game.camp_level >= 3:
		var lamp = OmniLight3D.new()
		lamp.position = kitchen + Vector3(0, 1.5, 0)
		lamp.light_color = Color("ffcd89")
		lamp.light_energy = 0.6
		lamp.omni_range = 5
		root.add_child(lamp)
	game.crew_system.camp_started(game)
