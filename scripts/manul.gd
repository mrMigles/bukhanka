extends RefCounted
## Shared low-poly model for mountain encounters and journal portraits.
static func part(parent: Node3D, pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh.mesh = sphere
	mesh.position = pos
	mesh.scale = size
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = 1.0
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh

static func create(parent: Node3D) -> Node3D:
	var cat = Node3D.new()
	cat.name = "Manul"
	parent.add_child(cat)
	part(cat, Vector3(0, 0.43, 0), Vector3(0.86, 0.48, 1.25), "989184")
	part(cat, Vector3(0, 0.66, 0.52), Vector3(0.91, 0.40, 0.72), "b6b09f")
	var legs: Array = []
	for side in [-1, 1]:
		for z in [-0.35, 0.36]:
			legs.append(part(cat, Vector3(side * 0.26, 0.19, z), Vector3(0.25, 0.19, 0.29), "7f7a70"))
		part(cat, Vector3(side * 0.37, 0.89, 0.47), Vector3(0.22, 0.14, 0.19), "777368")
		part(cat, Vector3(side * 0.37, 0.90, 0.53), Vector3(0.12, 0.08, 0.08), "c4ac9f")
		part(cat, Vector3(side * 0.34, 0.52, 0.64), Vector3(0.33, 0.19, 0.36), "d1cbbb")
		part(cat, Vector3(side * 0.21, 0.70, 0.83), Vector3(0.17, 0.06, 0.06), "d4b75e")
		part(cat, Vector3(side * 0.21, 0.70, 0.856), Vector3(0.055, 0.045, 0.025), "202a28")
		var brow = part(cat, Vector3(side * 0.21, 0.77, 0.80), Vector3(0.29, 0.055, 0.09), "6e7067")
		brow.rotation.z = side * 0.13
		for stripe in range(2):
			part(cat, Vector3(side * 0.34, 0.58 - stripe * 0.07, 0.77), Vector3(0.19, 0.025, 0.07), "595d57")
	part(cat, Vector3(0, 0.57, 0.83), Vector3(0.30, 0.10, 0.17), "ddd5c2")
	part(cat, Vector3(0, 0.63, 0.92), Vector3(0.11, 0.04, 0.06), "665753")
	for i in range(7):
		part(cat, Vector3(0.08 + i * 0.055, 0.22, -0.57 - i * 0.10), Vector3(0.27, 0.12, 0.23), "5c605a" if i % 2 == 0 else "a09a8b")
	cat.set_meta("legs", legs)
	cat.set_meta("species", "Манул")
	return cat
