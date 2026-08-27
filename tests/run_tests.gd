extends SceneTree

const SUITES := [
	"res://tests/test_smoke.gd",
	"res://tests/test_still_rng.gd",
	"res://tests/test_conditions.gd",
	"res://tests/test_fish_roll.gd",
	"res://tests/test_economy.gd",
	"res://tests/test_progression.gd",
	"res://tests/test_inventory.gd",
	"res://tests/test_journal.gd",
	"res://tests/test_fish_selection.gd",
	"res://tests/test_fishing_sim.gd",
	"res://tests/test_offline_sim.gd",
	"res://tests/test_database.gd",
	"res://tests/test_game_actions.gd",
	"res://tests/test_save_manager.gd",
	"res://tests/test_palette.gd",
]

func _init() -> void:
	# Autoloads existieren in _init() noch NICHT (erst ab dem ersten Frame),
	# ohne dieses await sind Database, Game und SaveManager hier null.
	await process_frame
	# Die Simulation darf während der Tests nicht nebenher weiterlaufen.
	if root.has_node("Game"):
		root.get_node("Game").paused = true

	var total := 0
	var failed := 0
	for path in SUITES:
		var script: GDScript = load(path)
		if script == null:
			push_error("Testdatei nicht ladbar: %s" % path)
			failed += 1
			continue
		if not script.can_instantiate():
			# load() liefert bei einem Parse-Fehler kein null. script.new() wuerde
			# die Coroutine vor quit() abbrechen und den Prozess haengen lassen.
			push_error("Parse-Fehler in Testdatei: %s" % path)
			failed += 1
			continue
		var suite = script.new()
		if not (suite is TestCase):
			push_error("Keine TestCase: %s" % path)
			failed += 1
			continue
		for method in suite.get_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			total += 1
			suite.failures.clear()
			suite.call(name)
			if suite.failures.is_empty():
				print("  ok    %s::%s" % [path.get_file(), name])
			else:
				failed += 1
				print("  FAIL  %s::%s" % [path.get_file(), name])
				for f in suite.failures:
					print("        %s" % f)
	print("")
	print("%d Tests, %d fehlgeschlagen" % [total, failed])
	quit(1 if failed > 0 else 0)
