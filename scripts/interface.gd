extends Control
var game: Node
var small: Label
var speed_label: Label
var trip_label: Label
var terrain_label: Label
var wallet_label: Label
var status_label: Label
var speaker: Label
var dialogue: Label
var toast_label: Label
var task_label: Label
var task_bar: ProgressBar
var menu: Panel
var garage: Panel
var pause_panel: Panel
var hud: Control
var mini: Control
var upgrade_buttons: Array[Button] = []
var camp_button: Button
var auto_button: Button
var mode_label: Label
var muted_button: Button
var journey_label: Label
var menu_caption: Label
var camp_upgrade_button: Button
var mobile_layout = false
var cream = Color("f0eddb")
var muted = Color("aabfb5")
var accent = Color("ecc180")
var green = Color("92d7be")
var ink = Color("142f30")

func panel(parent: Node, rect: Rect2, color = Color("142f30"), radius = 16) -> Panel:
	var p = Panel.new()
	p.position = rect.position
	p.size = rect.size
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.set_border_width_all(1)
	s.border_color = Color(0.68, 0.73, 0.58, 0.24)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 6
	p.add_theme_stylebox_override("panel", s)
	parent.add_child(p)
	return p

func label(parent: Node, text: String, pos: Vector2, font_size = 18, color = Color("f0eddb"), width = 0.0) -> Label:
	var l = Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size.x = width
	parent.add_child(l)
	if width > 0:
		l.set_deferred("size", Vector2(width, 0))
	return l

func button(parent: Node, text: String, rect: Rect2, callback: Callable, primary = false) -> Button:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.position = rect.position
	b.size = rect.size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 17)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s = StyleBoxFlat.new()
		s.bg_color = Color("34eed3") if primary else Color("082d31")
		if state == "hover": s.bg_color = s.bg_color.lightened(0.13)
		if state == "pressed": s.bg_color = s.bg_color.darkened(0.15)
		if state == "disabled": s.bg_color = Color("354542")
		s.set_corner_radius_all(12)
		s.set_border_width_all(1)
		s.border_color = Color("4a9090")
		if state == "focus":
			s.set_border_width_all(2)
			s.border_color = green
		b.add_theme_stylebox_override(state, s)
	b.add_theme_color_override("font_color", ink if primary else cream)
	b.add_theme_color_override("font_hover_color", ink if primary else cream)
	b.add_theme_color_override("font_pressed_color", ink if primary else cream)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

var design = preload("res://scripts/expedition_hud.gd").new()

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	design.build(self)
	build_menu()
	build_garage()
	build_pause()
func build_menu():
	menu = panel(self, Rect2(58, 136, 530, 584), Color(0.055, 0.12, 0.12, 0.95), 5)
	label(menu, "АЛТАЙ  /  ЭКСПЕДИЦИЯ 4×4", Vector2(32, 25), 15, accent)
	label(menu, "ВЫШЕ\nОБЛАКОВ", Vector2(28, 62), 62, cream)
	label(menu, "Четверо друзей. Один дом. Тысячи дорог.", Vector2(32, 240), 19, green)
	var emblem = Control.new()
	emblem.position = Vector2(32, 278)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.draw.connect(func():
		for i in range(5):
			emblem.draw_polyline(PackedVector2Array([Vector2(0, 68-i*4), Vector2(80, 30-i*3), Vector2(130, 49-i*3), Vector2(210, -i*2), Vector2(300, 57-i*3), Vector2(410, 15-i*3), Vector2(465, 52-i*3)]), Color(0.66, 0.70, 0.52, 0.22), 1.0, true))
	menu.add_child(emblem)
	label(menu, "Выбирайте тропу. Чувствуйте грунт.\nОстанавливайтесь там, где хочется остаться.", Vector2(32, 368), 19, muted, 465)
	button(menu, "ЗАВЕСТИ БУХАНКУ   >", Rect2(32, 445, 466, 64), func(): game.start_trip(), true)
	menu_caption = label(menu, "Мышь — обзор  /  WASD — ехать  /  E — лагерь", Vector2(32, 533), 14, muted)

func sixty() -> int:
	return 60

func build_garage():
	garage = panel(self, Rect2(100, 90, 1240, 730), Color(0.055, 0.12, 0.12, 0.985), 5)
	garage.visible = false
	label(garage, "ПОЛЕВОЙ КАТАЛОГ  /  СНАРЯЖЕНИЕ ЭКСПЕДИЦИИ", Vector2(30, 24), 13, green)
	label(garage, "Обустроить жизнь в пути", Vector2(28, 51), 40)
	label(garage, "Каждая вещь меняет путешествие. Выберите, чего сейчас не хватает вашей команде.", Vector2(30, 110), 18, muted)
	var names = ["ПРОХОДИМОСТЬ", "ДОМ НА КОЛЁСАХ", "СВЯЗЬ", "ЭКСПЕДИЦИЯ", "ЛАГЕРЬ"]
	var descriptions = ["Шины, лифт и блокировки.\n\nСцепление в грязи и уверенный подъём.", "Кровать, кухня и жилой модуль.\n\nУют и продуктивность команды.", "Питание и Starlink Pro.\n\nБыстрый интернет и защита от обрывов.", "Снаряжение и багажник.\n\nБольше наград за поездки и заказы.", "Тент, стены, отопление.\n\nУкрытие для друзей в дождь и снег."]
	for i in range(5):
		var card = panel(garage, Rect2(28 + i * 238, 162, 230, 418), Color("203730"), 4)
		var art = Control.new()
		art.position = Vector2(115, 86)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.draw.connect(func(): draw_equipment(art, i))
		card.add_child(art)
		label(card, names[i], Vector2(15, 159), 17, accent)
		label(card, descriptions[i], Vector2(15, 198), 16, muted, 200)
		var b = button(card, "Улучшить", Rect2(12, 336, 206, 65), func(): game.buy_camp_upgrade() if i == 4 else game.buy_upgrade(i))
		b.add_theme_font_size_override("font_size", 15)
		if i == 4: camp_upgrade_button = b
		else: upgrade_buttons.append(b)
	button(garage, "СОБРАТЬСЯ В ПУТЬ   [U / Esc]", Rect2(28, 627, 1182, 65), func(): game.toggle_garage(), true)

func build_pause():
	pause_panel = panel(self, Rect2(470, 240, 500, 410), Color("142f30"), 22)
	pause_panel.visible = false
	label(pause_panel, "Никуда не спешим", Vector2(30, 28), 33)
	label(pause_panel, "Путешествие сохранено автоматически.", Vector2(30, 81), 17, muted)
	button(pause_panel, "Продолжить", Rect2(30, 130, 440, 49), func(): game.toggle_pause(), true)
	muted_button = button(pause_panel, "Звук: включён", Rect2(30, 193, 440, 49), func(): game.toggle_sound())
	button(pause_panel, "На стартовый экран", Rect2(30, 256, 440, 49), func(): game.show_title())
	button(pause_panel, "Сохранить и выйти", Rect2(30, 319, 440, 49), func(): game.show_title() if OS.has_feature("web") else game.exit_game())

func update_view():
	if not is_instance_valid(game): return
	speed_label.text = "%02d" % roundi(abs(game.speed) * 3.6)
	var regions = ["ДОЛИНА КЕДРОВ", "БИРЮЗОВАЯ КАТУНЬ", "ТИХИЙ ПЕРЕВАЛ", "СНЕЖНЫЙ ХРЕБЕТ"]
	trip_label.text = game.weather.current_name + " · " + ("ПЕРЕВАЛ" if game.world.nearest_route(game.van.position.x, game.van.position.z) else "ДОЛИНА")
	terrain_label.text = "%s · %d м" % [game.surface_name, 1240 + int(game.van.position.y)]
	journey_label.text = "%d открытий · %s" % [game.discoveries.size(), "Пониженная 4L" if game.low_range else "Свободная экспедиция"]
	wallet_label.text = "%s руб." % int(game.money)
	status_label.text = "НЕТ СВЯЗИ · НЕПОГОДА" if game.signal_speed == 0 else "STARLINK  /  %d Мбит/с" % game.signal_speed
	task_label.text = str(game.projects.active.get("title", "P · Выберите IT-проект"))
	task_bar.value = game.work_progress * 100
	small.text = "+ %d руб. · %s" % [game.job_reward(), "ночной отдых" if game.model.is_night() else "нужны припасы" if game.model.supplies_factor() == 0 else "обсуждение в лагере [P]" if game.projects.active.get("pending", false) else "ждём связь" if game.signal_speed == 0 else "в дороге медленнее" if abs(game.speed) > 1 else "работаем под крышей" if game.camping and game.weather.intensity > 0.3 else "пишем код"]
	mode_label.text = "ЛАГЕРЬ · ДОМ" if game.camping else ("АВТОПИЛОТ · 4×4" if game.autopilot else "%d передача · %d об/мин" % [game.dynamics.gear, game.dynamics.rpm])
	camp_button.text = "E  Свернуть лагерь" if game.camping else "E  Лагерь"
	auto_button.text = "J  За руль" if game.autopilot else "J  Автопилот"
	for i in range(upgrade_buttons.size()):
		var b = upgrade_buttons[i]
		b.text = "УРОВЕНЬ %d / 3\n%d руб.  >" % [game.levels[i], game.upgrade_cost(i)] if game.levels[i] < 3 else "ПОЛНЫЙ КОМПЛЕКТ"
		b.disabled = game.levels[i] >= 3 or game.money < game.upgrade_cost(i)
	camp_upgrade_button.text = "УРОВЕНЬ %d / 3\n%d руб.  >" % [game.camp_level, game.camp_upgrade_cost()] if game.camp_level < 3 else "ЛАГЕРЬ ОБУСТРОЕН"
	camp_upgrade_button.disabled = game.camp_level >= 3 or game.money < game.camp_upgrade_cost()
	if is_instance_valid(game.touch_controls) and game.touch_controls.enabled and not mobile_layout: apply_mobile_layout()
	hud.visible = game.started and not game.photo and not garage.visible
	mini.queue_redraw()
	design.refresh()

func draw_equipment(art: Control, kind: int):
	art.draw_circle(Vector2.ZERO, 61, Color("304b3d"))
	art.draw_arc(Vector2.ZERO, 69, 0, TAU, 64, Color("9d936e"), 1, true)
	if kind == 0:
		art.draw_circle(Vector2.ZERO, 42, Color("111f1c"))
		art.draw_circle(Vector2.ZERO, 23, muted)
		art.draw_circle(Vector2.ZERO, 10, ink)
		for i in range(12):
			var p = Vector2.from_angle(i * TAU / 12) * 39
			art.draw_line(p, p * 1.22, accent, 9, true)
	elif kind == 1:
		art.draw_rect(Rect2(-46, -26, 92, 50), accent)
		for i in range(3): art.draw_rect(Rect2(-35 + i * 25, -18, 19, 20), ink)
		art.draw_circle(Vector2(-27, 28), 13, ink)
		art.draw_circle(Vector2(28, 28), 13, ink)
	elif kind == 2:
		art.draw_line(Vector2(0, 42), Vector2(0, -10), accent, 6)
		art.draw_line(Vector2(-30, 42), Vector2(30, 42), accent, 5)
		art.draw_arc(Vector2(0, -36), 40, 0.1, PI - 0.1, 32, cream, 10, true)
		for i in range(3): art.draw_arc(Vector2(0, -34), 12 + i * 12, -PI * 0.75, -PI * 0.25, 20, green, 3, true)
	elif kind == 3:
		art.draw_rect(Rect2(-29, -37, 58, 76), accent)
		art.draw_rect(Rect2(-21, 3, 42, 24), Color("9d7951"))
		art.draw_arc(Vector2(0, -37), 17, PI, TAU, 20, cream, 6, true)
		art.draw_line(Vector2(0, -26), Vector2(0, 31), ink, 4)
	else:
		art.draw_colored_polygon(PackedVector2Array([Vector2(-51, 36), Vector2(0, -40), Vector2(51, 36)]), accent)
		art.draw_colored_polygon(PackedVector2Array([Vector2(-22, 36), Vector2(0, -6), Vector2(22, 36)]), ink)
		art.draw_line(Vector2(-62, 39), Vector2(62, 39), cream, 3, true)

func apply_mobile_layout():
	mobile_layout = true
	menu_caption.text = "Джойстик — ехать  /  Проведите по миру — обзор"
	for child in hud.get_children():
		if child is Button or child.position.y > 700: child.hide()
	speed_label.get_parent().show()
	speed_label.get_parent().position = Vector2(28, 130)
	speed_label.get_parent().scale = Vector2(0.8, 0.8)
	speaker.get_parent().show()
	speaker.get_parent().position = Vector2(340, 754)
	speaker.get_parent().scale = Vector2(0.95, 0.8)
	mini.hide()

func draw_map():
	mini.draw_circle(Vector2(102, 102), 100, Color(0.06, 0.16, 0.16, 0.93))
	mini.draw_arc(Vector2(102, 102), 92, 0, TAU, 64, Color("5b7970"), 1.0, true)
	var points = PackedVector2Array()
	var river = PackedVector2Array()
	var branch = PackedVector2Array()
	var z = game.van.position.z
	for i in range(31):
		var pz = z - 65 + i * 8
		branch.append(Vector2(102 + (game.world.branch_x(pz) - game.van.position.x) * 0.65, 152 - i * 4.3))
		points.append(Vector2(102 + (game.world.road_x(pz) - game.van.position.x) * 0.65, 152 - i * 4.3))
		river.append(Vector2(102 + (game.world.river_x(pz) - game.van.position.x) * 0.65, 152 - i * 4.3))
	mini.draw_polyline(river, Color("498f92"), 5, true)
	mini.draw_polyline(points, accent, 3, true)
	mini.draw_polyline(branch, green, 2, true)
	mini.draw_colored_polygon(PackedVector2Array([Vector2(102, 109), Vector2(95, 125), Vector2(109, 125)]), cream)
	mini.draw_circle(Vector2(102, 13), 3, accent)
	if not game.model.destination.is_empty():
		var target = game.model.destination
		var direction = Vector2(target.x - game.van.position.x, -(target.z - game.van.position.z))
		mini.draw_circle(Vector2(102, 102) + direction.normalized() * minf(78, direction.length() * 0.53), 5, Color("f3d88c"))
	for item in game.world.director.near_z(z):
		if item.z < z - 70 or item.z > z + 190: continue
		var marker_position = Vector2(102 + (item.x - game.van.position.x) * 0.65, 117 - (item.z - z) * 0.5375)
		if marker_position.distance_to(Vector2(102, 102)) > 86: continue
		var colors = {"lake": Color("69bace"), "waterfall": Color("b4e0e7"), "village": accent, "food": Color("b6cd70"), "animals": Color("c3b08c"), "tunnel": Color("9faeae")}
		mini.draw_circle(marker_position, 3.5 if item.kind in ["lake", "village"] else 2.5, colors.get(item.kind, green))
