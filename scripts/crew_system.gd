extends RefCounted
var state: RefCounted
var tasks: Array = [{}, {}, {}, {}]
var sources: Array = []
var grid: AStarGrid2D
var origin = Vector3.ZERO
var schedule_clock = 0.0
var animation_clock = 0.0
var day_work = 0.0
var total_day = 0.0
var refill_kind = ""
var meal_clock = 0.0
var gathering_xp: Dictionary = {}
var harvest_visual_clock = 2.0
var rain_work_blocked = false

func gather_duration(kind: String) -> float:
	return 26.0 if kind == "fishing" else 12.0 if kind == "water" else 18.0

func batch_size(kind: String) -> float:
	return 4.0 if kind == "water" else 3.0 if kind == "food" else 2.5 + state.upgrades.fishing * 0.25

func work_exposed(game: Node) -> bool:
	return game.camping and game.weather.intensity > 0.05 and game.camp_level == 0

func _init(model: RefCounted): state = model

func camp_started(game: Node):
	tasks = [{}, {}, {}, {}]
	origin = game.camp_location
	sources = game.world.director.nearby_sources(origin)
	grid = AStarGrid2D.new()
	grid.region = Rect2i(-24, -24, 49, 49)
	grid.cell_size = Vector2(2, 2)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(-24, 25):
		for z in range(-24, 25):
			var p = origin + Vector3(x * 2, 0, z * 2)
			p.y = game.world.drive_height(p.x, p.z)
			var slope = maxf(absf(game.world.drive_height(p.x + 1, p.z) - p.y), absf(game.world.drive_height(p.x, p.z + 1) - p.y))
			var blocked = slope > 0.65 or game.world.sample_water(p).depth > 0.15 or game.world.collides(p)
			if Vector2(x * 2, z * 2).length() < 1.0: blocked = true
			grid.set_point_solid(Vector2i(x, z), blocked)
	# Interactions happen beside bushes/on dry banks, not inside their colliders.
	var reachable: Array = []
	for source in sources:
		var found = false
		for offset in [Vector3.ZERO, Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, -2), Vector3(2, 0, 2), Vector3(-2, 0, -2), Vector3(4, 0, 0), Vector3(-4, 0, 0)]:
			var route = path_to(game, game.camp_people[0].global_position, source.position + offset)
			if not route.is_empty():
				var copy = source.duplicate()
				copy.position = route.back()
				reachable.append(copy)
				found = true
				break
		if found: continue
	sources = reachable
	schedule_clock = 15

func worker_count() -> int:
	var count = 0
	for hero in state.crew:
		if hero.activity == "Работает": count += 1
	return count

func efficiency(hero: Dictionary, role: int) -> float:
	var value = 1.0 + (state.level(hero.xp) - 1) * 0.08
	if hero.role == role: value *= 1.15
	value *= lerpf(0.6, 1.0, clampf(float(hero.energy) / 40, 0, 1))
	value *= lerpf(0.85, 1.05, float(hero.mood) / 100)
	if hero.trait == 0: value *= 0.96
	if hero.trait == 1: value *= 1.08
	if hero.perks.has("speed"): value *= 1.08
	return value

func work_sum(game: Node) -> float:
	if work_exposed(game): return 0.0
	if game.camping and state.camp_mode == "supplies": return 0.0
	var value = 0.0
	var role = int(game.projects.active.get("role", -1))
	for i in range(4):
		if not game.camping:
			if absf(game.speed) > 0.3 and i == 0: continue
		elif not tasks[i].is_empty() or state.crew[i].activity in ["Спит", "Играет", "Играет с друзьями", "Играет на гитаре", "Готовит", "Ушёл в туалет", "Отдыхает", "Отдыхает у костра"]: continue
		value += efficiency(state.crew[i], role)
	return value

func contribution(game: Node, dt: float):
	var role = int(game.projects.active.get("role", -1))
	for i in range(4):
		if state.crew[i].activity == "Работает": state.crew[i].contribution += efficiency(state.crew[i], role) * dt

func path_to(game: Node, from: Vector3, to: Vector3) -> Array:
	if grid == null: return []
	var start = Vector2i(roundi((from.x - origin.x) / 2), roundi((from.z - origin.z) / 2))
	var target = Vector2i(roundi((to.x - origin.x) / 2), roundi((to.z - origin.z) / 2))
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(target): return []
	if grid.is_point_solid(target): return []
	var was_solid = grid.is_point_solid(start)
	grid.set_point_solid(start, false)
	var coordinates = grid.get_id_path(start, target)
	grid.set_point_solid(start, was_solid)
	var path: Array = []
	for cell in coordinates:
		var p = origin + Vector3(cell.x * 2, 0, cell.y * 2)
		p.y = game.world.drive_height(p.x, p.z)
		path.append(p)
	return path

func assign(game: Node, i: int, source: Dictionary) -> bool:
	if not tasks[i].is_empty() or not game.camping: return false
	var path: Array = []
	for step in range(9):
		var offset = Vector3(cos((step + i * 2) * PI / 4), 0, sin((step + i * 2) * PI / 4)) * 2.0 if step < 8 else Vector3.ZERO
		var candidate = path_to(game, game.camp_people[i].global_position, source.position + offset)
		if candidate.is_empty(): continue
		var occupied = false
		for task in tasks:
			if not task.is_empty() and not task.returning and task.get("destination", task.source.position).distance_to(candidate.back()) < 1.0: occupied = true
		if not occupied:
			path = candidate
			break
	if path.is_empty(): return false
	tasks[i] = {"source": source, "path": path, "destination": path.back(), "outbound": path.duplicate(), "returning": false, "clock": 0.0, "carried": 0.0}
	return true

func request_activity(game: Node, i: int, kind: String) -> bool:
	if not game.camping or state.is_night(): return false
	for n in range(sources.size()):
		var source = sources[(n + i) % sources.size()]
		var reserved = 0.0
		for task in tasks:
			if not task.is_empty() and not task.returning and task.source.id == source.id: reserved += batch_size(kind)
		if source.kind == kind and (kind == "water" or state.stock_available(source.id, source.maximum, 1 if kind == "fishing" else 2) > reserved):
			if assign(game, i, source): return true
	return false

func social_time() -> bool:
	return state.is_night() or state.phase() >= 0.58

func social_activity(i: int) -> String:
	var lead = posmod(int(animation_clock / 36.0), 4)
	if i == lead: return "Играет на гитаре"
	if i == posmod(lead + 1, 4) or i == posmod(lead + 2, 4): return "Играет с друзьями"
	return "Отдыхает у костра"

func guitar_active() -> bool:
	for hero in state.crew:
		if hero.activity == "Играет на гитаре": return true
	return false

func schedule(game: Node):
	if state.is_night(): return
	if state.camp_mode == "auto" and social_time() and minf(state.food, state.water) >= state.stock_capacity() * 0.4: return
	if game.auto_controller.departure or game.packing_camp or game.pending_sleep: return
	var busy = 0
	var expected = {"food": state.food, "water": state.water}
	for task in tasks:
		if task.is_empty(): continue
		busy += 1
		var kind = "water" if task.source.kind == "water" else "food"
		expected[kind] += float(task.carried) if task.returning else batch_size(task.source.kind)
	if state.camp_mode != "work":
		var target = state.stock_capacity() * (1.0 if state.camp_mode == "supplies" else 0.9)
		for i in range(4):
			if busy >= (4 if state.camp_mode == "supplies" else 2): break
			if not tasks[i].is_empty(): continue
			var priorities = ["water", "food"] if expected.water < expected.food else ["food", "water"]
			for kind in priorities:
				if expected[kind] >= target: continue
				if request_activity(game, i, kind) or (kind == "food" and request_activity(game, i, "fishing")):
					expected[kind] += batch_size(kind)
					busy += 1
					break
	if busy == 0 and int(state.simulation_seconds) % 120 < 16:
		var person = posmod(int(state.simulation_seconds / 120), 4)
		if tasks[person].is_empty():
			state.crew[person].activity = ["Готовит", "Играет", "Ушёл в туалет", "Отдыхает"][posmod(int(state.simulation_seconds / 120), 4)]

func tick(game: Node, dt: float):
	rain_work_blocked = work_exposed(game)
	harvest_visual_clock += dt
	if harvest_visual_clock >= 2.0:
		harvest_visual_clock = 0.0
		for plant in game.get_tree().get_nodes_in_group("harvest_visuals"):
			var maximum = float(plant.get_meta("maximum"))
			var fraction = state.stock_available(plant.get_meta("source_id"), maximum, 2) / maximum
			for i in range(plant.get_child_count()): plant.get_child(i).visible = i < ceili(plant.get_child_count() * fraction)
	animation_clock += dt
	var rain_idle: Array = []
	for offset in range(4):
		var index = posmod(offset + int(animation_clock / 45.0), 4)
		if tasks[index].is_empty(): rain_idle.append(index)
	for i in range(4):
		var hero = state.crew[i]
		if not game.camping:
			hero.activity = "Отдыхает" if state.is_night() else "Едет" if i == 0 and absf(game.speed) > 0.3 else "Работает"
		else:
			if state.is_night() and not tasks[i].is_empty(): start_return(game, i)
			if not tasks[i].is_empty() and not game.packing_camp: update_task(game, i, dt)
			elif state.is_night() or (state.camp_mode == "auto" and social_time()):
				hero.activity = social_activity(i)
			elif fposmod(state.simulation_seconds, 120) > 18 or hero.activity in ["Едет", "Возвращается", "Собирает", "Набирает воду", "Рыбачит"]:
				hero.activity = "Работает"
			if tasks[i].is_empty() and state.camp_mode == "supplies" and not state.is_night(): hero.activity = "Отдыхает"
			if tasks[i].is_empty() and rain_work_blocked and hero.activity == "Работает": hero.activity = "Отдыхает"
			if tasks[i].is_empty() and game.weather.intensity > 0.05 and not state.is_night() and not social_time() and state.camp_mode == "auto":
				var outdoor = rain_idle.find(i)
				if outdoor >= 0 and outdoor < maxi(0, rain_idle.size() - 2): hero.activity = "Играет с друзьями" if outdoor == 0 else "Отдыхает у костра"
		if hero.activity == "Работает":
			hero.energy = maxf(0, float(hero.energy) - 0.03 * dt)
		else:
			var rest = 0.05 * (1.25 if game.camping else 1.0)
			hero.energy = minf(100, float(hero.energy) + (rest if hero.activity == "Отдыхает" else -0.015) * dt)
			if game.camping and hero.activity == "Отдыхает": hero.energy = minf(100, hero.energy + rest * dt * float(game.camp_controller.quality.get("rest_bonus", 0)))
		if state.supplies_factor() == 0: hero.mood = maxf(0, float(hero.mood) - 0.02 * dt)
		if hero.activity == "Готовит" and state.food > 0 and state.last_meal_day != state.day():
			meal_clock += dt * (1 + state.upgrades.kitchen * 0.25)
			if meal_clock >= 10:
				meal_clock = 0
				state.last_meal_day = state.day()
				for friend in state.crew: friend.mood = minf(100, float(friend.mood) + 5 + state.upgrades.kitchen)
				state.add_journal("Приготовили горячую еду у костра")
		if state.auto_projects:
			for threshold in [3, 5]:
				if state.level(hero.xp) >= threshold and hero.perks.size() < (1 if threshold == 3 else 2): hero.perks.append("safe" if threshold == 3 else "speed")
	if game.camping:
		schedule_clock += dt
		if schedule_clock >= 3:
			schedule_clock = 0
			schedule(game)
		if state.is_night() and state.last_social_day != state.day():
			state.last_social_day = state.day()
			for hero in state.crew: hero.mood = minf(100, float(hero.mood) + 3)
		animate(game, dt)

func update_task(game: Node, i: int, dt: float):
	var task = tasks[i]
	var person = game.camp_people[i]
	var hero = state.crew[i]
	var kind = task.source.kind
	hero.activity = "Возвращается" if task.returning else {"food": "Собирает", "water": "Набирает воду", "fishing": "Рыбачит"}[kind]
	if not task.path.is_empty():
		var target: Vector3 = task.path[0]
		var direction = target - person.global_position
		if direction.length() < 0.2: task.path.pop_front()
		else:
			person.global_position = person.global_position.move_toward(target, 2.8 * dt)
			person.rotation.y = lerp_angle(person.rotation.y, atan2(direction.x, direction.z), minf(1, dt * 5))
		return
	if task.returning:
		if kind == "water": state.water = minf(state.stock_capacity(), state.water + float(task.carried))
		else: state.food = minf(state.stock_capacity(), state.food + float(task.carried))
		if float(task.carried) > 0:
			game.toast("%s принёс: %s +%.1f" % [hero.name, "вода" if kind == "water" else "еда", task.carried])
			var xp_key = "%s:%d" % [hero.id, state.day()]
			var gained = minf(8, 24.0 - float(gathering_xp.get(xp_key, 0)))
			hero.outdoor_xp += gained
			gathering_xp[xp_key] = float(gathering_xp.get(xp_key, 0)) + gained
		tasks[i] = {}
		hero.activity = "Работает"
		game.save_game()
		schedule_clock = 15
		return
	var bonus = 1.0 + (state.level(hero.outdoor_xp) - 1) * 0.10
	var facing: Vector3 = task.source.get("water_position", task.source.position) - person.global_position
	if Vector2(facing.x, facing.z).length() > 0.1: person.rotation.y = lerp_angle(person.rotation.y, atan2(facing.x, facing.z), minf(1, dt * 5))
	if (kind == "fishing" and hero.talent == 0) or (kind == "food" and hero.talent == 1): bonus *= 1.2
	bonus *= 1.0 + 0.15 * int(state.upgrades.fishing if kind == "fishing" else state.upgrades.storage if kind == "water" else 0)
	task.clock += dt * bonus
	if task.clock >= gather_duration(kind):
		if kind in ["water", "fishing"] and task.source.has("water_position"):
			game.effects.emit_ripple(task.source.water_position, 0.6)
		if kind == "water": task.carried = batch_size(kind)
		else: task.carried = state.harvest(task.source.id, batch_size(kind), task.source.maximum, 2 if kind == "food" else 1)
		start_return(game, i)

func start_return(game: Node, i: int):
	if tasks[i].is_empty() or tasks[i].returning: return
	tasks[i].returning = true
	var person = game.camp_people[i]
	var seat = game.camp.to_global(person.get_meta("seat"))
	tasks[i].path = path_to(game, person.global_position, seat)
	if tasks[i].path.is_empty():
		tasks[i].path = tasks[i].get("outbound", []).duplicate()
		tasks[i].path.reverse()

func return_all(game: Node):
	for i in range(4):
		if tasks[i].is_empty(): continue
		if tasks[i].source.kind == "water": state.water = minf(state.stock_capacity(), state.water + float(tasks[i].carried))
		else: state.food = minf(state.stock_capacity(), state.food + float(tasks[i].carried))
	tasks = [{}, {}, {}, {}]

func all_home() -> bool:
	for task in tasks:
		if not task.is_empty(): return false
	return true

func set_mode(game: Node, mode: String):
	if mode not in ["auto", "supplies", "work"]: return
	state.camp_mode = mode
	if mode == "work":
		for i in range(4): start_return(game, i)
	schedule_clock = 15
	game.save_game()

func status_text() -> String:
	var lines: Array[String] = []
	var names = {"auto": "Авто", "supplies": "Пополнение запасов", "work": "Работа"}
	lines.append("Режим: " + names[state.camp_mode])
	if rain_work_blocked and not state.is_night(): lines.append("Работа ждёт: нужен навес (лагерь ур. 1). Отдыхаем у костра.")
	if state.is_night():
		lines.append("Ночью отдыхаем. Сбор продолжится после рассвета.")
		return "\n".join(lines)
	for i in range(4):
		var task = tasks[i]
		if task.is_empty(): continue
		var action = "воду" if task.source.kind == "water" else "рыбу" if task.source.kind == "fishing" else "еду"
		lines.append("%s: %s %s%s" % [state.crew[i].name, "несёт" if task.returning else "идёт за" if not task.path.is_empty() else "добывает", action, " (+%.1f)" % task.carried if task.returning else " · %.0f%%" % (task.clock / gather_duration(task.source.kind) * 100) if task.path.is_empty() else ""])
	if state.camp_mode == "work": lines.append("Сбор выключен. Для пополнения выберите «Авто» или «Пополнить запасы».")
	else:
		for kind in ["food", "water"]:
			var available = false
			for source in sources:
				if source.kind == kind or (kind == "food" and source.kind == "fishing"):
					if source.kind == "water" or state.stock_available(source.id, source.maximum, 1 if source.kind == "fishing" else 2) > 0: available = true
			if not available: lines.append(("Еда" if kind == "food" else "Вода") + ": нет доступного неисчерпанного источника. Нужна другая стоянка или магазин.")
		if all_home() and minf(state.food, state.water) >= state.stock_capacity() * (0.98 if state.camp_mode == "supplies" else 0.89): lines.append("Запасы пополнены. Можно работать или отправляться дальше.")
	return "\n".join(lines)

func animate(game: Node, dt: float):
	for i in range(game.camp_people.size()):
		var person = game.camp_people[i]
		var hero = state.crew[i]
		if game.packing_camp:
			var door = game.van.to_global(Vector3(1.3, 0.1, 0.5))
			person.global_position = person.get_meta("boarding_from", person.global_position).lerp(door, clampf((game.packing_clock + dt) / 1.5, 0, 1))
			person.rotation.y = atan2(door.x - person.global_position.x, door.z - person.global_position.z)
			person.get_meta("gather_label").hide()
			person.get_meta("gather_bar").hide()
			preload("res://scripts/crew_visual.gd").animate(person, "Возвращается", animation_clock + i, true)
			continue
		var walking = not tasks[i].is_empty() and not tasks[i].path.is_empty()
		var sheltering = game.weather.intensity > 0.05 and hero.activity == "Работает" and game.camp_level > 0
		person.visible = true
		game.van.people[i].visible = false
		if tasks[i].is_empty():
			var target: Vector3 = person.get_meta("seat")
			if hero.activity == "Играет с друзьями" and game.camp.has_meta("game_table"):
				target = game.camp.get_meta("game_table") + Vector3(-0.65 if i % 2 == 0 else 0.65, 0, 0)
			elif sheltering:
				target = game.camp_shelter + Vector3((i % 2) * 0.45, 0.1, int(i / 2) * 0.45)
			elif hero.activity == "Ушёл в туалет": target = game.camp.get_meta("toilet")
			elif hero.activity == "Готовит": target = game.camp.get_meta("kitchen") + Vector3(0, 0, -0.6)
			walking = person.position.distance_to(target) > 0.2
			person.position = person.position.move_toward(target, dt * 1.6)
		preload("res://scripts/crew_visual.gd").animate(person, hero.activity, animation_clock + i, walking)
		var task = tasks[i]
		var collecting = not task.is_empty() and not task.returning and task.path.is_empty()
		var label: Label3D = person.get_meta("gather_label")
		var bar: MeshInstance3D = person.get_meta("gather_bar")
		label.visible = not task.is_empty()
		bar.visible = collecting
		if not task.is_empty():
			var progress = clampf(task.clock / gather_duration(task.source.kind), 0, 1)
			var resource_name = task.source.get("label", "Вода" if task.source.kind == "water" else "Рыбалка" if task.source.kind == "fishing" else "Ягоды")
			label.text = "%s · %d%%" % [resource_name, roundi(progress * 100)] if collecting else "Несёт +%.1f" % task.carried if task.returning else "Идёт к воде" if task.source.kind != "food" else "Идёт за едой"
			bar.material_override.set_shader_parameter("progress", progress)
