extends RefCounted
const Kit = preload("res://scripts/ui_kit.gd")
var ui: Control
var resources: Array[Label] = []
var clock_label: Label
var gear: Label
var gauge: Control
var range_buttons: Array[Button] = []

func build(owner_ui: Control):
	ui = owner_ui
	ui.theme = Kit.theme()
	ui.hud = Control.new()
	ui.hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(ui.hud)
	var brand = tile(Rect2(26, 22, 124, 96))
	var logo = Kit.art(brand, "mountain", 70, true)
	logo.position = Vector2(25, 3)
	logo.size = Vector2(74, 46)
	ui.label(brand, "Б У Х А Н К А", Vector2(12, 49), 15)
	ui.label(brand, "ВЫШЕ ОБЛАКОВ", Vector2(17, 72), 10, Kit.GOLD)
	var location = tile(Rect2(162, 22, 310, 88))
	put_icon(location, "pin", Vector2(14, 24), 34)
	ui.trip_label = ui.label(location, "", Vector2(62, 14), 19)
	ui.terrain_label = ui.label(location, "", Vector2(62, 49), 15, Kit.MUTED)
	var target = tile(Rect2(484, 22, 402, 88))
	put_icon(target, "mountain", Vector2(12, 22), 42)
	ui.label(target, "ТЕКУЩАЯ ЦЕЛЬ", Vector2(66, 10), 11, Kit.TEAL)
	ui.task_label = ui.label(target, "", Vector2(66, 29), 18, Kit.TEXT, 322)
	ui.task_label.max_lines_visible = 1
	ui.task_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ui.small = ui.label(target, "", Vector2(66, 57), 13, Kit.MUTED, 322)
	var click = Button.new()
	click.flat = true
	click.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click.pressed.connect(func(): ui.game.rpg_ui.open_panel("projects"))
	target.add_child(click)
	for i in range(5):
		var p = tile(Rect2(902 + i * 103, 26, 95, 60))
		put_icon(p, ["money", "energy", "food", "water", "signal"][i], Vector2(8, 16), 25)
		resources.append(ui.label(p, "", Vector2(38, 10), 15, Kit.GOLD if i == 0 else Kit.TEXT))
	var clock_panel = tile(Rect2(26, 132, 446, 48))
	put_icon(clock_panel, "sun", Vector2(13, 8), 30)
	clock_label = ui.label(clock_panel, "", Vector2(57, 13), 15)
	for i in range(6):
		var key = ["camp", "projects", "crew", "upgrades", "journal", "settings"][i]
		var b = ui.button(ui.hud, "", Rect2(26, 220 + 68 * i, 64, 66), func(): ui.game.rpg_ui.open_panel(key))
		Kit.button_content(b, key)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 30)
		b.tooltip_text = ["Лагерь · B", "Проекты · P", "Команда", "Мастерская · U", "Дневник", "Настройки"][i]
	ui.mini = Control.new()
	ui.mini.position = Vector2(1195, 152)
	ui.mini.size = Vector2(204, 204)
	ui.mini.scale = Vector2(1.08, 1.08)
	ui.mini.draw.connect(ui.draw_map)
	ui.hud.add_child(ui.mini)
	for item in [["N", Vector2(104, 1)], ["S", Vector2(104, 182)], ["W", Vector2(6, 93)], ["E", Vector2(184, 93)]]:
		ui.label(ui.mini, item[0], item[1], 12)
	var waypoint = tile(Rect2(1188, 388, 226, 62))
	put_icon(waypoint, "pin", Vector2(10, 13), 31)
	ui.journey_label = ui.label(waypoint, "", Vector2(53, 11), 14, Kit.TEXT, 166)
	var navigate = Button.new()
	navigate.flat = true
	navigate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	navigate.pressed.connect(func(): ui.game.rpg_ui.open_panel("journal"))
	waypoint.add_child(navigate)
	gauge = Control.new()
	gauge.position = Vector2(30, 731)
	gauge.draw.connect(draw_speed)
	ui.hud.add_child(gauge)
	ui.speed_label = ui.label(gauge, "00", Vector2(38, 49), 49)
	ui.label(gauge, "КМ/Ч", Vector2(53, 111), 16, Kit.MUTED)
	var transmission = tile(Rect2(209, 768, 80, 105))
	gear = ui.label(transmission, "D", Vector2(26, 7), 40)
	ui.label(transmission, "P R N D", Vector2(10, 72), 12, Kit.MUTED)
	var terrain = tile(Rect2(300, 788, 180, 85))
	ui.mode_label = ui.label(terrain, "L · РАЗДАТКА", Vector2(12, 7), 12, Kit.MUTED, 156)
	for i in range(2):
		var low = i == 1
		var b = ui.button(terrain, "4L" if low else "4H", Rect2(8 + i * 84, 29, 80, 46), func(): ui.game.set_low_range(low))
		b.tooltip_text = "Пониженная: больше тяги" if low else "Обычный диапазон: движение по дороге"
		range_buttons.append(b)
	var chat = tile(Rect2(505, 775, 458, 98))
	put_icon(chat, "signal", Vector2(12, 29), 37)
	ui.speaker = ui.label(chat, "", Vector2(65, 10), 14, Kit.GOLD)
	ui.dialogue = ui.label(chat, "", Vector2(65, 35), 17, Kit.TEXT, 375)
	ui.dialogue.max_lines_visible = 3
	ui.dialogue.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for i in range(4):
		var b = ui.button(ui.hud, ["C\nКамера", "J\nАвтопилот", "E\nЛагерь", "K\nКино"][i], Rect2(991 + i * 108, 783, 98, 90), func(): action(i))
		Kit.button_content(b, ["camera", "auto", "camp", "camera"][i], ["C · Камера", "J · Автопилот", "E · Лагерь", "K · Кино"][i], true)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 24)
		b.add_theme_font_size_override("font_size", 13)
		if i == 1: ui.auto_button = b
		if i == 2: ui.camp_button = b
	ui.toast_label = ui.label(ui.hud, "", Vector2(450, 195), 19, Kit.TEXT, 600)
	ui.toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.toast_label.add_theme_constant_override("outline_size", 5)
	# Legacy data labels are retained for compatibility with the old update API.
	ui.wallet_label = Label.new()
	ui.status_label = Label.new()
	ui.task_bar = ProgressBar.new()
	ui.add_child(ui.wallet_label); ui.wallet_label.hide()
	ui.add_child(ui.status_label); ui.status_label.hide()
	ui.add_child(ui.task_bar); ui.task_bar.hide()

func tile(rect: Rect2) -> Panel:
	var panel = ui.panel(ui.hud, rect)
	panel.add_theme_stylebox_override("panel", Kit.box())
	return panel

func put_icon(parent: Node, key: String, pos: Vector2, extent: float):
	var icon = Kit.art(parent, key, extent, key == "money" or key == "sun")
	icon.position = pos
	icon.size = Vector2.ONE * extent

func action(i: int):
	match i:
		0: ui.game.cycle_camera()
		1: ui.game.toggle_auto()
		2:
			if ui.game.camping: ui.game.toggle_camp()
			else: ui.game.rpg_ui.open_panel("placement")
		3: ui.game.rpg_ui.toggle_cinema()

func refresh():
	var g = ui.game
	var m = g.model
	var values = ["%d\nруб." % g.money, "%.0f%%\nзаряд" % m.percent(), "Еда\n%.1f" % m.food, "Вода\n%.1f" % m.water, "%d\nМбит/с" % g.signal_speed]
	for i in range(5): resources[i].text = values[i]
	var minutes = int(fposmod(m.phase() * 1440 + 300, 1440))
	clock_label.text = "День %d · %s %02d:%02d   |   %s" % [m.day(), m.phase_name(), minutes / 60, minutes % 60, g.weather.current_name]
	ui.small.text = "Готово %.0f%% · %s" % [g.work_progress * 100, "обсудить в лагере →" if g.projects.active.get("pending", false) else "%.1f суток" % ((g.projects.active.get("deadline", m.simulation_seconds) - m.simulation_seconds) / 1200)] if not g.projects.active.is_empty() else "Выбрать заказ для команды →"
	ui.mode_label.text = "L · РАЗДАТКА"
	for i in range(range_buttons.size()):
		range_buttons[i].add_theme_stylebox_override("normal", Kit.box(g.low_range == (i == 1), 4))
		range_buttons[i].add_theme_color_override("font_color", Kit.TEAL if g.low_range == (i == 1) else Kit.MUTED)
	gear.text = "P" if g.camping or absf(g.speed) < 0.1 else "R" if g.speed < 0 else "D"
	Kit.caption(ui.camp_button, "E · В путь" if g.camping else "E · Лагерь")
	Kit.caption(ui.auto_button, "J · За руль" if g.autopilot else "J · Автопилот")
	if not m.destination.is_empty():
		var distance = Vector2(m.destination.x - g.van.position.x, m.destination.z - g.van.position.z).length()
		ui.journey_label.text = "%.1f км\n%s →" % [distance / 1000.0, m.destination.title]
	else: ui.journey_label.text = "Выбрать место →\nДневник и маршрут"
	ui.hud.visible = g.started and not g.photo and not g.paused and not g.rpg_ui.overlay.visible
	gauge.queue_redraw()

func draw_speed():
	Kit.draw_speedometer(gauge, absf(ui.game.speed) * 3.6, 88)
