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

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	enabled = DisplayServer.is_touchscreen_available() or "--touch-test" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		enabled = bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0 && matchMedia('(pointer: coarse)').matches", true)) or "--touch-test" in OS.get_cmdline_user_args()
	actions = Control.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(actions)
	game.ui.button(actions, "ЛАГЕРЬ", Rect2(1110, 650, 140, 65), func(): game.toggle_camp())
	game.ui.button(actions, "АВТОПИЛОТ", Rect2(1110, 725, 140, 65), func(): game.toggle_auto())
	game.ui.button(actions, "4L", Rect2(1260, 570, 120, 65), func(): game.set_low_range(not game.low_range))
	game.ui.button(actions, "ТРОС", Rect2(1260, 650, 120, 65), func(): game.winch())
	game.ui.button(actions, "КАМЕРА", Rect2(1110, 570, 140, 65), func(): game.cycle_camera())
	game.ui.button(actions, "ПАУЗА", Rect2(1260, 490, 120, 65), func(): game.toggle_pause())
	brake_button = game.ui.button(actions, "ТОРМОЗ", Rect2(1260, 725, 120, 65), func(): pass, true)
	brake_button.button_down.connect(func(): braking = true)
	brake_button.button_up.connect(func(): braking = false)
	visible = enabled

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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.distance_to(center) < 140 and joystick_id == -1:
			joystick_id = -2
			set_stick(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and joystick_id == -2:
			joystick_id = -1
			stick = Vector2.ZERO
			throttle = 0
			steer = 0
	if event is InputEventMouseMotion and joystick_id == -2:
		set_stick(event.position)
		get_viewport().set_input_as_handled()
	if event is InputEventScreenTouch:
		if event.pressed and Rect2(1260, 725, 120, 65).has_point(event.position):
			brake_id = event.index
			braking = true
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == brake_id:
			brake_id = -1
			braking = false
		elif event.pressed and event.position.distance_to(center) < 140 and joystick_id == -1:
			joystick_id = event.index
			set_stick(event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == joystick_id:
			joystick_id = -1
			stick = Vector2.ZERO
			throttle = 0
			steer = 0
		elif event.pressed and event.position.y > 180 and event.position.y < 550 and event.position.x < 1100:
			camera_id = event.index
		elif not event.pressed and event.index == camera_id: camera_id = -1
	if event is InputEventScreenDrag:
		if event.index == joystick_id:
			set_stick(event.position)
			get_viewport().set_input_as_handled()
		elif event.index == camera_id:
			game.model.cinematic = false
			game.orbit_yaw -= event.relative.x * 0.005
			game.orbit_pitch = clampf(game.orbit_pitch + event.relative.y * 0.004, 0.08, 1.1)
			game.camera_idle = 0
