extends RefCounted
var status = "Вы за рулём"
var target_z = -INF
var camp_clock = 0.0
var look_clock = 0.0
var departure = false
var stuck_clock = 0.0
var recoveries = 0
var shot_clock = 20.0
var shot = -1
var roadside = Vector3.ZERO
var route = 0

func tick(game: Node, dt: float):
	if not game.autopilot: return
	if game.packing_camp:
		status = "Все в машину · выезжаем"
		return
	var state = game.model
	if game.camping:
		camp_clock += dt
		status = "Лагерь · зарядка и припасы"
		if state.is_night():
			status = "Ночлег · отдыхаем у костра"
			if camp_clock >= 35:
				game.resources.sleep_until_dawn(game)
				camp_clock = 0
			return
		if state.until_night() < 90:
			status = "Лагерь · встречаем закат"
			return
		if not game.projects.active.is_empty() and bool(game.projects.active.get("pending", false)) and not state.auto_projects:
			status = "Ждём решение по проекту · P"
			return
		var stocks_ready = minf(state.food, state.water) >= state.stock_capacity() * 0.40
		var useful_source = false
		for source in game.crew_system.sources:
			if state.water < state.stock_capacity() * 0.4 and source.kind == "water": useful_source = true
			if state.food < state.stock_capacity() * 0.4 and source.kind in ["food", "fishing"]: useful_source = true
		if not stocks_ready and not useful_source and minf(state.food, state.water) > state.stock_capacity() * 0.15: stocks_ready = true
		if state.percent() >= 85 and stocks_ready:
			# Let already assigned gatherers finish instead of cancelling every
			# outing as soon as the battery reaches the departure threshold.
			departure = true
			if not game.crew_system.all_home():
				status = "Ждём доставку припасов"
				return
			if game.crew_system.all_home():
				game.toggle_camp()
				game.autopilot = true
				departure = false
				target_z = -INF
				camp_clock = 0
				status = "Продолжаем экспедицию"
		elif camp_clock > 180 and state.supplies_factor() == 0 and game.crew_system.all_home(): status = "Нет доступных припасов · нужна помощь в лагере"
		return
	departure = false
	var needs_stop = state.percent() <= 25 or state.until_night() < 90 or state.is_night() or minf(state.food, state.water) < state.stock_capacity() * 0.25
	if needs_stop:
		status = "Ищем безопасную стоянку"
		if not is_finite(target_z):
			var best_score = -INF
			for offset in [16.0, 40.0, 72.0, 110.0, 160.0]:
				var z = game.van.position.z + offset
				var x = game.world.route_x(z, route)
				var p = Vector3(x, game.world.drive_height(x, z), z)
				var energy_needed = offset / maxf(2.5, absf(game.speed)) * maxf(0.02, game.resources.consumption - game.resources.generation)
				if state.energy > 0 and energy_needed > maxf(2, state.energy - state.capacity() * 0.1): continue
				var site = game.camp_controller.find_site(game, p)
				if site.is_empty(): continue
				var score = -offset * 0.03
				for source in site.sources:
					if source.kind == "water" and state.water < 10: score += 10
					if source.kind in ["food", "fishing"] and state.food < 10: score += 10
				if score > best_score:
					best_score = score
					target_z = z
			if not is_finite(target_z): target_z = game.van.position.z
		if game.van.position.z >= target_z - 2 or state.energy <= 0:
			game.toggle_camp()
			if game.camping:
				game.autopilot = true
				game.crew_system.set_mode(game, "auto")
				camp_clock = 0
			else:
				game.autopilot = false
				status = "Не удалось безопасно припарковаться · выберите место"
	else:
		status = "Едем к следующему виду"
		if absf(game.speed) < 0.35:
			stuck_clock += dt
			if stuck_clock > 12:
				stuck_clock = 0
				recoveries += 1
				game.recover()
				game.autopilot = recoveries <= 2
				if not game.autopilot: status = "Сложный участок · нужна помощь водителя"
		else:
			stuck_clock = 0
			recoveries = 0

func camera_pose(game: Node, dt: float) -> Dictionary:
	shot_clock += dt
	if shot_clock > 9:
		shot_clock = 0
		shot = (shot + 1) % 6
		roadside = game.van.position + Vector3(11, 3.5, 27).rotated(Vector3.UP, game.heading)
	var look = game.camera_anchor + Vector3(0, 1.3, 0)
	var offsets = [Vector3(13, 4, -4), Vector3(-7, 2, 12), Vector3(0, 6, -22), Vector3(0, 0, 0), Vector3(18, 22, -28), Vector3(-18, 8, -18)]
	var offset: Vector3 = offsets[maxi(0, shot)]
	var target = roadside if shot == 3 else look + offset.rotated(Vector3.UP, game.heading)
	if game.camping:
		look = game.camp_location + Vector3(0, 1.0, 0)
		target = look + Vector3(sin(game.model.simulation_seconds * 0.015) * 14, 6, cos(game.model.simulation_seconds * 0.015) * 14)
	if not game.world.director.tunnel_at(game.van.position).is_empty(): target = look + Vector3(0, 2, -8).rotated(Vector3.UP, game.heading)
	target = game.world.safe_camera(look, target)
	return {"target": target, "look": look, "fov": 52.0 if shot in [0, 3] else 65.0}
