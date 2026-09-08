extends SceneTree
var errors = 0
func _initialize(): call_deferred("run")
func check(ok: bool, text: String):
	print("PASS " if ok else "FAIL ", text)
	if not ok: errors += 1
func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g.set_physics_process(false)
	g.start_trip()
	g.speed = 0
	g.camera_anchor = g.van.position
	g.camera_idle = 0
	var yaw = g.orbit_yaw
	var anchor_y = g.camera_anchor.y
	for i in range(120):
		g.van.position.y = anchor_y + sin(i * 0.9) * 0.15
		g.heading += 0.01
		g.update_camera(1.0 / 60)
	check(abs(g.camera_anchor.y - anchor_y) < 0.01, "Camera filters suspension bumps")
	check(abs(g.orbit_yaw - yaw) < 0.01, "Camera does not inherit steering yaw")
	g.looking = true
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(100, 40)
	g._input(motion)
	check(abs(g.orbit_yaw - yaw) > 0.3, "Mouse orbits camera")
	g.release_mouse()
	g.recover()
	var max_travel = 0.0
	for i in range(300):
		g.dynamics.step(g, 1, 0.3, false, 1.0 / 60)
		max_travel = maxf(max_travel, abs(g.dynamics.suspension[0] - g.dynamics.suspension[3]))
	check(max_travel > 0.015, "Wheels have independent suspension travel")
	check(is_finite(g.speed) and abs(g.van.rotation.x) < 0.7, "Chassis integration remains stable")
	g.weather.elapsed = 150
	for i in range(120): g.weather.update_weather(g, 0.1)
	check(g.weather.intensity > 0.8 and g.weather.wetness > 0.5, "Forecast produces rain and wet ground")
	g.weather.elapsed = 235
	for i in range(120): g.weather.update_weather(g, 0.1)
	check(g.weather.mist > 0.5 and g.environment.fog_density > 0.004, "Forecast transitions into mountain fog")
	check(abs(g.world.branch_x(490) - g.world.road_x(490)) > 50 and g.world.branch_y(490) > g.world.road_y(490) + 30, "Branch offers elevated mountain route")
	var ford = false
	for z in range(950, 4000):
		if g.world.ford_amount(z) > 0.7 and g.world.water_y(z) > g.world.drive_height(g.world.road_x(z), z): ford = true
	check(ford, "River has traversable submerged fords")
	g.toggle_camp()
	g.animate_camp(30)
	check(g.camp_people.size() == 4 and g.camp_people[1].position.distance_to(g.camp_people[1].get_meta("seat")) > 0.1, "Camp friends leave seats and explore")
	g.discoveries.clear()
	var wallet = g.money
	g.record_discovery("test", 1, 100)
	g.record_discovery("test", 1, 100)
	check(g.money == wallet + 100, "Discovery rewards cannot be repeatedly farmed")
	g.queue_free()
	await process_frame
	print("RESULT ", errors)
	quit(errors)
