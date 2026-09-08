const fs=require('fs');let s=fs.readFileSync('scripts/game.gd','utf8');
s=s.replace('if event is InputEventMouseButton:\n\t\tif event.button_index', 'if event is InputEventMouseButton:\n\t\tif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: looking = false\n\t\tif event.button_index');
s+=`
func _unhandled_input(event):
	if started and not paused and not ui.garage.visible and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			looking = true
			camera_idle = 0
`;
s=s.replace('friend.set_meta("walking_legs", legs)',`friend.set_meta("walking_legs", legs)
		var bubble = Label3D.new()
		bubble.text = ["Миша: сыграю ещё одну...", "Соня: пойду посмотрю на реку.", "Лёша: чай почти готов!", "Даня: вот ради чего мы ехали."][i]
		bubble.font_size = 32
		bubble.pixel_size = 0.009
		bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		bubble.position = Vector3(0, 1.5, 0)
		bubble.modulate = Color("f0e3c4")
		friend.add_child(bubble)
		friend.set_meta("bubble", bubble)`);
s=s.replace('var phase = fposmod(camp_clock + i * 11, 52)', 'var phase = fposmod(camp_clock + i * 11, 52)\n\t\tperson.get_meta("bubble").visible = int(camp_clock / 9) % 4 == i and fmod(camp_clock, 9) < 6');
fs.writeFileSync('scripts/game.gd',s);
