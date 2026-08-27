extends TestCase

## Szenen-Skripte werden von der Suite sonst NIE kompiliert: sie stehen in
## keiner SUITES-Liste. Ein Tippfehler in scenes/ blieb dadurch gruen und fiel
## erst beim Starten der Szene auf.

func _all_scripts(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		var name := Database.resource_name_of(f)
		if f.ends_with(".gd") or f.ends_with(".gd.remap"):
			out.append(dir_path.path_join(f.trim_suffix(".remap")))
	for d in dir.get_directories():
		_all_scripts(dir_path.path_join(d), out)

func test_every_script_outside_tests_compiles() -> void:
	var scripts: Array = []
	for folder in ["res://scenes", "res://core", "res://autoload", "res://resources", "res://tools"]:
		_all_scripts(folder, scripts)
	assert_true(scripts.size() >= 20, "es sollten mindestens 20 Skripte sein, gefunden: %d" % scripts.size())
	for path in scripts:
		var res: Resource = load(path)
		# load() liefert auch bei einem Parse-Fehler ein Objekt zurueck --
		# can_instantiate() ist der Pruefstein (in Task 3c gemessen).
		assert_true(res != null and (res as Script).can_instantiate(),
			"kompiliert nicht: %s" % path)

func test_every_scene_loads() -> void:
	var scenes: Array = []
	_all_scenes("res://scenes", scenes)
	assert_true(scenes.size() >= 6, "es sollten mindestens 6 Szenen sein, gefunden: %d" % scenes.size())
	for path in scenes:
		var ps: Resource = load(path)
		assert_true(ps != null and (ps as PackedScene).can_instantiate(),
			"Szene laedt nicht: %s" % path)

func _all_scenes(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".tscn") or f.ends_with(".tscn.remap"):
			out.append(dir_path.path_join(f.trim_suffix(".remap")))
	for d in dir.get_directories():
		_all_scenes(dir_path.path_join(d), out)
