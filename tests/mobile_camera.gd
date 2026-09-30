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
	g.tutorial.finish()
	g.rpg_ui.close_panel()
	g.camping = false
	g.paused = false
	g.photo = false
	g.camera_mode = 0
	var t = g.touch_controls
	t.enabled = true
	t.visible = true
	for view in [Vector2(320, 568), Vector2(390, 844), Vector2(844, 390)]:
		t.configure_for_size(view, Vector4(4, 24, 4, 20))
		var reachable = true
		for b in t.action_buttons:
			reachable = reachable and b.size.x >= 44 and b.size.y >= 44 and b.position.x >= 4 and b.position.y >= 24 and b.position.x + b.size.x <= view.x - 4 and b.position.y + b.size.y <= view.y - 20
		check(reachable and t.world_pointer(view * 0.5), "Touch: reachable controls and an unobstructed centre at %s" % view)
	t.configure_for_size(Vector2(390, 844))
	t.press_pointer(0, t.center + Vector2(0, -38))
	t.press_pointer(1, Vector2(170, 280))
	var before = g.orbit_yaw
	t.drag_pointer(1, Vector2(230, 280))
	check(t.throttle > 0.8 and abs(g.orbit_yaw - before) > 0.3, "Touch: driving and looking work with two independent fingers")
	t.release_pointer(1)
	t.press_pointer(2, t.brake_button.position + t.brake_button.size * 0.5)
	check(t.braking and t.throttle > 0.8, "Touch: a third finger brakes without stealing the joystick")
	t.release_pointer(2)
	t.release_pointer(0)
	check(not t.braking and t.throttle == 0 and t.steer == 0, "Touch: releasing fingers clears all driving input")
	t.toggle_tools()
	check(not g.simulation_running() and t.tools_open, "Touch: the tools menu safely holds the simulation")
	t.close_tools()
	g.looking = false
	g.camera_idle = 0
	g.camera_motion_clock = 0
	g.dynamics.velocity = Vector3(6, 0, 4)
	g.orbit_yaw = 0.7
	for i in range(120): g.update_camera_follow(1.0 / 60)
	check(is_equal_approx(g.orbit_yaw, 0.7), "Camera: waits for continuous movement before returning")
	for i in range(360): g.update_camera_follow(1.0 / 60)
	var desired = atan2(-6.0, 4.0)
	check(absf(angle_difference(g.orbit_yaw, desired)) < 0.025, "Camera: settles behind actual travel with the correct X sign")
	g.looking = true
	g.orbit_yaw = 1.2
	for i in range(240): g.update_camera_follow(1.0 / 60)
	check(is_equal_approx(g.orbit_yaw, 1.2), "Camera: never fights a held manual look")
	g.looking = false
	g.dynamics.velocity = Vector3.ZERO
	for i in range(240): g.update_camera_follow(1.0 / 60)
	check(is_equal_approx(g.orbit_yaw, 1.2), "Camera: holds the view when stationary")
	g.queue_free()
	await process_frame
	quit(1 if failures else 0)
