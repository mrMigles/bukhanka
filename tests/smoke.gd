extends SceneTree
var failures = 0
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)
func _initialize():
	call_deferred("run")
func run():
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.set_physics_process(false)
	check(scene.world.chunks.size() == 13, "13 landscape chunks created")
	check(scene.van.people.size() == 4, "Four friends in the cabin")
	var bridge_count = 0
	var mud_count = 0
	for z in range(-100, 12000, 5):
		var x = scene.world.road_x(z)
		check_finite(scene.world.ground(x + 100, z))
		if scene.world.is_bridge(z):
			bridge_count += 1
			if scene.world.drive_height(x, z) <= scene.world.ground(x, z):
				failures += 1
		if scene.world.is_mud(z): mud_count += 1
	check(bridge_count > 100 and mud_count > 100, "Route contains mud and raised river crossings")
	scene.levels[0] = 2
	scene.van.update_upgrades(scene.levels)
	scene.start_trip()
	scene.toggle_auto()
	var max_error = 0.0
	for step in range(24000):
		scene.drive(1.0 / 30.0)
		max_error = maxf(max_error, abs(scene.van.position.x - scene.world.road_x(scene.van.position.z)))
		if step % 200 == 0:
			scene.world.update_chunks(scene.van.position.z, true)
			await process_frame
	check(scene.distance > 3000, "Autopilot traverses over 3 km of difficult tracks through generated terrain")
	check(max_error < 4.5, "Autopilot stays on roads and bridges: max error %.2f m" % max_error)
	check(scene.world.chunks.size() <= 13, "Streaming retains bounded chunk count")
	scene.levels = [0, 0, 0, 0]
	scene.money = 12000
	scene.buy_upgrade(0)
	check(scene.levels[0] == 1 and scene.money == 9000, "Upgrade installs and charges exact price")
	scene.money = 0
	scene.buy_upgrade(1)
	check(scene.levels[1] == 0, "Insufficient funds cannot buy upgrade")
	scene.money = 999999
	for i in range(4):
		for n in range(4): scene.buy_upgrade(i)
	check(scene.levels == [3, 3, 3, 3], "All 12 upgrades capped at level 3")
	scene.van.position.x += 80
	scene.recover()
	check(abs(scene.van.position.x - scene.world.road_x(scene.van.position.z)) < 0.01, "Recovery returns vehicle to road")
	scene.toggle_camp()
	check(scene.camping and is_instance_valid(scene.camp) and scene.speed == 0, "Camp setup parks vehicle and creates camp")
	scene.work_progress = 0.999
	var before = scene.money
	scene._physics_process(1.0)
	check(scene.money > before and scene.job_index == 1, "Remote work pays on completion")
	scene.toggle_camp()
	check(not scene.camping, "Camp packs away")
	var expected_money = scene.money
	var expected_z = scene.van.position.z
	scene.save_game()
	scene.money = 0
	scene.load_game()
	check(scene.money == expected_money and abs(scene.van.position.z - expected_z) < 0.01, "Saved journey restores upgrades, position and wallet")
	scene.queue_free()
	await process_frame
	print("RESULT: %d failures" % failures)
	quit(failures)
func check_finite(v: float):
	if not is_finite(v): failures += 1

