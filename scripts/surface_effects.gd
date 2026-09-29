extends Node3D
var game: Node
var terrain_image: Image
var texture: ImageTexture
var origin = Vector2(-10000, -10000)
var cells: Dictionary = {}
var rings = PackedVector4Array()
var ring_heights = PackedFloat32Array()
var ring_cursor = 0
var ring_clock = 0.0
var stamp_clock = 0.0
var tracks_dirty = false
var coating = 0.0
var splashes: Array[CPUParticles3D] = []
var mud_parts: Array[MeshInstance3D] = []
var previous_contacts: Array[Vector3] = []
var mud_material: StandardMaterial3D

func _ready():
	terrain_image = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	terrain_image.fill(Color(0, 0, 0, 1))
	texture = ImageTexture.create_from_image(terrain_image)
	game.world.surface_effects = self
	game.world.terrain_material.set_shader_parameter("tracks", texture)
	game.world.road_material.set_shader_parameter("tracks", texture)
	for i in range(16):
		rings.append(Vector4(0, 0, 10, 0))
		ring_heights.append(-10000.0)
	mud_material = game.van.mat(Color("594332"))
	for i in range(4):
		previous_contacts.append(Vector3.INF)
		var spray = CPUParticles3D.new()
		spray.amount = 24
		spray.lifetime = 0.6
		spray.local_coords = false
		spray.emitting = false
		spray.direction = Vector3(-1 if i % 2 == 0 else 1, 1.2, 0)
		spray.spread = 35
		spray.gravity = Vector3(0, -9.8, 0)
		spray.initial_velocity_min = 1.5
		spray.initial_velocity_max = 4.0
		spray.scale_amount_min = 0.035
		spray.scale_amount_max = 0.13
		var droplet = SphereMesh.new()
		droplet.radial_segments = 5
		droplet.rings = 2
		droplet.material = game.van.mat(Color("b1d8d0"), 0.1)
		spray.mesh = droplet
		spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spray)
		splashes.append(spray)
		for j in range(10):
			var angle = j * TAU / 10
			var lump = game.van.box(game.van.wheels[i].get_child(0), Vector3(0, sin(angle) * 0.575, cos(angle) * 0.575), Vector3(0.34, 0.09, 0.17), mud_material)
			lump.rotation.x = -angle
			lump.hide()
			mud_parts.append(lump)

func depth_at(x: float, z: float) -> float:
	# Match linear texture sampling at the very same terrain mesh vertices.
	var p = (Vector2(x, z) - origin) * 2 - Vector2(0.5, 0.5)
	if p.x < 0 or p.y < 0 or p.x > 254 or p.y > 254: return 0
	var ix = int(floor(p.x))
	var iz = int(floor(p.y))
	var f = p - Vector2(ix, iz)
	return lerpf(lerpf(terrain_image.get_pixel(ix, iz).r, terrain_image.get_pixel(ix + 1, iz).r, f.x), lerpf(terrain_image.get_pixel(ix, iz + 1).r, terrain_image.get_pixel(ix + 1, iz + 1).r, f.x), f.y) * 0.22

func stamp(p: Vector3, strength: float):
	var key = Vector2i(floor(p.x * 2), floor(p.z * 2))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k = key + Vector2i(dx, dz)
			var value = maxf(cells.get(k, 0.0), strength * (1.0 if dx == 0 and dz == 0 else 0.28))
			cells[k] = value
			var pixel = k - Vector2i(origin * 2)
			if pixel.x >= 0 and pixel.y >= 0 and pixel.x < 256 and pixel.y < 256:
				terrain_image.set_pixel(pixel.x, pixel.y, Color(value, 0, 0, 1))
				tracks_dirty = true

func update_surface(delta: float):
	var p = game.van.position
	var new_origin = Vector2(floor(p.x / 64) * 64 - 32, floor(p.z / 64) * 64 - 32)
	if origin != new_origin:
		origin = new_origin
		terrain_image.fill(Color(0, 0, 0, 1))
		for key in cells:
			var pixel = key - Vector2i(origin * 2)
			if pixel.x >= 0 and pixel.y >= 0 and pixel.x < 256 and pixel.y < 256:
				terrain_image.set_pixel(pixel.x, pixel.y, Color(cells[key], 0, 0, 1))
		texture.update(terrain_image)
		tracks_dirty = false
		game.world.terrain_material.set_shader_parameter("track_origin", origin)
		game.world.road_material.set_shader_parameter("track_origin", origin)
	var water = game.world.sample_water(p).depth > 0.1
	var muddy = game.world.mud_at(p.x, p.z)
	var moving = game.started and not game.paused and not game.camping and game.simulation_running() and abs(game.speed) > 0.25
	coating = move_toward(coating, 0.0 if water else 1.0 if muddy and moving else coating, delta * (0.22 if water else 0.045))
	for i in range(mud_parts.size()):
		mud_parts[i].visible = coating > float(i % 10) / 12.0 + 0.08
	stamp_clock += delta
	ring_clock += delta
	for i in range(16): rings[i].z += delta
	for i in range(4):
		var wheel = game.van.wheels[i]
		var contact = wheel.global_position - Vector3(0, 0.55 * wheel.scale.x, 0)
		splashes[i].global_position = contact + Vector3(0, 0.2, 0)
		splashes[i].emitting = moving and (water or (muddy and game.dynamics.throttle_load > 0.5))
		splashes[i].mesh.material.albedo_color = Color("b1d8d0") if water else Color("624832")
		splashes[i].initial_velocity_max = minf(5.0, 1.8 + abs(game.speed) * 0.5)
		if moving and not water and stamp_clock > 0.10:
			var from = previous_contacts[i]
			if not from.is_finite() or from.distance_to(contact) > 5: from = contact
			var count = maxi(1, int(from.distance_to(contact) / 0.2))
			for j in range(count + 1): stamp(from.lerp(contact, float(j) / count), 0.92 if muddy else 0.32)
			previous_contacts[i] = contact
		elif not moving: previous_contacts[i] = Vector3.INF
	if stamp_clock > 0.10:
		stamp_clock = 0
		if tracks_dirty:
			texture.update(terrain_image)
			tracks_dirty = false
		if cells.size() > 24000:
			var keys = cells.keys()
			for i in range(4000): cells.erase(keys[i])
	if water and moving and ring_clock > 0.22:
		ring_clock = 0
		emit_ripple(p, minf(abs(game.speed) / 3, 1))
	for mat in game.world.water_materials:
		mat.set_shader_parameter("rings", rings)
		mat.set_shader_parameter("ring_heights", ring_heights)
		mat.set_shader_parameter("sim_time", game.model.simulation_seconds)
	game.world.water_material.set_shader_parameter("vehicle", p)
	game.world.water_material.set_shader_parameter("disturbance", minf(abs(game.speed) * 0.2, 1) if water else 0.0)
	game.world.terrain_material.set_shader_parameter("vehicle", p)
	game.world.road_material.set_shader_parameter("vehicle", p)

func emit_ripple(position: Vector3, strength: float):
	var sample = game.world.sample_water(position)
	if not sample.present: return
	rings[ring_cursor] = Vector4(position.x, position.z, 0, clampf(strength, 0, 1))
	ring_heights[ring_cursor] = sample.height
	ring_cursor = (ring_cursor + 1) % 16
