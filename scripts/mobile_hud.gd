extends RefCounted
## Compact driving HUD in screen pixels; the centre remains available for looking.
const Kit = preload("res://scripts/ui_kit.gd")
var touch: Control
var header: Button
var location: Label
var conditions: Label
var speed: Label
var drive_mode: Label
var notice: Label
var menu: Button
var camera: Button
var more: Button
var gear: Button
var tools: Control
var tools_card: PanelContainer
var tool_buttons: Array[Button] = []
var low_button: Button
var auto_button: Button
var brake_normal: StyleBoxFlat
var brake_active: StyleBoxFlat
var last_braking = false

func build(owner_touch: Control):
	touch = owner_touch
	var g = touch.game
	var parent = touch.actions
	header = g.ui.button(parent, "", Rect2(), func(): g.rpg_ui.open_panel("journal"))
	header.name = "MobileRoute"
	header.add_theme_stylebox_override("normal", Kit.box(false, 0))
	header.modulate.a = 0.88
	location = g.ui.label(header, "", Vector2(12, 7), 13)
	conditions = g.ui.label(header, "", Vector2(12, 27), 11, Kit.MUTED)
	menu = icon_button(parent, "MobileMenu", "menu", func(): g.rpg_ui.open_panel("camp"))
	menu.tooltip_text = "Меню экспедиции"
	camera = icon_button(parent, "MobileCamera", "camera", func(): g.cycle_camera())
	camera.tooltip_text = "Сменить камеру"
	more = icon_button(parent, "MobileTools", "more", func(): touch.toggle_tools())
	more.tooltip_text = "Машина и стоянка"
	gear = g.ui.button(parent, "4H", Rect2(), func(): g.set_low_range(not g.low_range))
	gear.name = "MobileLowRange"
	gear.tooltip_text = "Пониженная передача · 4L"
	gear.add_theme_font_size_override("font_size", 16)
	touch.brake_button = g.ui.button(parent, "Тормоз", Rect2(), func(): pass)
	touch.brake_button.name = "MobileBrake"
	touch.brake_button.add_theme_font_size_override("font_size", 12)
	brake_normal = Kit.box(false, 0)
	brake_normal.set_corner_radius_all(36)
	brake_normal.bg_color = Color(0.025, 0.13, 0.14, 0.72)
	brake_normal.border_color = Kit.GOLD
	brake_active = brake_normal.duplicate()
	brake_active.bg_color = Color(0.1, 0.42, 0.38, 0.9)
	touch.brake_button.add_theme_stylebox_override("normal", brake_normal)
	touch.brake_button.add_theme_stylebox_override("pressed", brake_active)
	touch.brake_button.add_theme_stylebox_override("hover", brake_normal)
	speed = g.ui.label(parent, "00", Vector2.ZERO, 24)
	speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed.size = Vector2(72, 30)
	speed.add_theme_constant_override("outline_size", 3)
	drive_mode = g.ui.label(parent, "", Vector2.ZERO, 11, Kit.MUTED)
	drive_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drive_mode.size = Vector2(92, 30)
	drive_mode.add_theme_constant_override("outline_size", 2)
	notice = g.ui.label(parent, "", Vector2.ZERO, 12, Kit.TEXT, 300)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.max_lines_visible = 2
	notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	notice.add_theme_constant_override("outline_size", 3)
	tools = Control.new()
	tools.mouse_filter = Control.MOUSE_FILTER_STOP
	touch.add_child(tools)
	tools_card = PanelContainer.new()
	tools_card.add_theme_stylebox_override("panel", Kit.box(false, 12))
	tools.add_child(tools_card)
	var stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	tools_card.add_child(stack)
	var heading = Label.new()
	heading.text = "Машина и стоянка"
	heading.add_theme_font_size_override("font_size", 16)
	stack.add_child(heading)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	stack.add_child(grid)
	low_button = tool_button(grid, "Пониженная · 4L", func(): g.set_low_range(not g.low_range))
	tool_button(grid, "Лебёдка", func(): g.winch())
	auto_button = tool_button(grid, "Автопилот", func(): g.toggle_auto())
	tool_button(grid, "Лагерь", func(): g.rpg_ui.open_panel("camp") if g.camping else g.rpg_ui.open_panel("placement"))
	tool_button(grid, "Пауза", func(): g.toggle_pause())
	tool_button(grid, "Закрыть", func(): pass)
	tools.gui_input.connect(func(event):
		if event is InputEventScreenTouch and event.pressed: touch.close_tools()
		elif event is InputEventMouseButton and event.pressed: touch.close_tools()
	)
	tools.hide()
	touch.action_buttons.assign([menu, camera, more, gear, touch.brake_button])

func icon_button(parent: Control, node_name: String, icon: String, action: Callable) -> Button:
	var b = touch.game.ui.button(parent, "", Rect2(), action)
	b.name = node_name
	Kit.button_content(b, icon)
	b.get_meta("symbol").custom_minimum_size = Vector2(24, 24)
	for state in ["normal", "hover", "pressed"]:
		var style = Kit.box(state == "pressed", 0)
		style.bg_color.a = 0.72 if state == "normal" else 0.94
		b.add_theme_stylebox_override(state, style)
	return b

func tool_button(parent: Control, caption: String, action: Callable) -> Button:
	var b = touch.game.ui.button(parent, caption, Rect2(), func(): touch.close_tools(); action.call())
	b.custom_minimum_size = Vector2(130, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 12)
	tool_buttons.append(b)
	return b

func layout(view: Vector2, safe: Vector4):
	var left = 12.0 + safe.x
	var right = view.x - 12.0 - safe.z
	var top = 12.0 + safe.y
	var bottom = view.y - 14.0 - safe.w
	header.position = Vector2(left, top)
	header.size = Vector2(minf(280, right - left - 58), 48)
	menu.position = Vector2(right - 48, top)
	menu.size = Vector2(48, 48)
	touch.center = Vector2(left + 54, bottom - 54)
	touch.brake_button.position = Vector2(right - 72, bottom - 72)
	touch.brake_button.size = Vector2(72, 72)
	camera.position = Vector2(right - 44, bottom - 126)
	camera.size = Vector2(44, 44)
	more.position = Vector2(right - 96, bottom - 126)
	more.size = Vector2(44, 44)
	gear.position = Vector2(right - 148, bottom - 126)
	gear.size = Vector2(44, 44)
	speed.position = Vector2((left + right) * 0.5 - 36, bottom - 58)
	drive_mode.position = Vector2((left + right) * 0.5 - 46, bottom - 29)
	notice.position = Vector2(left + 8, top + 58)
	notice.size = Vector2(right - left - 16, 42)
	tools.position = Vector2.ZERO
	tools.size = view
	var width = minf(324, right - left)
	tools_card.position = Vector2(right - width, bottom - 342)
	tools_card.size = Vector2(width, 208)
	for b in tool_buttons: b.custom_minimum_size.x = (width - 32) * 0.5

func refresh():
	var g = touch.game
	var m = g.model
	location.text = "%s · %d м" % ["Перевал" if g.world.nearest_route(g.van.position.x, g.van.position.z) else "Долина", 1240 + int(g.van.position.y)]
	var minutes = int(fposmod(m.phase() * 1440 + 300, 1440))
	conditions.text = "%s · %02d:%02d · заряд %.0f%%" % [g.weather.current_name, minutes / 60, minutes % 60, m.percent()]
	speed.text = "%02d" % roundi(abs(g.speed) * 3.6)
	drive_mode.text = "км/ч · %s" % ["Стоянка" if g.camping else "4L" if g.low_range else "Авто" if g.autopilot else "4H"]
	notice.text = g.ui.toast_label.text if g.toast_timer > 0 else g.auto_controller.status if g.autopilot else ""
	notice.visible = not notice.text.is_empty() and not touch.tools_open
	notice.modulate.a = minf(1, g.toast_timer) if g.toast_timer > 0 else 1.0
	low_button.text = "Обычная · 4H" if g.low_range else "Пониженная · 4L"
	gear.text = "4L" if g.low_range else "4H"
	gear.add_theme_stylebox_override("normal", Kit.box(g.low_range, 0))
	auto_button.text = "За руль" if g.autopilot else "Автопилот"
	if last_braking != touch.braking:
		last_braking = touch.braking
		touch.brake_button.add_theme_stylebox_override("normal", brake_active if touch.braking else brake_normal)

func button_rects() -> Dictionary:
	var rects = {}
	for b in touch.action_buttons:
		rects[str(b.name)] = {"x": b.position.x, "y": b.position.y, "width": b.size.x, "height": b.size.y}
	return rects
