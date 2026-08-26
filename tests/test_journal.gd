extends TestCase

func _fish(id: StringName, secret: bool = false) -> FishData:
	var f := FishData.new()
	f.id = id
	f.is_secret = secret
	f.weight_min = 0.0
	f.weight_max = 10.0
	return f

func test_first_catch_is_a_discovery() -> void:
	var j := Journal.new()
	assert_true(j.record(CaughtFish.make(&"bluegill", 1.0, 2, false)))
	assert_false(j.record(CaughtFish.make(&"bluegill", 1.0, 2, false)))

func test_counts_and_extremes() -> void:
	var j := Journal.new()
	j.record(CaughtFish.make(&"bluegill", 2.0, 1, false))
	j.record(CaughtFish.make(&"bluegill", 5.0, 4, false))
	j.record(CaughtFish.make(&"bluegill", 0.5, 0, false))
	var e := j.entry(&"bluegill")
	assert_eq(e["caught_count"], 3)
	assert_almost_eq(e["best_weight"], 5.0)
	assert_almost_eq(e["worst_weight"], 0.5)
	assert_eq(e["best_quality"], 4)

func test_shiny_flag_sticks() -> void:
	var j := Journal.new()
	j.record(CaughtFish.make(&"bluegill", 1.0, 0, true))
	j.record(CaughtFish.make(&"bluegill", 1.0, 0, false))
	assert_true(j.entry(&"bluegill")["shiny_found"])

func test_completion_ignores_secrets() -> void:
	var j := Journal.new()
	var all: Array[FishData] = [_fish(&"a"), _fish(&"b"), _fish(&"s", true)]
	j.record(CaughtFish.make(&"a", 1.0, 0, false))
	assert_almost_eq(j.completion(all), 0.5, 0.0001, "2 zählbare Fische, einer entdeckt")
	j.record(CaughtFish.make(&"s", 1.0, 0, false))
	assert_almost_eq(j.completion(all), 0.5, 0.0001, "Secret darf die Quote nicht heben")

func test_has_any_secret_flips_after_first_secret() -> void:
	var j := Journal.new()
	var all: Array[FishData] = [_fish(&"a"), _fish(&"s", true)]
	assert_false(j.has_any_secret())
	j.record(CaughtFish.make(&"s", 1.0, 0, false), true)
	assert_true(j.has_any_secret())

func test_dict_roundtrip() -> void:
	var j := Journal.new()
	j.record(CaughtFish.make(&"bluegill", 3.0, 5, true))
	var other := Journal.new()
	other.load_dict(j.to_dict())
	assert_eq(other.entry(&"bluegill")["caught_count"], 1)
	assert_true(other.entry(&"bluegill")["shiny_found"])
