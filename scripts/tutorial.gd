extends Control
const Kit = preload("res://scripts/ui_kit.gd")
const PAGES = [
	["Движение и понижайка", "Четверо друзей, один дом, тысячи дорог.", "Цель — путешествовать всё дальше, открывать озёра, деревни и перевалы. IT-заказы оплачивают припасы и улучшения. Обязательного финиша нет: маршрут выбираете вы.", "W / S — газ / замедление и задний ход\nA / D — руль · Пробел — тормоз\nL или 4H / 4L — пониженная передача\nПКМ + мышь — обзор · Колесо — масштаб", "Буксуете на подъёме? Включите 4L. Для обычной дороги верните 4H."],
	["Лагерь и припасы", "Остановитесь там, где хочется остаться.", "E открывает выбор площадки. Ищите ровное сухое место рядом с водой и плодами. Лагерь быстрее заряжает батарею; ночью солнечные панели не работают.", "E — поставить или свернуть лагерь\nB — управление стоянкой\nАвто — работа и необходимые припасы\nПополнить запасы — вся команда на сборе", "Еду дают ягоды, яблоки и рыбалка. Нет источника рядом — смените стоянку или посетите магазин. Ночь можно проспать; для работы под дождём нужен навес."],
	["Работа и свобода маршрута", "Зарабатывайте на следующую экспедицию.", "P — выберите заказ. В лагере принимайте решения по проекту: надёжно, творчески или быстро с риском. Результат влияет на оплату и репутацию. Без еды и воды разработка останавливается.", "P — проекты и автоуправление ими\nU — улучшения машины и лагеря\nJ — автопилот · K — кинокамера\nДневник — выбрать следующую точку", "Первый шаг: возьмите небольшой проект, отметьте интересное место и отправляйтесь в путь. Автопилот сам ищет остановки для зарядки и ночлега."]
]
var game: Node
var page = 0
var content: VBoxContainer
var viewport: SubViewport
var view_camera: Camera3D
var heading: Label
var next: Button
var previous: Button

func _ready():
	var mobile = is_instance_valid(game.touch_controls) and game.touch_controls.enabled
	var portrait = get_viewport_rect().size.y > get_viewport_rect().size.x
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Kit.theme()
	var background = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.015, 0.045, 0.055, 0.92)
	add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Kit.box(false, 18))
	margin.add_child(panel)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)
	heading = label(layout, "", 27)
	var row: BoxContainer = VBoxContainer.new() if mobile and portrait else HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 20)
	layout.add_child(row)
	var image_column = VBoxContainer.new()
	image_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_column.size_flags_stretch_ratio = 1.15
	row.add_child(image_column)
	var frame = SubViewportContainer.new()
	frame.stretch = true
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(220, 160)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_column.add_child(frame)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 480)
	# Share the landscape, but introduce no extra lights into it.
	viewport.world_3d = game.get_world_3d()
	frame.add_child(viewport)
	view_camera = Camera3D.new()
	viewport.add_child(view_camera)
	view_camera.fov = 58
	label(image_column, "БУХАНКА • ВЫШЕ ОБЛАКОВ\nВаш мир, ваша команда, ваш маршрут", 17)
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	scroll.add_child(content)
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	layout.add_child(footer)
	previous = button(footer, "← Назад", func(): page -= 1; rebuild())
	button(footer, "Пропустить обучение", finish)
	next = button(footer, "Далее →", func():
		if page == 2: finish()
		else: page += 1; rebuild()
	)
	hide()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if mobile:
		var factor = 2.4 if portrait else 1.4
		set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		size = get_viewport_rect().size / factor
		scale = Vector2.ONE * factor
		if portrait:
			frame.custom_minimum_size = Vector2(220, 115)
			frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			image_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			viewport.size = Vector2i(320, 180)

func label(parent: Node, text: String, font_size: int) -> Label:
	var item = Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", font_size)
	parent.add_child(item)
	return item

func button(parent: Node, text: String, action: Callable) -> Button:
	var item = Button.new()
	item.text = text
	item.custom_minimum_size.y = 48
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.pressed.connect(action)
	parent.add_child(item)
	return item

func open():
	game.release_mouse()
	page = 0
	show()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	rebuild()

func rebuild():
	page = clampi(page, 0, 2)
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var data = PAGES[page]
	heading.text = "%d / 3   ·   %s" % [page + 1, data[0]]
	label(content, data[1], 23).modulate = Kit.TEAL
	label(content, data[2], 19)
	label(content, "Управление", 23)
	label(content, "На телефоне: джойстик — газ и руль, свайп — обзор; используйте кнопки HUD и бокового меню." if game.touch_controls.enabled else data[3], 19)
	label(content, data[4], 18).modulate = Color("efd28c")
	var target: Vector3 = game.van.global_position + Vector3(0, 1.4, 0)
	var offset: Vector3 = [Vector3(-8, 5, -12), Vector3(12, 11, -9), Vector3(-6, 3, 9)][page]
	view_camera.global_position = game.world.safe_camera(target, target + offset.rotated(Vector3.UP, game.heading))
	view_camera.look_at(target)
	previous.disabled = page == 0
	next.text = "В путь →" if page == 2 else "Далее →"

func finish():
	hide()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	game.tutorial_seen = true
	game.save_game()
