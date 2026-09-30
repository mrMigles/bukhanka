extends RefCounted
## Read-only state for explicitly requested browser E2E sessions (?e2e).
static func publish(g: Node):
	var view = g.get_viewport().get_visible_rect().size
	var width = float(JavaScriptBridge.eval("innerWidth"))
	var factor = width / view.x
	var buttons: Array = []
	for node in [g.ui, g.rpg_ui, g.tutorial, g.touch_controls]: collect_buttons(node, factor, buttons)
	var t = g.touch_controls
	var state = {"started": g.started, "paused": g.paused, "running": g.simulation_running(), "tutorial": g.tutorial.visible,
		"speed": g.speed, "position": [g.van.position.x, g.van.position.z], "heading": g.heading, "velocity": [g.dynamics.velocity.x, g.dynamics.velocity.z],
		"yaw": g.orbit_yaw, "pitch": g.orbit_pitch, "follow_clock": g.camera_motion_clock, "camera_mode": g.camera_mode, "fps": Engine.get_frames_per_second(),
		"panel": g.rpg_ui.section if g.rpg_ui.overlay.visible else "", "panel_bounds": bounds(g.rpg_ui.body, factor), "low_range": g.low_range, "tools": t.tools_open, "touch": t.enabled, "throttle": t.throttle, "steer": t.steer, "braking": t.braking,
		"joystick": {"x": t.center.x, "y": t.center.y, "radius": 52}, "controls": t.hud.button_rects(), "buttons": buttons}
	var overflowing: Array = []
	collect_overflow(g.rpg_ui.body, factor, width, overflowing)
	state["overflow"] = overflowing
	JavaScriptBridge.eval("window.bukhankaTestState = " + JSON.stringify(state))

static func collect_overflow(node: Node, factor: float, width: float, result: Array):
	if node is Control and node.is_visible_in_tree() and node.get_combined_minimum_size().x * factor > width - 48:
		result.append({"path": str(node.get_path()), "minimum": node.get_combined_minimum_size().x * factor})
	for child in node.get_children(): collect_overflow(child, factor, width, result)

static func bounds(node: Control, factor: float) -> Dictionary:
	var rect = node.get_global_rect()
	return {"x": rect.position.x * factor, "y": rect.position.y * factor, "width": rect.size.x * factor, "height": rect.size.y * factor}

static func collect_buttons(node: Node, factor: float, result: Array):
	if node is Button and node.is_visible_in_tree():
		var rect = node.get_global_rect()
		var caption = str(node.get_meta("caption").text) if node.has_meta("caption") else node.text
		result.append({"name": str(node.name), "text": caption, "disabled": node.disabled, "x": rect.position.x * factor, "y": rect.position.y * factor, "width": rect.size.x * factor, "height": rect.size.y * factor})
	for child in node.get_children(): collect_buttons(child, factor, result)
