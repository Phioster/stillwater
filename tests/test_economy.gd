extends TestCase

func _fish() -> FishData:
	var f := FishData.new()
	f.id = &"test_fish"
	f.base_value = 100
	f.weight_min = 0.0
	f.weight_max = 10.0
	return f

func _rarity(mult: float) -> RarityData:
	var r := RarityData.new()
	r.value_mult = mult
	return r

func test_price_uses_every_factor() -> void:
	var f := _fish()
	var c := CaughtFish.make(&"test_fish", 10.0, 2, false)  # Perzentil 1.0, Qualität C = 1.0
	# 100 * 2.0 * 1.0 * (0.5 + 1.0) = 300
	assert_eq(Economy.sell_price(c, f, _rarity(2.0)), 300)

func test_shiny_quadruples_price() -> void:
	var f := _fish()
	var plain := CaughtFish.make(&"test_fish", 10.0, 2, false)
	var shiny := CaughtFish.make(&"test_fish", 10.0, 2, true)
	assert_eq(Economy.sell_price(shiny, f, _rarity(1.0)), Economy.sell_price(plain, f, _rarity(1.0)) * 4)

func test_quality_multiplier_table_matches_spec() -> void:
	# Verankert die Qualitaetsmultiplikator-Tabelle gegen unabhaengig berechnete
	# Literale statt gegen den eigenen sell_price()-Output. base_value=100,
	# value_mult=1.0, weight=weight_max -> pct=1.0 -> Faktor (0.5+pct)=1.5.
	# price = 100 * mult * 1.5, floor. Mit python3 nachgerechnet.
	var f := _fish()
	var r := _rarity(1.0)
	var expected := [90, 120, 150, 195, 255, 360, 525]
	for q in expected.size():
		var c := CaughtFish.make(&"test_fish", 10.0, q, false)
		assert_eq(Economy.sell_price(c, f, r), expected[q], "Qualitaet %d" % q)

func test_lightest_fish_is_worth_half_the_weight_factor() -> void:
	var f := _fish()
	var c := CaughtFish.make(&"test_fish", 0.0, 2, false)  # Perzentil 0.0
	# 100 * 1.0 * 1.0 * 0.5 = 50
	assert_eq(Economy.sell_price(c, f, _rarity(1.0)), 50)

func test_consumable_bonus_applies() -> void:
	var f := _fish()
	var c := CaughtFish.make(&"test_fish", 0.0, 2, false)
	assert_eq(Economy.sell_price(c, f, _rarity(1.0), 2.0), 100)

func test_caught_fish_dict_roundtrip() -> void:
	var c := CaughtFish.make(&"bluegill", 0.42, 4, true)
	c.is_favorite = true
	var back := CaughtFish.from_dict(c.to_dict())
	assert_eq(back.fish_id, c.fish_id)
	assert_almost_eq(back.weight, c.weight)
	assert_eq(back.quality, c.quality)
	assert_eq(back.is_shiny, c.is_shiny)
	assert_eq(back.is_favorite, c.is_favorite)
