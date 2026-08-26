extends SceneTree

const SUITES := [
	"res://tests/test_smoke.gd",
	"res://tests/test_still_rng.gd",
	"res://tests/test_conditions.gd",
]

func _init() -> void:
	# Autoloads existieren in _init() noch NICHT — sie werden erst beim ersten
	# Frame in den Baum gehängt. Ohne dieses await sind Database, Game und
	# SaveManager in den Tests null. Empirisch bestätigt mit Godot 4.7.2.
	await process_frame
	# Die Simulation darf während der Tests nicht nebenher weiterlaufen.
	# (Das Autoload Game entsteht erst in Task 11.)
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
