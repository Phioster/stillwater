extends TestCase

## In der APK heissen die Daten "x.tres.remap", im Quellbaum "x.tres". Bis
## Godot einmal wirklich exportiert hatte, war dieser Unterschied unsichtbar --
## und liess in der APK keine einzige Datendatei laden.

func test_plain_tres_is_accepted() -> void:
	assert_eq(Database.resource_name_of("bluegill.tres"), "bluegill.tres")

func test_remap_is_reduced_to_the_tres_name() -> void:
	assert_eq(Database.resource_name_of("bluegill.tres.remap"), "bluegill.tres")

func test_unrelated_files_are_skipped() -> void:
	assert_eq(Database.resource_name_of("liesmich.txt"), "")
	assert_eq(Database.resource_name_of("bluegill.png.remap"), "")
	assert_eq(Database.resource_name_of("bluegill.tres.remap.bak"), "")

func test_every_real_data_file_would_load_under_both_namings() -> void:
	var folders: Array[String] = ["res://data/rarities", "res://data/bait", "res://data/fish", "res://data/zones", "res://data/upgrades"]
	var seen := 0
	for folder in folders:
		var dir := DirAccess.open(folder)
		assert_true(dir != null, "Datenordner fehlt: %s" % folder)
		for file in dir.get_files():
			if not file.ends_with(".tres"):
				continue
			seen += 1
			assert_eq(Database.resource_name_of(file), file, "Quellbaum-Name")
			assert_eq(Database.resource_name_of(file + ".remap"), file, "Export-Name")
	assert_true(seen >= 20, "es sollten mindestens 20 Datendateien sein, gefunden: %d" % seen)
