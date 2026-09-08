extends RefCounted
var sky_material: ShaderMaterial
var sky_clock = 0.0
var headlights: Array[SpotLight3D] = []

func setup(game: Node):
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/expedition_sky.gdshader")
	game.environment.sky.sky_material = sky_material
	game.environment.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	game.environment.sky.radiance_size = Sky.RADIANCE_SIZE_64
	game.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	game.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	game.environment.tonemap_exposure = 0.85
	game.environment.tonemap_white = 6.0
	game.environment.ssao_enabled = true
	game.environment.ssao_radius = 1.1
	game.environment.ssao_intensity = 0.85
	game.environment.glow_enabled = true
	game.environment.glow_intensity = 0.16
	game.environment.glow_bloom = 0.0
	game.environment.glow_hdr_threshold = 1.4
	game.environment.adjustment_enabled = true
	game.environment.adjustment_brightness = 1.0
	game.environment.adjustment_contrast = 1.06
	game.environment.adjustment_saturation = 1.08
	game.environment.fog_light_energy = 0.65
	game.environment.fog_sun_scatter = 0.08
	for x in [-0.74, 0.74]:
		var light = SpotLight3D.new()
		game.van.add_child(light)
		light.position = Vector3(x, 1.55, 2.4)
		light.rotation.y = PI
		light.rotation.x = -0.08
		light.spot_range = 38
		light.spot_angle = 28
		light.light_color = Color("ffe4b3")
		light.light_energy = 2.0
		light.shadow_enabled = false
		headlights.append(light)
	update(game, 1.0)

# Smooth astronomical weights; gameplay still retains exactly 70/30 day/night.
func sky_weights(phase: float) -> Vector3:
	var angle = phase / 0.7 * PI if phase < 0.7 else PI + (phase - 0.7) / 0.3 * PI
	var altitude = sin(angle)
	var darkness = 1.0 - smoothstep(-0.20, 0.16, altitude)
	return Vector3(altitude, darkness, 1.0 - smoothstep(0.02, 0.55, absf(altitude)))

func update(game: Node, dt: float):
	var model = game.model
	var weights = sky_weights(model.phase())
	var altitude = weights.x
	var night = weights.y
	var twilight = weights.z * (1.0 - night * 0.65)
	var weather = game.weather
	var phase = model.phase()
	# Keep long readable shadows while preserving the continuous solar cycle.
	game.sun.rotation_degrees = Vector3(-rad_to_deg(asin(clampf(altitude * 0.72, -1, 1))), -37 + 140 * smoothstep(0.20, 0.50, phase), 0)
	game.sun.light_energy = pow(maxf(0, altitude), 0.65) * 0.85 * (1.0 - weather.cloud * 0.65)
	game.sun.light_color = Color("ffdda9").lerp(Color("ff995e"), twilight)
	game.environment.ambient_light_color = Color("93adc9").lerp(Color("7186a4"), night)
	game.environment.ambient_light_energy = lerpf(0.22 + maxf(0, altitude) * 0.08, 0.16, night)
	var fog = Color("b6cbd0").lerp(Color("df9980"), twilight * 0.65).lerp(Color("24364c"), night)
	game.environment.fog_light_color = fog.lerp(Color("98a9af").lerp(Color("647582"), night), weather.cloud * 0.55)
	game.environment.fog_density = 0.0011 + weather.mist * 0.004 + weather.intensity * 0.0009
	var in_tunnel = not game.world.director.tunnel_at(game.van.position).is_empty()
	for light in headlights:
		light.visible = game.started and (night > 0.1 or in_tunnel or weather.mist > 0.5) and model.energy > 0
		light.light_energy = 2.0 * (1.0 if in_tunnel or weather.mist > 0.5 else smoothstep(0.1, 0.8, night))
	if in_tunnel: game.environment.ambient_light_energy *= 0.3
	# Cheap uniforms update every frame; no binary switches at sunset or dawn.
	sky_material.set_shader_parameter("daylight", maxf(0, altitude))
	sky_material.set_shader_parameter("night", night)
	sky_material.set_shader_parameter("cloudiness", weather.cloud)
	sky_material.set_shader_parameter("sky_time", model.simulation_seconds)
	sky_material.set_shader_parameter("sun_direction", game.sun.global_basis.z)
	for mat in game.world.water_materials:
		if is_instance_valid(mat): mat.set_shader_parameter("sky_tint", fog)
