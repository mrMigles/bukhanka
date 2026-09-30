extends RefCounted
const Kit = preload("res://scripts/ui_kit.gd")
var ui: Control
var bindings: Array = []
var category = 0
var journal_page = 0
var album_page = 0
var preview: SubViewport
var preview_camera: Camera3D
var ghost: MeshInstance3D
var candidate = Vector3.ZERO
var angle = 0.0
var assessment: Dictionary = {}
var dirty = false
var dragging = false
var place_button: Button
var assessment_label: Label

func reset_bindings():
	bindings.clear()
	close_preview()

func close_preview():
	if is_instance_valid(ghost): ghost.queue_free()
	ghost = null
	if is_instance_valid(preview): preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
	dragging = false

func live_label(parent: Node, getter: Callable, size: int = 17) -> Label:
	var label = ui.text(parent, str(getter.call()), size)
	bindings.append({"node": label, "getter": getter, "property": "text"})
	return label

func live_meter(parent: Node, getter: Callable, caption: String):
	var bar = Kit.meter(parent, getter.call(), caption)
	bindings.append({"node": bar, "getter": getter, "property": "value"})

func refresh():
	if not ui.overlay.visible: return
	for binding in bindings:
		if is_instance_valid(binding.node): binding.node.set(binding.property, binding.getter.call())
	if ui.section == "placement" and dirty: assess()

func project_card(parent: Node):
	var g = ui.game
	var card = Kit.card(parent)
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	card.add_child(header)
	Kit.art(header, "mountain", 38, true)
	var copy = VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(copy)
	live_label(copy, func(): return g.projects.active.get("title", "Выберите следующий проект"), 23)
	ui.text(copy, "Удалёнка на колёсах", 14)
	live_meter(card, func(): return g.work_progress * 100, "Текущий проект")
	live_label(card, func():
		var a = g.projects.active
		return "Три предложения ждут команду. Выбирайте задачу и обсуждайте решения в лагере." if a.is_empty() else "Готово %.0f%%   ·   Оплата %d ₽   ·   Качество %.0f   ·   Осталось %.1f суток" % [g.work_progress * 100, a.reward, a.quality, (a.deadline - g.model.simulation_seconds) / 1200.0]
	, 16)
	ui.button(card, "Детали проекта   ›", func(): ui.open_panel("projects"))

func action_card(parent: Node, icon: String, title: String, description: String, action: Callable):
	var card = Kit.card(parent)
	Kit.art(card, icon, 28, true)
	ui.text(card, title, 19)
	ui.text(card, description, 14)
	ui.button(card, "Открыть   ›", action)

func build_camp():
	var g = ui.game
	project_card(ui.content)
	ui.text(ui.content, "Управление лагерем", 21)
	if g.camping:
		var modes = ui.row()
		for entry in [["Авто", "auto"], ["Пополнить запасы", "supplies"], ["Работа", "work"]]:
			var key = str(entry[1])
			var b = ui.button(modes, entry[0], func(): g.crew_system.set_mode(g, key); ui.build_panel())
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_stylebox_override("normal", Kit.box(g.model.camp_mode == key))
		ui.camp_status = ui.text(ui.content, g.crew_system.status_text(), 14)
		ui.camp_status.max_lines_visible = 4
		ui.camp_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var row = ui.row()
		ui.sleep_button = ui.button(row, "Спать до рассвета", ui.sleep)
		ui.sleep_button.disabled = not g.model.is_night()
		ui.button(row, "Свернуть лагерь", func(): g.toggle_camp(); ui.close_panel())
	else:
		ui.text(ui.content, "Выберите площадку: ровность помогает работе, солнце — зарядке, берег — пополнению воды.", 16)
	var tiles = ui.row()
	if g.camping and g.world.near_village(g.van.position):
		action_card(tiles, "food", "Магазин", "Еда, питьевая вода и зарядка от деревенской розетки.", func(): ui.open_panel("shop"))
	else:
		action_card(tiles, "camp", "Наша стоянка" if g.camping else "Разбить лагерь", "Оценить место и подготовиться к следующему этапу пути.", func(): ui.open_panel("placement") if not g.camping else ui.open_panel("camp"))
	action_card(tiles, "upgrades", "Снаряжение", "Улучшения машины, солнечные панели и походный быт.", func(): ui.open_panel("upgrades"))
	action_card(tiles, "signal", "Позвать помощь", "Эвакуация, резерв энергии и припасы. 1500 ₽ или долг.", func(): ui.open_panel("rescue"))
	action_card(tiles, "journal", "Новая экспедиция", "Сохранить это путешествие и отправиться с новой командой.", func(): ui.open_panel("new"))

func build_shop():
	var g = ui.game
	if not g.camping or not g.world.near_village(g.van.position):
		ui.text(ui.content, "Разбейте лагерь рядом с деревней, чтобы зайти в магазин.", 20)
		ui.button(ui.content, "К стоянке", func(): ui.open_panel("camp"))
		return
	ui.text(ui.content, "Припасы сразу попадут в запас команды. Розетка заряжает по 1 ед./с, пока стоит лагерь.", 17)
	var row = ui.row()
	for entry in [["food", "Еда", 400, 8], ["water", "Питьевая вода", 160, 8], ["energy", "Зарядка", 300, 60]]:
		var item = entry.duplicate()
		var card = Kit.card(row)
		Kit.art(card, item[0], 48)
		ui.text(card, item[1], 22)
		ui.text(card, "До +%d ед. · %d ₽" % [item[3], item[2]], 19)
		live_label(card, func():
			if item[0] == "energy" and g.shop_charge > 0: return "Заряжаем · осталось %.0f ед." % g.shop_charge
			return "В запасе: %.1f / %.0f" % [g.model.get(item[0]), g.model.capacity() if item[0] == "energy" else g.model.stock_capacity()]
		, 16)
		var buy = ui.button(card, "Купить", func(): g.shop_purchase(item[0], item[2], item[3]))
		buy.name = "Buy_" + item[0]
		var disabled = func(): return g.money < item[2] or g.model.get(item[0]) >= (g.model.capacity() if item[0] == "energy" else g.model.stock_capacity()) or (item[0] == "energy" and g.shop_charge > 0)
		buy.disabled = disabled.call()
		bindings.append({"node": buy, "getter": disabled, "property": "disabled"})
	ui.button(ui.content, "Вернуться в лагерь", func(): ui.open_panel("camp"))

func build_crew():
	var g = ui.game
	var top = live_label(ui.content, func():
		var mood = 0.0
		for hero in g.model.crew: mood += hero.mood
		return "4 участника   ·   Настроение команды %.0f%%   ·   В лагере всё распределяется автоматически" % (mood / 4)
	, 15)
	top.add_theme_color_override("font_color", Kit.MUTED)
	var cards = ui.row()
	for i in range(4):
		var hero = g.model.crew[i]
		var card = Kit.card(cards)
		card.add_theme_constant_override("separation", 7)
		person_preview(card, hero, 105)
		ui.text(card, "%s   ·   %s" % [hero.name, g.model.ROLES[hero.role]], 18)
		live_meter(card, func(): return hero.energy, "Энергия")
		live_meter(card, func(): return hero.mood, "Настроение")
		live_label(card, func(): return "●  " + hero.activity, 16)
		ui.text(card, "%s · IT %d · Поход %d" % [g.model.TALENTS[hero.talent], g.model.level(hero.xp), g.model.level(hero.outdoor_xp)], 13)
		var unlocked = (1 if g.model.level(hero.xp) >= 3 else 0) + (1 if g.model.level(hero.xp) >= 5 else 0)
		if hero.perks.size() < unlocked:
			var choose = OptionButton.new()
			choose.add_item("Выбрать талант…")
			choose.add_item("Надёжность +")
			choose.add_item("Скорость +")
			choose.item_selected.connect(func(index):
				if index > 0:
					hero.perks.append("safe" if index == 1 else "speed")
					g.save_game()
					ui.build_panel()
			)
			card.add_child(choose)

func build_editor():
	var g = ui.game
	ui.text(ui.content, "Соберите свою четвёрку или оставьте готовую команду. Модель сразу показывает выбранные цвета и головной убор.", 15)
	var strip = ScrollContainer.new()
	strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if ui.mobile_portrait else ScrollContainer.SCROLL_MODE_AUTO
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if is_instance_valid(g.touch_controls) and g.touch_controls.enabled else ScrollContainer.SCROLL_MODE_DISABLED
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui.content.add_child(strip)
	var cards: BoxContainer = VBoxContainer.new() if ui.mobile_portrait else HBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 10)
	strip.add_child(cards)
	for i in range(4):
		var hero = g.model.crew[i]
		var card = Kit.card(cards, 0 if ui.mobile_portrait else 205)
		card.add_theme_constant_override("separation", 5)
		var viewport = person_preview(card, hero, 125)
		var name_edit = LineEdit.new()
		name_edit.text = hero.name
		name_edit.max_length = 20
		name_edit.placeholder_text = "Имя"
		name_edit.text_changed.connect(func(value): hero.name = value.strip_edges())
		card.add_child(name_edit)
		compact_option(card, g.model.ROLES, hero.role, func(value): hero.role = value)
		compact_option(card, g.model.TALENTS, hero.talent, func(value): hero.talent = value)
		var appearance: BoxContainer = VBoxContainer.new() if ui.mobile_portrait else HBoxContainer.new()
		appearance.add_theme_constant_override("separation", 4)
		card.add_child(appearance)
		compact_option(appearance, ["Охра", "Голубой", "Терракота", "Зелёный"], hero.shirt, func(value): hero.shirt = value; rebuild_person_preview(viewport, hero))
		compact_option(appearance, ["К1", "К2", "К3", "К4"], hero.skin, func(value): hero.skin = value; rebuild_person_preview(viewport, hero))
		compact_option(appearance, ["Коротко", "Кудри", "Шапка", "Кепка"], hero.hair, func(value): hero.hair = value; rebuild_person_preview(viewport, hero))
		compact_option(card, g.model.TRAITS, hero.trait, func(value): hero.trait = value)
		ui.button(card, "Случайный образ", func():
			hero.shirt = randi_range(0, 3)
			hero.skin = randi_range(0, 3)
			hero.hair = randi_range(0, 3)
			rebuild_person_preview(viewport, hero)
		)
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	ui.content.add_child(footer)
	var hint = ui.text(footer, "Повторяющиеся роли разрешены. Внешность можно изменить только перед стартом.", 14)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_instance_valid(g.touch_controls) and g.touch_controls.enabled: hint.hide()
	var start = ui.button(footer, "Отправиться в путь   ›", func():
		for hero in g.model.crew:
			if str(hero.name).is_empty(): hero.name = "Друг"
		g.model.configured = true
		g.van.rebuild_crew(g.model)
		ui.close_panel()
		g.start_trip()
	)
	start.custom_minimum_size = Vector2(255, 52)
	if is_instance_valid(g.touch_controls) and g.touch_controls.enabled:
		start.custom_minimum_size.x = 0
		start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.name = "StartExpedition"
	start.add_theme_stylebox_override("normal", Kit.box(true))

func compact_option(parent: Node, entries: Array, selected: int, action: Callable) -> OptionButton:
	var menu = OptionButton.new()
	for entry in entries: menu.add_item(str(entry))
	menu.select(selected)
	menu.fit_to_longest_item = false
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.custom_minimum_size.y = 32
	if is_instance_valid(ui.game.touch_controls) and ui.game.touch_controls.enabled:
		menu.custom_minimum_size.y = 44
		menu.add_theme_font_size_override("font_size", 14)
	menu.item_selected.connect(action)
	parent.add_child(menu)
	return menu

func person_preview(parent: Node, hero: Dictionary, height: float) -> SubViewport:
	var frame = PanelContainer.new()
	frame.custom_minimum_size = Vector2(120, height)
	frame.add_theme_stylebox_override("panel", Kit.box(false, 0))
	parent.add_child(frame)
	var container = SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(container)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(260, 210)
	viewport.world_3d = World3D.new()
	viewport.transparent_bg = false
	container.add_child(viewport)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("173b3d")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b9d8d2")
	environment.environment.ambient_light_energy = 0.8
	viewport.add_child(environment)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -28, 0)
	light.light_color = Color("ffe0a3")
	light.light_energy = 1.5
	viewport.add_child(light)
	var camera = Camera3D.new()
	camera.position = Vector3(2.2, 1.45, 3.2)
	viewport.add_child(camera)
	camera.look_at(Vector3(0, 0.72, 0))
	camera.fov = 34
	rebuild_person_preview(viewport, hero)
	return viewport

func rebuild_person_preview(viewport: SubViewport, hero: Dictionary):
	var old = viewport.get_node_or_null("Character")
	if is_instance_valid(old): old.free()
	var root = Node3D.new()
	root.name = "Character"
	viewport.add_child(root)
	var maker = preload("res://scripts/van.gd").new()
	var person = preload("res://scripts/crew_visual.gd").create(maker, root, hero)
	person.position = Vector3(0, 0.05, 0)
	preload("res://scripts/crew_visual.gd").animate(person, "Отдыхает", 0.0, false)
	maker.free()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func build_upgrades():
	var g = ui.game
	var categories = ui.row()
	for i in range(4):
		var index = i
		var b = ui.button(categories, ["Вездеход", "Дом", "Энергия и связь", "Экспедиция"][i] + "\n%d / 3" % g.levels[i], func(): category = index; ui.build_panel())
		Kit.button_content(b, ["settings", "home", "energy", "journal"][i], ["Вездеход", "Дом", "Энергия и связь", "Экспедиция"][i] + "\n%d / 3" % g.levels[i], true)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 32)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 86
		b.add_theme_stylebox_override("normal", Kit.box(category == i))
	var modules_button = ui.button(categories, "Модули\nлагеря", func(): category = 4; ui.build_panel())
	modules_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modules_button.add_theme_stylebox_override("normal", Kit.box(category == 4))
	if category == 4:
		build_modules()
		return
	var columns = ui.row()
	var main = Kit.card(columns)
	ui.text(main, ["Подготовка к бездорожью", "Дом на колёсах", "Starlink и связь", "Походное снаряжение"][category], 25)
	ui.text(main, ["Шины, лифт и блокировки повышают сцепление на сложном грунте.", "Жилой модуль повышает комфорт и производительность команды.", "Больше пропускная способность и устойчивее связь в непогоду.", "Развивайте автономность команды и возможности стоянки."][category], 16)
	var levels = HBoxContainer.new()
	levels.add_theme_constant_override("separation", 10)
	main.add_child(levels)
	for tier in range(1, 4):
		var card = Kit.card(levels)
		card.get_parent().add_theme_stylebox_override("panel", Kit.box(tier == g.levels[category] + 1))
		Kit.art(card, ["settings", "home", "signal", "journal"][category], 45)
		ui.text(card, "Уровень %d" % tier, 20)
		ui.text(card, "Установлено" if tier <= g.levels[category] else "Следующий" if tier == g.levels[category] + 1 else "После уровня %d" % (tier - 1), 15)
		ui.text(card, [["Шины", "Лифт", "Блокировки"], ["Спальное место", "Кухня", "Жилой модуль"], ["Starlink", "Защита связи", "Starlink Pro"], ["Багаж", "Инструменты", "Экспедиция"]][category][tier-1], 16)
	var cost = g.upgrade_cost(category)
	var purchase = ui.button(main, "Купить улучшение · %d ₽" % cost if g.levels[category] < 3 else "Максимальный уровень", func(): g.buy_upgrade(category); ui.build_panel())
	purchase.custom_minimum_size.y = 62
	purchase.disabled = g.levels[category] >= 3 or g.money < cost
	var detail = Kit.card(columns, 240)
	ui.text(detail, "Ваша Буханка", 23)
	ui.text(detail, "Экспедиционная версия", 14)
	van_preview(detail)
	live_meter(detail, func(): return g.model.percent(), "Заряд")
	Kit.meter(detail, 40 + g.levels[1] * 20, "Комфорт жилого модуля")
	Kit.meter(detail, 40 + g.levels[0] * 20, "Подготовка к бездорожью")

func build_modules():
	var g = ui.game
	ui.text(ui.content, "Модули лагеря и автономности", 22)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	ui.content.add_child(grid)
	for key in g.model.upgrades:
		var id = str(key)
		var card = Kit.card(grid)
		ui.text(card, {"battery": "Батарея", "roof": "Панели на крыше", "panels": "Панели лагеря", "kitchen": "Походная кухня", "storage": "Фильтр и хранение", "fishing": "Рыболовный комплект"}[id], 18)
		Kit.meter(card, g.model.upgrades[id] / 3.0 * 100, "Уровень %d / 3" % g.model.upgrades[id])
		ui.button(card, "Улучшить · %d ₽" % g.rpg_upgrade_cost(id), func(): g.buy_rpg_upgrade(id); ui.build_panel()).disabled = g.model.upgrades[id] >= 3 or g.money < g.rpg_upgrade_cost(id)
	ui.button(ui.content, "Навес и обустройство лагеря · %d / 3 · %d ₽" % [g.camp_level, g.camp_upgrade_cost()], func(): g.buy_camp_upgrade(); ui.build_panel()).disabled = g.camp_level >= 3 or g.money < g.camp_upgrade_cost()

func van_preview(parent: Node):
	var container = SubViewportContainer.new()
	container.custom_minimum_size = Vector2(220, 195)
	container.stretch = true
	parent.add_child(container)
	preview = SubViewport.new()
	preview.size = Vector2i(300, 230)
	preview.world_3d = World3D.new()
	preview.transparent_bg = true
	container.add_child(preview)
	var van = preload("res://scripts/van.gd").new()
	preview.add_child(van)
	van.update_upgrades(ui.game.levels)
	van.update_solar(ui.game.model)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.6
	preview.add_child(light)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("bfd9dd")
	env.environment.ambient_light_energy = 0.7
	preview.add_child(env)
	preview_camera = Camera3D.new()
	preview.add_child(preview_camera)
	preview_camera.position = Vector3(5, 4.8, 7)
	preview_camera.look_at(Vector3(0, 1.4, 0))
	preview_camera.fov = 40

func build_settings():
	var g = ui.game
	var graphics_card = Kit.card(ui.content)
	ui.text(graphics_card, "Графика", 23)
	var quality = OptionButton.new()
	quality.name = "GraphicsPreset"
	for label in g.graphics.TITLES: quality.add_item(label)
	quality.select(g.graphics.PRESETS.find(g.graphics.preset))
	quality.custom_minimum_size.y = 48
	quality.get_popup().add_theme_stylebox_override("panel", Kit.box(false, 10))
	quality.get_popup().add_theme_stylebox_override("hover", Kit.box(true, 8))
	quality.get_popup().add_theme_color_override("font_color", Kit.TEXT)
	quality.get_popup().add_theme_color_override("font_hover_color", Kit.TEAL)
	quality.item_selected.connect(func(index): g.graphics.choose(g.graphics.PRESETS[index]); ui.build_panel())
	graphics_card.add_child(quality)
	ui.text(graphics_card, g.graphics.description(), 16)
	live_label(graphics_card, func(): return g.graphics.status(), 16)
	var shadows = CheckButton.new()
	shadows.name = "GraphicsShadows"
	shadows.text = "Тени" if ui.mobile_portrait else "Тени солнца и деревьев"
	shadows.button_pressed = g.graphics.shadows
	shadows.custom_minimum_size.y = 44
	shadows.toggled.connect(func(on): g.graphics.set_shadows(on))
	graphics_card.add_child(shadows)
	var nature = CheckButton.new()
	nature.name = "GraphicsNature"
	nature.text = "Погода и эффекты" if ui.mobile_portrait else "Ветер, пыль, дождь и брызги"
	nature.button_pressed = g.graphics.nature
	nature.custom_minimum_size.y = 44
	nature.toggled.connect(func(on): g.graphics.set_nature(on))
	graphics_card.add_child(nature)
	ui.text(graphics_card, "Чёткость картинки · в режиме «Авто» подстраивается сама", 14)
	var clarity = HSlider.new()
	clarity.name = "GraphicsClarity"
	clarity.min_value = 0.6
	clarity.max_value = 1.0
	clarity.step = 0.05
	clarity.value = g.graphics.scale
	clarity.editable = g.graphics.preset != "auto"
	clarity.custom_minimum_size.y = 36
	clarity.value_changed.connect(func(value): g.graphics.set_scale(value))
	graphics_card.add_child(clarity)
	var card = Kit.card(ui.content)
	ui.text(card, "Звук и путешествие", 23)
	if OS.has_feature("web"):
		ui.text(card, "Веб-версия %s" % str(JavaScriptBridge.eval("window.BUKHANKA_BUILD || 'неизвестна'")), 14)
		ui.button(card, "Проверить обновление", func(): JavaScriptBridge.eval("window.bukhankaCheckUpdate && window.bukhankaCheckUpdate()"))
	var voices = CheckButton.new()
	voices.text = "Голоса друзей"
	voices.button_pressed = g.model.voices_enabled
	voices.toggled.connect(func(on): g.model.voices_enabled = on; g.save_game())
	card.add_child(voices)
	var volume = HSlider.new()
	volume.max_value = 1
	volume.step = 0.05
	volume.value = g.model.voice_volume
	volume.value_changed.connect(func(value): g.model.voice_volume = value)
	card.add_child(volume)
	ui.button(card, "Переключить общий звук", func(): g.toggle_sound())
	ui.button(card, "Кинокамера" if ui.mobile_portrait else "Кинематографическая камера · K", ui.toggle_cinema)
	ui.button(card, "Как играть · обучение", func(): ui.close_panel(); g.tutorial.open())
	ui.text(card, "Джойстик — газ и руль. Проведите по миру для обзора. 4H/4L — пониженная. Камера и дополнительные действия — справа внизу." if is_instance_valid(g.touch_controls) and g.touch_controls.enabled else "WASD — ехать · ПКМ — обзор · C — камера\nE — место лагеря · B — стоянка · P — проекты\nL — пониженная · F — лебёдка · J — автопилот\nU — мастерская · O — фоторежим · Esc — закрыть", 16)

func build_journal():
	var g = ui.game
	ui.text(ui.content, "Куда отправимся дальше?", 25)
	ui.text(ui.content, "Выберите цель на маршруте. У воды можно пополнить запасы, в деревне — купить припасы и зарядиться.", 16)
	var cards = ui.row()
	var shown: Array = []
	for place in g.world.director.near_z(g.van.position.z):
		if place.z < g.van.position.z + 60 or place.kind not in ["lake", "village", "waterfall"] or shown.has(place.kind): continue
		shown.append(place.kind)
		var card = Kit.card(cards)
		var name = {"lake": "Горное озеро", "village": "Деревня", "waterfall": "Водопад"}[place.kind]
		Kit.art(card, "home" if place.kind == "village" else "water", 54, true)
		ui.text(card, name, 23)
		ui.text(card, "%.1f км от машины" % (Vector2(place.x-g.van.position.x, place.z-g.van.position.z).length()/1000), 17)
		ui.text(card, {"lake": "Вода, рыбалка и спокойная стоянка.", "village": "Магазин, зарядка и фруктовые деревья.", "waterfall": "Новый вид и воспоминание экспедиции."}[place.kind], 16)
		var target = {"id": place.id, "title": name, "x": place.x, "z": place.z}
		ui.button(card, "Отметить на карте", func(): g.model.destination = target; g.save_game(); ui.close_panel(); g.toast("Цель маршрута: " + target.title))
	ui.text(ui.content, "Путевой дневник · %d открытий" % g.discoveries.size(), 23)
	if not g.discoveries.is_empty():
		var memories = g.discoveries.duplicate()
		memories.reverse()
		var album_pages = maxi(1, ceili(memories.size() / 3.0))
		album_page = clampi(album_page, 0, album_pages - 1)
		var album = ui.row()
		for memory in memories.slice(album_page * 3, (album_page + 1) * 3):
			var kind = str(memory).get_slice(":", 0)
			var card = Kit.card(album)
			preload("res://scripts/discovery_portrait.gd").create(card, g, kind)
			ui.text(card, kind, 21)
			ui.text(card, "Воспоминание экспедиции · № %d" % (g.discoveries.find(memory) + 1), 14)
		var album_nav = ui.row()
		ui.button(album_nav, "‹ Фото", func(): album_page -= 1; ui.build_panel()).disabled = album_page == 0
		ui.text(album_nav, "Альбом · %d / %d" % [album_page + 1, album_pages], 15)
		ui.button(album_nav, "Фото ›", func(): album_page += 1; ui.build_panel()).disabled = album_page >= album_pages - 1
	else:
		ui.text(ui.content, "Здесь появятся портреты открытий. Подъезжайте ближе к животным и исследуйте горы.", 16)
	var entries = g.model.journal.duplicate()
	entries.reverse()
	var page_size = 4
	var pages = maxi(1, ceili(entries.size() / float(page_size)))
	journal_page = clampi(journal_page, 0, pages - 1)
	for entry in entries.slice(journal_page * page_size, (journal_page + 1) * page_size):
		var label = ui.text(ui.content, str(entry), 14)
		label.max_lines_visible = 2
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.tooltip_text = str(entry)
	var pager = ui.row()
	ui.button(pager, "‹ Новее", func(): journal_page -= 1; ui.build_panel()).disabled = journal_page == 0
	ui.text(pager, "%d / %d" % [journal_page + 1, pages], 15)
	ui.button(pager, "Старее ›", func(): journal_page += 1; ui.build_panel()).disabled = journal_page >= pages - 1

func build_placement():
	var g = ui.game
	if g.camping:
		ui.text(ui.content, "Лагерь уже установлен. Сверните его перед выбором новой площадки.")
		return
	var site = g.camp_controller.find_site(g, g.van.position)
	candidate = site.get("position", g.van.position + Vector3(10, 0, 0))
	angle = g.camp_controller.rotation
	var columns = ui.row()
	var view = Kit.card(columns)
	ui.text(view, "Площадка у маршрута", 21)
	var container = SubViewportContainer.new()
	var mobile = is_instance_valid(g.touch_controls) and g.touch_controls.enabled
	container.custom_minimum_size = Vector2(0, 190) if mobile else Vector2(420, 360)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.stretch = true
	view.add_child(container)
	preview = SubViewport.new()
	preview.size = Vector2i(600, 440)
	preview.world_3d = g.get_world_3d()
	container.add_child(preview)
	preview_camera = Camera3D.new()
	preview.add_child(preview_camera)
	preview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	preview_camera.size = 48
	preview_camera.position = g.van.position + Vector3(18, 36, 24)
	preview_camera.look_at(g.van.position)
	container.gui_input.connect(func(event):
		if event is InputEventScreenTouch: dragging = event.pressed
		if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
			if event.button_index == MOUSE_BUTTON_LEFT: dragging = event.pressed
			if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				angle += PI / 2 * (1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
				dirty = true
		if dragging and (event is InputEventScreenDrag or (event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION)):
			var right = preview_camera.global_basis.x
			var forward = preview_camera.global_basis.y
			candidate += (right * event.relative.x - forward * event.relative.y) * 48.0 / maxf(1, container.size.x)
			dirty = true
	)
	ui.text(view, "Двигайте площадку пальцем. Поворот — кнопкой ниже.\nЗелёная сетка: можно поставить лагерь." if mobile else "Перетаскивайте площадку мышью. Колесо — поворот.\nЗелёная сетка: можно поставить. Красная: найдите другое место.", 14)
	var stats = Kit.card(columns, 0 if mobile else 260)
	ui.text(stats, "Оценка места", 23)
	for entry in [["Ровность", "flatness"], ["Укрытие рельефом", "shelter"], ["Солнечный свет", "sun"], ["Близость к воде", "water"], ["Подъезд", "access"]]:
		var key = str(entry[1])
		live_meter(stats, func(): return assessment.get(key, 0), entry[0])
	assessment_label = ui.text(stats, "", 16)
	var actions = ui.row()
	place_button = ui.button(actions, "Поставить лагерь", func():
		assess()
		if not assessment.valid: return
		g.camp_controller.selected = assessment.duplicate()
		g.camp_controller.rotation = angle
		g.toggle_camp()
		if g.camping: ui.close_panel()
	)
	ui.button(actions, "Повернуть на 90°", func(): angle += PI / 2; dirty = true)
	ui.button(actions, "Авторазмещение", func():
		var best = g.camp_controller.find_site(g, g.van.position)
		if not best.is_empty(): candidate = best.position
		dirty = true
	)
	ui.button(actions, "Отмена", ui.close_panel)
	assess()

func assess():
	dirty = false
	var g = ui.game
	assessment = g.camp_controller.evaluate(g, candidate, angle)
	candidate = assessment.position
	place_button.disabled = not assessment.valid
	assessment_label.text = "+%.0f%% к работе\n+%.0f%% к восстановлению\n\n%s" % [assessment.work_bonus * 100, assessment.rest_bonus * 100, "Сухая площадка в пределах 36 м от машины." if assessment.valid else "Есть вода, препятствия, крутой склон или машина слишком далеко."]
	if is_instance_valid(preview): preview.render_target_update_mode = SubViewport.UPDATE_ONCE
	if is_instance_valid(ghost): ghost.queue_free()
	ghost = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Kit.TEAL if assessment.valid else Color("ff6868")
	material.no_depth_test = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for i in range(-4, 5):
		for line in [[Vector3(i*2, 0, -6), Vector3(i*2, 0, 8)], [Vector3(-8, 0, i*2), Vector3(8, 0, i*2)]]:
			for offset in line:
				var p = candidate + offset.rotated(Vector3.UP, angle)
				p.y = g.world.drive_height(p.x, p.z) + 0.15
				mesh.surface_add_vertex(p)
	mesh.surface_end()
	ghost.mesh = mesh
	g.add_child(ghost)
