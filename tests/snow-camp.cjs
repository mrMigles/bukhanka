const fs=require('fs');let s=fs.readFileSync('scripts/world.gd','utf8');
s=s.replace('330.0 + noise', '215.0 + noise').replace('elif altitude > 260.0:', 'elif altitude > 190.0:').replace('elif altitude > 175.0:', 'elif altitude > 155.0:').replace('if h > 295:', 'if h > 220:');
s=s.replace('if route == 0 and is_bridge(z): col =', 'if (branch_y(z) if route == 1 else road_y(z)) > 215: col = Color("dce3dd")\n\t\t\tif route == 0 and is_bridge(z): col =');
fs.writeFileSync('scripts/world.gd',s);
s=fs.readFileSync('scripts/weather.gd','utf8');
s=s.replace('rain.global_position = game.van.position',`var snowing = game.van.position.y > 215
	if snowing and index == 2: current_name = "Снег"
	rain.mesh.size = Vector3(0.065, 0.065, 0.065) if snowing else Vector3(0.018, 0.6, 0.018)
	rain.initial_velocity_min = 2.5 if snowing else 18.0
	rain.initial_velocity_max = 4.0 if snowing else 24.0
	rain.gravity = Vector3(0.5, -0.3, 0) if snowing else Vector3(1, -4, 0)
	rain.mesh.material.albedo_color = Color.WHITE if snowing else Color(0.6, 0.75, 0.83, 0.45)
	rain.global_position = game.van.position`);
s=s.replace('game.world.terrain_material.roughness =', 'game.world.road_material.set_shader_parameter("wetness", wetness)\n\tgame.world.terrain_material.roughness =');
fs.writeFileSync('scripts/weather.gd',s);
s=fs.readFileSync('scripts/game.gd','utf8');
s=s.replace('if not started or ui.garage.visible or photo: return\n\tdynamics.reset()',`if not started or ui.garage.visible or photo: return
	if not camping and world.water_y(van.position.z) > world.drive_height(van.position.x, van.position.z) and abs(van.position.x - world.river_x(van.position.z)) < 11:
		toast("Сначала выберитесь на сухой берег: здесь не поставить палатки.")
		return
	dynamics.reset()`);
s=s.replace('fire_pos.y = world.ground(', 'fire_pos.y = world.drive_height(');
s=s.replace('var p = fire_pos + Vector3(cos(a) * 2.1, 0.3, sin(a) * 2.1)', 'var p = fire_pos + Vector3(cos(a) * 2.1, 0.3, sin(a) * 2.1)\n\t\tp.y = world.drive_height(camp.position.x + p.x, camp.position.z + p.z) - camp.position.y + 0.4');
fs.writeFileSync('scripts/game.gd',s);
