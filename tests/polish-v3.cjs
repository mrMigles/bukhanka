const fs=require('fs');let s=fs.readFileSync('scripts/game.gd','utf8');
s=s.replace('var beat = fmod(t, 1.5)',`var beat = fmod(t, 1.5)`);
const start=s.indexOf('\t\telse:\n\t\t\tvar beat = fmod(t, 1.5)'),end=s.indexOf('\n\t\tvar envelope',start);
if(start<0)throw Error('audio block');
s=s.slice(0,start)+`\t\telse:
			var chord = [110.0, 130.813, 98.0, 146.832][int(t / 3) % 4]
			for string_index in range(4):
				var beat = fmod(t, 3.0) - string_index * 0.13
				if beat < 0: continue
				var note = chord * [1.0, 1.5, 2.0, 2.3784][string_index]
				for harmonic in range(1, 7):
					sample += sin(TAU * note * harmonic * beat) / harmonic * exp(-beat * (1.1 + harmonic * 0.4)) * minf(beat * 180, 1) * 0.075
`+s.slice(end);
// A seated guitarist and friends who occasionally stand and walk around the campsite.
s=s.replace('friend.set_meta("seat", p)',`friend.set_meta("seat", p)
		var legs: Array = []
		if i > 0:
			for side in [-1, 1]:
				var leg = van.box(friend, Vector3(side * 0.1, -0.05, 0.04), Vector3(0.13, 0.55, 0.13), van.dark)
				leg.hide()
				legs.append(leg)
		friend.set_meta("walking_legs", legs)`);
s=s.replace('if i == 0:\n\t\t\tperson.rotation.z', 'for leg in person.get_meta("walking_legs", []):\n\t\t\tleg.visible = phase > 18 and phase < 43\n\t\t\tleg.rotation.x = sin(camp_clock * 5 + leg.position.x * 16) * 0.35\n\t\tif i == 0:\n\t\t\tperson.rotation.z');
s=s.replace('- camp.position.y + 0.15 + abs', '- camp.position.y + 0.4 + abs');
// Dedicated weather ambience, independent of music and the engine.
s=s.replace('var wind_audio: AudioStreamPlayer', 'var rain_audio: AudioStreamPlayer\nvar wind_audio: AudioStreamPlayer');
s=s.replace('music_audio.play()','music_audio.play()\n\train_audio = AudioStreamPlayer.new()\n\train_audio.stream = wind_audio.stream\n\train_audio.volume_db = -60\n\tadd_child(rain_audio)\n\train_audio.play()');
s=s.replace('music_audio.volume_db = lerpf', 'rain_audio.volume_db = -60 + weather.intensity * 46\n\tmusic_audio.volume_db = lerpf');
s=s.replace('[engine_audio, wind_audio, music_audio]', '[engine_audio, wind_audio, music_audio, rain_audio]');
fs.writeFileSync('scripts/game.gd',s);
s=fs.readFileSync('scripts/world.gd','utf8').replace('smoothstep(3.5, 13, d)','smoothstep(6.5, 16, d)').replace('smoothstep(3.5, 12, bd)','smoothstep(6.5, 15, bd)');fs.writeFileSync('scripts/world.gd',s);
s=fs.readFileSync('scripts/interface.gd','utf8');
s=s.replace('var menu_caption: Label','var journey_label: Label\nvar menu_caption: Label');
s=s.replace('var account = panel(hud,',`var journal = panel(hud, Rect2(720, 26, 395, 81))
	label(journal, "ПУТЕВОЙ ДНЕВНИК", Vector2(16, 12), 12, green)
	journey_label = label(journal, "К перевалу: по левой тропе", Vector2(16, 37), 15, cream, 360)
	var account = panel(hud,`);
s=s.replace('"Пробел  тормоз   ·   R  на дорогу   ·   P фото · K снимок · Esc меню"', '"L пониженная · F лебёдка · ПКМ обзор · Esc меню"');
s=s.replace('"W / S  газ     A / D  руль"','"WASD ехать · L тяга · F трос"');
s=s.replace('trip_label.text = regions[posmod(int(game.van.position.z / 900), 4)] + " / " + game.weather.current_name','trip_label.text = game.weather.current_name + " · " + ("ПЕРЕВАЛ" if game.world.nearest_route(game.van.position.x, game.van.position.z) else "ДОЛИНА")');
s=s.replace('terrain_label.text = "%s · %d м · %.1f км" % [game.surface_name, 1240 + int(game.van.position.y), game.distance / 1000.0]','terrain_label.text = "%s · %d м" % [game.surface_name, 1240 + int(game.van.position.y)]\n\tjourney_label.text = "%d открытий · %s" % [game.discoveries.size(), "Пониженная 4L" if game.low_range else "Перевал ← / долина →"]');
s=s.replace('var river = PackedVector2Array()','var river = PackedVector2Array()\n\tvar branch = PackedVector2Array()');
s=s.replace('points.append(Vector2(', 'branch.append(Vector2(102 + (game.world.branch_x(pz) - game.van.position.x) * 0.65, 152 - i * 4.3))\n\t\tpoints.append(Vector2(');
s=s.replace('mini.draw_polyline(points, accent, 3, true)', 'mini.draw_polyline(points, accent, 3, true)\n\tmini.draw_polyline(branch, green, 2, true)');
s=s.replace('func(): game.save_game(); game.get_tree().quit()', 'func(): game.show_title() if OS.has_feature("web") else game.exit_game()');
fs.writeFileSync('scripts/interface.gd',s);
fs.appendFileSync('scripts/game.gd','\nfunc exit_game():\n\tsave_game()\n\tget_tree().quit()\n');
