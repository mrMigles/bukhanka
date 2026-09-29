extends Node3D
var roof: Node3D
var house_level = 0
var decor: Node3D
var home: Node3D
var wheels: Array[Node3D] = []
var people: Array[Node3D] = []
var cream = mat(Color("c7b896"))
var teal = mat(Color("285953"))
var dark = mat(Color("243537"))
var rubber = mat(Color("252c2c"))
var chrome = mat(Color("b5bfb2"), 0.65)
var glass = mat(Color("4d858f"), 0.4)
var wood = mat(Color("ae8459"))
var screen = mat(Color("7dd6bf"), 0.0, true)

func mat(color: Color, metal = 0.0, glow = false) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.45 if metal > 0 else 0.8
	if glow:
		m.emission_enabled = true
		m.emission = color
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material
	n.position = pos
	parent.add_child(n)
	return n

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material, top = -1.0) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius if top < 0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	n.mesh = mesh
	n.material_override = material
	n.position = pos
	parent.add_child(n)
	return n

func _ready():
	cream.roughness = 0.43
	teal.roughness = 0.48
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.28
	glass.roughness = 0.22
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Original hand-built UAZ-inspired cab-over van, +Z is forward.
	box(self, Vector3(0, 0.65, 0), Vector3(2.22, 0.28, 4.45), dark)
	box(self, Vector3(0, 1.0, 0), Vector3(2.34, 0.65, 4.55), teal)
	for side in [-1, 1]: box(self, Vector3(side * 1.175, 0.78, 0), Vector3(0.018, 0.20, 4.45), dark)
	box(self, Vector3(0, 1.36, 0), Vector3(2.38, 0.16, 4.59), cream)
	# Floor and low walls retain a usable interior.
	box(self, Vector3(0, 1.34, 0), Vector3(2.13, 0.1, 4.1), wood)
	for side in [-1, 1]:
		box(self, Vector3(side * 1.12, 1.67, 0), Vector3(0.12, 0.52, 4.48), cream)
		for z in [-2.17, -1.08, 0.2, 1.16, 2.17]:
			box(self, Vector3(side * 1.12, 2.14, z), Vector3(0.13, 0.88, 0.12), cream)
		for z in [-1.61, -0.44, 0.67]:
			box(self, Vector3(side * 1.13, 2.14, z), Vector3(0.024, 0.63, 0.93), glass)
		box(self, Vector3(side * 1.13, 2.14, 1.65), Vector3(0.025, 0.63, 0.84), glass)
		box(self, Vector3(side * 1.16, 1.7, 0.9), Vector3(0.06, 0.045, 0.25), chrome)
		box(self, Vector3(side * 1.28, 0.9, 1.3), Vector3(0.27, 0.1, 0.7), dark)
		box(self, Vector3(side * 1.43, 2.02, 1.8), Vector3(0.27, 0.42, 0.12), dark)
		box(self, Vector3(side * 1.29, 1.96, 1.8), Vector3(0.28, 0.055, 0.07), chrome)
	box(self, Vector3(0, 1.64, 2.21), Vector3(2.24, 0.49, 0.17), cream)
	for x in [-0.55, 0.55]:
		box(self, Vector3(x, 2.14, 2.22), Vector3(0.98, 0.65, 0.028), glass)
	box(self, Vector3(0, 2.14, 2.24), Vector3(0.075, 0.76, 0.075), cream)
	for x in [-0.74, 0.74]:
		var lamp = cylinder(self, Vector3(x, 1.53, 2.32), 0.21, 0.08, chrome)
		lamp.rotation.x = PI / 2
		lamp = cylinder(self, Vector3(x, 1.53, 2.37), 0.16, 0.08, mat(Color("fff0b5"), 0, true))
		lamp.rotation.x = PI / 2
		box(self, Vector3(x, 1.18, -2.3), Vector3(0.22, 0.26, 0.08), mat(Color("bd5945"), 0, true))
	for y in [1.18, 1.27, 1.36]:
		box(self, Vector3(0, y, 2.31), Vector3(0.75, 0.045, 0.07), dark)
	box(self, Vector3(0, 0.95, 2.39), Vector3(2.45, 0.17, 0.19), chrome)
	box(self, Vector3(0, 0.91, -2.4), Vector3(2.4, 0.17, 0.19), chrome)
	box(self, Vector3(0, 1.86, -2.23), Vector3(2.24, 1.3, 0.13), cream)
	for x in [-0.56, 0.56]:
		box(self, Vector3(x, 2.13, -2.31), Vector3(0.91, 0.57, 0.03), glass)
	box(self, Vector3(0, 1.45, -2.32), Vector3(0.04, 1.7, 0.03), dark)
	var spare = cylinder(self, Vector3(-0.53, 1.57, -2.54), 0.46, 0.25, rubber)
	spare.rotation.x = PI / 2
	var hub = cylinder(self, Vector3(-0.53, 1.57, -2.69), 0.23, 0.04, chrome)
	hub.rotation.x = PI / 2
	box(self, Vector3(0.67, 1.15, -2.4), Vector3(0.64, 0.19, 0.02), cream)
	for z in [-1.42, 1.36]:
		for x in [-1.18, 1.18]:
			var wheel = Node3D.new()
			wheel.position = Vector3(x, 0.53, z)
			add_child(wheel)
			wheels.append(wheel)
			var rolling = Node3D.new()
			wheel.add_child(rolling)
			var tire = cylinder(rolling, Vector3.ZERO, 0.55, 0.32, rubber)
			tire.rotation.z = PI / 2
			var cap = cylinder(rolling, Vector3(signf(x) * 0.18, 0, 0), 0.3, 0.035, chrome)
			cap.rotation.z = PI / 2
			var treads: Array[Transform3D] = []
			for k in range(12):
				var a = k * TAU / 12
				treads.append(Transform3D(Basis(Vector3.RIGHT, -a).scaled(Vector3(0.35, 0.1, 0.12)), Vector3(0, sin(a) * 0.53, cos(a) * 0.53)))
			var tread_batch = MultiMeshInstance3D.new()
			tread_batch.multimesh = MultiMesh.new()
			tread_batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			tread_batch.multimesh.mesh = BoxMesh.new()
			tread_batch.multimesh.instance_count = treads.size()
			for k in range(treads.size()): tread_batch.multimesh.set_instance_transform(k, treads[k])
			tread_batch.material_override = dark
			if OS.has_feature("web"): tread_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rolling.add_child(tread_batch)
	roof = Node3D.new()
	add_child(roof)
	box(roof, Vector3(0, 2.62, 0), Vector3(2.36, 0.19, 4.55), cream)
	box(roof, Vector3(0, 2.74, 0), Vector3(2.18, 0.13, 4.30), cream)
	# Starlink terminal is part of the base vehicle.
	cylinder(roof, Vector3(0.55, 3.0, 1.3), 0.055, 0.5, dark)
	var dish = box(roof, Vector3(0.55, 3.26, 1.3), Vector3(0.68, 0.065, 0.48), cream)
	dish.rotation.x = 0.25
	# Cabin and four friends.
	box(self, Vector3(0, 1.72, 1.84), Vector3(2.0, 0.18, 0.52), dark)
	for i in range(4):
		var pos = [Vector3(0.56, 1.36, 1.02), Vector3(-0.56, 1.36, 1.02), Vector3(0.62, 1.36, -0.7), Vector3(-0.62, 1.36, -0.7)][i]
		box(self, pos + Vector3(0, 0.05, 0), Vector3(0.63, 0.13, 0.66), mat(Color("b17851")))
		box(self, pos + Vector3(0, 0.35, -0.27), Vector3(0.63, 0.6, 0.12), mat(Color("b17851")))
		var person = Node3D.new()
		person.position = pos
		add_child(person)
		people.append(person)
		var shirt = mat([Color("d19d54"), Color("6f9da7"), Color("b77468"), Color("77976c")][i])
		box(person, Vector3(0, 0.39, 0), Vector3(0.4, 0.47, 0.25), shirt)
		cylinder(person, Vector3(0, 0.79, 0.04), 0.155, 0.29, mat(Color("dcb18c")))
		cylinder(person, Vector3(0, 0.94, 0.03), 0.165, 0.09, dark)
		for side in [-1, 1]:
			box(person, Vector3(side * 0.1, 0.16, 0.23), Vector3(0.13, 0.13, 0.47), dark)
			var arm = box(person, Vector3(side * 0.25, 0.37, 0.15), Vector3(0.11, 0.14, 0.37), shirt)
			arm.rotation.x = -0.2
			box(person, Vector3(side * 0.075, 0.83, 0.183), Vector3(0.1, 0.055, 0.02), dark)
		if i > 0:
			box(person, Vector3(0, 0.27, 0.38), Vector3(0.39, 0.025, 0.25), chrome)
			var laptop = box(person, Vector3(0, 0.42, 0.5), Vector3(0.39, 0.27, 0.025), dark)
			laptop.rotation.x = -0.2
			box(person, Vector3(0, 0.42, 0.481), Vector3(0.34, 0.21, 0.01), screen)
	home = Node3D.new()
	add_child(home)
	decor = Node3D.new()
	roof.add_child(decor)
	batch_body_boxes()

func batch_body_boxes():
	var groups = {}
	for child in get_children():
		if not child is MeshInstance3D or not child.mesh is BoxMesh or child.material_override == glass: continue
		var key = child.material_override.get_instance_id()
		if not groups.has(key): groups[key] = []
		groups[key].append(child)
	for group in groups.values():
		if group.size() < 2: continue
		var batch = MultiMeshInstance3D.new()
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = BoxMesh.new()
		batch.multimesh.instance_count = group.size()
		batch.material_override = group[0].material_override
		for i in range(group.size()):
			var part: MeshInstance3D = group[i]
			var box_mesh: BoxMesh = part.mesh
			batch.multimesh.set_instance_transform(i, part.transform * Transform3D(Basis().scaled(box_mesh.size), Vector3.ZERO))
			part.queue_free()
		add_child(batch)

func update_upgrades(levels: Array):
	house_level = levels[1]
	for c in home.get_children():
		c.queue_free()
	if levels[1] > 0:
		box(home, Vector3(0, 1.48, -1.65), Vector3(1.95, 0.22, 0.82), mat(Color("667e8d")))
		box(home, Vector3(0.64, 1.65, -1.65), Vector3(0.44, 0.12, 0.56), cream)
	if levels[1] > 1:
		box(home, Vector3(-0.85, 1.64, 0), Vector3(0.38, 0.58, 0.86), wood)
		box(home, Vector3(-0.85, 1.95, 0), Vector3(0.42, 0.05, 0.9), chrome)
		cylinder(home, Vector3(-0.85, 2.04, 0.1), 0.12, 0.14, dark)
	if levels[1] > 2:
		box(home, Vector3(0.85, 2.25, -1.8), Vector3(0.32, 0.32, 0.45), wood)
		var lamp = OmniLight3D.new()
		lamp.position = Vector3(0, 2.4, 0)
		lamp.light_color = Color("ffda9c")
		lamp.light_energy = 0.45
		lamp.omni_range = 3.5
		home.add_child(lamp)
	for c in decor.get_children():
		c.queue_free()
	if levels[0] > 0:
		for w in wheels:
			w.scale = Vector3.ONE * (1.0 + levels[0] * 0.07)
	if levels[1] > 0:
		box(decor, Vector3(0, 3.0, -0.65), Vector3(1.9, 0.42 + levels[1] * 0.22, 2.35), mat(Color("b88e60")))
		box(decor, Vector3(0, 3.28 + levels[1] * 0.11, -0.65), Vector3(1.95, 0.09, 2.4), cream)
	if levels[3] > 0:
		box(decor, Vector3(-0.6, 2.9, -1.9), Vector3(0.54, 0.35, 0.43), teal)
		box(decor, Vector3(0.7, 2.9, -1.9), Vector3(0.45, 0.35, 0.43), mat(Color("c99b56")))

func animate(speed: float, time: float):
	for i in people.size():
		people[i].rotation.z = sin(time * 1.4 + i) * 0.022

func rebuild_crew(model: RefCounted):
	for person in people:
		remove_child(person)
		person.queue_free()
	people.clear()
	for i in range(4):
		var person = preload("res://scripts/crew_visual.gd").create(self, self, model.crew[i])
		person.position = [Vector3(0.56, 1.0, 1.02), Vector3(-0.56, 1.0, 1.02), Vector3(0.62, 1.0, -0.7), Vector3(-0.62, 1.0, -0.7)][i]
		people.append(person)
		preload("res://scripts/crew_visual.gd").animate(person, "Едет", 0, false)
		if i == 0: person.get_meta("laptop").hide()

func update_solar(model: RefCounted):
	var old = get_node_or_null("SolarRoof")
	if old != null:
		remove_child(old)
		old.queue_free()
	var solar = Node3D.new()
	solar.name = "SolarRoof"
	add_child(solar)
	var height = 3.36 + house_level * 0.11 if house_level > 0 else 2.92
	for i in range(1 + int(model.upgrades.roof)):
		var panel = box(solar, Vector3(-0.50 + (i % 2) * 0.95, height, -1.1 + int(i / 2) * 1.35), Vector3(0.86, 0.06, 1.22), mat(Color("28485d"), 0.25))
		for j in range(5): box(panel, Vector3(0, 0.04, -0.5 + j * 0.25), Vector3(0.83, 0.009, 0.015), chrome)

func levels_house_present() -> bool:
	return home.get_child_count() > 0
