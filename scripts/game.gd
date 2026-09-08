extends Node3D
const WorldScript = preload("res://scripts/world.gd")
const VanScript = preload("res://scripts/van.gd")
const UIScript = preload("res://scripts/interface.gd")
var model = preload("res://scripts/expedition_state.gd").new()
var resources = preload("res://scripts/resource_system.gd").new(model)
var projects = preload("res://scripts/project_manager.gd").new(model)
var crew_system = preload("res://scripts/crew_system.gd").new(model)
var camp_controller = preload("res://scripts/camp_controller.gd").new()
var auto_controller = preload("res://scripts/autopilot_controller.gd").new()
var lighting = preload("res://scripts/lighting_controller.gd").new()
var dialogues = preload("res://scripts/dialogue_director.gd").new()
var saves = preload("res://scripts/save_service.gd").new()
var rpg_ui: Control
var camp_location = Vector3.ZERO
var restore_camping = false
var shop_charge = 0.0
var logic_accumulator = 0.0
var packing_camp = false
var packing_clock = 0.0
var tutorial: Control
var tutorial_seen = false
var pending_sleep = false
var view_clock = 0.0
var dynamics = preload("res://scripts/vehicle_physics.gd").new()
var weather: Node3D
var orbit_yaw = -0.45
var orbit_pitch = 0.30
var orbit_distance = 13.0
var looking = false
var camera_anchor = Vector3.ZERO
var camera_idle = 0.0
var low_range = false
var bog_warning = 0.0
var discoveries: Array = []
var camp_people: Array[Node3D] = []
var camp_clock = 0.0
var journal_timer = 0.0
var effects: Node3D
var touch_controls: Control
var camp_level = 0
var connection_quality = 0.3
var connection_status = "Слабый сигнал"
var camp_shelter = Vector3.ZERO
var world: Node3D
var van: Node3D
var camera: Camera3D
var ui: Control
var environment: Environment
var sun: DirectionalLight3D
var camp: Node3D
var fire: OmniLight3D
var dust: CPUParticles3D
var engine_audio: AudioStreamPlayer
var rain_audio: AudioStreamPlayer
var wind_audio: AudioStreamPlayer
var music_audio: AudioStreamPlayer
var time = 0.0
var speed = 0.0
var heading = 0.0
var money = 3000.0
var distance = 0.0
var levels: Array = [0, 0, 0, 0]
var work_progress = 0.0
var job_index = 0
var jobs = ["Деплой с видом на горы", "Починить один маленький баг", "Ревью под шум реки", "Сверстать лендинг для кофейни", "Оптимизировать тяжёлый запрос", "Научить бота не падать"]
var signal_speed = 94
var surface_name = "Грунтовая дорога"
var started = false
var camping = false
var autopilot = false
var paused = false
var photo = false
var muted_audio = false
var camera_mode = 0
var dialogue_timer = 0.0
var dialogue_index = 0
var toast_timer = 0.0
var save_timer = 0.0
var chunk_timer = 0.0
var last_km = 0
var stuck_timer = 0.0
var test_mode = false
var chatter = [
	["МИША · BACKEND", "Если связь пропадёт — скажем, что ушли в горы. Хотя мы и правда ушли в горы."],
	["СОНЯ · FRONTEND", "Посмотрите направо. Вот такой градиент я вчера два часа подбирала в CSS."],
	["ЛЁША · DEVOPS", "Starlink поднялся. Прод — тоже. Можно наконец поставить чайник."],
	["ДАНЯ · GAMEDEV", "Нам бы сохранить этот вид. Хотя лучше просто остановиться и посмотреть."],
	["МИША · BACKEND", "У нас четыре программиста и одна машина. Почему механика всё ещё никто не выучил?"],
	["СОНЯ · FRONTEND", "Потому что у машины нет stack trace. Только вот этот тревожный стук."],
	["ЛЁША · DEVOPS", "Это не стук. Это распределённая система подвески."],
	["ДАНЯ · GAMEDEV", "Предлагаю считать каждый мост чекпоинтом. А чай — автосохранением."],
	["СОНЯ · FRONTEND", "Когда поставим кухню, я сделаю сырники. Этот таск у меня уже в работе."],
	["МИША · BACKEND", "Сырники в прод без тестирования не пропущу. Мне две порции."],
	["ЛЁША · DEVOPS", "Пинг сорок. До ближайшего магазина — сто километров. Приоритеты расставлены."],
	["ДАНЯ · GAMEDEV", "Какой следующий пункт маршрута? Ещё одна гора. Отличный план."],
	["МИША · BACKEND", "У реки слышно, как голова перестаёт компилировать рабочие задачи."],
	["СОНЯ · FRONTEND", "Давайте сегодня никуда не успевать. Просто ехать, пока красиво."],
	["ЛЁША · DEVOPS", "Солнечная панель — это когда инфраструктуру оплачивает звезда."],
	["ДАНЯ · GAMEDEV", "Если сделать из буханки дом, у нас будет бесконечный отпуск с ежедневным стендапом."],
	["МИША · BACKEND", "Я закрыл баг. И ноутбук. Второе далось сложнее."],
	["СОНЯ · FRONTEND", "Вот увидите: через год будем вспоминать не дедлайны, а этот поворот."],
	["ЛЁША · DEVOPS", "Бэкап сделал. Термос наполнил. Поехали выше облаков."],
	["ДАНЯ · GAMEDEV", "Самое дорогое улучшение тут уже есть. Хорошая компания."]
]

func _ready():
	test_mode = "--test-mode" in OS.get_cmdline_user_args()
	saves.backup_legacy(test_mode)
	var fresh = get_tree().root.get_meta("fresh_expedition", false)
	get_tree().root.remove_meta("fresh_expedition")
	if not test_mode and not fresh:
		var initial = saves.read_data(false)
		if not initial.is_empty(): model.decode(initial.model)
	world = WorldScript.new()
	world.seed_value = model.seed_value
	add_child(world)
	setup_environment()
	weather = preload("res://scripts/weather.gd").new()
	add_child(weather)
	van = VanScript.new()
	add_child(van)
	van.position = Vector3(world.road_x(120), world.drive_height(world.road_x(120), 120) + 0.2, 120)
	heading = atan2(world.road_x(123) - world.road_x(120), 3)
	if not test_mode and not fresh: load_game()
	van.rotation.y = heading
	van.update_upgrades(levels)
	van.update_solar(model)
	world.update_chunks(van.position.z, true)
	time = model.simulation_seconds
	camera = Camera3D.new()
	camera.fov = 65
	camera.far = 1600
	camera.near = 0.08
	add_child(camera)
	camera.make_current()
	if "--standalone-test" in OS.get_cmdline_user_args():
		DisplayServer.window_set_title("Буханка • Проверка сборки")
	camera.position = van.position + Vector3(-8, 5, -12)
	camera_anchor = van.position
	orbit_yaw = heading - 0.45
	setup_dust()
	setup_audio()
	lighting.setup(self)
	dialogues.setup(self)
	van.rebuild_crew(model)
	var layer = CanvasLayer.new()
	add_child(layer)
	ui = UIScript.new()
	ui.game = self
	layer.add_child(ui)
	rpg_ui = preload("res://scripts/expedition_ui.gd").new()
	rpg_ui.game = self
	layer.add_child(rpg_ui)
	effects = preload("res://scripts/surface_effects.gd").new()
	effects.game = self
	add_child(effects)
	touch_controls = preload("res://scripts/touch_controls.gd").new()
	touch_controls.game = self
	layer.add_child(touch_controls)
	tutorial = preload("res://scripts/tutorial.gd").new()
	tutorial.game = self
	layer.add_child(tutorial)
	projects.on_calendar(self)
	weather.update_weather(self, 0.0)
	next_dialogue()
	ui.update_view()
	get_tree().auto_accept_quit = false

func setup_environment():
	var we = WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("416e82")
	sky_mat.sky_horizon_color = Color("cad9cc")
	sky_mat.ground_bottom_color = Color("485c53")
	sky_mat.ground_horizon_color = Color("c6d4c4")
	sky_mat.sky_curve = 0.18
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c4d5dd")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("adc6bb")
	environment.fog_density = 0.0007
	we.environment = environment
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-31, -37, 0)
	sun.light_color = Color("ffdfac")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 170
	add_child(sun)

func setup_dust():
	dust = CPUParticles3D.new()
	dust.amount = 36
	dust.lifetime = 1.6
	dust.emitting = false
	dust.local_coords = false
	dust.direction = Vector3(0, 0.3, -1)
	dust.spread = 30
	dust.initial_velocity_min = 0.4
	dust.initial_velocity_max = 1.4
	dust.gravity = Vector3(0, 0.25, 0)
	dust.scale_amount_min = 0.13
	dust.scale_amount_max = 0.5
	var mesh = SphereMesh.new()
	mesh.radial_segments = 5
	mesh.rings = 2
	dust.mesh = mesh
	var dust_mat = ShaderMaterial.new()
	dust_mat.shader = load("res://shaders/dust.gdshader")
	dust.material_override = dust_mat
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)

func make_audio(kind: int) -> AudioStreamWAV:
	var rate = 22050
	var duration = 2 if kind == 0 else 12
	var bytes = PackedByteArray()
	bytes.resize(rate * duration * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 84 + kind
	var smooth_noise = 0.0
	var notes = [146.832, 174.614, 220.0, 261.626, 220.0, 174.614, 130.813, 164.814]
	for i in range(rate * duration):
		var t = float(i) / rate
		var sample = 0.0
		if kind == 0:
			sample = sin(TAU * 44 * t) * 0.32 + sin(TAU * 88 * t) * 0.19 + sin(TAU * 132 * t) * 0.13 + sin(TAU * 220 * t) * 0.09 + rng.randf_range(-0.04, 0.04)
			sample *= 0.8 + 0.2 * sin(TAU * 11 * t)
		elif kind == 1:
			smooth_noise = lerpf(smooth_noise, rng.randf_range(-1, 1), 0.035)
			sample = smooth_noise * 0.7 + sin(t * TAU * 1200 + sin(t * 7) * 20) * pow(maxf(0, sin(t * TAU / 3)), 24) * 0.025
		else:
			var chord = [110.0, 130.813, 98.0, 146.832][int(t / 3) % 4]
			for string_index in range(4):
				var beat = fmod(t, 3.0) - string_index * 0.13
				if beat < 0: continue
				var note = chord * [1.0, 1.5, 2.0, 2.3784][string_index]
				for harmonic in range(1, 7):
					sample += sin(TAU * note * harmonic * beat) / harmonic * exp(-beat * (1.1 + harmonic * 0.4)) * minf(beat * 180, 1) * 0.075

		var envelope = minf(1.0, minf(t * 20, (duration - t) * 20)) if kind != 0 else 1.0
		bytes.encode_s16(i * 2, int(clampf(sample * envelope, -1, 1) * 32767))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = rate * duration
	return wav

func setup_audio():
	engine_audio = AudioStreamPlayer.new()
	engine_audio.stream = make_audio(0)
	engine_audio.volume_db = -19
	add_child(engine_audio)
	engine_audio.play()
	wind_audio = AudioStreamPlayer.new()
	wind_audio.stream = make_audio(1)
	wind_audio.volume_db = -20
	add_child(wind_audio)
	wind_audio.play()
	music_audio = AudioStreamPlayer.new()
	music_audio.stream = make_audio(2)
	music_audio.volume_db = -25
	add_child(music_audio)
	music_audio.play()
	rain_audio = AudioStreamPlayer.new()
	rain_audio.stream = wind_audio.stream
	rain_audio.volume_db = -60
	add_child(rain_audio)
	rain_audio.play()

func _physics_process(delta):
	if not simulation_running(): return
	var was_night = model.is_night()
	model.simulation_seconds += delta
	time = model.simulation_seconds
	weather.update_weather(self, delta)
	if camping:
		speed = 0
	else:
		drive(delta)
	update_connection()
	resources.tick(self, delta)
	if shop_charge > 0 and camping:
		var amount = minf(delta, shop_charge)
		model.energy = minf(model.capacity(), model.energy + amount)
		shop_charge -= amount
	logic_accumulator += delta
	if logic_accumulator >= 0.1:
		var dt = logic_accumulator
		logic_accumulator = 0
		crew_system.tick(self, dt)
		update_packing(dt)
		if pending_sleep and crew_system.all_home():
			pending_sleep = false
			rpg_ui.sleep()
		projects.tick(self, dt)
		auto_controller.tick(self, dt)
		dialogues.tick(self, dt)
	if was_night != model.is_night():
		model.prune_resources()
		projects.on_calendar(self)
	if not projects.active.is_empty():
		work_progress = float(projects.active.progress) / maxf(1, projects.active.effort)
	else: work_progress = 0
	save_timer += delta
	if save_timer > 20:
		save_timer = 0
		save_game()
	journal_timer += delta
	if journal_timer > 2:
		journal_timer = 0
		check_discoveries()
	if camping and is_instance_valid(fire):
		fire.light_energy = 1.8 + sin(time * 2.3) * 0.12

func simulation_running() -> bool:
	if is_instance_valid(tutorial) and tutorial.visible: return false
	return started and not paused and not ui.garage.visible and not photo and not (is_instance_valid(rpg_ui) and rpg_ui.overlay.visible and rpg_ui.freezes)

func drive(delta: float):
	var throttle = float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	var steer = float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
	var brake = Input.is_physical_key_pressed(KEY_SPACE)
	if is_instance_valid(touch_controls):
		throttle = clampf(throttle + touch_controls.throttle, -1, 1)
		steer = clampf(steer + touch_controls.steer, -1, 1)
		brake = brake or touch_controls.braking
	if throttle != 0 or steer != 0 or brake:
		autopilot = false
		auto_controller.target_z = -INF
		model.cinematic = false
	if autopilot:
		var route = auto_controller.route
		var target_z = van.position.z + 8 + abs(speed) * 0.8
		var desired = atan2(world.route_x(target_z, route) - van.position.x, target_z - van.position.z)
		steer = clampf(wrapf(desired - heading, -PI, PI) * 3.4, -1, 1)
		var desired_speed = 3.0 if world.mud_at(van.position.x, van.position.z) else (5.0 if world.ford_amount(van.position.z) > 0.2 else 6.875)
		low_range = world.mud_at(van.position.x, van.position.z) or world.ford_amount(van.position.z) > 0.2
		throttle = clampf((desired_speed - speed) * 0.8, -0.5, 1)
	if model.energy <= 0: throttle = 0
	if model.percent() < 5 and absf(speed) > 3.5: throttle = 0
	dynamics.step(self, throttle, steer, brake, delta)
	if abs(speed) < 0.4 and throttle > 0.5 and world.mud_at(van.position.x, van.position.z):
		bog_warning += delta
		if bog_warning > 5:
			toast("Увязли. L — пониженная, F — лебёдка. Грязевые шины помогут на подъёме.")
			bog_warning = 0
	else: bog_warning = 0
	var km = int(distance / 1000)
	if km > last_km:
		last_km = km
		model.add_journal("Проехали %d км" % km)
func _process(delta):
	if not is_instance_valid(ui): return
	chunk_timer += delta
	if chunk_timer > 0.18:
		world.update_chunks(van.position.z)
		chunk_timer = 0
	van.animate(speed, time)
	update_camera(delta)
	dust.position = van.position + Vector3(0, 0.4, -1.4).rotated(Vector3.UP, heading)
	dust.emitting = abs(speed) > 3 and not camping and simulation_running() and weather.wetness < 0.4
	engine_audio.pitch_scale = clampf(dynamics.rpm / 1100.0, 0.7, 2.8)
	rain_audio.volume_db = -60 + weather.intensity * 46
	music_audio.volume_db = lerpf(music_audio.volume_db, (-25.0 if dialogues.voice.playing else -14.0 if crew_system.guitar_active() else -24.0) if camping else -45.0, minf(1, delta * 1.5))
	engine_audio.volume_db = -55 if camping or not started or paused else -13.0 + dynamics.throttle_load * 4.0
	if is_instance_valid(effects): effects.update_surface(delta if simulation_running() else 0)
	if simulation_running(): world.animate_wildlife(van.position, time, delta)
	toast_timer = maxf(0, toast_timer - delta)
	ui.toast_label.visible = toast_timer > 0
	view_clock += delta
	if view_clock > 0.1:
		view_clock = 0
		ui.update_view()
	lighting.update(self, delta)

func update_camera(delta: float):
	var target: Vector3
	var look: Vector3
	if started and camping and model.cinematic and not photo:
		var pose = camp_camera_pose()
		target = camera.position.lerp(pose.target, 1.0 - exp(-delta * 1.4))
		camera.position = world.safe_camera(van.position + Vector3.UP * 1.8, target)
		var facing = -camera.global_basis.z
		var desired = (pose.look - camera.position).normalized()
		camera.look_at(camera.position + facing.slerp(desired, 1.0 - exp(-delta * 1.4)))
		camera.fov = lerpf(camera.fov, pose.fov, minf(1, delta * 1.4))
		return
	if started and autopilot and model.cinematic:
		camera_anchor = camera_anchor.lerp(van.position, 1.0 - exp(-delta * 3))
		var pose = auto_controller.camera_pose(self, delta if simulation_running() else 0)
		target = camera.position.lerp(pose.target, 1.0 - exp(-delta * 2))
		target = world.safe_camera(pose.look, target)
		camera.position = target
		camera.look_at(pose.look)
		camera.fov = lerpf(camera.fov, pose.fov, minf(1, delta * 2))
		return
	if not started:
		var a = sin(time * 0.085) * 0.35 - 0.75
		target = van.position + Vector3(sin(a) * 11, 4.8, -cos(a) * 11)
		look = van.position + Vector3(0, 1.7, 1)
	elif camera_mode == 2 and not camping and not photo:
		target = van.to_global(Vector3(0, 2.32, -1.88))
		look = target + Vector3(sin(orbit_yaw), -sin(orbit_pitch - 0.2), cos(orbit_yaw)).rotated(Vector3.UP, heading) * 5
	else:
		camera_anchor.x = lerpf(camera_anchor.x, van.position.x, 1.0 - exp(-delta * 7))
		camera_anchor.z = lerpf(camera_anchor.z, van.position.z, 1.0 - exp(-delta * 7))
		var height_delta = van.position.y - camera_anchor.y
		if abs(height_delta) > 0.20:
			camera_anchor.y = lerpf(camera_anchor.y, van.position.y - signf(height_delta) * 0.20, 1.0 - exp(-delta * (4.5 if abs(height_delta) > 1.2 else 1.5)))
		camera_idle += delta
		if camera_idle > 4.0 and abs(speed) > 2.0 and not camping and not photo:
			var motion_yaw = atan2(dynamics.velocity.x, dynamics.velocity.z)
			orbit_yaw = lerp_angle(orbit_yaw, motion_yaw, 1.0 - exp(-delta * 0.30))
		look = camera_anchor + (camp.get_meta("focus", Vector3(0, 1.6, 0)) if camping and is_instance_valid(camp) else Vector3(0, 1.6, 0))
		var dist = orbit_distance * (1.6 if camera_mode == 1 else 1.0)
		var a = orbit_yaw
		target = look + Vector3(sin(a) * cos(orbit_pitch), sin(orbit_pitch), -cos(a) * cos(orbit_pitch)) * dist
	if started and (camera_mode != 2 or camping or photo):
		target = world.safe_camera(look, target)
	camera.position = camera.position.lerp(target, 1.0 if camera_mode == 2 and not camping and not photo else 1.0 - exp(-delta * 9))
	if started and (camera_mode != 2 or camping or photo) and world.camera_blocked(camera.position): camera.position = target
	camera.look_at(look)
	camera.fov = lerpf(camera.fov, 65.0 + minf(abs(speed) * 0.32, 9), delta * 2)

func camp_camera_pose() -> Dictionary:
	var phase = model.simulation_seconds
	var angle = phase * 0.018
	var focus = camp_location + Vector3.UP * 1.5
	var target = focus + Vector3(sin(angle) * 13, 5.0, cos(angle) * 13)
	var fov = 55.0
	if model.is_night() and posmod(int(phase / 18.0), 3) == 1:
		var moon = Vector3(-0.4, 0.48, 0.65).normalized()
		target = van.position - Vector3(moon.x, 0, moon.z).normalized() * 8.0 + Vector3.UP * 1.3
		target.y = maxf(target.y, world.drive_height(target.x, target.z) + 1.3)
		focus = target + Vector3(moon.x, moon.y * 0.62, moon.z).normalized() * 30.0
		fov = 72.0
	return {"target": target, "look": focus, "fov": fov}

func _input(event):
	if is_instance_valid(tutorial) and tutorial.visible: return
	if not started or paused or ui.garage.visible or (is_instance_valid(rpg_ui) and rpg_ui.overlay.visible): return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: looking = false
		if event.button_index == MOUSE_BUTTON_RIGHT:
			looking = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if looking else Input.MOUSE_MODE_VISIBLE
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbit_distance = clampf(orbit_distance - 1.2, 5, 35)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit_distance = clampf(orbit_distance + 1.2, 5, 35)
	if event is InputEventMouseMotion and looking:
		camera_idle = 0
		model.cinematic = false
		orbit_yaw -= event.relative.x * 0.004
		orbit_pitch = clampf(orbit_pitch + event.relative.y * 0.003, -0.25 if camera_mode == 2 else 0.05, 1.25)

func release_mouse():
	looking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_key_input(event):
	if not event is InputEventKey or not event.pressed or event.echo: return
	if is_instance_valid(tutorial) and tutorial.visible:
		if event.physical_keycode == KEY_ESCAPE: tutorial.finish()
		return
	if is_instance_valid(rpg_ui) and rpg_ui.overlay.visible:
		if event.physical_keycode == KEY_ESCAPE: rpg_ui.close_panel()
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			if photo:
				toggle_photo()
			elif ui.garage.visible:
				toggle_garage()
			elif started:
				toggle_pause()
		KEY_ENTER:
			if not started: start_trip()
		KEY_L:
			set_low_range(not low_range)
		KEY_F:
			if started and not camping: winch()
		KEY_C:
			if started and not paused: cycle_camera()
		KEY_E:
			if started and not paused:
				if camping: toggle_camp()
				else: rpg_ui.open_panel("placement")
		KEY_J:
			if started and not paused: toggle_auto()
		KEY_U:
			if started and not paused: toggle_garage()
		KEY_R:
			if started and not paused and not camping: recover()
		KEY_T:
			if started: next_dialogue()
		KEY_P:
			if started and not paused: rpg_ui.open_panel("projects")
		KEY_B:
			if started and not paused: rpg_ui.open_panel("camp")
		KEY_O:
			if started and not paused: toggle_photo()
		KEY_K:
			if started: rpg_ui.toggle_cinema()
		KEY_F12:
			if started: save_photo()
		KEY_F11:
			var full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func start_trip():
	if not model.configured and not test_mode:
		rpg_ui.open_panel("editor")
		return
	started = true
	if restore_camping:
		restore_camping = false
		toggle_camp()
	paused = false
	ui.menu.hide()
	ui.pause_panel.hide()
	toast("Джойстик — газ и руль. Проведите по миру для обзора. Для телефона удобнее альбомный режим." if is_instance_valid(touch_controls) and touch_controls.enabled else "ПКМ + мышь — обзор. Колесо — приближение. WASD — ехать, J — автопилот.")
	if not tutorial_seen and not test_mode: tutorial.open()

func show_title():
	save_game()
	started = false
	paused = false
	ui.pause_panel.hide()
	ui.menu.show()

func toggle_pause():
	release_mouse()
	paused = not paused
	ui.pause_panel.visible = paused
	if paused: save_game()

func cycle_camera():
	camera_mode = (camera_mode + 1) % 3
	orbit_yaw = 0.0 if camera_mode == 2 else heading - 0.45
	orbit_pitch = 0.2 if camera_mode == 2 else 0.30
	toast(["Камера: за буханкой", "Камера: панорама", "Камера: в салоне · четверо своих"][camera_mode])

func toggle_auto():
	if not started: return
	autopilot = not autopilot
	auto_controller.target_z = -INF
	auto_controller.camp_clock = 0
	auto_controller.route = world.nearest_route(van.position.x, van.position.z)
	if not autopilot: model.cinematic = false
	toast("Миша ведёт экспедицию: остановки, зарядка и ночлег." if autopilot else "Вы за рулём.")

func toggle_garage():
	if not started: return
	rpg_ui.open_panel("upgrades")

func upgrade_cost(i: int) -> int:
	return [[3000, 5000, 8000], [3000, 5000, 8000], [3000, 4500, 7000], [2500, 4500, 7000]][i][mini(levels[i], 2)]

func buy_upgrade(i: int):
	if i < 0 or i > 3 or levels[i] >= 3: return
	var cost = upgrade_cost(i)
	if money < cost: return
	money -= cost
	levels[i] += 1
	van.update_upgrades(levels)
	van.update_solar(model)
	toast("Установлено: %s, уровень %d" % [["вездеход", "дом на колёсах", "энергия и связь", "экспедиция"][i], levels[i]])
	save_game()

func job_reward() -> int:
	return int(projects.active.get("reward", 0))

func update_connection():
	var moving = abs(speed) > 1 and not camping
	var rain_loss = weather.intensity * maxf(0.15, 0.65 - levels[2] * 0.17)
	var outage = not world.director.tunnel_at(van.position).is_empty()
	var base = (8.0 + levels[2] * 28) * (0.78 + sin(time * 0.13) * 0.15)
	signal_speed = maxi(1, int(base * (0.55 if moving else 1.0) * (1 - rain_loss)))
	if outage: signal_speed = 0
	connection_quality = clampf(float(signal_speed) / (signal_speed + 14.0), 0, 1)
	connection_status = "Нет связи · ждём окно" if outage else "Слабый сигнал" if signal_speed < 10 else "Связь стабильна"

func set_low_range(enabled: bool):
	if not started or paused: return
	if autopilot: toggle_auto()
	low_range = enabled
	toast("4L · пониженная, больше тяги" if low_range else "4H · обычный диапазон")

func work_rate() -> float:
	if not resources.can_work() or signal_speed <= 0: return 0.0
	if camping and crew_system.work_exposed(self): return 0.0
	var moving = abs(speed) > 0.3 and not camping
	var location = 0.30 if moving else 1.10 + camp_level * 0.025 if camping else 1.0
	var comfort = 1.0 + levels[1] * 0.04
	if camping: comfort *= 1.0 + float(camp_controller.quality.get("work_bonus", 0))
	var connection = 0.60 + 0.40 * connection_quality
	return crew_system.work_sum(self) * location * comfort * connection * model.supplies_factor()

func camp_upgrade_cost() -> int:
	return [2500, 4500, 7000][mini(camp_level, 2)]

func buy_camp_upgrade():
	if camp_level >= 3 or money < camp_upgrade_cost(): return
	money -= camp_upgrade_cost()
	camp_level += 1
	if camping:
		crew_system.return_all(self)
		camp.queue_free()
		build_camp()
	toast(["", "Рабочий навес, лавочки, палатки и туалет", "Кухня и защита от холода", "Утеплённый лагерь и тёплые фонари"][camp_level])
	save_game()

func recover():
	dynamics.reset()
	speed = 0
	autopilot = false
	var route = world.nearest_route(van.position.x, van.position.z)
	van.position.x = world.route_x(van.position.z, route)
	van.position.y = world.drive_height(van.position.x, van.position.z) + 0.3
	heading = atan2(world.route_x(van.position.z + 3, route) - van.position.x, 3)
	van.rotation = Vector3(0, heading, 0)
	toast("Друзья помогли выбраться. Снова на дороге!")

func toggle_camp():
	if not started or ui.garage.visible or photo: return
	if not camping:
		if world.sample_water(van.position).depth > 0.10:
			toast("Сначала выберитесь на сухой берег.")
			return
		var site = camp_controller.find_site(self, van.position)
		if not camp_controller.selected.is_empty():
			site = camp_controller.evaluate(self, camp_controller.selected.position, camp_controller.rotation)
			camp_controller.selected = {}
			if not site.valid:
				toast("Площадка не подходит: переместите или поверните лагерь.")
				return
		if site.is_empty():
			toast("Здесь тесно или слишком крутой склон. Найдите сухую площадку рядом с дорогой.")
			return
		camp_location = site.position
		camp_controller.quality = camp_controller.evaluate(self, camp_location, camp_controller.rotation)
		dynamics.reset()
		speed = 0
		camping = true
		orbit_pitch = 0.45
		orbit_distance = 20
		for friend in van.people: friend.visible = false
		build_camp()
		rpg_ui.close_panel()
		record_discovery("Стоянка", int(van.position.z / 500), 0)
		toast("Панели разложены. B — лагерь, P — проекты. Друзья займутся работой и припасами.")
	else:
		if not packing_camp:
			packing_camp = true
			packing_clock = 0.0
			for person in camp_people: person.set_meta("boarding_from", person.global_position)
			for i in range(4): crew_system.start_return(self, i)
			rpg_ui.close_panel()
			toast("Собираем лагерь · все в машину! Выезжаем через 2 секунды.")
			return
		if packing_clock < 1.5: return
		packing_camp = false
		crew_system.return_all(self)
		camping = false
		shop_charge = 0
		if is_instance_valid(camp): camp.queue_free()
		camp_people.clear()
		for friend in van.people: friend.visible = true
		orbit_pitch = 0.30
		orbit_distance = 13
		toast("Лагерь собран. За следующим поворотом — новый вид.")
	save_game()

func update_packing(dt: float):
	if not packing_camp: return
	packing_clock += dt
	if packing_clock >= 1.5:
		crew_system.return_all(self)
		toggle_camp()

func camp_site() -> Vector3:
	var best = Vector3(0, 0, 7)
	var score = INF
	for i in range(24):
		var a = i * TAU / 24
		var p = Vector3(sin(a) * 6.5, 0, cos(a) * 6.5)
		var h = world.drive_height(van.position.x + p.x, van.position.z + p.z)
		var variation = abs(h - van.position.y) * 0.5
		for j in range(8):
			var q = van.position + p + Vector3(sin(j * TAU / 8) * 2.6, 0, cos(j * TAU / 8) * 2.6)
			variation += abs(world.drive_height(q.x, q.z) - h)
			if world.camera_blocked(Vector3(q.x, h + 1.8, q.z)): variation += 10
		if variation < score:
			score = variation
			best = p
	best.y = world.drive_height(van.position.x + best.x, van.position.z + best.z) - van.position.y + 0.25
	return best

func build_camp():
	camp_controller.build(self)

func next_dialogue():
	dialogues.speak(self)

func toast(message: String):
	ui.toast_label.text = message
	toast_timer = 6

func toggle_photo():
	if ui.garage.visible: return
	photo = not photo
	ui.hud.visible = not photo
	if not photo: toast("Фоторежим закрыт. Снова в путь.")

func toggle_sound():
	muted_audio = not muted_audio
	AudioServer.set_bus_mute(0, muted_audio)
	ui.muted_button.text = "Звук: выключен" if muted_audio else "Звук: включён"

func save_path() -> String:
	return saves.path(test_mode)

func save_game():
	if not saves.save(self) and is_instance_valid(ui):
		toast(saves.last_error)

func load_game():
	saves.restore(self)

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and started and not paused:
		toggle_pause()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

func save_photo():
	var was_visible = ui.hud.visible
	ui.hud.hide()
	await RenderingServer.frame_post_draw
	var picture = get_viewport().get_texture().get_image()
	var folder = "user://photos"
	DirAccess.make_dir_recursive_absolute(folder)
	var filename = folder + "/Altai-" + Time.get_datetime_string_from_system().replace(":", "-") + ".png"
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(picture.save_png_to_buffer(), "Altai.png", "image/png")
		ui.hud.visible = was_visible
		return
	var result = picture.save_png(filename)
	ui.hud.visible = was_visible
	if result == OK:
		toast("Фото сохранено: " + ProjectSettings.globalize_path(filename))


func _exit_tree():
	for player in [engine_audio, wind_audio, music_audio, rain_audio]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func winch():
	if model.energy < 0.35:
		toast("Лебёдке нужен заряд. Разбейте лагерь.")
		return
	if abs(speed) > 2:
		toast("Для лебёдки сначала остановитесь.")
		return
	var route = world.nearest_route(van.position.x, van.position.z)
	var dest = van.position.z + 9
	van.position = Vector3(world.route_x(dest, route), world.drive_height(world.route_x(dest, route), dest) + 0.25, dest)
	dynamics.reset()
	speed = 0
	model.energy = maxf(0, model.energy - 0.35)
	toast("Друзья закрепили трос. Девять метров ближе к сухой земле.")

func record_discovery(kind: String, sector: int, _reward: int):
	var id = "%s:%d" % [kind, sector]
	if discoveries.has(id): return
	discoveries.append(id)
	model.add_journal("Открытие: " + kind)
	toast("%s · новое воспоминание" % kind)

func check_discoveries():
	if not model.destination.is_empty():
		var target = model.destination
		if Vector2(target.x - van.position.x, target.z - van.position.z).length() < 60:
			model.add_journal("Добрались до цели: " + str(target.title))
			toast("Цель маршрута достигнута: " + str(target.title))
			model.destination = {}
			save_game()
	for item in world.director.near_z(van.position.z):
		if Vector2(item.x - van.position.x, item.z - van.position.z).length() > 90: continue
		if item.kind in ["lake", "waterfall", "village", "animals", "tunnel"]:
			if item.kind == "animals": continue
			record_discovery({"lake": "Горное озеро", "waterfall": "Водопад", "village": "Деревня", "animals": "Животные", "tunnel": "Горный тоннель"}[item.kind], item.owner, 0)
	for animal in world.wildlife:
		if is_instance_valid(animal) and animal.global_position.distance_to(van.position) < 45:
			record_discovery(animal.get_meta("species", "Животные"), int(floor(animal.get_meta("home").z / 144.0)), 0)

func animate_camp(delta: float):
	crew_system.tick(self, delta)

func exit_game():
	save_game()
	if OS.has_feature("web"):
		if camping: toggle_camp()
		started = false
		paused = false
		release_mouse()
		ui.pause_panel.hide()
		ui.hud.hide()
		ui.menu.show()
	else:
		get_tree().quit()

func _unhandled_input(event):
	if is_instance_valid(rpg_ui) and rpg_ui.overlay.visible: return
	if started and not paused and not ui.garage.visible and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			looking = true
			camera_idle = 0

func rpg_upgrade_cost(key: String) -> int:
	var prices = {"battery": [4000, 6500, 10000], "roof": [3000, 4500, 7000], "panels": [2000, 3500, 5500], "kitchen": [1800, 3000, 4500], "storage": [1800, 3000, 4500], "fishing": [1500, 2500, 4000]}
	return prices[key][mini(model.upgrades[key], 2)]

func buy_rpg_upgrade(key: String):
	if not model.upgrades.has(key) or model.upgrades[key] >= 3 or money < rpg_upgrade_cost(key): return
	money -= rpg_upgrade_cost(key)
	model.upgrades[key] += 1
	van.update_solar(model)
	if camping:
		crew_system.return_all(self)
		camp.queue_free()
		build_camp()
	save_game()

func shop_purchase(key: String, cost: int, amount: float):
	if not camping or not world.near_village(van.position):
		toast("Магазин доступен на стоянке рядом с деревней.")
		return
	var catalog = {"food": [400, 8.0], "water": [160, 8.0], "energy": [300, 60.0]}
	if not catalog.has(key): return
	cost = catalog[key][0]
	amount = catalog[key][1]
	if money < cost:
		toast("Не хватает денег: нужно %d ₽." % cost)
		return
	if key == "energy":
		if shop_charge > 0 or model.energy >= model.capacity(): return
		shop_charge = minf(amount, model.capacity() - model.energy)
	elif key == "food":
		if model.food >= model.stock_capacity(): return
		amount = minf(amount, model.stock_capacity() - model.food)
		model.food = minf(model.stock_capacity(), model.food + amount)
	elif key == "water":
		if model.water >= model.stock_capacity(): return
		amount = minf(amount, model.stock_capacity() - model.water)
		model.water = minf(model.stock_capacity(), model.water + amount)
	money -= cost
	toast("Зарядка оплачена. Не сворачивайте лагерь до завершения." if key == "energy" else "Купили %s: +%.0f ед." % ["еду" if key == "food" else "воду", amount])
	save_game()

func new_expedition():
	save_game()
	var filename = save_path()
	if FileAccess.file_exists(filename):
		var backup = filename + ".archive_" + str(int(Time.get_unix_time_from_system()))
		if DirAccess.copy_absolute(filename, backup) != OK:
			toast("Не удалось сделать резервную копию. Новая игра не начата.")
			return
	get_tree().root.set_meta("fresh_expedition", true)
	get_tree().reload_current_scene()
