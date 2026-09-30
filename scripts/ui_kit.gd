extends RefCounted
const TEAL = Color("34eed3")
const GOLD = Color("f3d88c")
const TEXT = Color("eef8f5")
const MUTED = Color("9fc5c8")
static var icons: Dictionary = {}

static func draw_speedometer(canvas: Control, speed_kmh: float, radius: float):
	var center = Vector2.ONE * radius
	var ring = radius * 72.0 / 88.0
	var thickness = maxf(3, radius * 7.0 / 88.0)
	canvas.draw_circle(center, radius, Color(0.01, 0.08, 0.09, 0.92))
	canvas.draw_arc(center, radius - 1, 0, TAU, 72, MUTED, 1, true)
	canvas.draw_arc(center, ring, PI * 0.78, PI * 2.22, 64, Color("264b4c"), thickness, true)
	canvas.draw_arc(center, ring, PI * 0.78, PI * 0.78 + PI * 1.44 * clampf(speed_kmh / 60, 0.005, 1), 64, TEAL, thickness, true)

static func button_content(button: Button, key: String, caption: String = "", stacked: bool = false):
	button.text = ""
	button.icon = null
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var center = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	var line = BoxContainer.new()
	line.vertical = stacked
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 5 if stacked else 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(line)
	var symbol = art(line, key, 28)
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	symbol.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not caption.is_empty():
		var label = Label.new()
		label.text = caption
		label.add_theme_font_size_override("font_size", 13 if stacked else 15)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if stacked else HORIZONTAL_ALIGNMENT_LEFT
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(label)
		button.set_meta("caption", label)
	button.set_meta("symbol", symbol)

static func caption(button: Button, value: String):
	if button.has_meta("caption"):
		button.text = ""
		button.get_meta("caption").text = value
	else: button.text = value

static func box(active: bool = false, padding: int = 10) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.015, 0.095, 0.105, 0.91) if not active else Color(0.01, 0.25, 0.24, 0.96)
	s.border_color = TEAL if active else Color(0.31, 0.66, 0.66, 0.65)
	s.set_border_width_all(2 if active else 1)
	s.set_corner_radius_all(12)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

static func theme() -> Theme:
	var t = Theme.new()
	t.default_font_size = 17
	for type in ["Label", "Button", "CheckButton", "OptionButton"]:
		t.set_color("font_color", type, TEXT)
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var s = box(state in ["hover", "pressed", "focus"], 12)
			if state == "disabled": s.bg_color.a = 0.45
			t.set_stylebox(state, type, s)
		t.set_color("font_hover_color", type, TEAL)
		t.set_color("font_disabled_color", type, Color("648b8e"))
	t.set_stylebox("panel", "PanelContainer", box())
	return t

static func card(parent: Node, width: float = 0) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = width
	panel.add_theme_stylebox_override("panel", box())
	parent.add_child(panel)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	panel.add_child(body)
	return body

static func meter(parent: Node, value: float, caption: String) -> ProgressBar:
	var label = Label.new()
	label.text = caption
	label.add_theme_color_override("font_color", MUTED)
	parent.add_child(label)
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(80, 8)
	bar.show_percentage = false
	bar.value = value
	var bg = box(false, 0)
	bg.bg_color = Color("183d40")
	bg.set_border_width_all(0)
	var fill = bg.duplicate()
	fill.bg_color = TEAL
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

static func icon(key: String, color: String = "eef8f5") -> Texture2D:
	var id = key + color
	if icons.has(id): return icons[id]
	var paths = {
		"menu": '<path d="M5 8h22M5 16h22M5 24h22"/>',
		"more": '<circle cx="6" cy="16" r="2"/><circle cx="16" cy="16" r="2"/><circle cx="26" cy="16" r="2"/>',
		"camp": '<path d="M5 27 16 5l11 22H5zm8 0 3-10 4 10M14 4l5 5"/>',
		"mountain": '<path d="m2 26 9-13 4 5 7-13 9 21M7 19l4-6 4 5M19 10l3-5 5 10"/>',
		"projects": '<rect x="5" y="5" width="22" height="18" rx="2"/><path d="M2 28h28M12 23v5m8-5v5"/>',
		"crew": '<circle cx="16" cy="10" r="5"/><circle cx="5" cy="13" r="3"/><circle cx="27" cy="13" r="3"/><path d="M8 28v-5a8 8 0 0 1 16 0v5ZM1 27v-5q0-6 6-5m24 10v-5q0-6-6-5"/>',
		"journal": '<path d="m2 7 9-3 10 4 9-4v23l-9 3-10-4-9 3ZM11 4v22M21 8v22"/>',
		"settings": '<circle cx="16" cy="16" r="8"/><circle cx="16" cy="16" r="3"/><path d="M16 1v6m0 18v6M1 16h6m18 0h6M5 5l5 5m12 12 5 5M5 27l5-5M22 10l5-5"/>',
		"energy": '<rect x="7" y="5" width="18" height="25" rx="2"/><path d="M12 5V2h8v3m-4 5-5 8h6l-1 7 6-10h-6z"/>',
		"water": '<path d="M16 2C13 10 5 16 5 22a11 11 0 0 0 22 0C27 16 19 10 16 2Z"/>',
		"food": '<path d="M4 2v9q0 5 5 5V2m5 0v9q0 5-5 5v14M25 30V2q-9 10 0 17"/>',
		"signal": '<path d="M4 29V23m8 6V17m8 12V10m8 19V3" stroke-width="4"/>',
		"camera": '<path d="M3 9h7l2-4h8l2 4h7v20H3Z"/><circle cx="16" cy="18" r="6"/>',
		"pin": '<path d="M16 30S5 17 5 12a11 11 0 0 1 22 0c0 5-11 18-11 18Z"/><circle cx="16" cy="12" r="4"/>',
		"sun": '<path d="M16 1v5m0 20v5M1 16h5m20 0h5M5 5l4 4m14 14 4 4M5 27l4-4M23 9l4-4"/><circle cx="16" cy="16" r="7"/>',
		"upgrades": '<path d="M27 3a8 8 0 0 1-10 11L5 29l-4-4L16 13A8 8 0 0 1 26 3l-6 5 4 4 5-6"/>',
		"auto": '<path d="M7 8a12 12 0 1 1-3 15M2 3v9h9m2 0 8 5-8 5z"/>',
		"exit": '<path d="M12 3H3v26h9m7-21 9 8-9 8M9 16h19"/>',
		"moon": '<path d="M24 26A13 13 0 0 1 12 2a12 12 0 0 0 12 24Z"/>',
		"home": '<path d="m2 15 14-12 14 12M6 12v18h20V12M13 30V19h7v11"/>',
		"money": '<path d="M10 30V3h10a7 7 0 0 1 0 14H5m0 6h17"/>',
		"close": '<path d="m6 6 20 20M6 26 26 6"/>'
	}
	var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 32 32"><g fill="none" stroke="#%s" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [color, paths.get(key, paths.mountain)]
	var im = Image.new()
	im.load_svg_from_string(svg)
	icons[id] = ImageTexture.create_from_image(im)
	return icons[id]

static func art(parent: Node, key: String, height: float = 44, gold: bool = false) -> TextureRect:
	var image = TextureRect.new()
	image.texture = icon(key, "f3d88c" if gold else "34eed3")
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(height, height)
	parent.add_child(image)
	return image
