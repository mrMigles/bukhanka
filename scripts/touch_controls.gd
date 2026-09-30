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
var center = Vector2(72, 720)
var camera_pointer = Vector2.ZERO
var actions: Control
var brake_button: Button
var action_buttons: Array[Button] = []
var tools_open = false
var screen_size = Vector2(1280, 800)
var safe_area = Vector4.ZERO
var refresh_clock = 0.0
var hud = preload("res://scripts/mobile_hud.gd").new()

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	enabled = DisplayServer.is_touchscreen_available() or "--touch-test" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		enabled = bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0 && matchMedia('(pointer: coarse)').matches", true)) or "--touch-test" in OS.get_cmdline_user_args()
	actions = Control.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(actions)
	hud.build(self)
	visible = enabled
	if enabled: configure_mobile_layout()
	get_viewport().size_changed.connect(configure_mobile_layout)

func configure_mobile_layout():
	if not enabled: return
	var physical = Vector2(DisplayServer.window_get_size())
	if physical.x < 1 or physical.y < 1: physical = get_viewport_rect().size
	if OS.has_feature("web"):
		var result = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify({width:innerWidth,height:innerHeight,insets:['left','top','right','bottom'].map(s=>parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--safe-'+s))||0)})")))
		if result is Dictionary:
			physical = Vector2(result.width, result.height)
			var inset = result.insets
			safe_area = Vector4(inset[0], inset[1], inset[2], inset[3])
	configure_for_size(Vector2(maxf(320, physical.x), maxf(180, physical.y)), safe_area)

func configure_for_size(view: Vector2, safe: Vector4 = Vector4.ZERO):
	reset_input()
	screen_size = view
	safe_area = safe
	scale = Vector2.ONE * (get_viewport_rect().size.x / view.x)
	hud.layout(view, safe)
	queue_redraw()

func local_pointer(pointer: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * pointer

func reset_input():
	throttle = 0
	steer = 0
	braking = false
	joystick_id = -1
	camera_id = -1
	brake_id = -1
	stick = Vector2.ZERO
	queue_redraw()

func toggle_tools():
	if tools_open: close_tools(); return
	reset_input()
	game.release_mouse()
	tools_open = true
	hud.tools.show()
	hud.refresh()

func close_tools():
	tools_open = false
	hud.tools.hide()
	reset_input()

func _process(delta):
	visible = enabled and game.started and not game.paused and not game.ui.garage.visible and not game.photo and not game.rpg_ui.overlay.visible and not game.tutorial.visible
	if not visible:
		if tools_open: close_tools()
		else: reset_input()
		return
	refresh_clock += delta
	if refresh_clock >= 0.1:
		refresh_clock = 0
		hud.refresh()
	if joystick_id != -1 or braking: queue_redraw()

func _draw():
	if not visible: return
	draw_circle(center, 52, Color(0.035, 0.12, 0.13, 0.48))
	draw_arc(center, 51, 0, TAU, 48, Color(0.62, 0.82, 0.79, 0.6), 1.5, true)
	draw_line(center + Vector2(-27, 0), center + Vector2(27, 0), Color(0.8, 0.9, 0.85, 0.16), 1, true)
	draw_line(center + Vector2(0, -27), center + Vector2(0, 27), Color(0.8, 0.9, 0.85, 0.16), 1, true)
	draw_circle(center + stick * 32, 22, Color(0.84, 0.74, 0.51, 0.85))
	draw_circle(center + stick * 32, 17, Color(0.08, 0.26, 0.25, 0.9))

func set_stick(pointer: Vector2):
	stick = ((pointer - center) / 42).limit_length()
	steer = -stick.x if abs(stick.x) > 0.1 else 0.0
	throttle = -stick.y if abs(stick.y) > 0.1 else 0.0
	queue_redraw()

func world_pointer(pointer: Vector2) -> bool:
	if pointer.y < safe_area.y + 70: return false
	if pointer.distance_to(center) < 74: return false
	for b in action_buttons:
		if Rect2(b.position - Vector2(5, 5), b.size + Vector2(10, 10)).has_point(pointer): return false
	return true

func press_pointer(id: int, pointer: Vector2) -> bool:
	if Rect2(brake_button.position, brake_button.size).has_point(pointer) and brake_id == -1:
		brake_id = id
		braking = true
	elif pointer.distance_to(center) < 74 and joystick_id == -1:
		joystick_id = id
		set_stick(pointer)
	elif world_pointer(pointer) and camera_id == -1:
		camera_id = id
		camera_pointer = pointer
		game.camera_idle = 0
	else: return false
	return true

func release_pointer(id: int):
	if id == brake_id:
		brake_id = -1
		braking = false
	if id == joystick_id:
		joystick_id = -1
		stick = Vector2.ZERO
		throttle = 0
		steer = 0
	if id == camera_id: camera_id = -1
	queue_redraw()

func drag_pointer(id: int, pointer: Vector2):
	if id == joystick_id: set_stick(pointer)
	elif id == camera_id:
		var motion = pointer - camera_pointer
		camera_pointer = pointer
		game.model.cinematic = false
		game.orbit_yaw -= motion.x * 0.006
		game.orbit_pitch = clampf(game.orbit_pitch + motion.y * 0.004, 0.08, 1.1)
		game.camera_idle = 0

func _input(event):
	if event is InputEventScreenTouch and not enabled:
		enabled = true
		game.ui.apply_mobile_layout()
	if not enabled or not visible or tools_open: return
	if event is InputEventScreenTouch:
		if event.pressed:
			if press_pointer(event.index, local_pointer(event.position)): get_viewport().set_input_as_handled()
		else: release_pointer(event.index)
	elif event is InputEventScreenDrag:
		drag_pointer(event.index, local_pointer(event.position))
		if event.index == joystick_id or event.index == camera_id or event.index == brake_id: get_viewport().set_input_as_handled()
	elif event.device != InputEvent.DEVICE_ID_EMULATION:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if press_pointer(-2, local_pointer(event.position)): get_viewport().set_input_as_handled()
			else: release_pointer(-2)
		elif event is InputEventMouseMotion and (joystick_id == -2 or camera_id == -2):
			drag_pointer(-2, local_pointer(event.position))
			get_viewport().set_input_as_handled()
