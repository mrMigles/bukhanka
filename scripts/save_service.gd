extends RefCounted
var last_error = ""

func path(test_mode: bool) -> String: return "user://test_journey_v2.json" if test_mode else "user://journey_v2.json"

func backup_legacy(test_mode: bool):
	if test_mode or not FileAccess.file_exists("user://journey.json") or FileAccess.file_exists("user://journey.v1.backup.json"): return
	var error = DirAccess.copy_absolute("user://journey.json", "user://journey.v1.backup.json")
	if error != OK: last_error = "Не удалось создать копию старого путешествия. Исходный файл сохранён."

func read_data(test_mode: bool) -> Dictionary:
	for filename in [path(test_mode), path(test_mode) + ".bak"]:
		if not FileAccess.file_exists(filename): continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(filename))
		if data is Dictionary and data.get("schema_version", 0) == 2 and data.get("model") is Dictionary:
			return data
	return {}

func save(game: Node) -> bool:
	if not is_instance_valid(game.van): return false
	var filename = path(game.test_mode)
	var data = {"schema_version": 2, "world_generation_version": 2, "model": game.model.encode(), "projects": game.projects.encode(), "x": game.van.position.x, "z": game.van.position.z, "heading": game.heading, "distance": game.distance, "money": game.money, "levels": game.levels, "camp_level": game.camp_level, "discoveries": game.discoveries, "camping": game.camping}
	var cargo = {"food": 0.0, "water": 0.0}
	for task in game.crew_system.tasks:
		if not task.is_empty(): cargo["water" if task.source.kind == "water" else "food"] += float(task.carried)
	data["returning_cargo"] = cargo
	data["tutorial_seen"] = game.tutorial_seen
	data["shop_charge"] = game.shop_charge
	data["camp_position"] = [game.camp_location.x, game.camp_location.z]
	data["camp_rotation"] = game.camp_controller.rotation
	data["outdoor_daily_xp"] = game.crew_system.gathering_xp
	data["dialogue_sequence"] = game.dialogues.sequence
	data["dialogue_recent"] = game.dialogues.recent
	var file = FileAccess.open(filename + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Не удалось сохранить путешествие"
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	if not JSON.parse_string(FileAccess.get_file_as_string(filename + ".tmp")) is Dictionary:
		last_error = "Ошибка проверки сохранения"
		return false
	if FileAccess.file_exists(filename):
		if DirAccess.copy_absolute(filename, filename + ".bak") != OK:
			last_error = "Не удалось создать резервную копию"
			return false
	var result = DirAccess.rename_absolute(filename + ".tmp", filename)
	last_error = "" if result == OK else "Не удалось записать сохранение"
	return result == OK

func restore(game: Node):
	var data = read_data(game.test_mode)
	if data.is_empty(): return
	game.model.decode(data.model)
	game.tutorial_seen = bool(data.get("tutorial_seen", false))
	game.shop_charge = game.model.finite_number(data.get("shop_charge", 0), 0, 0, game.model.capacity() - game.model.energy)
	var cargo = data.get("returning_cargo", {})
	if cargo is Dictionary:
		game.model.food = minf(game.model.stock_capacity(), game.model.food + game.model.finite_number(cargo.get("food", 0), 0, 0, 24))
		game.model.water = minf(game.model.stock_capacity(), game.model.water + game.model.finite_number(cargo.get("water", 0), 0, 0, 24))
	game.crew_system.gathering_xp = data.get("outdoor_daily_xp", {}) if data.get("outdoor_daily_xp", {}) is Dictionary else {}
	game.dialogues.sequence = int(data.get("dialogue_sequence", 0))
	game.dialogues.recent = data.get("dialogue_recent", []) if data.get("dialogue_recent", []) is Array else []
	game.projects.decode(data.get("projects", {}))
	game.money = game.model.finite_number(data.get("money", 1500), 1500, 0, 1e10)
	game.distance = game.model.finite_number(data.get("distance", 0), 0, 0, 1e12)
	var levels = data.get("levels", [])
	if levels is Array and levels.size() == 4:
		for i in range(4): game.levels[i] = clampi(int(levels[i]), 0, 3)
	game.camp_level = clampi(int(data.get("camp_level", 0)), 0, 3)
	game.discoveries = data.get("discoveries", []) if data.get("discoveries", []) is Array else []
	var z = game.model.finite_number(data.get("z", 120), 120, -1e7, 1e7)
	var x = game.model.finite_number(data.get("x", game.world.road_x(z)), game.world.road_x(z), -550, 550)
	game.heading = game.model.finite_number(data.get("heading", 0), 0, -TAU, TAU)
	game.van.position = Vector3(x, game.world.drive_height(x, z) + 0.3, z)
	game.last_km = int(game.distance / 1000)
	game.time = game.model.simulation_seconds
	game.restore_camping = bool(data.get("camping", false))
	if game.restore_camping:
		var p = data.get("camp_position", [])
		if p is Array and p.size() == 2:
			var cx = game.model.finite_number(p[0], x, x - 36, x + 36)
			var cz = game.model.finite_number(p[1], z, z - 36, z + 36)
			game.camp_controller.selected = {"position": Vector3(cx, game.world.drive_height(cx, cz), cz)}
		game.camp_controller.rotation = game.model.finite_number(data.get("camp_rotation", 0), 0, -TAU * 100, TAU * 100)
