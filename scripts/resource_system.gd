extends RefCounted
var state: RefCounted
var generation = 0.0
var consumption = 0.0
var warnings: Dictionary = {}

func _init(model: RefCounted): state = model

func can_work() -> bool: return not state.is_night() and state.supplies_factor() > 0.0

func power_balance(speed: float, throttle: float, grade: float, mud: float, depth: float, camp: bool, workers: int, solar_factor: float, exposure: float = 1.0) -> Vector2:
	var roof = [0.055, 0.075, 0.09, 0.11][state.upgrades.roof]
	var panels = [0.45, 0.60, 0.75, 0.90][state.upgrades.panels] if camp else 0.0
	var incoming = (roof + panels) * state.irradiance() * solar_factor * exposure
	var outgoing = 0.0015 if state.is_night() else 0.004 + 0.002 * workers
	if not camp and (absf(speed) > 0.3 or throttle > 0.1):
		outgoing += minf(0.38, 0.10 + 0.012 * absf(speed) + 0.04 * throttle + 0.07 * clampf(grade / 0.25, 0, 1) + 0.05 * mud + 0.06 * clampf(depth, 0, 1))
	if camp and incoming > outgoing: incoming = outgoing + (incoming - outgoing) * 1.25
	return Vector2(incoming, outgoing)

func tick(game: Node, dt: float):
	var p = game.camp_location if game.camping else game.van.position
	var direction = Vector3(sin(game.heading), 0, cos(game.heading))
	var grade = (game.world.drive_height(p.x + direction.x, p.z + direction.z) - game.world.drive_height(p.x - direction.x, p.z - direction.z)) * 0.5
	var wet = game.world.sample_water(p)
	var balance = power_balance(game.speed, game.dynamics.throttle_load, grade, 1.0 if game.world.mud_at(p.x, p.z) else 0.0, wet.depth, game.camping, game.crew_system.worker_count(), game.weather.solar_factor, game.world.solar_exposure(p, state.phase()))
	generation = balance.x
	consumption = balance.y
	state.energy = clampf(state.energy + (generation - consumption) * dt, 0, state.capacity())
	consume_supplies(dt)
	for threshold in [30, 10, 0]:
		if state.percent() <= threshold and not warnings.has(threshold):
			warnings[threshold] = true
			game.toast("Заряд %d%% · %s" % [roundi(state.percent()), "разбейте лагерь и дождитесь солнца" if threshold == 0 else "пора искать солнечную стоянку"])
		elif state.percent() > threshold + 8: warnings.erase(threshold)
	if state.supplies_factor() == 0 and not warnings.has("supplies"):
		warnings["supplies"] = true
		game.toast("Закончились припасы. Работа ждёт: соберите еду и воду или вызовите помощь в лагере.")
	elif minf(state.food, state.water) > state.stock_capacity() * 0.1: warnings.erase("supplies")

func consume_supplies(dt: float):
	state.food = maxf(0, state.food - dt * 8.0 / state.DAY_SECONDS)
	state.water = maxf(0, state.water - dt * 8.0 / state.DAY_SECONDS)

func sleep_until_dawn(game: Node) -> Dictionary:
	if not game.camping or not state.is_night(): return {}
	if not game.crew_system.all_home():
		if not game.pending_sleep: game.toast("Перед сном ждём возвращения друзей.")
		game.pending_sleep = true
		for i in range(4): game.crew_system.start_return(game, i)
		return {}
	game.crew_system.return_all(game)
	var remaining = state.until_dawn()
	var before = Vector3(state.energy, state.food, state.water)
	# Logical integration only: never run physics or rendering while sleeping.
	var cursor = remaining
	while cursor > 0.0001:
		var dt = minf(1.0, cursor)
		consume_supplies(dt)
		state.energy = maxf(0, state.energy - 0.0015 * dt)
		for hero in state.crew:
			hero.energy = minf(100, float(hero.energy) + 0.3125 * dt * (1.0 + float(game.camp_controller.quality.get("rest_bonus", 0))))
			hero.mood = minf(100, float(hero.mood) + 0.015 * dt)
		state.simulation_seconds += dt
		cursor -= dt
	state.simulation_seconds = roundf(state.simulation_seconds / state.DAY_SECONDS) * state.DAY_SECONDS
	state.prune_resources()
	game.weather.update_weather(game, 0.0)
	game.projects.on_calendar(game)
	game.lighting.update(game, 0.0)
	var used = before - Vector3(state.energy, state.food, state.water)
	state.add_journal("Ночлег: еда −%.1f, вода −%.1f, заряд −%.1f" % [used.y, used.z, used.x])
	game.save_game()
	game.toast("Доброе утро! Запасы −%.1f · заряд −%.1f%% · %s" % [used.y, used.x / state.capacity() * 100, game.weather.current_name])
	return {"seconds": remaining, "energy_used": used.x, "food_used": used.y, "water_used": used.z}

func rescue(game: Node):
	game.crew_system.return_all(game)
	var paid = minf(game.money, 1500)
	game.money -= paid
	state.debt += 1500 - paid
	state.reputation = maxf(0, state.reputation - 5)
	consume_supplies(600)
	state.simulation_seconds += 600
	state.energy = maxf(state.energy, 35)
	state.food = maxf(state.food, 6)
	state.water = maxf(state.water, 6)
	if game.camping: game.toggle_camp()
	game.recover()
	game.autopilot = false
	game.auto_controller.status = "Помощь доставила припасы"
	state.add_journal("Помощь экспедиции: 1500 ₽, долг %.0f ₽" % state.debt)
	game.save_game()
	game.toast("Друзья из долины помогли. Заряд и припасы восстановлены; долг %.0f ₽." % state.debt)
