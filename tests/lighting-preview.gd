extends SceneTree

func _initialize(): call_deferred("run")

func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_physics_process(false)
	g.start_trip()
	# Reproduce the transition from all four portrait lights to the landscape.
	g.rpg_ui.open_panel("editor")
	for frame in range(3): await process_frame
	g.rpg_ui.close_panel()
	g.model.simulation_seconds = 420
	g.weather.update_weather(g, 0)
	g.lighting.update(g, 0)
	for frame in range(15): await process_frame
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png("res://tests/lighting-preview.png")
	print("LIGHTING_PREVIEW ", result)
	g.queue_free()
	await process_frame
	quit(result)
