extends TestCase

func _fish() -> FishData:
	var f := FishData.new()
	f.weight_min = 1.0
	f.weight_max = 5.0
	f.strength = 40.0
	return f

func _rarity(bias: float, strength_mult: float = 1.0) -> RarityData:
	var r := RarityData.new()
	r.quality_bias = bias
	r.strength_mult = strength_mult
	return r

func test_weight_stays_in_bounds() -> void:
	var rng := StillRNG.new(3)
	var f := _fish()
	for i in 500:
		assert_between(FishRoll.roll_weight(f, rng), 1.0, 5.0)

func test_weight_is_biased_towards_light() -> void:
	var rng := StillRNG.new(11)
	var f := _fish()
	var heavy := 0
	for i in 2000:
		if FishRoll.percentile(f, FishRoll.roll_weight(f, rng)) > 0.5:
			heavy += 1
	# Exponent 1.6 heißt: rund 33 % liegen über der Mitte.
	assert_between(float(heavy) / 2000.0, 0.25, 0.42)

func test_percentile_endpoints() -> void:
	var f := _fish()
	assert_almost_eq(FishRoll.percentile(f, 1.0), 0.0)
	assert_almost_eq(FishRoll.percentile(f, 5.0), 1.0)
	assert_almost_eq(FishRoll.percentile(f, 3.0), 0.5)

func test_percentile_handles_zero_span() -> void:
	var f := FishData.new()
	f.weight_min = 2.0
	f.weight_max = 2.0
	assert_almost_eq(FishRoll.percentile(f, 2.0), 0.0)

func test_quality_index_in_range() -> void:
	var rng := StillRNG.new(5)
	var r := _rarity(0.0)
	for i in 500:
		var q := FishRoll.roll_quality(rng.randf(), r, rng)
		assert_between(float(q), 0.0, 6.0)

func test_rarity_bias_lifts_average_quality() -> void:
	var rng := StillRNG.new(21)
	var plain := 0
	var biased := 0
	for i in 3000:
		plain += FishRoll.roll_quality(0.5, _rarity(0.0), rng)
		biased += FishRoll.roll_quality(0.5, _rarity(0.30), rng)
	assert_true(biased > plain, "Bias muss die Qualität heben")

func test_shiny_base_rate() -> void:
	var rng := StillRNG.new(77)
	var hits := 0
	for i in 80000:
		if FishRoll.roll_shiny(0, 1.0, rng):
			hits += 1
	# 80000 / 800 = 100 erwartet
	assert_between(float(hits), 70.0, 135.0)

func test_fish_level_raises_shiny_chance() -> void:
	var rng := StillRNG.new(78)
	var low := 0
	var high := 0
	for i in 80000:
		if FishRoll.roll_shiny(0, 1.0, rng):
			low += 1
		if FishRoll.roll_shiny(20, 1.0, rng):
			high += 1
	assert_true(high > low, "Level 20 muss häufiger shiny sein als Level 0")

func test_strength_scales_with_weight_and_rarity() -> void:
	var f := _fish()
	var r := _rarity(0.0, 2.0)
	# 40 * 2.0 * (0.75 + 0.5 * 0.0) = 60
	assert_almost_eq(FishRoll.strength_for(f, r, 0.0), 60.0)
	# 40 * 2.0 * (0.75 + 0.5 * 1.0) = 100
	assert_almost_eq(FishRoll.strength_for(f, r, 1.0), 100.0)
