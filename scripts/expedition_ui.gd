extends Control
var game: Node
var overlay: ColorRect
var content: VBoxContainer
var title: Label
var resource_text: Label
var info: Label
var actions: HBoxContainer
var section = ""
var freezes = false
var refresh_clock = 0.0
var sleep_cover: ColorRect
var body: PanelContainer
var sidebar: VBoxContainer
var content_scroll: ScrollContainer
var close_button: Button
var state_text: Label
var panel_version = ""
var project_progress: Label
var hero_labels: Array[Label] = []

var camp_status: Label
var sleep_button: Button

const Kit = preload("res://scripts/ui_kit.gd")
var screens = preload("res://scripts/expedition_screens.gd").new()
var nav_buttons: Dictionary = {}
var resource_cards: Array[Label] = []

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Kit.theme()
	screens.ui = self
	# All travel information belongs to the single HUD.
	resource_text = Label.new()
	resource_text.hide()
	add_child(resource_text)
	state_text = Label.new()
	state_text.position = Vector2(490, 120)
	state_text.size = Vector2(640, 44)
	state_text.add_theme_font_size_override("font_size", 14)
	state_text.add_theme_constant_override("outline_size", 4)
	state_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(state_text)
	actions = HBoxContainer.new()
	add_child(actions)
	actions.hide()
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var glass = ShaderMaterial.new()
	glass.shader = load("res://shaders/ui_glass.gdshader")
	overlay.material = glass
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	body = PanelContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 58
	body.offset_top = 28
	body.offset_right = -58
	body.offset_bottom = -28
	overlay.add_child(body)
	style(body)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	body.add_child(layout)
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	layout.add_child(header)
	Kit.art(header, "mountain", 44, true)
	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	header.add_child(title)
	close_button = button(header, "Закрыть · Esc   ×", close_panel)
	var divider = HSeparator.new()
	layout.add_child(divider)
	var workspace = HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 24)
	layout.add_child(workspace)
	sidebar = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 204
	sidebar.add_theme_constant_override("separation", 10)
	workspace.add_child(sidebar)
	for entry in [["camp", "Лагерь", "Текущая стоянка"], ["projects", "Проекты", "Задания и заказы"], ["crew", "Команда", "Люди в путешествии"], ["upgrades", "Улучшения", "Машина и снаряжение"], ["journal", "Дневник", "События и места"], ["settings", "Настройки", "Игра и управление"]]:
		var key = str(entry[0])
		var b = button(sidebar, "  %s\n  %s" % [entry[1], entry[2]], func(): open_panel(key))
		Kit.button_content(b, key, "%s\n%s" % [entry[1], entry[2]])
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 31)
		b.add_theme_font_size_override("font_size", 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 64
		nav_buttons[key] = b
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(spacer)
	Kit.art(sidebar, "mountain", 46, true)
	text(sidebar, "БОЛЬШИЕ МЕСТА\nНАЧИНАЮТСЯ\nС МАЛЕНЬКИХ ШАГОВ", 11)
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 9)
	workspace.add_child(right)
	info = Label.new()
	info.custom_minimum_size.y = 20
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_color_override("font_color", Kit.MUTED)
	right.add_child(info)
	var wallet = HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 10)
	right.add_child(wallet)
	for i in range(5):
		var tile = PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wallet.add_child(tile)
		var line = HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		tile.add_child(line)
		Kit.art(line, ["money", "energy", "food", "water", "signal"][i], 25, i == 0)
		var label = text(line, "", 15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resource_cards.append(label)
	content_scroll = ScrollContainer.new()
	content_scroll.name = "PanelScroll"
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(content_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 9)
	content_scroll.add_child(content)
	overlay.hide()
	sleep_cover = ColorRect.new()
	sleep_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sleep_cover.color = Color(0.02, 0.03, 0.06, 0)
	sleep_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sleep_cover)

func configure_mobile_layout():
	if not is_instance_valid(game.touch_controls) or not game.touch_controls.enabled: return
	var view = get_viewport_rect().size
	var portrait = view.y > view.x
	var factor = 2.7 if portrait else 1.45
	overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	overlay.position = Vector2.ZERO
	overlay.size = view / factor
	overlay.scale = Vector2.ONE * factor
	body.offset_left = 10
	body.offset_right = -10
	body.offset_top = 10
	body.offset_bottom = -10
	sidebar.custom_minimum_size.x = 125 if portrait else 160
	resource_cards[0].get_parent().get_parent().get_parent().hide()
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(45, 45)
	var names = {"camp": "Лагерь", "projects": "Проекты", "crew": "Команда", "upgrades": "Улучшения", "journal": "Дневник", "settings": "Настройки"}
	for key in nav_buttons:
		var button_node: Button = nav_buttons[key]
		button_node.custom_minimum_size.y = 50 if portrait else 58
		Kit.caption(button_node, names[key])

func style(panel: Control):
	panel.add_theme_stylebox_override("panel", Kit.box(false, 14))
func text(parent: Node, value: String, size: int = 18) -> Label:
	var label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("eee9d7"))
	parent.add_child(label)
	return label

func button(parent: Node, value: String, action: Callable) -> Button:
	var b = Button.new()
	b.text = value
	b.custom_minimum_size.y = 36
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func row() -> HBoxContainer:
	var result = HBoxContainer.new()
	result.add_theme_constant_override("separation", 10)
	content.add_child(result)
	return result

func _process(dt: float):
	if not is_instance_valid(game.ui): return
	resource_text.hide()
	actions.hide()
	state_text.visible = game.started and not game.photo and not overlay.visible and not game.paused
	refresh_clock += dt
	if refresh_clock < 0.2: return
	refresh_clock = 0
	screens.refresh()
	var s = game.model
	var values = ["%d ₽" % game.money, "%.0f%%\n%+.1f/мин" % [s.percent(), (game.resources.generation-game.resources.consumption)*60], "Еда\n%.1f / %.0f" % [s.food,s.stock_capacity()], "Вода\n%.1f / %.0f" % [s.water,s.stock_capacity()], "Интернет\n%d Мбит/с" % game.signal_speed]
	for i in range(resource_cards.size()): resource_cards[i].text = values[i]
	resource_text.text = "ДЕНЬ %d · %s · до %s %02d:%02d\nЗАРЯД %.0f%% (%+.1f/мин)     ЕДА %.1f/%.0f     ВОДА %.1f/%.0f" % [s.day(), s.phase_name(), "рассвета" if s.is_night() else "ночи", int((s.until_dawn() if s.is_night() else s.until_night()) / 60), int(s.until_dawn() if s.is_night() else s.until_night()) % 60, s.percent(), (game.resources.generation - game.resources.consumption) * 60 / s.capacity() * 100, s.food, s.stock_capacity(), s.water, s.stock_capacity()]
	state_text.text = game.auto_controller.status if game.autopilot else "Лагерь · " + {"auto": "Авто", "supplies": "Пополнение запасов", "work": "Работа"}[s.camp_mode] + " [B]" if game.camping else ""
	if game.packing_camp: state_text.text = "Все в машину · выезд через %.0f с" % maxf(0, ceilf(1.5 - game.packing_clock))
	if game.projects.active.get("pending", false): state_text.text += "  ·  Команда ждёт решения по проекту [P]"
	if overlay.visible:
		info.text = "День %d · %s   |   %s" % [s.day(), s.phase_name(), "Время остановлено" if freezes else "Команда продолжает жизнь лагеря"]
		if section == "projects":
			if panel_version != project_version():
				freezes = not game.camping or (game.projects.active.get("pending", false) and not game.model.auto_projects)
				build_panel()
			if is_instance_valid(project_progress) and not game.projects.active.is_empty(): project_progress.text = project_caption()
		if section == "camp" and is_instance_valid(camp_status): camp_status.text = game.crew_system.status_text()
		if section == "camp" and is_instance_valid(sleep_button): sleep_button.disabled = not s.is_night() or game.pending_sleep
		if section == "crew":
			for i in range(hero_labels.size()): hero_labels[i].text = hero_caption(game.model.crew[i])
	if get_viewport_rect().size.x < 900:
		body.offset_left = 12
		body.offset_right = -12

func open_panel(kind: String):
	if kind != "editor" and not game.started: return
	game.release_mouse()
	section = kind
	freezes = kind in ["upgrades", "editor", "rescue", "new", "placement", "settings"] or not game.camping or (kind == "projects" and bool(game.projects.active.get("pending", false)) and game.camping)
	overlay.show()
	build_panel()

func close_panel():
	screens.close_preview()
	overlay.hide()
	freezes = false
	game.save_game()

func build_panel():
	screens.reset_bindings()
	for key in nav_buttons: nav_buttons[key].add_theme_stylebox_override("normal", Kit.box(key == section or (key == "camp" and section == "placement")))
	panel_version = project_version()
	project_progress = null
	camp_status = null
	sleep_button = null
	hero_labels.clear()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	title.text = {"projects": "Передвижная IT-студия", "camp": "Наша стоянка", "crew": "Команда экспедиции", "journal": "Путевой дневник", "upgrades": "Мастерская Буханки", "settings": "Настройки экспедиции", "placement": "Выбор места для лагеря", "editor": "Кто отправится выше облаков?", "rescue": "Помощь из долины", "new": "Новая экспедиция"}.get(section, section)
	if is_instance_valid(game.touch_controls) and game.touch_controls.enabled:
		sidebar.visible = section != "editor"
		title.text = {"editor": "Наша команда", "camp": "Лагерь", "projects": "Проекты", "crew": "Команда", "journal": "Дневник", "upgrades": "Улучшения", "settings": "Настройки"}.get(section, title.text)
	match section:
		"projects": build_projects()
		"camp": screens.build_camp()
		"shop":
			title.text = "Деревенский магазин"
			screens.build_shop()
		"crew": screens.build_crew()
		"editor": screens.build_editor()
		"upgrades": screens.build_upgrades()
		"placement": screens.build_placement()
		"settings": screens.build_settings()
		"journal": screens.build_journal()
		"rescue":
			text(content, "Помощь стоит 1500 ₽. Если денег не хватит, остаток станет долгом без процентов. Из следующих заказов 25% пойдёт на погашение.\n\nВы получите минимум 35 единиц заряда и по 6 единиц еды и воды. Пройдёт половина суток, репутация снизится на 5.")
			button(content, "Вызвать помощь за 1500 ₽", func(): game.resources.rescue(game); close_panel())
		"new":
			text(content, "Текущее путешествие будет сохранено отдельной резервной копией. Новая команда начнёт с 1500 ₽, полным зарядом и базовым снаряжением.")
			button(content, "Начать новую экспедицию", func(): game.new_expedition())

func build_projects():
	var auto = CheckButton.new()
	auto.text = "Автоуправление проектами"
	auto.button_pressed = game.model.auto_projects
	auto.toggled.connect(func(on): game.model.auto_projects = on; game.save_game(); open_panel("projects"))
	content.add_child(auto)
	var p = game.projects
	if p.active.is_empty():
		p.on_calendar(game)
		text(content, "Следующий заказ для команды", 25)
		text(content, "Один проект за раз. Выбирайте по профессиям команды, сроку и оплате.", 16)
		var offers = row()
		for offer in p.offers:
			var card = Kit.card(offers)
			Kit.art(card, "projects", 64)
			text(card, offer.title, 22)
			text(card, game.model.ROLES[offer.role], 16).add_theme_color_override("font_color", Kit.TEAL)
			text(card, "%d ₽\nСрок: %s" % [offer.reward, "%d ч" % roundi(offer.duration * 24) if offer.duration < 1 else "%d дн." % roundi(offer.duration)], 20)
			text(card, ["Небольшая задача на полдня", "Спокойный заказ на день", "Большой заказ на два дня"][int(offer.size)], 15)
			var id = str(offer.id)
			button(card, "Взять заказ   ›", func(): p.accept(id, game); open_panel("projects"))
	else:
		var card = Kit.card(content)
		project_progress = text(card, project_caption(), 23)
		Kit.meter(card, game.work_progress * 100, "Выполнение заказа")
		text(card, "Качество %.0f   ·   Риск %.0f   ·   Этап %d" % [p.active.quality, p.active.risk, p.active.stage + 1], 17)
		if p.active.failed:
			text(card, p.last_result)
			button(card, "Исправить (+35% работы)", func(): p.rework(game); build_panel()).disabled = p.active.reworked
			button(card, "Закрыть заказ с компенсацией", func(): p.abandon(game); build_panel())
		elif p.active.pending:
			text(content, p.decision_text(), 23)
			if not game.camping: text(content, "Остановитесь в лагере, чтобы обсудить решение.")
			var choices = row()
			for choice in p.choices():
				var option = Kit.card(choices)
				Kit.art(option, "projects", 38, true)
				text(option, choice.title, 21)
				text(option, "%d ₽\nТруд %+.0f%%\nКачество %+d\nРиск %+d" % [choice.cost, choice.effort * 100, choice.quality, choice.risk], 17)
				var id = str(choice.id)
				button(option, "Принять решение", func(): p.resolve_decision(id, game); open_panel("projects")).disabled = not game.camping or game.money < choice.cost
		else:
			text(card, "Команда выполняет этап. Следующее обсуждение появится здесь.", 16)
	if not p.last_result.is_empty(): text(content, "Последний результат: " + p.last_result, 16)
func build_camp():
	if not game.camping:
		text(content, "Выберите сухую ровную площадку. Лагерь раскрывает солнечные панели и позволяет обсудить проект.")
		button(content, "Разбить лагерь", func(): game.toggle_camp(); build_panel())
	else:
		var available: Array = []
		for source in game.crew_system.sources:
			var label = {"food": "ягоды/яблоки", "water": "вода", "fishing": "рыбалка"}[source.kind]
			if not available.has(label): available.append(label)
		text(content, "Рядом: %s\nСолнечная генерация: %.1f ед./мин · связь %d Мбит/с" % [", ".join(available) if not available.is_empty() else "нет доступных источников", game.resources.generation * 60, game.signal_speed])
		var buttons = row()
		sleep_button = button(buttons, "Спать до рассвета", sleep)
		sleep_button.disabled = not game.model.is_night()
		button(buttons, "Свернуть лагерь", func(): game.toggle_camp(); close_panel())
		var modes = row()
		for entry in [["Авто", "auto"], ["Пополнить запасы", "supplies"], ["Работа", "work"]]:
			var mode = str(entry[1])
			button(modes, entry[0], func(): game.crew_system.set_mode(game, mode); build_panel()).disabled = game.model.camp_mode == mode
		text(content, "Авто: до двух друзей добывают запасы, остальные работают. Пополнение: вся команда занимается запасами. Работа: сбор выключен. Ночью все отдыхают.", 16)
		camp_status = text(content, game.crew_system.status_text(), 18)
		button(content, "Обсудить проект", func(): open_panel("projects"))
		if game.world.near_village(game.van.position):
			text(content, "Деревенский магазин", 22)
			for item in [["8 порций еды · 400 ₽", "food", 400, 8], ["8 л воды · 160 ₽", "water", 160, 8], ["Зарядка +60 · 300 ₽ / 60 секунд", "energy", 300, 60]]:
				var key = str(item[1])
				var cost = int(item[2])
				var amount = float(item[3])
				button(content, item[0], func(): game.shop_purchase(key, cost, amount); build_panel()).disabled = game.money < cost
	button(content, "Снаряжение и улучшения", func(): open_panel("upgrades"))
	button(content, "Вызвать помощь…", func(): open_panel("rescue"))
	button(content, "Новая экспедиция…", func(): open_panel("new"))

func dropdown(parent: Node, entries: Array, selected: int, action: Callable):
	var menu = OptionButton.new()
	for entry in entries: menu.add_item(str(entry))
	menu.select(selected)
	menu.item_selected.connect(action)
	menu.custom_minimum_size.y = 38
	parent.add_child(menu)

func build_crew(editor: bool):
	if editor: text(content, "Можно оставить нашу четвёрку или изменить имена, внешность, роли и таланты. Повторяющиеся профессии разрешены.")
	for i in range(4):
		var hero = game.model.crew[i]
		if editor:
			var fields = row()
			var name_edit = LineEdit.new()
			name_edit.text = hero.name
			name_edit.max_length = 20
			name_edit.custom_minimum_size.x = 150
			name_edit.text_changed.connect(func(value): hero.name = value.strip_edges())
			fields.add_child(name_edit)
			dropdown(fields, game.model.ROLES, hero.role, func(value): hero.role = value)
			dropdown(fields, game.model.TALENTS, hero.talent, func(value): hero.talent = value)
			var looks = row()
			dropdown(looks, ["Охра", "Голубой", "Терракота", "Зелёный"], hero.shirt, func(value): hero.shirt = value)
			dropdown(looks, ["Кожа 1", "Кожа 2", "Кожа 3", "Кожа 4"], hero.skin, func(value): hero.skin = value)
			dropdown(looks, ["Коротко", "Кудри", "Шапка", "Кепка"], hero.hair, func(value): hero.hair = value)
			dropdown(content, game.model.TRAITS, hero.trait, func(value): hero.trait = value)
		else:
			hero_labels.append(text(content, hero_caption(hero), 19))
			var tasks = row()
			var unlocked = (1 if game.model.level(hero.xp) >= 3 else 0) + (1 if game.model.level(hero.xp) >= 5 else 0)
			if hero.perks.size() < unlocked:
				button(tasks, "Талант: надёжность", func(): hero.perks.append("safe"); game.save_game(); build_panel())
				button(tasks, "Талант: скорость", func(): hero.perks.append("speed"); game.save_game(); build_panel())
	if editor:
		button(content, "Отправиться в путь", func():
			for hero in game.model.crew:
				if str(hero.name).is_empty(): hero.name = "Друг"
			game.model.configured = true
			game.van.rebuild_crew(game.model)
			close_panel()
			game.start_trip()
		)
	else:
		var voice_toggle = CheckButton.new()
		voice_toggle.text = "Голоса друзей"
		voice_toggle.button_pressed = game.model.voices_enabled
		voice_toggle.toggled.connect(func(on): game.model.voices_enabled = on)
		content.add_child(voice_toggle)
		var volume = HSlider.new()
		volume.min_value = 0
		volume.max_value = 1
		volume.step = 0.05
		volume.value = game.model.voice_volume
		volume.value_changed.connect(func(value): game.model.voice_volume = value)
		content.add_child(volume)

func build_upgrades():
	for i in range(3):
		var index = i
		button(content, "%s · уровень %d/3 · %d ₽" % [["Проходимость", "Дом в машине", "Starlink"][i], game.levels[i], game.upgrade_cost(i)], func(): game.buy_upgrade(index); build_panel()).disabled = game.levels[i] >= 3 or game.money < game.upgrade_cost(i)
	button(content, "Лагерь · уровень %d/3 · %d ₽" % [game.camp_level, game.camp_upgrade_cost()], func(): game.buy_camp_upgrade(); build_panel()).disabled = game.camp_level >= 3 or game.money < game.camp_upgrade_cost()
	for key in game.model.upgrades:
		var id = str(key)
		var label = {"battery": "Батарея", "roof": "Панели на крыше", "panels": "Панели лагеря", "kitchen": "Походная кухня", "storage": "Фильтр и хранение", "fishing": "Рыболовный комплект"}[id]
		button(content, "%s · уровень %d/3 · %d ₽" % [label, game.model.upgrades[id], game.rpg_upgrade_cost(id)], func(): game.buy_rpg_upgrade(id); build_panel()).disabled = game.model.upgrades[id] >= 3 or game.money < game.rpg_upgrade_cost(id)

func sleep():
	if not game.model.is_night(): return
	close_panel()
	var report = game.resources.sleep_until_dawn(game)
	if not report.is_empty():
		sleep_cover.color.a = 1.0
		create_tween().tween_property(sleep_cover, "color:a", 0.0, 1.2)

func toggle_cinema():
	if not game.autopilot and not game.camping:
		game.toast("Кино доступно в лагере или с автопилотом [J].")
		return
	game.model.cinematic = not game.model.cinematic
	game.toast("Кино: " + ("включено" if game.model.cinematic else "выключено"))

func project_version() -> String:
	var p = game.projects
	return "%s:%s:%s:%s:%s" % [p.active.get("id", ""), p.active.get("stage", 0), p.active.get("pending", false), p.active.get("failed", false), p.offer_day]

func project_caption() -> String:
	var a = game.projects.active
	return "%s\nГотово %.0f%% · оплата %d ₽ · осталось %.1f суток" % [a.title, 100 * float(a.progress) / maxf(1, a.effort), a.reward, (float(a.deadline) - game.model.simulation_seconds) / 1200]

func hero_caption(hero: Dictionary) -> String:
	return "%s · %s · %s\nIT %d · Поход %d · бодрость %.0f · настроение %.0f · %s" % [hero.name, game.model.ROLES[hero.role], game.model.TALENTS[hero.talent], game.model.level(hero.xp), game.model.level(hero.outdoor_xp), hero.energy, hero.mood, hero.activity]

func _unhandled_key_input(event):
	if not event is InputEventKey or not event.pressed or event.echo: return
	if overlay.visible and event.physical_keycode == KEY_ESCAPE:
		close_panel()
		get_viewport().set_input_as_handled()
