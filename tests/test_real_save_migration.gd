extends TestCase

## Der echte Spielstand vom Geraet (Version 1, 2026-08-30 gesichert). Die
## Migration wird hier gegen genau die Daten gefahren, die der Nutzer hat --
## eine erfundene Testeingabe haette den Ernstfall nicht bewiesen.
const PATH := "res://tests/fixtures/real_save_v1.json"

func _raw() -> Dictionary:
	var f := FileAccess.open(PATH, FileAccess.READ)
	assert_true(f != null, "Fixture fehlt: %s" % PATH)
	if f == null:
		return {}
	return JSON.parse_string(f.get_as_text())

func test_the_real_device_save_migrates_without_loss() -> void:
	var raw := _raw()
	assert_eq(int(raw.get("save_version", 0)), 1, "die Fixture muss ein Version-1-Stand sein")
	var before: Dictionary = raw["journal"]["entries"]

	var d := SaveManager.migrate(raw.duplicate(true))
	var after: Dictionary = d["journal"]["entries"]

	assert_eq(after.size(), before.size(), "keine Art darf verlorengehen")
	assert_eq(int(d["coins"]), int(raw["coins"]), "Münzen bleiben")
	assert_eq(int(d["player_level"]), int(raw["player_level"]), "Level bleibt")

	for id in before:
		var old: Dictionary = before[id]
		var neu: Dictionary = after[id]
		assert_eq(int(neu["caught_count"]), int(old["caught_count"]), "Fangzahl von %s" % id)
		assert_eq(bool(neu["shiny_found"]), bool(old["shiny_found"]), "Schimmer von %s" % id)
		assert_true(neu.has("best_dev"), "%s hat keine Abweichung" % id)
		assert_true(float(neu["best_dev"]) >= float(neu["worst_dev"]),
			"%s: bester Wert muss über dem schlechtesten liegen" % id)
		assert_eq(neu["caught_ranks"], [int(old["best_quality"])], "Rang von %s" % id)

## Die umgerechneten Gewichte muessen wieder herauskommen, wo sie hineingingen.
func test_the_migrated_weights_still_match_the_originals() -> void:
	var raw := _raw()
	var before: Dictionary = raw["journal"]["entries"]
	var d := SaveManager.migrate(raw.duplicate(true))
	for id in before:
		var f: FishData = Database.fish.get(StringName(id))
		if f == null:
			continue
		var back := f.weight_at(float(d["journal"]["entries"][id]["best_dev"]))
		assert_almost_eq(back, float(before[id]["best_weight"]), 0.01,
			"Rekordgewicht von %s darf sich nicht verschieben" % id)
