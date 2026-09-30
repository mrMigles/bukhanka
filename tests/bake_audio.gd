extends SceneTree
## Rebuild the original procedural loops once, outside the browser startup path.
func _initialize():
	var game = load("res://scripts/game.gd").new()
	DirAccess.make_dir_recursive_absolute("res://assets/audio")
	for kind in range(3):
		var audio = game.make_audio(kind)
		var result = audio.save_to_wav("res://assets/audio/" + ["engine", "wind", "music"][kind] + ".wav")
		if result != OK:
			quit(1)
			return
	game.free()
	quit()
