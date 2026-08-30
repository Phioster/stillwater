extends TestCase

func _fish(id: StringName, secret: bool = false) -> FishData:
	var f := FishData.new()
	f.id = id
	f.is_secret = secret
	f.weight_mean = 5.0000
	f.weight_dev = 1.6667
	return f

func test_first_catch_is_a_discovery() -> void:
	var j := Journal.new()
	assert_true(j.record(CaughtFish.make(&"bluegill", 1.0, false)))
	assert_false(j.record(CaughtFish.make(&"bluegill", 1.0, false)))

func test_counts_and_extremes() -> void:
	var j := Journal.new()
	j.record(CaughtFish.make(&"bluegill", 2.0, false))
	j.record(CaughtFish.make(&"bluegill", 5.0, false))
	j.record(CaughtFish.make(&"bluegill", 0.5, false))
	var e := j.entry(&"bluegill")
	assert_eq(e["caught_count"], 3)
	assert_almost_eq(e["best_dev"], 5.0)
	assert_almost_eq(e["worst_dev"], 0.5)
	# Gewicht 5,0 als Abweichung ist Rang S+, 2,0 ist Rang A, 0,5 ist B.
	assert_eq(e["caught_ranks"], [3, 4, 6] as Array)

func test_shiny_flag_sticks() -> void:
	var j := Journal.new()
	j.record(CaughtFish.make(&"bluegill", 1.0, true))
	j.record(CaughtFish.make(&"bluegill", 1.0, false))
	assert_true(j.entry(&"bluegill")["shiny_found"])

func test_completion_ignores_secrets() -> void:
	var j := Journal.new()
	var all: Array[FishData] = [_fish(&"a"), _fish(&"b"), _fish(&"s", true)]
	j.record(CaughtFish.make(&"a", 1.0, false))
	assert_almost_eq(j.completion(all), 0.5, 0.0001, "2 zählbare Fische, einer entdeckt")
	j.record(CaughtFish.make(&"s", 1.0, false))
	assert_almost_eq(j.completion(all), 0.5, 0.0001, "Secret darf die Quote nicht heben")

func test_has_any_secret_flips_after_first_secret() -> void:
	var j := Journal.new()
	var all: Array[FishData] = [_fish(&"a"), _fish(&"s", true)]
	assert_false(j.has_any_secret())
	j.record(CaughtFish.make(&"s", 1.0, false), true)
	assert_true(j.has_any_secret())

func test_dict_roundtrip() -> void:
	var j := Journal.new()
	j.record(CaughtFish.make(&"bluegill", 3.0, true))
	var other := Journal.new()
	other.load_dict(j.to_dict())
	assert_eq(other.entry(&"bluegill")["caught_count"], 1)
	assert_true(other.entry(&"bluegill")["shiny_found"])

func test_dict_roundtrip_is_isolated_from_later_changes() -> void:
	var j := Journal.new()
	j.record(CaughtFish.make(&"bluegill", 3.0, true))
	var other := Journal.new()
	other.load_dict(j.to_dict())
	j.record(CaughtFish.make(&"bluegill", 99.0, false))
	assert_almost_eq(other.entry(&"bluegill")["best_dev"], 3.0, 0.0001, "geladener Stand darf sich nicht mit der Quelle mitändern")

## Die Schwellen stehen als eigene Zahlen da, nicht als Aufruf der Formel --
## sonst prueft der Test nur, dass die Formel sich selbst gleicht.
func test_level_thresholds_are_triangular() -> void:
	assert_eq(Journal.catches_for_level(0), 0)
	assert_eq(Journal.catches_for_level(1), 5)
	assert_eq(Journal.catches_for_level(2), 15)
	assert_eq(Journal.catches_for_level(3), 30)
	assert_eq(Journal.catches_for_level(5), 75)
	assert_eq(Journal.catches_for_level(10), 275)

func test_level_for_count_at_and_around_each_threshold() -> void:
	assert_eq(Journal.level_for_count(0), 0)
	assert_eq(Journal.level_for_count(4), 0)
	assert_eq(Journal.level_for_count(5), 1)
	assert_eq(Journal.level_for_count(14), 1)
	assert_eq(Journal.level_for_count(15), 2)
	assert_eq(Journal.level_for_count(29), 2)
	assert_eq(Journal.level_for_count(30), 3)

func test_level_is_capped_and_ignores_negative_counts() -> void:
	assert_eq(Journal.level_for_count(275), Journal.MAX_FISH_LEVEL)
	assert_eq(Journal.level_for_count(999999), Journal.MAX_FISH_LEVEL)
	assert_eq(Journal.level_for_count(-3), 0)

func test_fish_level_rises_with_catches() -> void:
	var j := Journal.new()
	assert_eq(j.fish_level(&"bluegill"), 0)
	for i in 5:
		j.record(CaughtFish.make(&"bluegill", 1.0, false))
	assert_eq(j.fish_level(&"bluegill"), 1)
	assert_eq(j.fish_level(&"roach"), 0, "andere Arten steigen nicht mit")

func test_level_progress_counts_within_the_current_step() -> void:
	var j := Journal.new()
	for i in 7:
		j.record(CaughtFish.make(&"bluegill", 1.0, false))
	# 7 Faenge: Stufe 1 (ab 5), 2 von 10 Faengen bis Stufe 2 (ab 15).
	assert_eq(j.fish_level(&"bluegill"), 1)
	assert_eq(j.level_progress(&"bluegill"), [2, 10] as Array[int])

func test_level_progress_is_empty_at_the_cap() -> void:
	var j := Journal.new()
	var e := j.entry(&"bluegill")
	e["caught_count"] = 275
	j.entries[&"bluegill"] = e
	assert_eq(j.level_progress(&"bluegill"), [0, 0] as Array[int])

## Das Level war bisher gespeichert. Ein alter Spielstand darf den Wert nicht
## zurueckbringen -- er wird jetzt aus der Fangzahl abgeleitet.
func test_level_survives_a_save_round_trip_via_the_count() -> void:
	var j := Journal.new()
	for i in 15:
		j.record(CaughtFish.make(&"bluegill", 1.0, false))
	var back := Journal.new()
	back.load_dict(j.to_dict())
	assert_eq(back.fish_level(&"bluegill"), 2)

## Zweite Sammelachse: welche Groessenklassen einer Art schon an Land waren.
func test_caught_ranks_are_collected_without_duplicates() -> void:
	var j := Journal.new()
	j.record(CaughtFish.make(&"bluegill", 0.0, false))    # Rang C = 2
	j.record(CaughtFish.make(&"bluegill", 0.1, false))    # wieder C
	j.record(CaughtFish.make(&"bluegill", 2.0, false))    # Rang A = 4
	assert_eq(j.caught_ranks(&"bluegill"), [2, 4])
	assert_true(j.has_rank(&"bluegill", 2))
	assert_false(j.has_rank(&"bluegill", 6), "S+ war noch nie dran")

func test_ranks_survive_a_save_round_trip_and_are_not_shared() -> void:
	var j := Journal.new()
	j.record(CaughtFish.make(&"bluegill", 2.0, false))
	var back := Journal.new()
	back.load_dict(j.to_dict())
	assert_eq(back.caught_ranks(&"bluegill"), [4])
	# Eine flache Kopie wuerde das Array teilen -- dann waechst der geladene
	# Stand beim Weiterspielen des alten mit.
	j.record(CaughtFish.make(&"bluegill", -3.0, false))
	assert_eq(back.caught_ranks(&"bluegill"), [4], "der geladene Stand darf sich nicht mitändern")

func test_rank_completion_counts_species_times_ranks() -> void:
	var j := Journal.new()
	var all: Array[FishData] = [_fish(&"bluegill"), _fish(&"roach")]
	assert_almost_eq(j.rank_completion(all), 0.0)
	j.record(CaughtFish.make(&"bluegill", 0.0, false))
	# 1 von 2 Arten mal 7 Raengen = 1/14
	assert_almost_eq(j.rank_completion(all), 1.0 / 14.0, 0.0001)
