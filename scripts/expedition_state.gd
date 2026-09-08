extends RefCounted
## Persistent expedition model. All rates use active simulation seconds.
const DAY_SECONDS = 1200.0
const DAYLIGHT = 0.70
const ROLES = ["Backend", "Frontend", "DevOps", "GameDev"]
const TALENTS = ["Рыбак", "Собиратель", "Повар", "Логист"]
const TRAITS = ["Тестирует даже чайник", "Прототип за вечер", "Душа костра", "Эстет интерфейсов"]
const XP_LEVELS = [0, 40, 120, 260, 500]
var simulation_seconds = 96.0
var seed_value = 7429
var energy = 100.0
var food = 16.0
var water = 16.0
var debt = 0.0
var reputation = 50.0
var configured = false
var auto_projects = false
var cinematic = false
var voices_enabled = true
var voice_volume = 0.65
var upgrades = {"battery": 0, "roof": 0, "panels": 0, "kitchen": 0, "storage": 0, "fishing": 0}
var crew: Array = []
var journal: Array = []
var depleted: Dictionary = {}
var last_social_day = -1
var last_meal_day = -1
var camp_mode = "auto"
var destination: Dictionary = {}

func _init():
	for i in range(4):
		crew.append({"id": "friend_%d" % i, "name": ["Миша", "Соня", "Лёша", "Даня"][i], "role": i, "talent": i, "trait": i, "shirt": i, "skin": 1, "hair": 0, "xp": 0.0, "outdoor_xp": 0.0, "energy": 100.0, "mood": 70.0, "activity": "Едет", "perks": [], "contribution": 0.0})

func day() -> int: return int(simulation_seconds / DAY_SECONDS) + 1
func phase() -> float: return fposmod(simulation_seconds, DAY_SECONDS) / DAY_SECONDS
func is_night() -> bool: return phase() >= DAYLIGHT
func until_night() -> float: return maxf(0, (DAYLIGHT - phase()) * DAY_SECONDS)
func until_dawn() -> float: return (1.0 - phase()) * DAY_SECONDS
func capacity() -> float: return 100.0 + 25.0 * upgrades.battery
func stock_capacity() -> float: return 24.0 + 8.0 * upgrades.storage
func percent() -> float: return energy / capacity() * 100.0
func irradiance() -> float: return 0.0 if is_night() else maxf(0, sin(PI * phase() / DAYLIGHT))
func level(xp: float) -> int:
	var result = 1
	for threshold in XP_LEVELS:
		if xp >= threshold: result = XP_LEVELS.find(threshold) + 1
	return result

func phase_name() -> String:
	if is_night(): return "Ночь"
	if phase() < 0.07: return "Рассвет"
	if phase() >= 0.61: return "Закат"
	return "День"

func supplies_factor() -> float:
	if food <= 0.0 or water <= 0.0: return 0.0
	return lerpf(0.7, 1.0, clampf(minf(food, water) / (stock_capacity() * 0.25), 0, 1))

func add_journal(message: String):
	journal.append("День %d · %s" % [day(), message])
	if journal.size() > 100: journal.pop_front()

func stock_available(id: String, maximum: float, regrow_days: int) -> float:
	var entry = depleted.get(id, {})
	if entry.is_empty() or day() >= int(entry.get("regrow", 0)): return maximum
	return maxf(0, maximum - float(entry.get("used", 0)))

func harvest(id: String, amount: float, maximum: float, regrow_days: int) -> float:
	var available = stock_available(id, maximum, regrow_days)
	var taken = minf(available, amount)
	depleted[id] = {"used": maximum - available + taken, "regrow": day() + regrow_days if not depleted.has(id) or day() >= int(depleted[id].get("regrow", 0)) else depleted[id].regrow}
	return taken

func prune_resources():
	for key in depleted.keys():
		if day() >= int(depleted[key].get("regrow", 0)): depleted.erase(key)

func encode() -> Dictionary:
	return {"destination": destination.duplicate(true), "camp_mode": camp_mode, "simulation_seconds": simulation_seconds, "seed": seed_value, "energy": energy, "food": food, "water": water, "debt": debt, "reputation": reputation, "configured": configured, "auto_projects": auto_projects, "cinematic": cinematic, "voices_enabled": voices_enabled, "voice_volume": voice_volume, "upgrades": upgrades.duplicate(true), "crew": crew.duplicate(true), "journal": journal.duplicate(), "depleted": depleted.duplicate(true), "last_social_day": last_social_day, "last_meal_day": last_meal_day}

func decode(data: Dictionary):
	simulation_seconds = finite_number(data.get("simulation_seconds", 96), 96, 0, 1e12)
	seed_value = int(data.get("seed", 7429))
	for key in upgrades:
		upgrades[key] = clampi(int(data.get("upgrades", {}).get(key, 0)), 0, 3)
	energy = finite_number(data.get("energy", 100), 100, 0, capacity())
	food = finite_number(data.get("food", 16), 16, 0, stock_capacity())
	water = finite_number(data.get("water", 16), 16, 0, stock_capacity())
	debt = finite_number(data.get("debt", 0), 0, 0, 1e9)
	reputation = finite_number(data.get("reputation", 50), 50, 0, 100)
	configured = bool(data.get("configured", true))
	destination = data.get("destination", {}) if data.get("destination", {}) is Dictionary else {}
	if not destination.is_empty():
		if not destination.has_all(["id", "x", "z", "title"]): destination = {}
		else:
			destination.x = finite_number(destination.x, 0, -1e7, 1e7)
			destination.z = finite_number(destination.z, 120, -1e7, 1e7)
	camp_mode = str(data.get("camp_mode", "auto"))
	if camp_mode not in ["auto", "supplies", "work"]: camp_mode = "auto"
	auto_projects = bool(data.get("auto_projects", false))
	cinematic = bool(data.get("cinematic", false))
	voices_enabled = bool(data.get("voices_enabled", true))
	voice_volume = finite_number(data.get("voice_volume", 0.65), 0.65, 0, 1)
	var saved = data.get("crew", [])
	if saved is Array and saved.size() == 4:
		for i in range(4):
			if not saved[i] is Dictionary: continue
			for key in crew[i]:
				if saved[i].has(key): crew[i][key] = saved[i][key]
			crew[i].name = str(crew[i].name).strip_edges().replace("\n", " ").left(20)
			for key in ["role", "talent", "trait", "shirt", "skin", "hair"]: crew[i][key] = clampi(int(crew[i][key]), 0, 3)
			for key in ["energy", "mood"]: crew[i][key] = finite_number(crew[i][key], 70, 0, 100)
			for key in ["xp", "outdoor_xp", "contribution"]: crew[i][key] = finite_number(crew[i][key], 0, 0, 1e9)
			if not crew[i].perks is Array: crew[i].perks = []
			crew[i].activity = "Едет"
	journal = data.get("journal", []) if data.get("journal", []) is Array else []
	depleted = data.get("depleted", {}) if data.get("depleted", {}) is Dictionary else {}
	last_social_day = int(data.get("last_social_day", -1))
	last_meal_day = int(data.get("last_meal_day", -1))

func finite_number(value, fallback: float, low: float, high: float) -> float:
	var number = float(value) if value is float or value is int else fallback
	return clampf(number, low, high) if is_finite(number) else fallback
