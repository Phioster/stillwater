extends TestCase

func _state(bait: StringName, level: int) -> Dictionary:
	return {"bait_id": bait, "player_level": level, "cosmetics": {}, "zone_id": &"willow_lake"}

func test_bait_condition_matches_exact_bait() -> void:
	var c := BaitCondition.new()
	c.bait_id = &"mayfly_nymph"
	assert_true(c.is_met(_state(&"mayfly_nymph", 1)))
	assert_false(c.is_met(_state(&"pond_grub", 1)))

func test_level_condition_is_inclusive() -> void:
	var c := LevelCondition.new()
	c.min_level = 5
	assert_false(c.is_met(_state(&"pond_grub", 4)))
	assert_true(c.is_met(_state(&"pond_grub", 5)))
	assert_true(c.is_met(_state(&"pond_grub", 9)))

func test_base_condition_is_always_met() -> void:
	var c := CatchCondition.new()
	assert_true(c.is_met(_state(&"pond_grub", 1)))

func test_fish_data_defaults_are_sane() -> void:
	var f := FishData.new()
	assert_false(f.is_secret)
	assert_almost_eq(f.preferred_bait_mult, 2.0)
	assert_almost_eq(f.secret_chance, 0.0)

## Die drei neuen Bedingungstypen. Jeder wird von einem Geheimfisch benutzt --
## eine Bedingung, die niemand verlangt, waere selbst wieder ein totes Ende.

func test_cosmetic_condition_wants_the_exact_variant() -> void:
	var c := CosmeticCondition.new()
	c.category = &"hat"
	c.variant = 1
	assert_true(c.is_met({"cosmetics": {"hat": 1}}))
	assert_false(c.is_met({"cosmetics": {"hat": 0}}))
	assert_false(c.is_met({"cosmetics": {"shirt": 1}}), "falsche Kategorie zaehlt nicht")
	assert_false(c.is_met({}), "ohne Angabe ist sie nicht erfuellt")

func test_time_window_inside_one_day() -> void:
	var c := TimeOfDayCondition.new()
	c.from_hour = 18
	c.to_hour = 21
	assert_false(c.is_met({"hour_of_day": 17}))
	assert_true(c.is_met({"hour_of_day": 18}))
	assert_true(c.is_met({"hour_of_day": 21}))
	assert_false(c.is_met({"hour_of_day": 22}))

func test_time_window_across_midnight() -> void:
	var c := TimeOfDayCondition.new()
	c.from_hour = 21
	c.to_hour = 4
	assert_true(c.is_met({"hour_of_day": 23}))
	assert_true(c.is_met({"hour_of_day": 0}))
	assert_true(c.is_met({"hour_of_day": 4}))
	assert_false(c.is_met({"hour_of_day": 5}))
	assert_false(c.is_met({"hour_of_day": 20}))

func test_journal_condition_counts_discovered_species() -> void:
	var c := JournalCondition.new()
	c.min_species = 10
	assert_false(c.is_met({"journal_species": 9}))
	assert_true(c.is_met({"journal_species": 10}))

## Die Stunde muss wirklich im Zustand ankommen, sonst beisst der Abendfisch
## rund um die Uhr -- oder nie.
func test_context_passes_the_hour_and_the_species_count() -> void:
	Game.new_game()
	Game.ctx.hour_of_day = 19
	Game.ctx.journal.record(CaughtFish.make(&"bluegill", 1.0, 2, false))
	var state: Dictionary = Game.ctx.condition_state()
	assert_eq(state["hour_of_day"], 19)
	assert_eq(state["journal_species"], 1)

func test_every_condition_type_is_used_by_a_secret_fish() -> void:
	var seen: Dictionary = {}
	for id in Database.fish:
		for c in Database.fish[id].conditions:
			seen[c.get_script().get_global_name()] = true
	for type_name in ["LevelCondition", "BaitCondition", "CosmeticCondition",
			"TimeOfDayCondition", "JournalCondition"]:
		assert_true(seen.has(type_name), "kein Fisch verlangt %s" % type_name)

## Ein Fisch, der ein Kleidungsstueck verlangt, das es nicht gibt -- oder das
## erst spaeter freischaltet als er selbst -- waere nie fangbar.
## NICHT geprueft: ob der secret_hint das richtige Stueck benennt. Genau das
## war der echte Fehler der Strohhutbrasse (sie zeigte auf die Kappe, der
## Hinweis sprach vom Strohhut), und freier Text laesst sich nicht pruefen --
## bei neuen Hinweisen also von Hand gegen die Variante lesen.
func test_cosmetic_conditions_point_at_reachable_cosmetics() -> void:
	for fish_id in Database.fish:
		var fish: FishData = Database.fish[fish_id]
		var min_level := 1
		for c in fish.conditions:
			if c is LevelCondition:
				min_level = maxi(min_level, (c as LevelCondition).min_level)
		for c in fish.conditions:
			if not (c is CosmeticCondition):
				continue
			var want := c as CosmeticCondition
			var found: CosmeticData = null
			for cid in Database.cosmetics:
				var cos: CosmeticData = Database.cosmetics[cid]
				if cos.category == want.category and cos.variant == want.variant:
					found = cos
			assert_true(found != null,
				"%s verlangt %s/%d -- das gibt es nicht" % [fish_id, want.category, want.variant])
			if found != null:
				assert_true(found.unlock_level <= min_level,
					"%s ist ab Level %d fangbar, %s aber erst ab %d"
					% [fish_id, min_level, found.display_name, found.unlock_level])
