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
	g.graphics.choose("high")
	g.graphics.set_scale(0.85)
	g.graphics.set_shadows(false)
	var restored = preload("res://scripts/graphics_settings.gd").new()
	restored.load_preferences(true)
	check(restored.path == "user://test_graphics.cfg" and restored.preset == "high" and is_equal_approx(restored.scale, 0.85) and not restored.shadows, "Device quality persists independently of expedition saves")
	g.graphics.choose("auto")
	for i in range(40): g.graphics.adapt_resolution(20.0)
	check(is_equal_approx(g.graphics.current_scale, 0.65) and g.graphics.shadows and g.graphics.nature, "Auto limits resolution without disabling living effects or shadows")
	for i in range(40): g.graphics.adapt_resolution(65.0)
	check(is_equal_approx(g.graphics.current_scale, 1.0), "Auto restores resolution when there is rendering headroom")
	check(g.world.tree_mesh.surface_get_material(0) == g.world.tree_material and g.world.tree_material != g.world.terrain_material, "Foliage avoids terrain deformation and track sampling")
	g.graphics.choose("balanced")
	var river = Vector3(g.world.river_x(500.0), 0, 500.0)
	g.effects.emit_ripple(river, 0.4)
	g.effects.update_surface(0.0)
	check(g.world.water_materials[0].get_shader_parameter("ripple_count") > 0, "Water evaluates only active ripples")
	g.effects.update_surface(4.1)
	check(g.world.water_materials[0].get_shader_parameter("ripple_count") == 0, "Expired ripples leave the shader budget")
	g.effects.emit_ripple(river, 0.4)
	g.graphics.set_nature(false)
	g.effects.update_surface(0.0)
	check(g.world.water_materials[0].get_shader_parameter("ripple_count") == 0, "Disabling effects removes ripple shader work")
	g.graphics.choose("auto")
	quit(1 if failures else 0)
