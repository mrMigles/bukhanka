extends RefCounted
## Read-only state for explicitly requested browser E2E sessions (?e2e).
static func publish(g: Node):
	var view = g.get_viewport().get_visible_rect().size
	var width = float(JavaScriptBridge.eval("innerWidth"))
	var factor = width / view.x
	var buttons: Array = []
	for node in [g.ui, g.rpg_ui, g.tutorial, g.touch_controls]: collect_buttons(node, factor, buttons)
	var t = g.touch_controls
	var icons = {}
	for b in t.action_buttons:
		if b.has_meta("hud_icon"): icons[str(b.name)] = b.get_meta("hud_icon")
	var state = {"started": g.started, "paused": g.paused, "running": g.simulation_running(), "tutorial": g.tutorial.visible,
		"speed": g.speed, "position": [g.van.position.x, g.van.position.z], "heading": g.heading, "velocity": [g.dynamics.velocity.x, g.dynamics.velocity.z],
		"yaw": g.orbit_yaw, "pitch": g.orbit_pitch, "follow_clock": g.camera_motion_clock, "camera_mode": g.camera_mode, "fps": Engine.get_frames_per_second(),
		"panel": g.rpg_ui.section if g.rpg_ui.overlay.visible else "", "panel_bounds": bounds(g.rpg_ui.body, factor), "low_range": g.low_range, "tools": t.tools_open, "touch": t.enabled, "throttle": t.throttle, "steer": t.steer, "braking": t.braking,
		"joystick": {"x": t.center.x, "y": t.center.y, "radius": 52}, "controls": t.hud.button_rects(), "buttons": buttons,
		"hud_icons": icons, "speedometer": bounds(t.hud.gauge, factor), "speed_text": t.hud.speed.text}
	var overflowing: Array = []
	collect_overflow(g.rpg_ui.body, factor, width, overflowing)
	state["overflow"] = overflowing
	var scroll = g.rpg_ui.content_scroll
	state["scroll"] = {"offset": scroll.scroll_vertical, "max": maxf(0, scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page), "horizontal": scroll.scroll_horizontal, "bounds": bounds(scroll, factor)}
	state["camping"] = g.camping
	state["ghost"] = is_instance_valid(g.rpg_ui.screens.ghost)
	state["camp_angle"] = g.rpg_ui.screens.angle
	state["performance"] = {"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, "draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	state["candidate"] = [g.rpg_ui.screens.candidate.x, g.rpg_ui.screens.candidate.z]
	state["voice_volume"] = g.model.voice_volume
	state["modules"] = g.model.upgrades
	var sliders: Dictionary = {}
	collect_sliders(g.rpg_ui, factor, sliders)
	state["sliders"] = sliders
	var popups: Array = []
	collect_popups(g.rpg_ui, factor, popups)
	state["popups"] = popups
	if is_instance_valid(g.rpg_ui.screens.preview) and g.rpg_ui.section == "placement" and g.rpg_ui.overlay.visible:
		state["camp_map"] = bounds(g.rpg_ui.screens.preview.get_parent(), factor)
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

static func collect_popups(node: Node, factor: float, result: Array):
	if node is OptionButton and node.get_popup().visible:
		var popup = node.get_popup()
		result.append({"name": str(node.name), "x": popup.position.x * factor, "y": popup.position.y * factor, "width": popup.size.x * factor, "height": popup.size.y * factor, "items": popup.item_count})
	for child in node.get_children(): collect_popups(child, factor, result)

static func collect_sliders(node: Node, factor: float, result: Dictionary):
	if node is HSlider and node.is_visible_in_tree(): result[str(node.name)] = bounds(node, factor)
	for child in node.get_children(): collect_sliders(child, factor, result)
