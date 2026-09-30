extends RefCounted
## Device preferences are separate from expedition saves and never change physics.
const PRESETS = ["auto", "low", "balanced", "high"]
const TITLES = ["Авто", "Экономно", "Сбалансированно", "Красиво"]
var game: Node
var preset = "auto"
var shadows = true
var nature = true
var scale = 0.9
var current_scale = 0.9
var frame_clock = 0.0
var frame_count = 0
var settle_clock = 8.0
var shadow_clock = 0.0
var path = "user://graphics.cfg"
var last_shadow_center = -2147483648
var shadow_chunks: Dictionary = {}
var mobile_device = false

func load_preferences(test_mode: bool):
	mobile_device = OS.has_feature("web") and bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0 && matchMedia('(pointer: coarse)').matches", true))
	if mobile_device:
		shadows = false
		scale = 0.75
	path = "user://test_graphics.cfg" if test_mode else "user://graphics.cfg"
	var config = ConfigFile.new()
	if config.load(path) != OK:
		apply_web_recovery_profile()
		return
	preset = str(config.get_value("graphics", "preset", "auto"))
	if preset not in PRESETS: preset = "auto"
	shadows = bool(config.get_value("graphics", "shadows", preset != "low" and not mobile_device))
	nature = bool(config.get_value("graphics", "nature", true))
	var saved_scale = config.get_value("graphics", "scale", 0.9)
	scale = clampf(float(saved_scale), 0.6, 1.0) if (saved_scale is float or saved_scale is int) and is_finite(float(saved_scale)) else 0.9
	# Auto preferences from the heavier release must not burden phone startup.
	if mobile_device and preset == "auto":
		shadows = false
		scale = 0.75
	apply_web_recovery_profile()

func apply_web_recovery_profile():
	# A one-launch recovery option; never overwrite the stored quality preference.
	if OS.has_feature("web") and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('safe_mode') === '1'", true)):
		preset = "low"
		shadows = false
		scale = 0.65

func save_preferences():
	var config = ConfigFile.new()
	config.set_value("graphics", "preset", preset)
	config.set_value("graphics", "shadows", shadows)
	config.set_value("graphics", "nature", nature)
	config.set_value("graphics", "scale", scale)
	config.save(path)

func setup(owner_game: Node):
	game = owner_game
	apply()

func choose(value: String):
	if value not in PRESETS: return
	preset = value
	shadows = preset != "low" and not (preset == "auto" and mobile_device)
	nature = true
	scale = 0.75 if preset == "low" or (preset == "auto" and mobile_device) else 1.0 if preset == "high" else 0.9
	apply()
	save_preferences()

func set_shadows(on: bool):
	shadows = on
	apply()
	save_preferences()

func set_nature(on: bool):
	nature = on
	apply()
	save_preferences()

func set_scale(value: float):
	if preset == "auto": return
	scale = clampf(value, 0.6, 1.0)
	current_scale = scale
	game.get_viewport().scaling_3d_scale = current_scale
	publish_state()
	save_preferences()

func effect_budget() -> int:
	return 0 if not nature else 0 if preset == "low" else 2 if preset == "high" else 1

func apply():
	if not is_instance_valid(game): return
	current_scale = scale
	game.get_viewport().scaling_3d_scale = current_scale
	game.get_viewport().msaa_3d = Viewport.MSAA_2X if preset == "high" else Viewport.MSAA_DISABLED
	game.sun.shadow_enabled = shadows
	game.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if preset == "high" else DirectionalLight3D.SHADOW_ORTHOGONAL
	game.sun.directional_shadow_max_distance = 140.0 if preset == "high" else 75.0
	game.sun.directional_shadow_fade_start = 0.75
	RenderingServer.directional_shadow_atlas_set_size(2048 if preset == "high" else 1024, true)
	var budget = effect_budget()
	game.dust.amount = [12, 24, 40][budget]
	game.weather.rain.amount = [160, 320, 520][budget]
	game.effects.ripple_limit = [4, 8, 12][budget]
	for splash in game.effects.splashes: splash.amount = [10, 16, 24][budget]
	game.world.tree_material.set_shader_parameter("wind_strength", 1.0 if nature else 0.0)
	game.world.grass_material.set_shader_parameter("wind_strength", 1.0 if nature else 0.0)
	for mat in game.world.water_materials: mat.set_shader_parameter("effects_strength", 1.0 if nature else 0.0)
	game.world.terrain_material.set_shader_parameter("detail_strength", 0.65 if preset == "low" else 1.0)
	game.world.road_material.set_shader_parameter("detail_strength", 0.65 if preset == "low" else 1.0)
	settle_clock = 6.0
	frame_clock = 0.0
	frame_count = 0
	shadow_chunks.clear()
	update_foliage_shadows()
	publish_state()

func update_foliage_shadows():
	var center = int(floor(game.van.position.z / game.world.LENGTH))
	if center != last_shadow_center:
		last_shadow_center = center
		shadow_chunks.clear()
	for key in shadow_chunks.keys():
		if not game.world.chunks.has(key): shadow_chunks.erase(key)
	for index in game.world.chunks:
		var root = game.world.chunks[index]
		if not root.get_meta("ready", false) or shadow_chunks.has(index): continue
		# The nearest instanced tree belts supply life and depth in one extra draw.
		var casting = shadows and absi(index - center) <= (1 if preset == "high" else 0)
		for child in root.get_children():
			if child is MultiMeshInstance3D and child.multimesh.mesh == game.world.tree_mesh:
				child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casting else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shadow_chunks[index] = true

func tick(delta: float):
	shadow_clock += delta
	if shadow_clock >= 0.5:
		shadow_clock = 0.0
		update_foliage_shadows()
	if preset != "auto": return
	# Ignore loading spikes and menus containing additional character viewports.
	if game.world.building_chunk or (game.rpg_ui.overlay.visible) or game.paused:
		settle_clock = 3.0
		frame_clock = 0.0
		frame_count = 0
		return
	if settle_clock > 0.0:
		settle_clock -= delta
		return
	frame_clock += delta
	frame_count += 1
	if frame_clock < 3.0: return
	adapt_resolution(float(frame_count) / frame_clock)
	frame_clock = 0.0
	frame_count = 0

func adapt_resolution(fps: float):
	var next = current_scale
	if fps < 42.0: next = maxf(0.65, current_scale - 0.05)
	elif fps > 58.0: next = minf(1.0, current_scale + 0.025)
	if is_equal_approx(next, current_scale): return
	current_scale = next
	if is_instance_valid(game):
		game.get_viewport().scaling_3d_scale = current_scale
		publish_state()

func description() -> String:
	match preset:
		"low": return "Меньше частиц и мягкие детали. Для слабых устройств; природа и следы остаются живыми."
		"high": return "Полная чёткость, сглаживание, дальние тени и больше частиц. Для мощного устройства."
		"balanced": return "Тени рядом с машиной, движение леса, живая вода и выразительные эффекты."
	return "Быстрый старт на телефоне без тяжёлых теней. Чёткость подстраивается автоматически; погода, вода и движение природы сохраняются."

func status() -> String:
	return "%d FPS · чёткость %d%%" % [Engine.get_frames_per_second(), roundi(current_scale * 100)]

func publish_state():
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.bukhankaGraphicsState = " + JSON.stringify({"preset": preset, "shadows": shadows, "nature": nature, "scale": current_scale, "msaa": game.get_viewport().msaa_3d, "shadow_mode": game.sun.directional_shadow_mode}))
