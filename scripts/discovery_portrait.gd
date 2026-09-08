extends RefCounted
## A small, isolated scene: no streamed world or extra wildlife registrations.
static func create(parent: Node, game: Node, kind: String):
	var frame = SubViewportContainer.new()
	frame.custom_minimum_size = Vector2(220, 170)
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(440, 340)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	frame.add_child(viewport)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("223e47")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b6d4da")
	env.environment.ambient_light_energy = 0.65
	viewport.add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -40, 0)
	sun.light_color = Color("ffdeae")
	sun.light_energy = 1.7
	viewport.add_child(sun)
	var scene = Node3D.new()
	viewport.add_child(scene)
	var w = game.world
	w.box(scene, Vector3(0, -0.18, 0), Vector3(5, 0.30, 3.6), w.material(Color("738378")))
	for i in range(3):
		var peak = preload("res://scripts/manul.gd").part(scene, Vector3(-2.2 + i * 1.9, 0.55, -1.5), Vector3(2.2, 1.2 + i * 0.2, 1.3), "82958f")
		peak.rotation.z = i * 0.2
	var person = preload("res://scripts/crew_visual.gd").create(game.van, scene, game.model.crew[0])
	person.position = Vector3(-1.3, 0, 0.55)
	person.rotation.y = 0.35
	preload("res://scripts/crew_visual.gd").animate(person, "Отдыхает", 0.0, false)
	if kind == "Манул":
		var cat = preload("res://scripts/manul.gd").create(scene)
		cat.position = Vector3(0.45, 0.05, 0.5)
		cat.scale = Vector3.ONE * 1.35
	elif kind == "Животные":
		var rng = RandomNumberGenerator.new()
		rng.seed = 42
		preload("res://scripts/scenery.gd").animal(w, scene, Vector3(0.65, 0, 0), 0, rng, false)
	elif kind in ["Горное озеро", "Водопад"]:
		w.box(scene, Vector3(0.7, 0, 0.2), Vector3(2.6, 0.035, 2.3), w.material(Color("469eab")))
		if kind == "Водопад": w.box(scene, Vector3(0.7, 0.85, -0.7), Vector3(0.55, 1.7, 0.12), w.material(Color("a6e0dd")))
	elif kind == "Деревня":
		w.box(scene, Vector3(0.6, 0.5, -0.1), Vector3(1.5, 1.0, 1.3), w.material(Color("c4ad85")))
		var roof = w.box(scene, Vector3(0.6, 1.12, -0.1), Vector3(1.8, 0.2, 1.6), w.material(Color("995f49")))
		roof.rotation.z = -0.12
		w.box(scene, Vector3(0.6, 0.55, 0.56), Vector3(0.4, 0.4, 0.03), w.material(Color("f3cf83")))
	elif kind == "Горный тоннель":
		for x in [-0.05, 1.55]: w.box(scene, Vector3(x, 0.65, 0), Vector3(0.4, 1.3, 1.1), w.material(Color("596d6b")))
		w.box(scene, Vector3(0.75, 1.4, 0), Vector3(2.0, 0.4, 1.1), w.material(Color("83918a")))
	else:
		var tent = w.box(scene, Vector3(0.65, 0.5, 0), Vector3(1.3, 1, 1.5), w.material(Color("d6a55b")))
		tent.rotation.z = 0.12
	var camera = Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(3.1, 2.4, 6)
	camera.look_at(Vector3(0, 0.65, 0))
	camera.fov = 39
