extends RefCounted
const SHIRTS = [Color("d19d54"), Color("6f9da7"), Color("b77468"), Color("77976c")]
const SKINS = [Color("eccbb0"), Color("dcb18c"), Color("b88461"), Color("78513e")]

static func create(van: Node, parent: Node3D, hero: Dictionary) -> Node3D:
	var person = Node3D.new()
	parent.add_child(person)
	var shirt = van.mat(SHIRTS[int(hero.shirt)])
	van.box(person, Vector3(0, 0.68, 0), Vector3(0.4, 0.48, 0.26), shirt)
	van.cylinder(person, Vector3(0, 1.06, 0.02), 0.16, 0.30, van.mat(SKINS[int(hero.skin)]))
	van.cylinder(person, Vector3(0, 1.22, 0.01), 0.17, 0.08 + int(hero.hair) * 0.04, van.dark)
	if int(hero.hair) == 3: van.box(person, Vector3(0, 1.24, 0.14), Vector3(0.36, 0.045, 0.24), shirt)
	for x in [-0.065, 0.065]: van.box(person, Vector3(x, 1.09, 0.172), Vector3(0.055, 0.025, 0.018), van.dark)
	var legs: Array = []
	var arms: Array = []
	for side in [-1, 1]:
		var leg = Node3D.new()
		person.add_child(leg)
		leg.position = Vector3(side * 0.11, 0.47, 0)
		van.box(leg, Vector3(0, -0.22, 0), Vector3(0.14, 0.45, 0.16), van.dark)
		van.box(leg, Vector3(0, -0.43, 0.045), Vector3(0.16, 0.09, 0.25), van.rubber)
		legs.append(leg)
		var arm = Node3D.new()
		person.add_child(arm)
		arm.position = Vector3(side * 0.25, 0.89, 0)
		van.box(arm, Vector3(0, -0.21, 0), Vector3(0.12, 0.42, 0.14), shirt)
		arms.append(arm)
	var laptop = Node3D.new()
	person.add_child(laptop)
	laptop.position = Vector3(0, 0.55, 0.37)
	van.box(laptop, Vector3.ZERO, Vector3(0.42, 0.025, 0.28), van.chrome)
	van.box(laptop, Vector3(0, 0.14, 0.14), Vector3(0.42, 0.27, 0.025), van.dark)
	van.box(laptop, Vector3(0, 0.14, 0.124), Vector3(0.36, 0.21, 0.01), van.screen)
	var rod = van.box(person, Vector3(0.26, 0.8, 0.75), Vector3(0.035, 0.035, 1.7), van.wood)
	rod.rotation.x = -0.35
	rod.hide()
	var basket = van.box(person, Vector3(-0.32, 0.45, 0.13), Vector3(0.30, 0.28, 0.3), van.wood)
	basket.hide()
	var guitar = Node3D.new()
	person.add_child(guitar)
	guitar.position = Vector3(0.08, 0.62, 0.34)
	var guitar_body = van.cylinder(guitar, Vector3.ZERO, 0.21, 0.08, van.wood)
	guitar_body.rotation.x = PI / 2
	var sound_hole = van.cylinder(guitar, Vector3(0, 0, 0.046), 0.065, 0.012, van.dark)
	sound_hole.rotation.x = PI / 2
	var neck = van.box(guitar, Vector3(0.28, 0.08, 0), Vector3(0.58, 0.075, 0.06), van.wood)
	neck.rotation.z = -0.22
	guitar.hide()
	person.set_meta("legs", legs)
	person.set_meta("arms", arms)
	person.set_meta("laptop", laptop)
	person.set_meta("rod", rod)
	person.set_meta("basket", basket)
	person.set_meta("guitar", guitar)
	var label = Label3D.new()
	label.position.y = 1.85
	label.font_size = 32
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("d1fff1")
	label.outline_size = 8
	person.add_child(label)
	label.hide()
	person.set_meta("gather_label", label)
	var bar = MeshInstance3D.new()
	bar.mesh = QuadMesh.new()
	bar.mesh.size = Vector2(1.1, 0.08)
	bar.position.y = 1.60
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var progress_material = ShaderMaterial.new()
	progress_material.shader = preload("res://shaders/gather_progress.gdshader")
	bar.material_override = progress_material
	person.add_child(bar)
	bar.hide()
	person.set_meta("gather_bar", bar)
	return person

static func animate(person: Node3D, activity: String, clock: float, walking: bool):
	var gathering = not walking and activity in ["Собирает", "Набирает воду", "Рыбачит"]
	person.rotation.x = (0.14 + sin(clock * 2.8) * 0.12) if gathering and activity != "Рыбачит" else 0.0
	person.rotation.z = sin(clock * 2.0) * 0.025 if gathering else 0.0
	var sitting = activity in ["Работает", "Отдыхает", "Отдыхает у костра", "Играет", "Играет с друзьями", "Играет на гитаре", "Едет"]
	var index = 0
	for leg in person.get_meta("legs", []):
		leg.rotation.x = sin(clock * 6 + index * PI) * 0.5 if walking else -1.3 if sitting else 0.0
		index += 1
	index = 0
	for arm in person.get_meta("arms", []):
		arm.rotation.x = sin(clock * 6 + index * PI) * 0.3 if walking else -1.0 + sin(clock * 4 + index) * 0.035 if activity == "Работает" else -0.75 + sin(clock * 5 + index * 1.7) * 0.18 if activity == "Играет на гитаре" else -0.6 if activity in ["Рыбачит", "Готовит", "Играет", "Играет с друзьями"] else 0.0
		if gathering:
			arm.rotation.x = -0.9 + sin(clock * (1.4 if activity == "Рыбачит" else 3.2) + index * 1.7) * (0.16 if activity == "Рыбачит" else 0.5)
		arm.rotation.z = sin(clock * 2.3 + index) * 0.12 if gathering else 0.0
		index += 1
	if person.has_meta("laptop"): person.get_meta("laptop").visible = activity == "Работает" or activity == "Едет"
	if person.has_meta("rod"): person.get_meta("rod").visible = activity == "Рыбачит" and not walking
	if person.has_meta("rod"): person.get_meta("rod").rotation.x = -0.35 + sin(clock * 1.4) * 0.09
	if person.has_meta("basket"): person.get_meta("basket").visible = activity in ["Собирает", "Набирает воду", "Возвращается"]
	if person.has_meta("guitar"): person.get_meta("guitar").visible = activity == "Играет на гитаре" and not walking
