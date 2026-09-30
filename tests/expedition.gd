extends SceneTree
var failures = 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g.set_physics_process(false)
	g.start_trip()
	var spawn = g.van.position
	check(g.weather.current_name == "Ясно" and g.weather.intensity == 0 and not g.world.mud_at(spawn.x, spawn.z), "New expedition starts clear on firm ground")
	var spawn_slope = 0.0
	for offset in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 3), Vector2(0, -3)]:
		spawn_slope = maxf(spawn_slope, absf(g.world.drive_height(spawn.x + offset.x, spawn.z + offset.y) - g.world.drive_height(spawn.x, spawn.z)))
	check(spawn_slope < 0.05, "All four wheels start on a level clearing")
	g.levels = [0, 0, 0, 0]
	g.speed = 0
	g.weather.intensity = 0
	g.update_connection()
	var parked = g.work_rate()
	var starter_signal = g.signal_speed
	g.speed = 5
	g.update_connection()
	check(g.work_rate() < parked * 0.5, "Work is slower while driving")
	g.speed = 0
	g.weather.intensity = 1
	g.time = 22
	g.update_connection()
	check(g.signal_speed > 0 and g.signal_speed < starter_signal and g.work_rate() > 0, "Rain weakens starter internet without disconnecting it")
	g.levels[2] = 3
	g.update_connection()
	check(g.signal_speed > starter_signal and g.work_rate() > 0, "Upgraded internet survives weather")
	g.weather.intensity = 0
	g.recover()
	g.toggle_camp()
	g.rpg_ui.toggle_cinema()
	check(g.model.cinematic and g.camping, "Cinematic camera works in camp without autopilot")
	var saved_time = g.model.simulation_seconds
	var day_pose = g.camp_camera_pose()
	g.model.simulation_seconds = 882
	var night_pose = g.camp_camera_pose()
	check(night_pose.look.y > night_pose.target.y and night_pose.fov > day_pose.fov, "Night camp shot looks up toward moon and stars")
	g.model.simulation_seconds = saved_time
	g.model.cinematic = false
	g.projects.refresh_offers()
	check(is_equal_approx(g.projects.offers[0].duration, 1.0 / 3.0) and g.projects.offers[1].duration == 1 and g.projects.offers[2].duration == 2, "Contracts offer eight hours, one day and two days")
	g.weather.intensity = 1
	for i in range(100): g.animate_camp(0.1)
	check(g.camp_people[0].visible and not g.van.people[0].visible and g.work_rate() == 0, "Rain stops exposed work while friends remain by the fire")
	g.money = 100000
	g.buy_camp_upgrade()
	for i in range(100): g.animate_camp(0.1)
	check(g.camp_level == 1 and g.camp.has_node("WorkCanopy") and g.work_rate() > 0, "Camp upgrade adds a canopy and restores work in rain")
	check(g.crew_system.worker_count() == 2, "Rain leaves two workers sheltered and two friends doing outdoor activities")
	g.model.camp_mode = "auto"
	g.model.simulation_seconds = 700
	for i in range(10): g.animate_camp(0.1)
	var social = 0
	for hero in g.model.crew:
		if hero.activity in ["Играет на гитаре", "Играет с друзьями", "Отдыхает у костра"]: social += 1
	check(social == 4 and g.crew_system.guitar_active(), "Auto camp becomes a living evening scene with guitar and group play")
	g.toggle_camp()
	for step in range(16):
		g.crew_system.tick(g, 0.1)
		g.update_packing(0.1)
	check(not g.camping and not g.packing_camp, "Crew boards and camp packs within two seconds")
	g.effects.update_surface(0.1)
	var p = g.van.position
	var height_before_track = g.world.contact_ground(p.x, p.z)
	g.effects.stamp(p, 1)
	check(g.effects.depth_at(p.x, p.z) > 0.03, "Tires deform contact terrain")
	check(g.world.contact_ground(p.x, p.z) < height_before_track, "Cached terrain keeps tire deformation live")
	check(g.effects.cells.size() > 0, "Tracks persist in bounded world cells")
	var test_touch = InputEventScreenTouch.new()
	g.touch_controls.enabled = true
	g.ui.apply_mobile_layout()
	g.touch_controls.visible = true
	test_touch.index = 0
	test_touch.position = g.touch_controls.get_global_transform_with_canvas() * (g.touch_controls.center + Vector2(30, -60))
	test_touch.pressed = true
	g.touch_controls._input(test_touch)
	check(g.touch_controls.throttle > 0.5 and g.touch_controls.steer < -0.2, "Touch joystick controls throttle and steering")
	test_touch.pressed = false
	g.touch_controls._input(test_touch)
	check(g.touch_controls.throttle == 0 and g.touch_controls.steer == 0, "Joystick releases without stuck throttle")
	var villagers = false
	var falls = false
	for chunk in g.world.chunks.values():
		villagers = villagers or chunk.get_meta("village", false)
		falls = falls or chunk.get_meta("waterfall", false)
	check(villagers and falls and g.world.wildlife.size() > 0, "Streamed villages, waterfalls and wildlife exist")
	var manul = false
	for animal in g.world.wildlife:
		if animal.get_meta("species", "") == "Манул":
			manul = true
			var before_discovery = g.van.position
			g.van.position = animal.position + Vector3(0, 0, 5)
			g.check_discoveries()
			g.check_discoveries()
			g.van.position = before_discovery
	check(manul, "A mountain manul is generated")
	var cat_memories = 0
	for memory in g.discoveries:
		if str(memory).begins_with("Манул:"): cat_memories += 1
	check(cat_memories == 1, "Manul encounter is recorded once in the album")
	g.save_game()
	g.camp_level = 0
	g.load_game()
	check(g.camp_level == 1, "Camp upgrades persist")
	var original_world = g.world
	var slope = TestSlope.new()
	root.add_child(slope)
	g.world = slope
	g.levels = [0, 0, 0, 0]
	g.low_range = false
	g.heading = 0
	g.van.position = Vector3(0, 0.3, 0)
	g.van.rotation = Vector3.ZERO
	g.weather.wetness = 0
	g.dynamics.reset()
	for i in range(900): g.dynamics.step(g, 1, 0, false, 1.0 / 60)
	check(g.van.position.z > 20 and g.speed > 2, "Starter engine climbs a sustained 25 percent grade")
	slope.grade = 0
	g.van.position = Vector3(0, 0.3, 0)
	g.van.rotation = Vector3.ZERO
	g.dynamics.reset()
	for i in range(1200): g.dynamics.step(g, 1, 0, false, 1.0 / 60)
	check(g.speed > 9 and g.speed < 11.5, "Raised road speed remains bounded")
	g.world = original_world
	slope.queue_free()
	await preload("res://tests/rpg_checks.gd").run(g, check)
	g.queue_free()
	await process_frame
	print("RESULT ", failures)
	quit(failures)

class TestSlope extends Node3D:
	var grade = 0.25
	func nearest_route(_x, _z): return 0
	func route_x(_z, _route): return 0
	func mud_at(_x, _z): return false
	func water_y(_z): return -100
	func drive_height(_x, z): return z * grade
	func river_x(_z): return 1000
	func collides(_p): return false
	func is_bridge(_z): return false
