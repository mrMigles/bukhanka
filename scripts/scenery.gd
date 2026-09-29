extends RefCounted

static func populate(w: Node, root: Node3D, index: int, rng: RandomNumberGenerator):
	for item in w.director.for_chunk(index):
		match item.kind:
			"manul":
				var p = Vector3(item.x, w.drive_height(item.x, item.z), item.z)
				if not w.sample_water(p).present:
					var cat = preload("res://scripts/manul.gd").create(root)
					cat.position = p
					cat.set_meta("home", p)
					cat.set_meta("phase", rng.randf() * TAU)
					w.wildlife.append(cat)
			"village": village(w, root, item, rng)
			"animals":
				for i in range(3):
					var p = Vector3(item.x + i * 2.4, 0, item.z + i * 2.8)
					p.y = w.drive_height(p.x, p.z)
					if not w.sample_water(p).present: animal(w, root, p, i, rng)
			"waterfall": waterfall(w, root, item.z)
			"lake": root.set_meta("lake", true)
			"food": food_cluster(w, root, item, item.get("apple", false))
			"tunnel": tunnel(w, root, item)
	grass(w, root, index, rng)
	forest(w, root, index, rng)
	if posmod(index, 5) == 1:
		for i in range(3):
			var bird = Node3D.new()
			root.add_child(bird)
			var z = index * 144.0 + 70
			var home = Vector3(w.river_x(z), maxf(w.water_y(z), w.drive_height(w.river_x(z), z)) + 18 + i * 2, z)
			bird.position = home
			bird.set_meta("home", home)
			bird.set_meta("phase", float(i) * 1.4)
			for side in [-1, 1]:
				var wing = w.box(bird, Vector3(side * 0.30, 0, 0), Vector3(0.58, 0.035, 0.20), w.marker)
				wing.rotation.y = side * 0.2
			w.birds.append(bird)

static func forest(w: Node, root: Node3D, index: int, rng: RandomNumberGenerator):
	var start = index * w.LENGTH
	if maxf(w.director.forest_density(start), maxf(w.director.forest_density(start + 72), w.director.forest_density(start + 144))) <= 0: return
	var transforms: Array[Transform3D] = []
	for attempt in range(180):
		var z = rng.randf_range(start, start + w.LENGTH)
		if rng.randf() > w.director.forest_density(z): continue
		var x = w.road_x(z) + (-1 if attempt % 2 == 0 else 1) * rng.randf_range(7.5, 38)
		if absf(x - w.route_x(z, w.nearest_route(x, z))) < 7.5: continue
		var y = w.drive_height(x, z)
		var p = Vector3(x, y, z)
		if y > 205 or w.sample_water(p).depth > 0.05 or not w.director.tunnel_at(p).is_empty(): continue
		if absf(w.drive_height(x + 1, z) - y) > 1.1: continue
		var scale = rng.randf_range(0.85, 1.55)
		transforms.append(Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, scale * rng.randf_range(1.0, 1.25), scale)), p - Vector3(0, 0.15, 0)))
		w.obstacles[index].append(Vector3(x, scale * 0.65, z))
	if transforms.is_empty(): return
	var trees = MultiMeshInstance3D.new()
	trees.name = "ForestBelt"
	trees.multimesh = MultiMesh.new()
	trees.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	trees.multimesh.mesh = w.tree_mesh
	trees.multimesh.instance_count = transforms.size()
	for i in range(transforms.size()): trees.multimesh.set_instance_transform(i, transforms[i])
	trees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(trees)
	root.set_meta("forest", true)

static func village(w: Node, root: Node3D, item: Dictionary, rng: RandomNumberGenerator):
	root.set_meta("village", true)
	var wall = w.material(Color("aa9071"))
	var roof_mat = w.material(Color("506c70"))
	var window = w.material(Color("f5c77e"))
	window.emission_enabled = true
	window.emission = Color("a46c32")
	window.emission_energy_multiplier = 0.35
	for i in range(4):
		var z = item.z - 28 + i * 17
		var x = w.road_x(z) + (13.0 if i % 2 == 0 else -15.0)
		var y = w.drive_height(x, z)
		w.box(root, Vector3(x, y - 0.2, z), Vector3(6.2, 1.0, 5.4), w.wood)
		w.box(root, Vector3(x, y + 1.5, z), Vector3(5.6, 3.0, 4.8), wall)
		for side in [-1, 1]:
			var roof = w.box(root, Vector3(x + side * 1.5, y + 3.3, z), Vector3(3.5, 0.18, 5.6), roof_mat)
			roof.rotation.z = side * -0.45
			w.box(root, Vector3(x + side * 1.6, y + 1.9, z - 2.43), Vector3(0.9, 0.95, 0.06), window)
		w.box(root, Vector3(x, y + 1.0, z - 2.44), Vector3(1.0, 2.0, 0.07), w.wood)
		w.obstacles[int(item.owner)].append(Vector3(x, 3.4, z))
		var person = Node3D.new()
		root.add_child(person)
		person.position = Vector3(x - 4, w.drive_height(x - 4, z - 2), z - 2)
		w.box(person, Vector3(0, 0.65, 0), Vector3(0.38, 0.9, 0.3), roof_mat)
		w.box(person, Vector3(0, 1.25, 0), Vector3(0.3, 0.3, 0.3), wall)
	var signpost = Vector3(w.road_x(item.z) + 5, w.drive_height(w.road_x(item.z) + 5, item.z), item.z)
	w.box(root, signpost + Vector3(0, 1, 0), Vector3(0.1, 2, 0.1), w.wood)
	var sign_label = Label3D.new()
	sign_label.text = "ДЕРЕВНЯ
Припасы · зарядка · заказы"
	sign_label.font_size = 40
	sign_label.pixel_size = 0.008
	sign_label.position = signpost + Vector3(0, 2.3, 0)
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.visibility_range_end = 80
	root.add_child(sign_label)
	for i in range(2):
		var p = Vector3(w.road_x(item.z + 38) + 12 + i * 2, 0, item.z + 38)
		p.y = w.drive_height(p.x, p.z)
		animal(w, root, p, 5, rng)

static func food_cluster(w: Node, root: Node3D, item: Dictionary, apple: bool = false):
	var harvest_visual = Node3D.new()
	root.add_child(harvest_visual)
	harvest_visual.add_to_group("harvest_visuals")
	harvest_visual.set_meta("source_id", item.id)
	harvest_visual.set_meta("maximum", item.get("maximum", 8.0))
	var leaf_dark = w.material(Color("315d43"))
	var leaf_light = w.material(Color("527b4d"))
	var fruit = w.material(Color("b83f43") if apple else Color("702d5d"))
	var count = 1 if apple else 3
	var light_canopies: Array[Transform3D] = []
	var dark_canopies: Array[Transform3D] = []
	var fruits: Array[Transform3D] = []
	for i in range(count):
		var spread = 0.0 if apple else 1.7
		var p = Vector3(item.x + sin(i * 2.3) * spread, 0, item.z + cos(i * 2.3) * spread)
		p.y = w.drive_height(p.x, p.z)
		if w.sample_water(p).present: continue
		if apple:
			w.box(root, p + Vector3(0, 1.25, 0), Vector3(0.28, 2.5, 0.28), w.wood)
			for branch_index in range(3):
				var branch = w.box(root, p + Vector3(cos(branch_index * TAU / 3) * 0.35, 2.0, sin(branch_index * TAU / 3) * 0.35), Vector3(0.15, 1.25, 0.15), w.wood)
				branch.rotation.z = cos(branch_index * TAU / 3) * 0.55
				branch.rotation.x = sin(branch_index * TAU / 3) * 0.55
		for cluster_index in range(5 if apple else 3):
			var angle = cluster_index * TAU / (5.0 if apple else 3.0) + i
			var canopy_position = p + Vector3(cos(angle) * (0.75 if apple else 0.32), (2.65 if apple else 0.65) + sin(angle * 2) * 0.18, sin(angle) * (0.75 if apple else 0.32))
			var canopy_scale = Vector3(1.0, 0.78, 1.0) * (1.0 if apple else 0.52)
			var canopy_transform = Transform3D(Basis().scaled(canopy_scale), canopy_position)
			if cluster_index % 2 == 0: light_canopies.append(canopy_transform)
			else: dark_canopies.append(canopy_transform)
		if not apple:
			for stem_index in range(3):
				var stem = w.box(root, p + Vector3(cos(stem_index * 2.1) * 0.18, 0.34, sin(stem_index * 2.1) * 0.18), Vector3(0.055, 0.72, 0.055), w.wood)
				stem.rotation.z = cos(stem_index * 2.1) * 0.28
		for fruit_index in range(8 if apple else 6):
			var a = fruit_index * 2.399 + i
			var berry_position = p + Vector3(cos(a) * (0.95 if apple else 0.43), (2.55 if apple else 0.55) + sin(a * 1.7) * (0.48 if apple else 0.22), sin(a) * (0.95 if apple else 0.43))
			fruits.append(Transform3D(Basis().scaled(Vector3.ONE * (0.13 if apple else 0.065)), berry_position))
	w.add_rock_batch(root, light_canopies, leaf_light)
	w.add_rock_batch(root, dark_canopies, leaf_dark)
	w.add_rock_batch(harvest_visual, fruits, fruit)

static func tunnel(w: Node, root: Node3D, item: Dictionary):
	var rock = w.material(Color("687775"))
	var inside = w.material(Color("46514e"))
	for segment in range(int(item.length / 4)):
		var z = item.z - item.length * 0.5 + segment * 4 + 2
		var p = Vector3(w.road_x(z), w.drive_height(w.road_x(z), z), z)
		var basis = Node3D.new()
		root.add_child(basis)
		basis.position = p
		basis.rotation.y = atan2(w.road_x(z + 1) - w.road_x(z - 1), 2)
		for side in [-1, 1]:
			if item.gallery and side == 1:
				w.box(basis, Vector3(side * 4.1, 3.1, 0), Vector3(0.7, 6.2, 0.6), rock)
			else: w.box(basis, Vector3(side * 4.2, 1.8, 0), Vector3(1.2, 3.6, 4.3), rock)
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for arc in range(10):
			var a = arc * PI / 10
			var b = (arc + 1) * PI / 10
			w.quad(st, Vector3(cos(a)*4,3.1+sin(a)*4,-2.15), Vector3(cos(a)*4,3.1+sin(a)*4,2.15), Vector3(cos(b)*4,3.1+sin(b)*4,2.15), Vector3(cos(b)*4,3.1+sin(b)*4,-2.15), Color.WHITE)
		var shell = w.finish(st, basis, inside)
		inside.cull_mode = BaseMaterial3D.CULL_DISABLED
		w.box(basis, Vector3(0, 7.5, 0), Vector3(9.2, 1.0, 4.3), rock)
	root.set_meta("tunnel", true)
static func animal(w: Node, parent: Node3D, pos: Vector3, number: int, rng: RandomNumberGenerator, register: bool = true):
	var deer = Node3D.new()
	parent.add_child(deer)
	deer.position = pos
	deer.rotation.y = rng.randf() * TAU
	deer.set_meta("home", pos)
	deer.set_meta("phase", rng.randf() * TAU)
	var coat = w.material(Color("e2ded0") if number == 5 else Color("a08059") if pos.y < 180 else Color("b9b2a0"))
	w.box(deer, Vector3(0, 0.95, 0), Vector3(0.55, 0.55, 1.15), coat)
	var neck = w.box(deer, Vector3(0, 1.4, 0.47), Vector3(0.28, 0.8, 0.3), coat)
	neck.rotation.x = -0.25
	w.box(deer, Vector3(0, 1.8, 0.68), Vector3(0.34, 0.32, 0.58), coat)
	var legs: Array = []
	for x in [-0.19, 0.19]:
		for z in [-0.38, 0.38]:
			legs.append(w.box(deer, Vector3(x, 0.4, z), Vector3(0.1, 0.85, 0.1), w.wood))
	for side in [-1, 1]:
		var ear = w.box(deer, Vector3(side * 0.23, 2.0, 0.48), Vector3(0.13, 0.35, 0.12), coat)
		ear.rotation.z = side * 0.6
		if number == 0 or pos.y > 180:
			var horn = w.box(deer, Vector3(side * 0.16, 2.2, 0.4), Vector3(0.055, 0.65, 0.06), w.wood)
			horn.rotation.z = side * -0.35
	deer.set_meta("legs", legs)
	deer.set_meta("species", "Животные")
	if register: w.wildlife.append(deer)

static func waterfall(w: Node, root: Node3D, z: float):
	var rx = w.river_x(z)
	var side = -1.0 if rx < w.road_x(z) else 1.0
	var base = w.water_y(z)
	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/falls.gdshader")
	var rock = w.material(Color("788986"))
	for tier in range(3):
		var x = rx + side * (8.0 + tier * 4.2)
		var bottom = base + tier * 4.4
		var top = bottom + 4.6
		# A rock ledge behind each falling sheet; sheets never drape over the road.
		var ledge = MeshInstance3D.new()
		ledge.mesh = w.rock_mesh
		ledge.material_override = rock
		ledge.position = Vector3(x + side * 1.0, bottom + 2, z)
		ledge.scale = Vector3(3.0, 5.0, 6.0 - tier * 0.6)
		ledge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ledge)
		w.obstacles[int(floor(z / 144.0))].append(Vector3(x + side * 1.0, 1.9, z))
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for strip in range(4):
			var width = 1.2 - tier * 0.1
			var za = z - 2.4 + strip * width
			var zb = za + width * 0.92
			for vertex in [Vector3(x,top,za),Vector3(x-side*1.0,bottom,za-.12),Vector3(x-side*1.0,bottom,zb+.12),Vector3(x,top,za),Vector3(x-side*1.0,bottom,zb+.12),Vector3(x,top,zb)]:
				st.set_uv(Vector2((vertex.z-z)*.6,(top-vertex.y)*.5))
				st.add_vertex(vertex)
		w.finish(st,root,mat)
		# Horizontal connecting lip, with directional UV rather than world stripes.
		var lip = SurfaceTool.new()
		lip.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex in [Vector3(x,top,z-2),Vector3(x+side*4.2,top,z-2),Vector3(x+side*4.2,top,z+2),Vector3(x,top,z-2),Vector3(x+side*4.2,top,z+2),Vector3(x,top,z+2)]:
			lip.set_uv(Vector2(vertex.z-z,(vertex.x-x)*.5))
			lip.add_vertex(vertex)
		w.finish(lip,root,mat)
	var foam = CPUParticles3D.new()
	foam.amount = 40
	foam.lifetime = 1.3
	foam.position = Vector3(rx + side * 7, base + .15, z)
	foam.direction = Vector3(0,1,0)
	foam.spread = 65
	foam.initial_velocity_min = .6
	foam.initial_velocity_max = 2.3
	foam.gravity = Vector3(0,-2,0)
	foam.scale_amount_min = .04
	foam.scale_amount_max = .16
	foam.mesh = w.rock_mesh
	foam.material_override = w.material(Color("d4e8e1"))
	foam.visibility_range_end = 90
	root.add_child(foam)
	w.waterfall_emitters.append(foam)
	root.set_meta("waterfall",true)
static func grass(w: Node, root: Node3D, index: int, rng: RandomNumberGenerator):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(3):
		var a = i * PI / 3
		w.triangle(st, Vector3(cos(a) * 0.16, 0, sin(a) * 0.16), Vector3(-cos(a) * 0.16, 0, -sin(a) * 0.16), Vector3(0.12, 0.62, 0), Color.WHITE)
	var mesh = st.commit()
	var transforms: Array[Transform3D] = []
	for i in range(200):
		var z = index * w.LENGTH + rng.randf() * w.LENGTH
		var x = w.route_x(z, i % 4) + rng.randf_range(-15, 15)
		var route = w.nearest_route(x, z)
		var h = w.drive_height(x, z)
		if abs(x - w.route_x(z, route)) < 3.0 or h > 250 or abs(x - w.river_x(z)) < 9: continue
		transforms.append(Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.5, 1.2)), Vector3(x, h, z)))
	var blades = MultiMeshInstance3D.new()
	blades.multimesh = MultiMesh.new()
	blades.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	blades.multimesh.mesh = mesh
	blades.multimesh.instance_count = transforms.size()
	for i in range(transforms.size()): blades.multimesh.set_instance_transform(i, transforms[i])
	blades.material_override = w.grass_material
	blades.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blades.visibility_range_end = 90
	root.add_child(blades)
