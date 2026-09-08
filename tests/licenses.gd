extends SceneTree
func _initialize():
	var file = FileAccess.open("C:/code/bukhanka/builds/Windows/GODOT-LICENSE.txt", FileAccess.WRITE)
	file.store_string(Engine.get_license_text())
	file.close()
	file = FileAccess.open("C:/code/bukhanka/builds/Windows/GODOT-THIRD-PARTY.txt", FileAccess.WRITE)
	file.store_line("License notices extracted from the shipped Godot engine:\n")
	for component in Engine.get_copyright_info():
		file.store_line(JSON.stringify(component, "  "))
	var licenses = Engine.get_license_info()
	for key in licenses:
		file.store_line("\n" + key + "\n" + licenses[key])
	file.close()
	quit()
