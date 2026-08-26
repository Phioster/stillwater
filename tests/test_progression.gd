extends TestCase

func _fish(xp: int) -> FishData:
	var f := FishData.new()
	f.xp = xp
	return f

func _rarity(mult: float) -> RarityData:
	var r := RarityData.new()
	r.xp_mult = mult
	return r

func test_xp_curve_matches_spec() -> void:
	# Unabhaengig mit python3 nachgerechnet: round(80 * n^1.55) fuer n = 1, 2, 3, 5, 10, 20.
	assert_eq(Progression.xp_needed(1), 80)
	assert_eq(Progression.xp_needed(2), 234)
	assert_eq(Progression.xp_needed(3), 439)
	assert_eq(Progression.xp_needed(5), 969)
	assert_eq(Progression.xp_needed(10), 2839)
	assert_eq(Progression.xp_needed(20), 8312)

func test_xp_for_catch_scales_with_quality() -> void:
	var f := _fish(100)
	var r := _rarity(1.0)
	# Qualität 0: 100 * 1.0 * 0.75 = 75
	assert_eq(Progression.xp_for_catch(f, r, 0), 75)
	# Qualität 6: 100 * 1.0 * (0.75 + 0.5) = 125
	assert_eq(Progression.xp_for_catch(f, r, 6), 125)

func test_apply_xp_levels_up_once() -> void:
	var out := Progression.apply_xp(1, 0, 80)
	assert_eq(out["level"], 2)
	assert_eq(out["xp"], 0)
	assert_eq(out["levels_gained"], 1)

func test_apply_xp_can_level_up_multiple_times() -> void:
	var out := Progression.apply_xp(1, 0, 100000)
	assert_true(out["levels_gained"] > 5)

func test_apply_xp_keeps_remainder() -> void:
	var out := Progression.apply_xp(1, 0, 90)
	assert_eq(out["level"], 2)
	assert_eq(out["xp"], 10)
