extends RefCounted
const LINES = {
	"road": ["За поворотом снова гора. Карта пока не повторяется.", "Подвеска обсуждает архитектуру дороги.", "Мы уже выше облаков или это просто туман?", "Самое важное в маршруте — иногда выключать навигатор."],
	"power": ["Солнце сегодня наш единственный инвестор.", "Батарея просит отпуск у костра.", "Панели смотрят на небо. Мы — на проценты.", "Электрическая буханка звучит как дедова. Обратная совместимость."],
	"food": ["В бэклоге обнаружен критический голод.", "Эти ягоды точно не тестовые данные?", "Уха — это когда результат можно потрогать ложкой.", "Вода закончится раньше, чем аргументы на созвоне."],
	"night": ["Млечный Путь выглядит как очень аккуратный merge.", "Сегодня прод подождёт. Посмотрите на звёзды.", "Костёр работает без подписки и обновлений.", "Луна — единственный ночной дежурный, которому мы доверяем."],
	"weather": ["Облака поднялись, а облачный сервер почему-то нет.", "Дождь проводит нагрузочное тестирование палатки.", "Туман скрыл технический долг вместе с дорогой.", "Снег — это когда мир перешёл на светлую тему."],
	"water": ["У реки даже мысли перестают торопиться.", "Водопад работает без единого насоса.", "Озеро отражает горы лучше любого отчёта.", "Рыба клюёт. В отличие от клиента на повышение цены."],
	"animals": ["Олень смотрит так, будто видел наш код.", "Козы проходят этот склон без полного привода.", "У овец тоже стендап. Только короткий.", "Птицы явно знают более простой маршрут."],
	"village": ["Здесь магазин работает даже без интернета.", "У местных лучший прогноз: посмотреть в окно.", "Сад с яблоками — очень убедительный аргумент за остановку.", "Может, поможем деревне с сайтом? Только без микросервисов."],
	"project": ["Заказчик попросил просто маленькую кнопку.", "Сделаем надёжно — и успеем посмотреть закат.", "В задачах написано «быстро». В горах это понятие относительное.", "Перед сдачей проверим всё. Кроме терпения заказчика."],
	"tunnel": ["Связь ушла в тоннель раньше нас.", "Вот теперь сервер точно под землёй.", "Фары включены. Прод пока выключен.", "Эхо повторяет только то, что прошло ревью."]
}
const TAILS = [
	["Сначала проверим, потом оптимизируем.", "Главное — не хранить это в одной переменной.", "Я бы добавил резервную копию.", "Но обед всё-таки по расписанию."],
	["Зато какой здесь цвет!", "Такой интерфейс я бы не переделывала.", "Добавлю это в коллекцию хороших идей.", "Давайте просто минутку посмотрим."],
	["Мониторинг подтверждает.", "Инфраструктура одобряет.", "Термос уже готов к развёртыванию.", "Сегодня без пятничного деплоя."],
	["Отличная механика для нашей жизни.", "Считаю это новым уровнем.", "Сохраним момент, а не только игру.", "За такую графику не жалко остановиться."]
]
var clock = 0.0
var sequence = 0
var recent: Array = []
var voice: AudioStreamPlayer
var syllables: Array[AudioStreamWAV] = []
var pending_reply: Dictionary = {}

func setup(game: Node):
	voice = AudioStreamPlayer.new()
	game.add_child(voice)
	for i in range(8):
		var wav = AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 16000
		var bytes = PackedByteArray()
		bytes.resize(16000)
		for frame in range(8000):
			var t = frame / 16000.0
			var syllable = fmod(t, 0.16)
			var envelope = sin(clampf(syllable / 0.16, 0, 1) * PI) * (1.0 - t * 1.7)
			var frequency = 145.0 + i * 24.0 + sin(t * 21.0) * 28
			var sample = (sin(TAU * frequency * t) * 0.5 + sin(TAU * frequency * 2.03 * t) * 0.2 + sin(TAU * (650 + i * 65) * t) * 0.07) * envelope
			bytes.encode_s16(frame * 2, int(sample * 13000))
		wav.data = bytes
		syllables.append(wav)

func context(game: Node) -> String:
	if not game.world.director.tunnel_at(game.van.position).is_empty(): return "tunnel"
	if game.model.is_night(): return "night"
	if game.model.percent() < 30: return "power"
	if minf(game.model.food, game.model.water) < 6: return "food"
	if game.weather.intensity > 0.3 or game.weather.mist > 0.5: return "weather"
	if game.camping and not game.projects.active.is_empty(): return "project"
	for item in game.world.director.near_z(game.van.position.z):
		if absf(item.z - game.van.position.z) < 60:
			if item.kind in ["lake", "waterfall"]: return "water"
			if item.kind in ["animals", "village"]: return item.kind
	return "road"

func tick(game: Node, dt: float):
	clock += dt
	if not pending_reply.is_empty() and clock > 5:
		var author = int(pending_reply.author)
		var hero = game.model.crew[author]
		game.ui.speaker.text = "%s · %s" % [str(hero.name).to_upper(), game.model.ROLES[hero.role]]
		game.ui.dialogue.text = TAILS[author][int(pending_reply.variant)]
		play_voice(game, author)
		pending_reply = {}
		return
	if clock > 28 + posmod(sequence * 7, 17): speak(game)

func speak(game: Node):
	clock = 0
	var category = context(game)
	var hero_index = posmod(sequence, 4)
	var variant = posmod(int(sequence / 4), 4)
	var key = "%s:%d:%d" % [category, hero_index, variant]
	for attempt in range(16):
		if not recent.has(key): break
		variant = (variant + 1) % 4
		if variant == 0: hero_index = (hero_index + 1) % 4
		key = "%s:%d:%d" % [category, hero_index, variant]
	recent.append(key)
	if recent.size() > 20: recent.pop_front()
	var hero = game.model.crew[hero_index]
	game.ui.speaker.text = "%s · %s" % [str(hero.name).to_upper(), game.model.ROLES[hero.role]]
	game.ui.dialogue.text = LINES[category][variant] + " " + TAILS[hero_index][variant]
	if sequence % 3 == 0:
		game.ui.dialogue.text = LINES[category][variant]
		pending_reply = {"author": (hero_index + 1) % 4, "variant": variant}
	else: pending_reply = {}
	sequence += 1
	play_voice(game, hero_index)

func play_voice(game: Node, hero_index: int):
	if is_instance_valid(voice) and game.model.voices_enabled and game.started:
		voice.stream = syllables[posmod(sequence, syllables.size())]
		voice.pitch_scale = [0.88, 1.28, 1.0, 1.1][hero_index]
		voice.volume_db = linear_to_db(maxf(0.001, game.model.voice_volume)) - 14
		voice.play()
