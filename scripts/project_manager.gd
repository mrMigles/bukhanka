extends RefCounted
## One active contract, immutable seeded offers and explicit milestone decisions.
const TEMPLATES = [
	["Лендинг кофейни «На высоте»", 1, "Хозяин хочет анимацию каждого кофейного зерна", "Клиент прислал логотип в документе Word"],
	["Бронирование горных домиков", 0, "Две семьи забронировали один вид на горы", "Хозяин всё ещё доверяет тетрадке больше базы"],
	["Бот деревенских объявлений", 0, "Бот перепутал продажу козы с поиском DevOps", "Староста просит голосовые команды с трактора"],
	["Каталог семейной пасеки", 1, "У каждой пчелы оказался личный бренд", "Мёд закончился раньше тестовых данных"],
	["Сайт проката сапов", 1, "Заказчик просит кнопку «сделать воду потеплее»", "В мобильной версии весло перекрывает оплату"],
	["Оптимизация тяжёлого запроса", 0, "SELECT звёздочка выбирает весь Млечный Путь", "Старый отчёт считают уже третьи сутки"],
	["Переезд сервера в облако", 2, "Заказчик уточняет: облако должно быть дождевым?", "У старого сервера есть имя и привязанность к офису"],
	["Спасти пятничный деплой", 2, "Прод упал, но зато теперь на уровне моря", "Бэкап назван final_final_точно_новый"],
	["Мини-игра горного фестиваля", 3, "Тестировщик прошёл сквозь гору и попросил DLC", "Коза оказалась сильнее финального босса"],
	["Карта туристических троп", 3, "Короткий путь оказался вертикальным", "Карта уверена, что мост ещё существует"],
	["Магазин местных сувениров", 1, "Все товары называются «вот эта красивая штука»", "Корзина буквально стала плетёной"],
	["Учёт рыболовного улова", 0, "Рыбаки округляют вес исключительно вверх", "Приложение требует признать водоросли рыбой"]
]
var state: RefCounted
var offers: Array = []
var active: Dictionary = {}
var sequence = 0
var offer_day = -1
var settled: Array = []
var delivery_clock = 0.0
var last_result = ""

func _init(model: RefCounted): state = model

func refresh_offers():
	offers.clear()
	for i in range(3):
		var rng = RandomNumberGenerator.new()
		rng.seed = state.seed_value + sequence * 104729 + i * 7919 + state.day() * 997
		var template = rng.randi_range(0, TEMPLATES.size() - 1)
		var size = i
		offers.append({"id": "contract_%d_%d_%d" % [state.day(), sequence, i], "template": template, "title": TEMPLATES[template][0], "role": TEMPLATES[template][1], "size": size, "effort": [480.0, 800.0, 1280.0][size], "reward": [900, 1500, 2400][size], "duration": [8.0 / 24.0, 1.0, 2.0][size], "seed": int(rng.randi())})
	offer_day = state.day()
	sequence += 1

func on_calendar(_game: Node):
	if offers.is_empty() or offer_day != state.day(): refresh_offers()

func accept(id: String, game: Node) -> bool:
	if not active.is_empty(): return false
	for offer in offers:
		if offer.id != id: continue
		active = offer.duplicate(true)
		active.merge({"progress": 0.0, "quality": 60.0, "risk": 25.0, "stage": 0, "pending": true, "deadline": state.simulation_seconds + offer.duration * state.DAY_SECONDS, "choices": [], "failed": false, "reworked": false, "roll": -1.0})
		for hero in state.crew: hero.contribution = 0.0
		state.add_journal("Взяли заказ: " + str(active.title))
		game.save_game()
		return true
	return false

func decision_text() -> String:
	if active.is_empty(): return "Выберите заказ — команда готова обсудить план."
	if active.failed: return "Заказчик не принял работу. Можно исправить её один раз или закрыть проект."
	if int(active.stage) == 0: return "Как подойдём к проекту? Надёжный инструмент, свой велосипед или прототип на скотче?"
	return TEMPLATES[int(active.template)][mini(3, int(active.stage) + 1)]

func choices() -> Array:
	if active.is_empty(): return []
	var cost = [120, 200, 300][int(active.size)]
	var title_sets = [
		["Готовый инструмент и тесты", "Пишем аккуратно сами", "Прототип на скотче"],
		["Проверим вместе с заказчиком", "Исправим своими силами", "Спрячем за красивой кнопкой"],
		["Репетиция сдачи и резервная копия", "Проверим самое важное", "Деплой с криком «поехали!»"]
	]
	var labels = title_sets[mini(int(active.stage), 2)]
	return [
		{"id": "safe", "title": labels[0], "cost": cost, "effort": 0.08, "quality": 13, "risk": -12},
		{"id": "balanced", "title": labels[1], "cost": 0, "effort": 0.04, "quality": 7, "risk": -4},
		{"id": "fast", "title": labels[2], "cost": 0, "effort": -0.12, "quality": -5, "risk": 18}
	]

func resolve_decision(id: String, game: Node) -> bool:
	if active.is_empty() or not active.pending or not game.camping or active.failed: return false
	for choice in choices():
		if choice.id != id or game.money < choice.cost: continue
		game.money -= choice.cost
		active.effort = maxf(150, float(active.effort) * (1.0 + choice.effort))
		active.quality = clampf(float(active.quality) + choice.quality, 0, 100)
		active.risk = clampf(float(active.risk) + choice.risk, 0, 85)
		active.choices.append(id)
		active.stage += 1
		active.pending = false
		state.add_journal("%s: %s" % [active.title, choice.title])
		game.save_game()
		return true
	return false

func tick(game: Node, dt: float):
	on_calendar(game)
	if state.auto_projects and active.is_empty():
		var best = offers[0]
		var score = -INF
		for offer in offers:
			var fit = 0.0
			for hero in state.crew: fit += 0.15 if hero.role == offer.role else 0.0
			var candidate = float(offer.reward) / offer.effort + fit - offer.size * 0.15
			if candidate > score:
				score = candidate
				best = offer
		accept(best.id, game)
	if active.is_empty(): return
	if state.auto_projects and game.camping:
		if active.failed:
			rework(game) if not active.reworked else abandon(game)
			return
		if active.pending: resolve_decision("safe" if game.money >= choices()[0].cost + 500 else "balanced", game)
	if active.pending or active.failed or not game.resources.can_work(): return
	var rate = game.work_rate() * 1.35
	if rate <= 0:
		delivery_clock = 0
		return
	game.crew_system.contribution(game, dt)
	active.progress = minf(float(active.effort), float(active.progress) + dt * rate)
	var fraction = float(active.progress) / float(active.effort)
	var stops = [0.70] if int(active.size) == 0 else [0.45, 0.85]
	if not active.reworked and int(active.stage) <= stops.size() and fraction >= stops[int(active.stage) - 1]:
		active.pending = true
		game.toast("Команда ждёт обсуждения: " + decision_text() + " · P — проекты")
		game.save_game()
		return
	if fraction >= 1.0:
		delivery_clock = delivery_clock + dt * minf(1.0, game.signal_speed / 4.0) if game.signal_speed > 0 else 0.0
		if delivery_clock >= 3: finish(game)
	else: delivery_clock = 0.0

func finish(game: Node):
	if active.is_empty() or settled.has(active.id): return
	var rng = RandomNumberGenerator.new()
	rng.seed = int(active.seed)
	if float(active.roll) < 0: active.roll = rng.randf() * 100
	var quality = float(active.quality)
	var skill = 0.0
	for hero in state.crew:
		if hero.role == active.role: skill += state.level(hero.xp) * 1.5
		if hero.perks.has("safe"): skill += 2
		if hero.trait == 0: skill += 1
	quality += minf(10, skill)
	if float(active.roll) < float(active.risk): quality -= 35
	if active.reworked: quality = maxf(55, quality)
	quality = clampf(quality, 0, 100)
	if quality < 35:
		active.failed = true
		state.reputation = maxf(0, state.reputation - 6)
		last_result = "Заказ не принят: качество %.0f. Решения повысили риск до %.0f%%. Доступно исправление." % [quality, active.risk]
		state.add_journal(last_result)
		game.toast(last_result)
		game.save_game()
		return
	var late_days = int(maxf(0, state.simulation_seconds - float(active.deadline)) / state.DAY_SECONDS)
	var multiplier = 1.2 if quality >= 80 else 1.0 if quality >= 55 else 0.6
	var reward = roundi(float(active.reward) * multiplier * (1.0 - minf(0.25, late_days * 0.05)))
	var repayment = minf(state.debt, reward * 0.25)
	state.debt -= repayment
	game.money += reward - repayment
	state.reputation = clampf(state.reputation + (3 if quality >= 55 else -3), 0, 100)
	var contribution = 0.0
	for hero in state.crew: contribution += float(hero.contribution)
	for hero in state.crew:
		hero.xp += 100.0 * float(hero.contribution) / maxf(1, contribution)
		hero.contribution = 0.0
		hero.mood = clampf(float(hero.mood) + (4 if quality >= 55 else -4), 0, 100)
	settled.append(active.id)
	if settled.size() > 100: settled.pop_front()
	last_result = "%s · качество %.0f · +%d ₽%s" % [active.title, quality, reward - int(repayment), " · в погашение долга %d ₽" % int(repayment) if repayment > 0 else ""]
	state.add_journal(last_result)
	game.toast(last_result)
	active = {}
	delivery_clock = 0
	refresh_offers()
	game.save_game()

func rework(game: Node):
	if active.is_empty() or not active.failed or active.reworked: return
	active.failed = false
	active.reworked = true
	active.pending = false
	active.progress = 0.0
	active.effort *= 0.35
	state.add_journal("Исправляем заказ: " + str(active.title))
	game.save_game()

func abandon(game: Node):
	if active.is_empty(): return
	var compensation = minf(300, float(active.reward) * 0.1)
	var paid = minf(game.money, compensation)
	game.money -= paid
	state.debt += compensation - paid
	state.reputation = maxf(0, state.reputation - 3)
	state.add_journal("Закрыли заказ: %s · компенсация %.0f ₽" % [active.title, compensation])
	active = {}
	refresh_offers()
	game.save_game()

func encode() -> Dictionary:
	return {"balance_version": 2, "offers": offers, "active": active, "sequence": sequence, "offer_day": offer_day, "settled": settled, "last_result": last_result}

func decode(data: Dictionary):
	offers = data.get("offers", []) if data.get("offers", []) is Array else []
	active = data.get("active", {}) if data.get("active", {}) is Dictionary else {}
	sequence = maxi(0, int(data.get("sequence", 0)))
	offer_day = int(data.get("offer_day", -1))
	settled = data.get("settled", []) if data.get("settled", []) is Array else []
	last_result = str(data.get("last_result", ""))
	if not active.is_empty() and (not active.has("id") or not active.has("choices") or not active.has("effort")): active = {}
	# Refresh old shop offers; accepted contracts keep their promised deadline.
	if int(data.get("balance_version", 0)) < 2: refresh_offers()
