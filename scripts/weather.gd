extends Node3D
var elapsed = 0.0
var wetness = 0.0
var cloud = 0.0
var mist = 0.0
var intensity = 0.0
var current_name = "Ясно"
var solar_factor = 1.0
var rain: CPUParticles3D
var rain_audio: AudioStreamPlayer
const STATES = ["Ясно", "Облачно", "Дождь", "Туман", "Ясно"]

func _ready():
	rain = CPUParticles3D.new()
	rain.amount = 700
	rain.lifetime = 1.2
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(15, 8, 15)
	rain.direction = Vector3(0.15, -1, 0)
	rain.spread = 5
	rain.initial_velocity_min = 18
	rain.initial_velocity_max = 24
	rain.gravity = Vector3(1, -4, 0)
	rain.local_coords = false
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.018, 0.6, 0.018)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.75, 0.83, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	rain.mesh = mesh
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain)

func update_weather(game: Node, delta: float):
	elapsed = game.model.simulation_seconds - 96.0
	# Four-minute forecast blocks. Every day has a guaranteed clear window.
	var slot = posmod(int(maxf(0, elapsed) / 180.0), 10)
	var pattern = [0, 1, 2, 0, 3, 0, 1, 4, 0, 2]
	var index = pattern[slot]
	if game.model.day() == 1 and elapsed < 240: index = 0
	var snowing = game.van.position.y > 215
	var rainy = 1.0 if index == 2 or index == 4 else 0.0
	var transition = delta if delta > 0 else 30.0
	intensity = move_toward(intensity, rainy, transition / 12.0)
	cloud = move_toward(cloud, [0.0, 0.65, 0.85, 0.70, 1.0][index], transition / 20.0)
	mist = move_toward(mist, 1.0 if index == 3 else 0.0, transition / 20.0)
	wetness = move_toward(wetness, rainy, transition / (20.0 if rainy > 0 else 95.0))
	current_name = ["Ясно", "Облачно", "Снегопад" if snowing else "Дождь", "Туман", "Снегопад" if snowing else "Ливень"][index]
	var solar_target = [1.0, 0.55, 0.10 if snowing else 0.30, 0.15, 0.10 if snowing else 0.05][index]
	solar_factor = move_toward(solar_factor, solar_target, transition / 15.0)
	rain.mesh.size = Vector3(0.065, 0.065, 0.065) if snowing else Vector3(0.018, 0.6, 0.018)
	rain.initial_velocity_min = 2.5 if snowing else 18.0
	rain.initial_velocity_max = 4.0 if snowing else 24.0
	rain.gravity = Vector3(0.5, -0.3, 0) if snowing else Vector3(1, -4, 0)
	rain.mesh.material.albedo_color = Color.WHITE if snowing else Color(0.6, 0.75, 0.83, 0.45)
	rain.mesh.material.albedo_color.a = intensity * 0.45
	rain.global_position = game.van.position + Vector3(0, 8, 0)
	rain.emitting = intensity > 0.05 and game.started and not game.paused and game.world.director.tunnel_at(game.van.position).is_empty()
	game.world.road_material.set_shader_parameter("wetness", wetness)
	game.world.terrain_material.set_shader_parameter("wetness", wetness)
