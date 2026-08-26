extends TestCase

# Eigener Pfad, damit ein Testlauf nie den echten Spielstand des Entwicklers
# unter user://save.json überschreibt oder löscht. SAVE_PATH ist deshalb kein
# const, sondern per Test austauschbar (siehe SaveManager.gd).
const TEST_SAVE_PATH := "user://test_save_manager.json"

func _use_test_path() -> String:
	var original := SaveManager.SAVE_PATH
	SaveManager.SAVE_PATH = TEST_SAVE_PATH
	return original

func _restore_path(original: String) -> void:
	SaveManager.delete_save()
	SaveManager.SAVE_PATH = original

func test_roundtrip_restores_everything() -> void:
	Game.new_game()
	Game.coins = 1234
	Game.ctx.player_level = 7
	Game.ctx.player_xp = 55
	Game.upgrade_levels[&"rod_power"] = 3
	Game.unlocked_zones = [&"willow_lake", &"sunset_coast"]
	Game.ctx.bait_counts = {&"mayfly_nymph": 12}
	Game.ctx.inventory.add(CaughtFish.make(&"bluegill", 0.3, 4, true))
	Game.ctx.journal.record(CaughtFish.make(&"roach", 0.6, 3, false))

	var blob := SaveManager.serialize()
	Game.new_game()
	SaveManager.deserialize(blob)

	assert_eq(Game.coins, 1234)
	assert_eq(Game.ctx.player_level, 7)
	assert_eq(Game.ctx.player_xp, 55)
	assert_eq(int(Game.upgrade_levels[&"rod_power"]), 3)
	assert_true(&"sunset_coast" in Game.unlocked_zones)
	assert_eq(int(Game.ctx.bait_counts[&"mayfly_nymph"]), 12)
	assert_eq(Game.ctx.inventory.fish.size(), 1)
	assert_true(Game.ctx.inventory.fish[0].is_shiny)
	assert_true(Game.ctx.journal.is_discovered(&"roach"))

func test_upgrades_are_reapplied_after_loading() -> void:
	Game.new_game()
	Game.upgrade_levels[&"rod_power"] = 3
	var blob := SaveManager.serialize()
	Game.new_game()
	SaveManager.deserialize(blob)
	assert_almost_eq(Game.ctx.rod_power, 10.0, 0.0001, "4 + 3 * 2 = 10")

func test_file_roundtrip() -> void:
	var original := _use_test_path()
	Game.new_game()
	Game.coins = 999
	assert_true(SaveManager.save())
	assert_true(SaveManager.has_save())
	Game.new_game()
	assert_true(SaveManager.load_game())
	assert_eq(Game.coins, 999)
	SaveManager.delete_save()
	assert_false(SaveManager.has_save())
	_restore_path(original)

func test_missing_file_loads_nothing() -> void:
	var original := _use_test_path()
	SaveManager.delete_save()
	assert_false(SaveManager.load_game())
	_restore_path(original)

func test_migration_fills_a_missing_field() -> void:
	var old := {"save_version": 0, "coins": 42}
	var migrated := SaveManager.migrate(old)
	assert_eq(int(migrated["save_version"]), SaveManager.SAVE_VERSION)
	assert_true(migrated.has("unlocked_zones"), "Migration muss fehlende Felder ergänzen")
	assert_eq(int(migrated["coins"]), 42, "vorhandene Werte müssen erhalten bleiben")

func test_rng_state_survives_the_save() -> void:
	Game.new_game()
	for i in 10:
		Game.rng.randf()
	var blob := SaveManager.serialize()

	# Zweimal denselben Spielstand laden muss zweimal denselben Zufall geben.
	Game.new_game()
	SaveManager.deserialize(blob)
	var first := Game.rng.randf()

	Game.new_game()
	SaveManager.deserialize(blob)
	assert_almost_eq(Game.rng.randf(), first, 0.0, "geladener Zufall muss deterministisch sein")

func test_offline_summary_is_produced_on_load() -> void:
	Game.new_game()
	Game.ctx.inventory.capacity = 500
	var blob := SaveManager.serialize()
	blob["last_seen_unix"] = int(Time.get_unix_time_from_system()) - 3600
	Game.new_game()
	SaveManager.deserialize(blob)
	assert_true(int(SaveManager.pending_offline.get("caught", 0)) > 0, "eine Stunde muss Fänge liefern")

# --- Beschädigte Speicherdatei: jeder Fall einzeln --------------------------

func test_empty_file_does_not_crash() -> void:
	var original := _use_test_path()
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.close()
	assert_true(SaveManager.has_save(), "eine leere Datei zählt als vorhanden")
	assert_false(SaveManager.load_game(), "eine leere Datei ist kein gültiger Spielstand")
	_restore_path(original)

func test_corrupt_json_does_not_crash() -> void:
	var original := _use_test_path()
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{ das ist kein JSON")
	f.close()
	assert_false(SaveManager.load_game(), "kaputtes JSON darf nicht geladen werden")
	_restore_path(original)

func test_missing_version_defaults_to_the_oldest_migration() -> void:
	var old := {"coins": 7}
	var migrated := SaveManager.migrate(old)
	assert_eq(int(migrated["save_version"]), SaveManager.SAVE_VERSION,
		"eine fehlende Versionsangabe wird wie Version 0 behandelt, nicht abgelehnt")
	assert_eq(int(migrated["coins"]), 7)

func test_wrong_field_types_fall_back_to_defaults() -> void:
	var broken := {
		"save_version": 1,
		"coins": "nicht_numerisch",
		"unlocked_zones": 5,
		"upgrade_levels": ["auch falsch"],
		"fish_inventory": {"nicht": "array"},
		"journal": "nicht_mal_ein_dict",
	}
	var migrated := SaveManager.migrate(broken)
	assert_eq(int(migrated["coins"]), 0, "unlesbare Zahl wird auf den Standard zurückgesetzt")
	assert_true(migrated["unlocked_zones"] is Array, "unlocked_zones muss ein Array bleiben")
	assert_true(migrated["upgrade_levels"] is Dictionary, "upgrade_levels muss ein Dictionary bleiben")
	assert_true(migrated["fish_inventory"] is Array, "fish_inventory muss ein Array bleiben")
	assert_true(migrated["journal"] is Dictionary, "journal muss ein Dictionary bleiben")
	# darf nicht abstürzen: deserialize() mit dem falsch typisierten Rohzustand
	Game.new_game()
	SaveManager.deserialize(broken)
	assert_eq(Game.coins, 0)

func test_future_version_save_is_refused() -> void:
	Game.new_game()
	Game.coins = 321
	var future := SaveManager.serialize()
	future["save_version"] = SaveManager.SAVE_VERSION + 1
	future["coins"] = 999999

	Game.new_game()
	Game.coins = 7
	SaveManager.deserialize(future)
	assert_eq(Game.coins, 7, "ein Stand aus der Zukunft darf den aktuellen Zustand nicht überschreiben")

func test_future_version_file_is_refused_without_crashing() -> void:
	var original := _use_test_path()
	Game.new_game()
	Game.coins = 555
	SaveManager.save()
	# Datei von Hand auf eine Zukunftsversion anheben.
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var d: Dictionary = JSON.parse_string(text)
	d["save_version"] = SaveManager.SAVE_VERSION + 1
	f = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()

	Game.new_game()
	Game.coins = 3
	assert_false(SaveManager.load_game(), "eine Zukunftsversion darf nicht als geladen gelten")
	assert_eq(Game.coins, 3, "der aktuelle Zustand bleibt unangetastet")
	_restore_path(original)
