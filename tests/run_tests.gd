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
	"res://tests/test_journal_panel.gd",
	"res://tests/test_fish_window.gd",
	"res://tests/test_fish_selection.gd",
	"res://tests/test_fishing_sim.gd",
	"res://tests/test_offline_sim.gd",
	"res://tests/test_database.gd",
	"res://tests/test_game_actions.gd",
	"res://tests/test_panel_base.gd",
	"res://tests/test_upgrade_panel.gd",
	"res://tests/test_cosmetics.gd",
	"res://tests/test_character_panel.gd",
	"res://tests/test_save_manager.gd",
	"res://tests/test_palette.gd",
	"res://tests/test_project_settings.gd",
	"res://tests/test_resource_names.gd",
	"res://tests/test_rarity_levels.gd",
	"res://tests/test_scenes_compile.gd",
	"res://tests/test_export_anchors.gd",
	"res://tests/test_sprite_assets.gd",
	"res://tests/test_effects.gd",
	"res://tests/test_water_surface.gd",
	"res://tests/test_zone_look.gd",
	"res://tests/test_tap_button.gd",
	"res://tests/test_secret_tab.gd",
	"res://tests/test_real_save_migration.gd",
	"res://tests/test_catch_view.gd",
]

func _init() -> void:
	# Autoloads existieren in _init() noch NICHT (erst ab dem ersten Frame),
	# ohne dieses await sind Database, Game und SaveManager hier null.
	await process_frame
	# Die Simulation darf während der Tests nicht nebenher weiterlaufen.
	if root.has_node("Game"):
		root.get_node("Game").paused = true

	# Seit dem ereignisgetriebenen Autosave (Game.progress_changed) lösen
	# Game.sell_all()/buy_upgrade()/travel_to() in test_game_actions.gd einen
	# echten SaveManager.save() aus. Ohne diesen Pfadtausch würde jeder
	# Testlauf den echten Spielstand des Entwicklers überschreiben.
	var save_manager: Node = root.get_node("SaveManager") if root.has_node("SaveManager") else null
	var original_save_path := ""
	if save_manager != null:
		original_save_path = save_manager.SAVE_PATH
		save_manager.SAVE_PATH = "user://test_run_all.json"

	var total := 0
	var failed := 0
	for path in SUITES:
		var script: GDScript = load(path)
		if script == null:
			_suite_broken("Testdatei nicht ladbar", path)
			failed += 1
			continue
		if not script.can_instantiate():
			# load() liefert bei einem Parse-Fehler kein null. script.new() wuerde
			# die Coroutine vor quit() abbrechen und den Prozess haengen lassen.
			_suite_broken("Parse-Fehler in Testdatei", path)
			failed += 1
			continue
		var suite = script.new()
		if not (suite is TestCase):
			_suite_broken("Keine TestCase", path)
			failed += 1
			continue
		for method in suite.get_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			total += 1
			suite.failures.clear()
			await suite.call(name)
			if suite.failures.is_empty():
				print("  ok    %s::%s" % [path.get_file(), name])
			else:
				failed += 1
				print("  FAIL  %s::%s" % [path.get_file(), name])
				for f in suite.failures:
					print("        %s" % f)
	if save_manager != null:
		save_manager.delete_save()
		save_manager.SAVE_PATH = original_save_path

	print("")
	print("%d Tests, %d fehlgeschlagen" % [total, failed])
	quit(1 if failed > 0 else 0)

## push_error landet auf stderr und geht in Godots Fehlerrauschen unter --
## eine kaputte Suite sah dadurch aus wie ein einzelner fehlgeschlagener Test,
## obwohl alle ihre Tests gar nicht liefen. Deshalb zusaetzlich nach stdout.
func _suite_broken(reason: String, path: String) -> void:
	push_error("%s: %s" % [reason, path])
	print("  SUITE KAPUTT  %s -- %s (kein Test daraus lief)" % [path.get_file(), reason])
