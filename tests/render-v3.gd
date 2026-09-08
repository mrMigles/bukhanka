extends SceneTree
func _initialize(): call_deferred("run")
func capture(game: Node, name: String):
	for i in range(45): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/code/bukhanka/tests/" + name + ".png")
	print("CAPTURE ", name, " fps=", Engine.get_frames_per_second())
func relocate(g: Node, z: float, branch = false):
	var x = g.world.branch_x(z) if branch else g.world.road_x(z)
	g.world.update_chunks(z, true)
	g.van.position = Vector3(x, g.world.drive_height(x, z) + 0.3, z)
	g.van.rotation = Vector3.ZERO
	g.camera_anchor = g.van.position
	g.camera.position = g.van.position + Vector3(-7, 6, -13)
func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.start_trip()
	g.toast_timer = 0
	relocate(g, 475, true)
	g.orbit_yaw = -0.9
	g.orbit_pitch = 0.35
	await capture(g, "v3-pass")
	g.toggle_camp()
	for i in range(150): g.animate_camp(0.1)
	g.toast_timer = 0
	await capture(g, "v3-camp")
	g.toggle_camp()
	g.weather.elapsed = 155
	g.weather.intensity = 1
	g.weather.cloud = 1
	g.weather.wetness = 1
	relocate(g, 1350)
	g.orbit_yaw = -0.5
	await capture(g, "v3-rain")
	var peak_z = 0.0
	var peak_h = 0.0
	for z in range(120, 6000, 10):
		if g.world.branch_y(z) > peak_h:
			peak_h = g.world.branch_y(z)
			peak_z = z
	relocate(g, peak_z, true)
	await capture(g, "v3-snow")
	print("Peak route altitude ", peak_h)
	g.queue_free()
	await process_frame
	quit()
