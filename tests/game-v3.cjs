const fs=require('fs'); let s=fs.readFileSync('scripts/game.gd','utf8').replace(/\r\n/g,'\n');
s=s.replace('var looking = false','var looking = false\nvar camera_anchor = Vector3.ZERO\nvar camera_idle = 0.0\nvar low_range = false\nvar discoveries: Array = []\nvar camp_people: Array[Node3D] = []\nvar camp_clock = 0.0\nvar journal_timer = 0.0');
s=s.replace('camera.position = van.position + Vector3(-8, 5, -12)','camera.position = van.position + Vector3(-8, 5, -12)\n\tcamera_anchor = van.position\n\torbit_yaw = heading - 0.45');
s=s.replace('var a = heading + orbit_yaw','var a = orbit_yaw');
s=s.replace('look = van.position + (Vector3(-3, 1, 0) if camping else Vector3(0, 1.6, 0))',`camera_anchor.x = lerpf(camera_anchor.x, van.position.x, 1.0 - exp(-delta * 7))
		camera_anchor.z = lerpf(camera_anchor.z, van.position.z, 1.0 - exp(-delta * 7))
		var height_delta = van.position.y - camera_anchor.y
		if abs(height_delta) > 0.20:
			camera_anchor.y = lerpf(camera_anchor.y, van.position.y - signf(height_delta) * 0.20, 1.0 - exp(-delta * 1.5))
		camera_idle += delta
		if camera_idle > 4.0 and abs(speed) > 2.0 and not camping and not photo:
			var motion_yaw = atan2(dynamics.velocity.x, dynamics.velocity.z)
			orbit_yaw = lerp_angle(orbit_yaw, motion_yaw, 1.0 - exp(-delta * 0.30))
		look = camera_anchor + (Vector3(-3, 1, 0) if camping else Vector3(0, 1.6, 0))`);
s=s.replace('orbit_yaw -= event.relative.x * 0.004','camera_idle = 0\n\t\torbit_yaw -= event.relative.x * 0.004');
s=s.replace('var target_z = van.position.z + 8 + abs(speed) * 0.8','var route = world.nearest_route(van.position.x, van.position.z)\n\t\tvar target_z = van.position.z + 8 + abs(speed) * 0.8');
s=s.replace('world.road_x(target_z) - van.position.x','world.route_x(target_z, route) - van.position.x');
s=s.replace('throttle = clampf((15.0 - speed) * 0.5, -0.5, 1)', 'var desired_speed = 4.0 if world.mud_at(van.position.x, van.position.z) else (6.0 if world.ford_amount(van.position.z) > 0.2 else 11.0)\n\t\tlow_range = world.mud_at(van.position.x, van.position.z) or world.ford_amount(van.position.z) > 0.2\n\t\tthrottle = clampf((desired_speed - speed) * 0.8, -0.5, 1)');
s=s.replace('if camping and is_instance_valid(fire):','journal_timer += delta\n\tif journal_timer > 2:\n\t\tjournal_timer = 0\n\t\tcheck_discoveries()\n\tif camping:\n\t\tanimate_camp(delta)\n\tif camping and is_instance_valid(fire):');
s=s.replace('engine_audio.volume_db = -55', 'music_audio.volume_db = lerpf(music_audio.volume_db, -9.0 if camping else -45.0, delta * 1.5)\n\tengine_audio.volume_db = -55');
s=s.replace('KEY_C:', 'KEY_L:\n\t\t\tlow_range = not low_range\n\t\t\ttoast("Пониженная передача: " + ("включена — тяга на малой скорости" if low_range else "выключена"))\n\t\tKEY_F:\n\t\t\tif started and not camping: winch()\n\t\tKEY_C:');
s=s.replace('orbit_yaw = 0.0 if camera_mode == 2 else -0.45','orbit_yaw = 0.0 if camera_mode == 2 else heading - 0.45');
s=s.replace('var fire_pos = Vector3(-5, 0, -0.5)','camp_people.clear()\n\tcamp_clock = 0\n\tvar fire_pos = Vector3(-5, 0, -0.5)');
s=s.replace('friend.visible = true','camp_people.append(friend)\n\t\tfriend.visible = true');
s=s.replace('friend.rotation.y = -a - PI / 2',`friend.rotation.y = -a - PI / 2
		friend.set_meta("seat", p)
		if i == 0:
			var guitar = van.cylinder(friend, Vector3(0, 0.40, 0.4), 0.24, 0.10, van.wood)
			guitar.rotation.x = PI / 2
			van.box(friend, Vector3(0.31, 0.5, 0.42), Vector3(0.55, 0.075, 0.08), van.wood)
			var hole = van.cylinder(friend, Vector3(0, 0.4, 0.465), 0.075, 0.012, van.dark)
			hole.rotation.x = PI / 2`);
s=s.replace('"weather_time": weather.elapsed,','"discoveries": discoveries, "weather_time": weather.elapsed,');
s=s.replace('weather.elapsed = maxf(0, float(data.get("weather_time", 0)))','weather.elapsed = maxf(0, float(data.get("weather_time", 0)))\n\tdiscoveries = data.get("discoveries", [])');
s=s.replace('if camping:\n\t\tbuild_camp()', 'if camping:\n\t\tbuild_camp()\n\t\trecord_discovery("Стоянка", int(van.position.z / 500), 1200)');
s+=`
func winch():
	if abs(speed) > 2:
		toast("Для лебёдки сначала остановитесь.")
		return
	var route = world.nearest_route(van.position.x, van.position.z)
	var dest = van.position.z + 9
	van.position = Vector3(world.route_x(dest, route), world.drive_height(world.route_x(dest, route), dest) + 0.25, dest)
	dynamics.reset()
	speed = 0
	toast("Друзья закрепили трос. Девять метров ближе к сухой земле.")

func record_discovery(kind: String, sector: int, reward: int):
	var id = "%s:%d" % [kind, sector]
	if discoveries.has(id): return
	discoveries.append(id)
	money += reward
	toast("%s открыта · +%d ₽ · воспоминаний: %d" % [kind, reward, discoveries.size()])

func check_discoveries():
	var z = van.position.z
	if world.nearest_route(van.position.x, z) == 1 and world.branch_amount(z) > 0.75:
		record_discovery("Панорама перевала", int(z / 960), 1800)
	if world.ford_amount(z) > 0.7 and world.water_y(z) > world.drive_height(van.position.x, z):
		record_discovery("Переправа", int(z / 500), 1400)

func animate_camp(delta: float):
	camp_clock += delta
	for i in range(camp_people.size()):
		var person = camp_people[i]
		var seat: Vector3 = person.get_meta("seat")
		var phase = fposmod(camp_clock + i * 11, 52)
		if i == 0:
			person.rotation.z = sin(camp_clock * 2) * 0.04
		elif phase > 18 and phase < 43:
			var progress = (phase - 18) / 25.0
			var excursion = sin(progress * PI)
			person.position = seat + Vector3(sin(progress * TAU) * 1.3, 0, excursion * (2.0 + i * 0.6))
			person.position.y = world.drive_height(camp.position.x + person.position.x, camp.position.z + person.position.z) - camp.position.y + 0.15 + abs(sin(camp_clock * 5)) * 0.045
			person.rotation.y = sin(progress * TAU) * 0.8
		else:
			person.position = person.position.lerp(seat, delta * 2)
`;
fs.writeFileSync('scripts/game.gd',s);
s=fs.readFileSync('scripts/vehicle_physics.gd','utf8');
s=s.replace('var previous_speed = 0.0','var previous_speed = 0.0\nvar bog = 0.0');
s=s.replace('steering = 0\n','steering = 0\n\tbog = 0\n');
s=s.replace('var offroad = abs(body.position.x - terrain.road_x(body.position.z)) > 5.2', 'var route = terrain.nearest_route(body.position.x, body.position.z)\n\tvar offroad = abs(body.position.x - terrain.route_x(body.position.z, route)) > 3.4');
s=s.replace('var muddy = (terrain.is_mud(body.position.z) or offroad)','var muddy = terrain.mud_at(body.position.x, body.position.z)');
s=s.replace('var water = offroad and abs(body.position.x - terrain.river_x(body.position.z)) < 11','var depth = terrain.water_y(body.position.z) - terrain.drive_height(body.position.x, body.position.z)\n\tvar water = depth > 0.12 and abs(body.position.x - terrain.river_x(body.position.z)) < 11');
s=s.replace('var engine_force = throttle * (7.0 + game.levels[0] * 0.6)',`var drive_force = 7.0 + game.levels[0] * 0.85
	if game.low_range: drive_force *= 1.65
	if muddy:
		bog = move_toward(bog, clampf(0.8 + wet * 0.4 - game.levels[0] * 0.16, 0, 1), dt * 0.04)
		drive_force *= 0.65 + game.levels[0] * 0.07
	else: bog = move_toward(bog, 0, dt * 0.3)
	var engine_force = throttle * drive_force
	if game.low_range and abs(longitudinal) > 5.5: engine_force *= maxf(0, 1 - (abs(longitudinal) - 5.5) / 2)
`);
s=s.replace('var rolling = (1.0 if muddy else 0.42) + (0.23 if muddy else 0.0) * abs(longitudinal)', 'var rolling = (2.9 + bog * 3 if muddy else (1.1 if offroad else 0.42)) + (0.9 if muddy else 0.0) * abs(longitudinal)');
s=s.replace('if water: rolling += 5 + abs(longitudinal) * 1.4','if water: rolling += minf(depth * 3, 6) + abs(longitudinal) * depth * 0.7');
s=s.replace('"Глубокий брод · R помощь"', '"Брод %.0f см" % (depth * 100)');
s=s.replace('"Грязь · сцепление %.0f%%" % (grip * 15)', '"Грязь · L тяга / F трос"');
s=s.replace('"Грунтовая дорога"','"Гравий · перевал" if route == 1 else "Гравий · долина"');
fs.writeFileSync('scripts/vehicle_physics.gd',s);
