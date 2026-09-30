extends RefCounted
## Phone panels: compact content, one scroll surface, pinned primary actions.
const Kit = preload("res://scripts/ui_kit.gd")
var ui: Control
var owner_ref: WeakRef
var screens: RefCounted:
	get: return owner_ref.get_ref()
var editor_index = 0
var editor_details = false
var settings_details = false
var offer_index = 0

func setup(owner: RefCounted):
	owner_ref = weakref(owner)
	ui = owner.ui

func line(parent: Node) -> HBoxContainer:
	var result = HBoxContainer.new()
	result.add_theme_constant_override("separation", 6)
	parent.add_child(result)
	return result

func option(parent: Node, entries: Array, selected: int, action: Callable) -> OptionButton:
	var result = screens.compact_option(parent, entries, selected, action)
	var image = Kit.icon("down").get_image()
	image.resize(16, 16, Image.INTERPOLATE_LANCZOS)
	result.add_theme_icon_override("arrow", ImageTexture.create_from_image(image))
	var popup = result.get_popup()
	var popup_style = Kit.box(false, 8)
	popup_style.bg_color.a = 1
	popup.add_theme_stylebox_override("panel", popup_style)
	popup.add_theme_stylebox_override("hover", Kit.box(true, 6))
	popup.add_theme_color_override("font_color", Kit.TEXT)
	popup.add_theme_color_override("font_hover_color", Kit.TEAL)
	popup.add_theme_constant_override("v_separation", 28)
	result.item_selected.disconnect(action)
	result.item_selected.connect(func(index): if not ui.scroll_dragging: action.call(index))
	return result

func build_upgrades():
	var g = ui.game
	var labels = ["Вездеход", "Дом на колёсах", "Энергия и связь", "Экспедиция", "Модули лагеря"]
	option(ui.sticky_toolbar, labels, screens.category, func(index): screens.category = index; ui.build_panel()).name = "UpgradeCategory"
	var category = screens.category
	if category == 4:
		for key in g.model.upgrades:
			var id = str(key)
			var card = Kit.card(ui.content)
			ui.text(card, "%s · %d/3" % [{"battery": "Батарея", "roof": "Панели на крыше", "panels": "Панели лагеря", "kitchen": "Походная кухня", "storage": "Фильтр и хранение", "fishing": "Рыболовный комплект"}[id], g.model.upgrades[id]], 15)
			ui.button(card, "Улучшить · %d руб." % g.rpg_upgrade_cost(id), func(): g.buy_rpg_upgrade(id); ui.build_panel()).disabled = g.model.upgrades[id] >= 3 or g.money < g.rpg_upgrade_cost(id)
		ui.button(ui.content, "Навес · %d/3 · %d руб." % [g.camp_level, g.camp_upgrade_cost()], func(): g.buy_camp_upgrade(); ui.build_panel()).disabled = g.camp_level >= 3 or g.money < g.camp_upgrade_cost()
		return
	var level = g.levels[category]
	var card = Kit.card(ui.content)
	var heading = line(card)
	Kit.art(heading, ["upgrades", "home", "signal", "journal"][category], 28)
	ui.text(heading, "%s · %d/3" % [labels[category], level], 17).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.text(card, ["Сцепление и проходимость на сложном грунте.", "Комфорт и восстановление команды.", "Быстрый интернет и связь в непогоду.", "Автономность и походное снаряжение."][category], 13)
	var names = [["Шины", "Лифт", "Блокировки"], ["Спальное место", "Кухня", "Жилой модуль"], ["Starlink", "Защита связи", "Starlink Pro"], ["Багаж", "Инструменты", "Экспедиция"]][category]
	ui.text(card, "Следующее: " + names[mini(level, 2)] if level < 3 else "Всё установлено", 18)
	var cost = g.upgrade_cost(category)
	var buy = ui.button(ui.sticky_footer, "Установить · %d руб." % cost if level < 3 else "Максимальный уровень", func(): g.buy_upgrade(category); ui.build_panel())
	buy.name = "BuyUpgrade"
	buy.disabled = level >= 3 or g.money < cost
	if level < 3 and g.money < cost: ui.text(card, "Не хватает %d руб. · выполняйте заказы команды" % (cost - g.money), 12)

func build_crew():
	var g = ui.game
	var grid = GridContainer.new()
	grid.columns = 2 if ui.mobile_portrait else 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	ui.content.add_child(grid)
	for hero in g.model.crew:
		var card = Kit.card(grid)
		ui.text(card, hero.name, 17)
		ui.text(card, g.model.ROLES[hero.role], 12)
		screens.live_label(card, func(): return "Энергия %.0f%%\nНастроение %.0f%%" % [hero.energy, hero.mood], 12)
		screens.live_label(card, func(): return hero.activity, 12).max_lines_visible = 2
		ui.text(card, "IT %d · Поход %d" % [g.model.level(hero.xp), g.model.level(hero.outdoor_xp)], 11)
		var unlocked = (1 if g.model.level(hero.xp) >= 3 else 0) + (1 if g.model.level(hero.xp) >= 5 else 0)
		if hero.perks.size() < unlocked:
			option(card, ["Новый талант…", "Надёжность +", "Скорость +"], 0, func(index):
				if index > 0:
					hero.perks.append("safe" if index == 1 else "speed")
					g.save_game()
					ui.build_panel()
			)

func build_editor():
	var g = ui.game
	var selector = line(ui.sticky_toolbar)
	for i in range(4):
		var index = i
		var b = ui.button(selector, str(g.model.crew[i].name), func(): editor_index = index; ui.build_panel())
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.clip_text = true
		b.custom_minimum_size.x = 44
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", Kit.box(i == editor_index, 6))
	var hero = g.model.crew[editor_index]
	var card = Kit.card(ui.content)
	if ui.mobile_portrait and ui.overlay.size.y >= 500 and not editor_details: screens.person_preview(card, hero, 90)
	var name_edit = LineEdit.new()
	name_edit.text = hero.name
	name_edit.placeholder_text = "Имя друга"
	name_edit.max_length = 20
	name_edit.custom_minimum_size.y = 44
	name_edit.text_changed.connect(func(value): hero.name = value.strip_edges())
	card.add_child(name_edit)
	var roles = line(card)
	option(roles, g.model.ROLES, hero.role, func(value): hero.role = value)
	option(roles, g.model.TALENTS, hero.talent, func(value): hero.talent = value)
	ui.button(card, "Внешность и характер  " + ("−" if editor_details else "+"), func(): editor_details = not editor_details; ui.build_panel())
	if editor_details:
		var viewport = screens.person_preview(card, hero, 90)
		option(card, ["Одежда: охра", "Одежда: голубой", "Одежда: терракота", "Одежда: зелёный"], hero.shirt, func(value): hero.shirt = value; screens.rebuild_person_preview(viewport, hero))
		var looks = line(card)
		option(looks, ["Кожа 1", "Кожа 2", "Кожа 3", "Кожа 4"], hero.skin, func(value): hero.skin = value; screens.rebuild_person_preview(viewport, hero))
		option(looks, ["Коротко", "Кудри", "Шапка", "Кепка"], hero.hair, func(value): hero.hair = value; screens.rebuild_person_preview(viewport, hero))
		option(card, g.model.TRAITS, hero.trait, func(value): hero.trait = value)
	ui.text(ui.content, "Готовая команда уже собрана. Настраивайте друзей по желанию.", 12)
	var start = ui.button(ui.sticky_footer, "Отправиться в путь   ›", func():
		for person in g.model.crew:
			if str(person.name).is_empty(): person.name = "Друг"
		g.model.configured = true
		g.van.rebuild_crew(g.model)
		ui.close_panel()
		g.start_trip()
	)
	start.name = "StartExpedition"
	start.custom_minimum_size.y = 48
	start.add_theme_stylebox_override("normal", Kit.box(true, 6))

func build_settings():
	var g = ui.game
	var card = Kit.card(ui.content)
	var quality = option(card, g.graphics.TITLES, g.graphics.PRESETS.find(g.graphics.preset), func(index): g.graphics.choose(g.graphics.PRESETS[index]); ui.build_panel())
	quality.name = "GraphicsPreset"
	ui.text(card, g.graphics.description(), 12)
	screens.live_label(card, func(): return g.graphics.status(), 12)
	var toggles = line(card)
	for entry in [["Тени", "shadows", "GraphicsShadows"], ["Эффекты", "nature", "GraphicsNature"]]:
		var key = str(entry[1])
		var check = CheckButton.new()
		check.name = entry[2]
		check.text = entry[0]
		check.custom_minimum_size.y = 44
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.button_pressed = g.graphics.get(key)
		check.toggled.connect(func(on):
			if ui.scroll_dragging: check.set_pressed_no_signal(g.graphics.get(key)); return
			if key == "shadows": g.graphics.set_shadows(on)
			else: g.graphics.set_nature(on)
		)
		toggles.add_child(check)
	if g.graphics.preset != "auto":
		ui.text(card, "Чёткость картинки", 12)
		var clarity = HSlider.new()
		clarity.name = "GraphicsClarity"
		clarity.min_value = 0.6
		clarity.max_value = 1
		clarity.step = 0.05
		clarity.value = g.graphics.scale
		clarity.custom_minimum_size.y = 44
		ui.bind_scroll_slider(clarity, func(): return g.graphics.scale, func(value): g.graphics.set_scale(value))
		card.add_child(clarity)
	ui.button(ui.content, "Звук и путешествие  " + ("−" if settings_details else "+"), func(): settings_details = not settings_details; ui.build_panel())
	if settings_details:
		var extra = Kit.card(ui.content)
		var voices = CheckButton.new()
		voices.text = "Голоса друзей"
		voices.custom_minimum_size.y = 44
		voices.button_pressed = g.model.voices_enabled
		voices.toggled.connect(func(on):
			if ui.scroll_dragging: voices.set_pressed_no_signal(g.model.voices_enabled); return
			g.model.voices_enabled = on
			g.save_game()
		)
		extra.add_child(voices)
		var volume = HSlider.new()
		volume.name = "VoiceVolume"
		volume.max_value = 1
		volume.step = 0.05
		volume.value = g.model.voice_volume
		volume.custom_minimum_size.y = 44
		ui.bind_scroll_slider(volume, func(): return g.model.voice_volume, func(value): g.model.voice_volume = value)
		extra.add_child(volume)
		ui.button(extra, "Переключить общий звук", func(): g.toggle_sound())
		ui.button(extra, "Кинокамера", ui.toggle_cinema)
		if OS.has_feature("web"):
			ui.button(extra, "Проверить обновление", func(): JavaScriptBridge.eval("window.bukhankaCheckUpdate && window.bukhankaCheckUpdate()"))
	ui.button(ui.content, "Как играть", func(): ui.close_panel(); g.tutorial.open())

func build_camp():
	var g = ui.game
	var project = Kit.card(ui.content)
	screens.live_label(project, func(): return g.projects.active.get("title", "Команда готова к новому заказу"), 16)
	if not g.projects.active.is_empty(): screens.live_meter(project, func(): return g.work_progress * 100, "Проект")
	ui.button(project, "Проекты   ›", func(): ui.open_panel("projects"))
	if g.camping:
		option(ui.content, ["Лагерь: авто", "Лагерь: запасы", "Лагерь: работа"], ["auto", "supplies", "work"].find(g.model.camp_mode), func(index): g.crew_system.set_mode(g, ["auto", "supplies", "work"][index]))
		ui.camp_status = ui.text(ui.content, g.crew_system.status_text(), 12)
		ui.camp_status.max_lines_visible = 2
		var actions = line(ui.sticky_footer)
		ui.sleep_button = ui.button(actions, "До рассвета", ui.sleep)
		ui.sleep_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ui.sleep_button.disabled = not g.model.is_night()
		ui.button(actions, "Свернуть лагерь", func(): g.toggle_camp(); ui.close_panel()).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else: ui.button(ui.sticky_footer, "Выбрать место лагеря", func(): ui.open_panel("placement"))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	ui.content.add_child(grid)
	for entry in [["upgrades", "Снаряжение", "upgrades"], ["signal", "Помощь", "rescue"], ["journal", "Новый путь", "new"]]:
		var target = str(entry[2])
		var b = ui.button(grid, entry[1], func(): ui.open_panel(target))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Kit.button_content(b, entry[0], entry[1])
	if g.camping and g.world.near_village(g.van.position): ui.button(grid, "Магазин", func(): ui.open_panel("shop"))

func build_projects():
	var g = ui.game
	var p = g.projects
	var auto = CheckButton.new()
	auto.text = "Автоуправление заказами"
	auto.custom_minimum_size.y = 44
	auto.button_pressed = g.model.auto_projects
	auto.toggled.connect(func(on):
		if ui.scroll_dragging: auto.set_pressed_no_signal(g.model.auto_projects); return
		g.model.auto_projects = on
		g.save_game()
		ui.open_panel("projects")
	)
	ui.content.add_child(auto)
	if p.active.is_empty():
		p.on_calendar(g)
		if p.offers.is_empty(): return
		offer_index = clampi(offer_index, 0, p.offers.size() - 1)
		var titles: Array = []
		for offer in p.offers: titles.append(offer.title)
		option(ui.content, titles, offer_index, func(index): offer_index = index; ui.build_panel())
		var offer = p.offers[offer_index]
		var card = Kit.card(ui.content)
		ui.text(card, g.model.ROLES[offer.role], 15)
		ui.text(card, "%d руб. · срок %s" % [offer.reward, "%d ч" % roundi(offer.duration * 24) if offer.duration < 1 else "%d дн." % roundi(offer.duration)], 18)
		ui.text(card, ["Небольшая задача на полдня", "Спокойный заказ на день", "Большой заказ на два дня"][int(offer.size)], 13)
		var id = str(offer.id)
		ui.button(ui.sticky_footer, "Взять заказ", func(): p.accept(id, g); ui.open_panel("projects"))
	else:
		var card = Kit.card(ui.content)
		ui.project_progress = ui.text(card, ui.project_caption(), 16)
		screens.live_meter(card, func(): return g.work_progress * 100, "Выполнение")
		ui.text(card, "Качество %.0f · риск %.0f · этап %d" % [p.active.quality, p.active.risk, p.active.stage + 1], 12)
		if p.active.failed:
			ui.text(card, p.last_result, 14)
			ui.button(ui.sticky_footer, "Исправить (+35% работы)", func(): p.rework(g); ui.build_panel()).disabled = p.active.reworked
			ui.button(ui.sticky_footer, "Закрыть с компенсацией", func(): p.abandon(g); ui.build_panel())
		elif p.active.pending:
			ui.text(ui.content, p.decision_text(), 16)
			if not g.camping: ui.text(ui.content, "Обсудите решение в лагере.", 13)
			for choice in p.choices():
				var id = str(choice.id)
				ui.button(ui.content, "%s · %d руб." % [choice.title, choice.cost], func(): p.resolve_decision(id, g); ui.open_panel("projects")).disabled = not g.camping or g.money < choice.cost
	ui.panel_version = ui.project_version()

func build_journal():
	var g = ui.game
	ui.text(ui.content, "Цель маршрута", 18)
	var shown: Array = []
	for place in g.world.director.near_z(g.van.position.z):
		if place.z < g.van.position.z + 60 or place.kind not in ["lake", "village", "waterfall"] or shown.has(place.kind): continue
		shown.append(place.kind)
		var name = {"lake": "Горное озеро", "village": "Деревня", "waterfall": "Водопад"}[place.kind]
		var target = {"id": place.id, "title": name, "x": place.x, "z": place.z}
		var b = ui.button(ui.content, "%s · %.1f км" % [name, Vector2(place.x-g.van.position.x, place.z-g.van.position.z).length()/1000], func(): g.model.destination = target; g.save_game(); ui.close_panel(); g.toast("Цель: " + target.title))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	ui.text(ui.content, "Дневник · %d открытий" % g.discoveries.size(), 16)
	var entries = g.model.journal.duplicate()
	entries.reverse()
	var pages = maxi(1, ceili(entries.size() / 3.0))
	screens.journal_page = clampi(screens.journal_page, 0, pages - 1)
	for entry in entries.slice(screens.journal_page * 3, (screens.journal_page + 1) * 3):
		var label = ui.text(ui.content, str(entry), 12)
		label.max_lines_visible = 2
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if pages > 1:
		var pager = line(ui.content)
		ui.button(pager, "‹ Новее", func(): screens.journal_page -= 1; ui.build_panel()).disabled = screens.journal_page == 0
		ui.text(pager, "%d/%d" % [screens.journal_page + 1, pages], 12).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ui.button(pager, "Старее ›", func(): screens.journal_page += 1; ui.build_panel()).disabled = screens.journal_page == pages - 1
