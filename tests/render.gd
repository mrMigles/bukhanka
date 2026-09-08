extends SceneTree
func _initialize():
	call_deferred("run")
func capture(scene: Node, filename: String):
	for i in range(15):
		await process_frame
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png("C:/code/bukhanka/tests/" + filename + ".png")
	print("CAPTURE ", filename, " ", result)
func run():
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.time = 0
	await capture(scene, "title")
	scene.start_trip()
	await capture(scene, "road")
	scene.camera_mode = 2
	await capture(scene, "interior")
	scene.camera_mode = 0
	scene.levels = [3, 3, 3, 3]
	scene.van.update_upgrades(scene.levels)
	scene.toggle_camp()
	await capture(scene, "camp")
	scene.toggle_garage()
	await capture(scene, "workshop")
	scene.queue_free()
	await process_frame
	quit()
