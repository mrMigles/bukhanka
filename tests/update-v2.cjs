const fs = require('fs');
let s=fs.readFileSync('scripts/game.gd','utf8');
s=s.replace('var world: Node3D',`var dynamics = preload("res://scripts/vehicle_physics.gd").new()
var weather: Node3D
var orbit_yaw = -0.45
var orbit_pitch = 0.30
var orbit_distance = 13.0
var looking = false
var world: Node3D`);
s=s.replace('setup_environment()', 'setup_environment()\n\tweather = preload("res://scripts/weather.gd").new()\n\tadd_child(weather)');
let start=s.indexOf('func drive(delta: float):'), end=s.indexOf('\nfunc _process',start);
s=s.slice(0,start)+`func drive(delta: float):
	var throttle = float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	var steer = float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
	var brake = Input.is_physical_key_pressed(KEY_SPACE)
	if throttle != 0 or steer != 0 or brake: autopilot = false
	if autopilot:
		var target_z = van.position.z + 8 + abs(speed) * 0.8
		var desired = atan2(world.road_x(target_z) - van.position.x, target_z - van.position.z)
		steer = clampf(wrapf(desired - heading, -PI, PI) * 3.4, -1, 1)
		throttle = clampf((15.0 - speed) * 0.5, -0.5, 1)
	dynamics.step(self, throttle, steer, brake, delta)
	var km = int(distance / 1000)
	if km > last_km:
		money += (km - last_km) * (1000 + levels[3] * 500)
		last_km = km
		toast("Ещё километр воспоминаний! +%d ₽" % (1000 + levels[3] * 500))
`+s.slice(end);
s=s.replace('engine_audio.pitch_scale = 0.65 + abs(speed) / 18','engine_audio.pitch_scale = clampf(dynamics.rpm / 1100.0, 0.7, 2.8)');
s=s.replace('else -23 + minf(abs(speed), 15) * 0.25','else -9.0 + dynamics.throttle_load * 4.0');
s=s.replace('wind_audio.volume_db = -9','wind_audio.volume_db = -20').replace('music_audio.volume_db = -17','music_audio.volume_db = -25');
s=s.replace('sample = sin(TAU * 44 * t) * 0.24 + sin(TAU * 88 * t) * 0.12 + sin(TAU * 132 * t) * 0.04','sample = sin(TAU * 44 * t) * 0.32 + sin(TAU * 88 * t) * 0.19 + sin(TAU * 132 * t) * 0.13 + sin(TAU * 220 * t) * 0.09 + rng.randf_range(-0.04, 0.04)');
s=s.replace('dust.emitting = abs(speed) > 3 and not camping and not paused','dust.emitting = abs(speed) > 3 and not camping and not paused and weather.wetness < 0.4');
s=s.replace('sk.sky_horizon_color = Color("6b7f8c").lerp(Color("d3d8bd"), daylight)','sk.sky_horizon_color = Color("6b7f8c").lerp(Color("d3d8bd"), daylight)\n\tweather.update_weather(self, delta if started and not paused and not photo else 0.0)');
start=s.indexOf('func update_camera(delta: float):');end=s.indexOf('\nfunc _unhandled_key_input',start);
s=s.slice(0,start)+`func update_camera(delta: float):
	var target: Vector3
	var look: Vector3
	if not started:
		var a = sin(time * 0.085) * 0.35 - 0.75
		target = van.position + Vector3(sin(a) * 11, 4.8, -cos(a) * 11)
		look = van.position + Vector3(0, 1.7, 1)
	elif camera_mode == 2 and not camping and not photo:
		target = van.to_global(Vector3(0, 2.32, -1.88))
		look = target + Vector3(sin(orbit_yaw), -sin(orbit_pitch - 0.2), cos(orbit_yaw)).rotated(Vector3.UP, heading) * 5
	else:
		look = van.position + (Vector3(-3, 1, 0) if camping else Vector3(0, 1.6, 0))
		var dist = orbit_distance * (1.6 if camera_mode == 1 else 1.0)
		var a = heading + orbit_yaw
		target = look + Vector3(sin(a) * cos(orbit_pitch), sin(orbit_pitch), -cos(a) * cos(orbit_pitch)) * dist
		target.y = maxf(target.y, world.ground(target.x, target.z) + 0.7)
	camera.position = camera.position.lerp(target, 1.0 if camera_mode == 2 else 1.0 - exp(-delta * 9))
	camera.look_at(look)
	camera.fov = lerpf(camera.fov, 65.0 + minf(abs(speed) * 0.32, 9), delta * 2)

func _input(event):
	if not started or paused or ui.garage.visible: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			looking = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if looking else Input.MOUSE_MODE_VISIBLE
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbit_distance = clampf(orbit_distance - 1.2, 5, 35)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit_distance = clampf(orbit_distance + 1.2, 5, 35)
	if event is InputEventMouseMotion and looking:
		orbit_yaw -= event.relative.x * 0.004
		orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.003, -0.25 if camera_mode == 2 else 0.05, 1.25)

func release_mouse():
	looking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
`+s.slice(end);
s=s.replace('func toggle_pause():','func toggle_pause():\n\trelease_mouse()');
s=s.replace('func toggle_garage():','func toggle_garage():\n\trelease_mouse()');
s=s.replace('func recover():','func recover():\n\tdynamics.reset()');
s=s.replace('camera_mode = (camera_mode + 1) % 3','camera_mode = (camera_mode + 1) % 3\n\torbit_yaw = 0.0 if camera_mode == 2 else -0.45\n\torbit_pitch = 0.2 if camera_mode == 2 else 0.30');
s=s.replace('camping = not camping','dynamics.reset()\n\tcamping = not camping\n\torbit_yaw = -1.9 if camping else -0.45\n\torbit_pitch = 0.5 if camping else 0.3\n\torbit_distance = 17.0 if camping else 13.0');
s=s.replace('var data = {"version": 1,','var data = {"weather_time": weather.elapsed, "version": 1,');
s=s.replace('last_km = int(distance / 1000)','last_km = int(distance / 1000)\n\tweather.elapsed = maxf(0, float(data.get("weather_time", 0)))');
s=s.replace('var result = picture.save_png(filename)',`if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(picture.save_png_to_buffer(), "Altai.png", "image/png")
		ui.hud.visible = was_visible
		return
	var result = picture.save_png(filename)`);
s=s.replace('KEY_F12:', 'KEY_K, KEY_F12:');
s=s.replace('WASD — за руль. Или J — автопилот, а вы смотрите по сторонам.', 'ПКМ + мышь — обзор. Колесо — приближение. WASD — ехать, J — автопилот.');
fs.writeFileSync('scripts/game.gd',s);
s=fs.readFileSync('scripts/van.gd','utf8');
s=s.replace('wheels.append(wheel)', 'wheels.append(wheel)\n\t\t\tvar rolling = Node3D.new()\n\t\t\twheel.add_child(rolling)');
s=s.replaceAll('cylinder(wheel,','cylinder(rolling,').replaceAll('box(wheel,','box(rolling,');
s=s.replace(/\tfor w in wheels:\n\t\tw.rotation.x \+= speed \* get_process_delta_time\(\) \/ 0.55\n/,'');
fs.writeFileSync('scripts/van.gd',s);
s=fs.readFileSync('scripts/interface.gd','utf8');
s=s.replace('Грунтовая дорога · 1 248 м','Грунт · 1 248 м');
s=s.replace('game.surface_name, 1240', 'game.surface_name, 1240');
s=s.replace('mode_label.text = "ЛАГЕРЬ', 'mode_label.text = "ЛАГЕРЬ');
s=s.replace('"МЕХАНИКА · 4×4")','"%d передача · %d об/мин" % [game.dynamics.gear, game.dynamics.rpm])');
s=s.replace('trip_label.text = "АЛТАЙ / " + regions[posmod(int(game.van.position.z / 900), 4)]','trip_label.text = regions[posmod(int(game.van.position.z / 900), 4)] + " / " + game.weather.current_name');
s=s.replace('WASD — ехать   ·   C — салон   ·   E — лагерь','ПКМ + мышь — обзор · Колесо — зум · WASD — ехать');
s=s.replace('P  фото  ·  F12 снимок  ·  Esc меню','P фото · K снимок · Esc меню');
fs.writeFileSync('scripts/interface.gd',s);
