extends RefCounted
## Four independent spring/damper contacts with chassis heave, pitch, roll and tire slip.
const CONTACTS = [Vector3(-1.18, 0.98, -1.42), Vector3(1.18, 0.98, -1.42), Vector3(-1.18, 0.98, 1.36), Vector3(1.18, 0.98, 1.36)]
var velocity = Vector3.ZERO
var vertical_speed = 0.0
var pitch_rate = 0.0
var roll_rate = 0.0
var yaw_rate = 0.0
var steering = 0.0
var rpm = 900.0
var gear = 1
var contact_count = 4
var slip = 0.0
var suspension: Array = [0.53, 0.53, 0.53, 0.53]
var wheel_spin: Array = [0.0, 0.0, 0.0, 0.0]
var throttle_load = 0.0
var previous_speed = 0.0
var bog = 0.0

func reset():
	velocity = Vector3.ZERO
	vertical_speed = 0
	pitch_rate = 0
	roll_rate = 0
	yaw_rate = 0
	steering = 0
	bog = 0

func step(game: Node, throttle: float, turn: float, brake: bool, delta: float):
	var substeps = maxi(1, int(ceil(delta * 120)))
	for i in range(substeps):
		integrate(game, throttle, turn, brake, delta / substeps)
	for i in range(4):
		var wheel = game.van.wheels[i]
		wheel.position.y = suspension[i]
		wheel.rotation.y = steering if i >= 2 else 0.0
		wheel.get_child(0).rotation.x = wheel_spin[i]

func integrate(game: Node, throttle: float, turn: float, brake: bool, dt: float):
	var body = game.van
	var terrain = game.world
	var route = terrain.nearest_route(body.position.x, body.position.z)
	var offroad = abs(body.position.x - terrain.route_x(body.position.z, route)) > 3.4
	var muddy = terrain.mud_at(body.position.x, body.position.z)
	var water_sample = terrain.sample_water(body.position) if terrain.has_method("sample_water") else {"depth": maxf(0, terrain.water_y(body.position.z) - terrain.drive_height(body.position.x, body.position.z)), "flow": Vector3.ZERO}
	var depth = float(water_sample.depth)
	var water = depth > 0.12
	var wet = game.weather.wetness
	var grip = (2.3 if muddy else 8.0) * (1.0 - wet * 0.35) + game.levels[0] * 0.8
	var forward = Vector3(sin(game.heading), 0, cos(game.heading))
	var right = Vector3(cos(game.heading), 0, -sin(game.heading))
	var longitudinal = velocity.dot(forward)
	var lateral = velocity.dot(right)
	steering = move_toward(steering, turn * lerpf(0.52, 0.28, minf(abs(longitudinal) / 25, 1)), dt * 1.25)
	var target_yaw = longitudinal / 2.78 * tan(steering)
	yaw_rate = lerpf(yaw_rate, target_yaw, minf(dt * grip, 1))
	game.heading += yaw_rate * dt
	body.rotation.y = game.heading
	var sum_force = -9.81
	var pitch_acc = 0.0
	var roll_acc = 0.0
	contact_count = 0
	var radius = 0.55 * (1.0 + game.levels[0] * 0.07)
	for i in range(4):
		var local: Vector3 = CONTACTS[i]
		var wp = body.to_global(local)
		var height = terrain.drive_height(wp.x, wp.z)
		var length = wp.y - height - radius
		var compression = 0.72 - length
		var point_speed = vertical_speed + roll_rate * local.x - pitch_rate * local.z
		var force = 0.0
		if length < 0.9:
			contact_count += 1
			force = clampf(compression * (28.0 + game.levels[0] * 2.5) - point_speed * 3.2, 0, 35)
			sum_force += force
			pitch_acc -= force * local.z / 3.8
			roll_acc += force * local.x / 2.6
		suspension[i] = local.y - clampf(length, 0.25, 0.9)
		wheel_spin[i] += longitudinal / radius * dt
	var grounded = contact_count / 4.0
	var gradient = (terrain.drive_height(body.position.x + forward.x, body.position.z + forward.z) - terrain.drive_height(body.position.x - forward.x, body.position.z - forward.z)) * 0.5
	var drive_force = 8.2 + game.levels[0] * 0.85
	if game.low_range: drive_force *= 2.15
	if muddy:
		bog = move_toward(bog, clampf(0.8 + wet * 0.4 - game.levels[0] * 0.16, 0, 1), dt * 0.04)
		drive_force *= 0.65 + game.levels[0] * 0.07
	else: bog = move_toward(bog, 0, dt * 0.3)
	if game.model.energy <= 0: throttle = 0
	var engine_force = throttle * drive_force
	var cruise_limit = 3.5 if game.low_range else 8.75
	if abs(longitudinal) > cruise_limit: engine_force *= maxf(0, 1 - (abs(longitudinal) - cruise_limit) / 1.875)
	if abs(longitudinal) > cruise_limit + 1.875: engine_force -= signf(longitudinal) * (abs(longitudinal) - cruise_limit - 1.875) * 4.0

	if throttle < 0 and longitudinal > 0.5: engine_force = -12.0
	if throttle < 0 and longitudinal < -5: engine_force = 0
	var rolling = (2.9 + bog * 3 if muddy else (1.1 if offroad else 0.42)) + (0.9 if muddy else 0.0) * abs(longitudinal)
	if water: rolling += minf(depth * 3, 6) + abs(longitudinal) * depth * 0.7
	var acceleration = (engine_force - signf(longitudinal) * rolling - 0.009 * longitudinal * abs(longitudinal) - gradient * 9.81) * grounded
	if brake:
		acceleration -= signf(longitudinal) * 16 * grounded
		grip *= 0.32
	var old_speed = longitudinal
	longitudinal += acceleration * dt
	if (brake or throttle == 0) and old_speed * longitudinal < 0 and abs(gradient) < 0.1: longitudinal = 0
	lateral *= exp(-grip * grounded * dt)
	slip = abs(lateral) + abs(throttle) * (1.0 - grounded)
	velocity = forward * longitudinal + right * lateral
	if water:
		# The current pushes across the ford; traction and low range counter it.
		velocity += water_sample.flow * minf(depth, 1.5) * dt * 0.8
	var next = body.position + velocity * dt
	if terrain.collides(next):
		velocity *= -0.2
		longitudinal *= -0.2
		pitch_rate += minf(abs(old_speed) * 0.02, 0.3)
	else:
		game.distance += Vector2(next.x - body.position.x, next.z - body.position.z).length()
		body.position.x = next.x
		body.position.z = next.z
	vertical_speed += sum_force * dt
	body.position.y += vertical_speed * dt
	pitch_acc -= acceleration * 0.18 * grounded
	roll_acc += longitudinal * yaw_rate * 0.16 * grounded
	pitch_rate = (pitch_rate + pitch_acc * dt) * exp(-dt * 1.5)
	roll_rate = (roll_rate + roll_acc * dt) * exp(-dt * 1.7)
	body.rotation.x = clampf(body.rotation.x + pitch_rate * dt, -0.7, 0.7)
	body.rotation.z = clampf(body.rotation.z + roll_rate * dt, -0.65, 0.65)
	var floor_y = terrain.drive_height(body.position.x, body.position.z) - 0.05
	if body.position.y < floor_y:
		body.position.y = floor_y
		vertical_speed = maxf(vertical_speed, abs(vertical_speed) * 0.16)
	game.speed = longitudinal
	game.surface_name = "Брод %.0f см" % (depth * 100) if water else ("Грязь · L тяга / F трос" if muddy else "Гравий · перевал" if route == 1 else "Гравий · долина")
	if terrain.is_bridge(body.position.z) and not offroad: game.surface_name = "Мост · подвеска работает"
	gear = clampi(int(abs(longitudinal) / 6.5) + 1, 1, 4)
	rpm = lerpf(rpm, 850 + fmod(abs(longitudinal), 6.5) * 270 + abs(throttle) * 500, dt * 5)
	throttle_load = lerpf(throttle_load, abs(throttle), dt * 6)
