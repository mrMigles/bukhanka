extends RefCounted

static func run(g: Node, check: Callable):
	var Model = preload("res://scripts/expedition_state.gd")
	var ResourceModel = preload("res://scripts/resource_system.gd")
	var s = Model.new()
	var r = ResourceModel.new(s)
	s.simulation_seconds = 420
	var daylight_count = 0
	for second in range(1200):
		s.simulation_seconds = second
		if not s.is_night(): daylight_count += 1
	check.call(daylight_count == 840, "RPG: exactly 70 percent daylight in a 1200-second day")
	var sunset_before = g.lighting.sky_weights(0.69999)
	var sunset_after = g.lighting.sky_weights(0.70001)
	check.call(sunset_before.distance_to(sunset_after) < 0.002 and g.lighting.sky_weights(0.85).y > 0.99, "UI: sunset is continuous and deep night reveals stars")
	check.call(g.lighting.sky_weights(0.99999).distance_to(g.lighting.sky_weights(0.00001)) < 0.002, "UI: dawn remains continuous across calendar wrap")
	s.simulation_seconds = 420
	var drive = r.power_balance(6, 0.3, 0, 0, 0, false, 3, 1)
	var camp = r.power_balance(0, 0, 0, 0, 0, true, 4, 1)
	check.call(camp.x > drive.x * 8 and drive.y > drive.x, "RPG: camp panels are faster; driving consumes net energy")
	s.upgrades.roof = 3
	var bad_weather = true
	for coefficient in [0.15, 0.10, 0.05]:
		var balance = r.power_balance(3, 0.5, 0.2, 1, 0, false, 3, coefficient)
		bad_weather = bad_weather and balance.y > balance.x
	check.call(bad_weather, "RPG: maximum roof upgrade cannot sustain travel in bad weather")
	s.simulation_seconds = 900
	check.call(r.power_balance(0, 0, 0, 0, 0, true, 0, 1).x == 0, "RPG: zero solar generation at night")
	s.food = 0
	check.call(not r.can_work(), "RPG: no work without food")
	s.food = 16
	s.water = 0
	check.call(not r.can_work(), "RPG: no work without water")
	s.water = 16
	var taken = s.harvest("test_bush", 4, 8, 2)
	var loaded = Model.new()
	loaded.decode(s.encode())
	s.camp_mode = "supplies"
	loaded.decode(s.encode())
	check.call(loaded.camp_mode == "supplies", "RPG: camp mode survives save/load")
	check.call(taken == 4 and loaded.stock_available("test_bush", 8, 2) == 4, "RPG: harvested stock survives save/load")
	var lake = g.world.director.sector(0)[12]
	var sample = g.world.sample_water(Vector3(lake.x, 0, lake.z))
	check.call(sample.present and sample.depth > 1 and sample.id == lake.id, "RPG: lake geometry and physical water query share a basin")
	var descriptors = g.world.director.sector(0).duplicate(true)
	g.world.director.sector(4)
	g.world.director.cache.erase(0)
	check.call(descriptors == g.world.director.sector(0), "RPG: POI generation is independent of chunk order")
	var first: Dictionary = {}
	for item in descriptors:
		if not first.has(item.kind): first[item.kind] = item.z - 120
	check.call(first.animals <= 250 and first.food <= 350 and first.waterfall <= 650 and first.lake <= 1000 and first.village <= 1300, "RPG: first-route discovery distances are guaranteed")
	g.van.position = Vector3(g.world.road_x(120), g.world.drive_height(g.world.road_x(120), 120) + 0.3, 120)
	g.dynamics.reset()
	g.speed = 0
	g.model.food = 16
	g.model.water = 16
	g.model.energy = 50
	g.model.simulation_seconds = 840
	g.model.crew[0].energy = 0
	if not g.camping: g.toggle_camp()
	check.call(g.camping, "RPG: safe starter campsite is available")
	var report = g.resources.sleep_until_dawn(g)
	check.call(not report.is_empty() and is_equal_approx(report.energy_used, 0.54) and is_equal_approx(report.food_used, 2.4) and g.model.phase() == 0, "RPG: sleep advances needs and the calendar without free charging")
	check.call(g.model.crew[0].energy >= 90 and g.model.crew[0].energy <= 100, "RPG: sleep recovery includes campsite rest quality")
	g.model.simulation_seconds = 240
	g.model.food = 16
	g.model.water = 16
	g.model.auto_projects = true
	g.money = 1500
	g.projects.active = {}
	g.projects.refresh_offers()
	check.call(is_equal_approx(g.projects.offers[0].duration, 1.0 / 3.0) and is_equal_approx(g.projects.offers[2].duration, 2.0), "Projects: eight-hour and two-day deadlines")
	var offer = g.projects.offers[0].duplicate(true)
	g.projects.accept(offer.id, g)
	var saved_project = g.projects.encode().duplicate(true)
	var manager = preload("res://scripts/project_manager.gd").new(g.model)
	manager.decode(saved_project)
	check.call(manager.active.seed == g.projects.active.seed and manager.active.pending, "RPG: contract seed and pending decision persist")
	g.weather.intensity = 0
	g.signal_speed = 30
	g.connection_quality = 0.6
	g.projects.resolve_decision("balanced", g)
	var expected_progress = g.work_rate() * 1.35
	var before_progress = g.projects.active.progress
	g.projects.tick(g, 1)
	check.call(expected_progress > 0 and is_equal_approx(g.projects.active.progress - before_progress, expected_progress), "Projects: faster development advances the contract")
	var start_money = g.money
	for step in range(500):
		g.model.simulation_seconds += 1
		g.crew_system.tick(g, 1)
		g.projects.tick(g, 1)
		if g.projects.settled.has(offer.id): break
	check.call(g.projects.settled.has(offer.id) and g.money > start_money, "RPG: complete automatic contract passes decisions and pays once")
	var xp = 0.0
	for hero in g.model.crew: xp += hero.xp
	check.call(xp > 0, "RPG: actual contributors gain IT experience")
	var earned = g.money
	g.projects.active = saved_project.active.duplicate(true)
	g.projects.finish(g)
	check.call(g.money == earned, "RPG: duplicate settlement cannot mint money")
	g.projects.active = {}
	g.model.auto_projects = false
	g.model.simulation_seconds = 300
	g.model.energy = 100
	g.model.food = 16
	g.model.water = 16
	g.autopilot = true
	g.auto_controller.tick(g, 1)
	g.update_packing(1.6)
	check.call(not g.camping and g.autopilot, "RPG: autopilot packs a charged and supplied camp")
	g.model.energy = 20
	g.auto_controller.tick(g, 0.1)
	check.call(is_finite(g.auto_controller.target_z), "RPG: autopilot finds a low-energy stop")
	g.model.cinematic = true
	g.update_camera(0.016)
	check.call(g.camera.position.is_finite(), "RPG: cinematic camera produces a finite safe pose")
	g.autopilot = false
	var food_point: Dictionary = {}
	for item in descriptors:
		if item.kind == "food":
			food_point = item
			break
	g.van.position = Vector3(g.world.road_x(food_point.z), g.world.drive_height(g.world.road_x(food_point.z), food_point.z) + 0.3, food_point.z)
	g.dynamics.reset()
	g.speed = 0
	g.model.food = 16
	g.model.water = 16
	g.toggle_camp()
	g.crew_system.set_mode(g, "auto")
	g.crew_system.schedule(g)
	var assigned = not g.crew_system.all_home()
	var destinations: Array = []
	var separate = true
	for task in g.crew_system.tasks:
		if task.is_empty(): continue
		for destination in destinations: separate = separate and destination.distance_to(task.destination) >= 1.0
		destinations.append(task.destination)
	check.call(assigned and separate, "RPG: gatherers use separate reachable interaction spots")
	for step in range(140): g.crew_system.tick(g, 1)
	check.call(assigned and g.model.food > 16, "RPG: auto replenishes normal starting food from real berries without manual assignments")
	g.model.simulation_seconds = 720
	g.model.food = 0
	g.model.depleted.clear()
	g.crew_system.return_all(g)
	g.crew_system.schedule(g)
	check.call(not g.crew_system.all_home(), "RPG: evening auto camp still gathers when food runs out")
	var cargo = 0.0
	for step in range(300):
		g.crew_system.tick(g, 0.1)
		for task in g.crew_system.tasks:
			if not task.is_empty(): cargo = maxf(cargo, task.carried)
		if cargo > 0: break
	check.call(cargo > 0, "RPG: a nearby food source produces a batch in under thirty seconds")
	var before_boarding = g.model.food
	g.toggle_camp()
	for step in range(16):
		g.crew_system.tick(g, 0.1)
		g.update_packing(0.1)
	check.call(not g.camping and g.model.food >= before_boarding + cargo, "RPG: fast boarding preserves collected food")
	g.model.simulation_seconds = 300
	g.toggle_camp()
	g.crew_system.set_mode(g, "work")
	for i in range(4): g.crew_system.start_return(g, i)
	g.auto_controller.departure = true
	for step in range(80): g.crew_system.tick(g, 1)
	g.auto_controller.departure = false
	check.call(g.crew_system.all_home(), "RPG: all gathering friends can return before departure")
	g.crew_system.schedule(g)
	check.call(g.crew_system.all_home(), "RPG: work mode does not send new gatherers")
	g.toggle_camp()
	g.update_packing(1.6)
	var water_camp = false
	for z in range(140, 900, 24):
		g.van.position = Vector3(g.world.road_x(z), g.world.drive_height(g.world.road_x(z), z) + 0.3, z)
		g.toggle_camp()
		if not g.camping: continue
		for source in g.crew_system.sources:
			if source.kind == "water": water_camp = true
		if water_camp: break
		g.toggle_camp()
		g.update_packing(1.6)
	g.model.water = 16
	g.crew_system.set_mode(g, "supplies")
	check.call(g.crew_system.work_sum(g) == 0, "RPG: supplies mode suspends IT work")
	for step in range(220): g.crew_system.tick(g, 1)
	check.call(water_camp and g.model.water > 16, "RPG: crew reaches a real dry riverbank and delivers water automatically")
	g.crew_system.set_mode(g, "work")
	var tunnel: Dictionary = {}
	for item in descriptors:
		if item.kind == "tunnel": tunnel = item
	check.call(not tunnel.is_empty(), "RPG: starting region has a tunnel")
	if not tunnel.is_empty():
		var p = Vector3(g.world.road_x(tunnel.z), g.world.drive_height(g.world.road_x(tunnel.z), tunnel.z), tunnel.z)
		check.call(g.world.solar_exposure(p, 0.3) == 0 and not g.world.director.shell_blocked(p + Vector3(0, 2, 0)) and g.world.director.shell_blocked(p + Vector3(4.1, 2, 0)), "RPG: tunnel blocks sunlight and walls, leaving a driveable interior")
	g.paused = true
	var before = g.model.simulation_seconds
	g._physics_process(1)
	check.call(g.model.simulation_seconds == before, "RPG: pause freezes simulation")
	g.paused = false
	g.rpg_ui.open_panel("projects")
	g.rpg_ui.open_panel("crew")
	g.rpg_ui.open_panel("upgrades")
	g.rpg_ui.open_panel("camp")
	g.rpg_ui.close_panel()
	check.call(not g.rpg_ui.overlay.visible, "RPG: gameplay panels build and close")
	g.crew_system.return_all(g)
	if g.camping: g.toggle_camp()
	g.update_packing(1.6)
	g.rpg_ui.open_panel("placement")
	var panel = g.rpg_ui.screens
	check.call(not panel.assessment.is_empty() and is_instance_valid(panel.preview_camera), "UI: campsite placement builds a live preview and terrain assessment")
	var invalid = g.camp_controller.evaluate(g, g.van.position + Vector3(100, 0, 0))
	check.call(not invalid.valid, "UI: a campsite too far from the vehicle cannot be placed")
	g.rpg_ui.open_panel("settings")
	g.rpg_ui.close_panel()
	g.rpg_ui.open_panel("editor")
	await g.get_tree().process_frame
	await g.get_tree().process_frame
	var start_button = g.rpg_ui.content.find_child("StartExpedition", true, false)
	var previews = g.rpg_ui.content.find_children("*", "SubViewport", true, false)
	var isolated = true
	for viewport in previews: isolated = isolated and viewport.find_world_3d() != g.get_world_3d()
	check.call(isolated, "UI: portrait lights belong to isolated worlds and cannot overexpose the landscape")
	check.call(previews.size() == 4 and is_instance_valid(start_button) and start_button.get_global_rect().end.y <= g.get_viewport().get_visible_rect().size.y, "UI: editor keeps four low-poly previews and its start action on screen")
	g.rpg_ui.close_panel()
	g.paused = true
	for screen in ["camp", "crew", "projects", "upgrades", "placement", "journal", "settings"]:
		g.rpg_ui.open_panel(screen)
		await g.get_tree().process_frame
		await g.get_tree().process_frame
		var rect = g.rpg_ui.body.get_global_rect()
		check.call(rect.end.x <= g.get_viewport().get_visible_rect().size.x + 1 and rect.end.y <= g.get_viewport().get_visible_rect().size.y + 1, "UI: %s panel fits the viewport" % screen)
		if screen == "crew": check.call(g.rpg_ui.content.get_global_rect().end.y <= rect.end.y, "UI: crew content needs no vertical scrolling")
	g.rpg_ui.close_panel()
	g.paused = false
	var forest_samples = 0
	for z in range(0, 2304, 12):
		if g.world.director.forest_density(z) > 0: forest_samples += 1
	var forest_instances = 0
	for chunk in g.world.chunks.values():
		var trees = chunk.get_node_or_null("ForestBelt")
		if trees != null: forest_instances += trees.multimesh.instance_count
	check.call(forest_samples > 10 and forest_samples < 30 and forest_instances > 0, "World: sparse forest belts generate instanced trees while mountains dominate")
	if g.camping:
		g.toggle_camp()
		g.update_packing(1.6)
	var village_z = 1368.0
	g.van.position = Vector3(g.world.road_x(village_z), g.world.drive_height(g.world.road_x(village_z), village_z) + 0.3, village_z)
	g.speed = 0
	g.toggle_camp()
	check.call(g.camping and g.world.near_village(g.van.position), "Shop: village has an accessible campsite")
	g.money = 2000
	g.model.food = 10
	g.model.water = 10
	g.model.energy = 20
	g.shop_charge = 0
	g.rpg_ui.open_panel("shop")
	await g.get_tree().process_frame
	await g.get_tree().process_frame
	var buy_food = g.rpg_ui.content.find_child("Buy_food", true, false)
	check.call(buy_food != null and buy_food.get_global_rect().end.y < g.get_viewport().get_visible_rect().size.y, "Shop: purchase buttons stay on screen")
	buy_food.pressed.emit()
	g.shop_purchase("water", 160, 8)
	check.call(g.model.food == 18 and g.model.water == 18 and g.money == 1440, "Shop: buttons deliver supplies and deduct the displayed prices")
	g.shop_purchase("energy", 300, 60)
	g.shop_purchase("energy", 300, 60)
	check.call(g.shop_charge == 60 and g.money == 1140, "Shop: charging starts and cannot be purchased twice")
	g.rpg_ui.close_panel()
	g.tutorial.open()
	var tutorial_time = g.model.simulation_seconds
	g._physics_process(1)
	check.call(g.model.simulation_seconds == tutorial_time, "Tutorial: time and supplies pause while reading")
	for page in range(3):
		g.tutorial.page = page
		g.tutorial.rebuild()
		await g.get_tree().process_frame
		await g.get_tree().process_frame
		check.call(g.tutorial.next.get_global_rect().end.y <= g.get_viewport().get_visible_rect().size.y and g.tutorial.viewport.find_world_3d() == g.get_world_3d(), "Tutorial: page %d has a live render and reachable navigation" % (page + 1))
	g.tutorial.finish()
	g.save_game()
	var copy = g.saves.read_data(true)
	check.call(copy.get("tutorial_seen", false) and copy.get("shop_charge", 0) == 60, "Save: completed tutorial and paid charging survive reload data")
	check.call(copy.get("schema_version") == 2 and g.save_path().contains("test_journey_v2"), "RPG: versioned saves remain isolated from user progress")
