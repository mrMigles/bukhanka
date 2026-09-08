extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.start_trip()
	game.autopilot = true
	for j in range(18000):
		game.drive(1.0 / 30)
		if j % 1500 == 0:
			print("t=", j / 30, " z=", game.van.position.z, " v=", game.speed, " contacts=", game.dynamics.contact_count, " pitch=", game.van.rotation.x, " bog=", game.dynamics.bog, " low=", game.low_range, " pos=", game.van.position)
			game.world.update_chunks(game.van.position.z, true)
			await process_frame
	print("DISTANCE ", game.distance)
	game.queue_free()
	await process_frame
	quit()
