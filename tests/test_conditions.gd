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
