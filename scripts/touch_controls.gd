extends Control
var game: Node
var throttle = 0.0
var steer = 0.0
var braking = false
var enabled = false
var joystick_id = -1
var camera_id = -1
var brake_id = -1
var stick = Vector2.ZERO
var center = Vector2(185, 690)
var actions: Control
var brake_button: Button
var action_buttons: Array[Button] = []

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	enabled = DisplayServer.is_touchscreen_available() or "--touch-test" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		enabled = bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0 && matchMedia('(pointer: coarse)').matches", true)) or "--touch-test" in OS.get_cmdline_user_args()
	actions = Control.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(actions)
	action_buttons.append(game.ui.button(actions, "ЛАГЕРЬ", Rect2(1110, 650, 140, 65), func(): game.toggle_camp()))
	action_buttons.append(game.ui.button(actions, "АВТОПИЛОТ", Rect2(1110, 725, 140, 65), func(): game.toggle_auto()))
	action_buttons.append(game.ui.button(actions, "4L", Rect2(1260, 570, 120, 65), func(): game.set_low_range(not game.low_range)))
	action_buttons.append(game.ui.button(actions, "ТРОС", Rect2(1260, 650, 120, 65), func(): game.winch()))
	action_buttons.append(game.ui.button(actions, "КАМЕРА", Rect2(1110, 570, 140, 65), func(): game.cycle_camera()))
	action_buttons.append(game.ui.button(actions, "ПАУЗА", Rect2(1260, 490, 120, 65), func(): game.toggle_pause()))
	action_buttons.append(game.ui.button(actions, "МЕНЮ", Rect2(1110, 490, 140, 65), func(): game.rpg_ui.open_panel("camp")))
	brake_button = game.ui.button(actions, "ТОРМОЗ", Rect2(1260, 725, 120, 65), func(): pass, true)
	action_buttons.append(brake_button)
	brake_button.button_down.connect(func(): braking = true)
	brake_button.button_up.connect(func(): braking = false)
	visible = enabled
	if enabled: configure_mobile_layout()
	get_viewport().size_changed.connect(configure_mobile_layout)

func configure_mobile_layout():
	if not enabled or game.test_mode: return
	var view = get_viewport_rect().size
	var factor = 2.1 if view.y > view.x else 1.4
	scale = Vector2.ONE * factor
	var local_view = view / factor
	center = Vector2(150, local_view.y - 160)
	var button_x = local_view.x - 220
	var button_y = local_view.y - action_buttons.size() * 82 - 20
	for i in range(action_buttons.size()):
		action_buttons[i].position = Vector2(button_x, button_y + i * 82)
		action_buttons[i].size = Vector2(200, 76)
		action_buttons[i].add_theme_font_size_override("font_size", 20)

func local_pointer(position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * position

func _process(_delta):
	visible = enabled and game.started and not game.paused and not game.ui.garage.visible and not game.photo and not game.rpg_ui.overlay.visible
	if not visible:
		throttle = 0
		steer = 0
		braking = false
		joystick_id = -1
		camera_id = -1
		brake_id = -1
		stick = Vector2.ZERO
	queue_redraw()

func _draw():
	if not visible: return
	draw_circle(center, 100, Color(0.06, 0.14, 0.15, 0.65))
	draw_arc(center, 94, 0, TAU, 48, Color("d4ba85"), 3, true)
	draw_line(center + Vector2(-55, 0), center + Vector2(55, 0), Color(0.8, 0.8, 0.7, 0.3), 2)
	draw_line(center + Vector2(0, -55), center + Vector2(0, 55), Color(0.8, 0.8, 0.7, 0.3), 2)
	draw_circle(center + stick * 70, 36, Color("e3bf7f"))
	draw_circle(center + stick * 70, 27, Color("344d45"))

func set_stick(position: Vector2):
	stick = ((position - center) / 80).limit_length()
	steer = -stick.x if abs(stick.x) > 0.1 else 0.0
	throttle = -stick.y if abs(stick.y) > 0.1 else 0.0

func _input(event):
	if event is InputEventScreenTouch and not enabled:
		enabled = true
		game.ui.apply_mobile_layout()
	if not enabled or not game.started or game.paused or game.ui.garage.visible or game.rpg_ui.overlay.visible: return
	var pointer = local_pointer(event.position) if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag else Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and pointer.distance_to(center) < 140 and joystick_id == -1:
			joystick_id = -2
			set_stick(pointer)
			get_viewport().set_input_as_handled()
		elif not event.pressed and joystick_id == -2:
			joystick_id = -1
			stick = Vector2.ZERO
			throttle = 0
			steer = 0
	if event is InputEventMouseMotion and joystick_id == -2:
		set_stick(pointer)
		get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch:
		if event.pressed and Rect2(brake_button.position, brake_button.size).has_point(pointer):
			brake_id = event.index
			braking = true
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == brake_id:
			brake_id = -1
			braking = false
		elif event.pressed and pointer.distance_to(center) < 140 and joystick_id == -1:
			joystick_id = event.index
			set_stick(pointer)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == joystick_id:
			joystick_id = -1
			stick = Vector2.ZERO
			throttle = 0
			steer = 0
		elif event.pressed and pointer.y > 180 and pointer.y < center.y - 170 and pointer.x < (get_viewport_rect().size.x / scale.x - 220):
			camera_id = event.index
		elif not event.pressed and event.index == camera_id: camera_id = -1
	if event is InputEventScreenDrag:
		if event.index == joystick_id:
			set_stick(pointer)
			get_viewport().set_input_as_handled()
		elif event.index == camera_id:
			game.model.cinematic = false
			game.orbit_yaw -= event.relative.x * 0.005
			game.orbit_pitch = clampf(game.orbit_pitch + event.relative.y * 0.004, 0.08, 1.1)
			game.camera_idle = 0
