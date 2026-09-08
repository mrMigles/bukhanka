extends SceneTree
func _initialize(): call_deferred("run")
func shot(g: Node, name: String):
	for i in range(70): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/code/bukhanka/tests/" + name + ".png")
	print("CAPTURE ", name, " FPS ", Engine.get_frames_per_second())
func locate(g: Node, z: float, route = 0):
	g.world.update_chunks(z, true)
	var x = g.world.route_x(z, route)
	g.van.position = Vector3(x, g.world.drive_height(x, z) + 0.3, z)
	g.camera_anchor = g.van.position
	g.camera.position = g.van.position + Vector3(-8, 6, -13)
	g.dynamics.reset()
func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	await shot(g, "expedition-menu")
	g.start_trip()
	g.ui.garage.show()
	await shot(g, "expedition-garage")
	g.ui.garage.hide()
	locate(g, 1350)
	g.orbit_yaw = -0.55
	await shot(g, "expedition-village")
	locate(g, 600)
	g.orbit_yaw = 0.7
	g.orbit_distance = 24
	await shot(g, "expedition-valley")
	locate(g, 450, 1)
	g.camp_level = 2
	g.toggle_camp()
	g.weather.elapsed = 160
	g.weather.intensity = 1
	for i in range(100): g.animate_camp(0.1)
	await shot(g, "expedition-camp")
	g.touch_controls.enabled = true
	g.ui.apply_mobile_layout()
	g.toggle_camp()
	await shot(g, "expedition-touch")
	g.queue_free()
	await process_frame
	quit()
