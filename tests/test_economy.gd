extends TestCase

func _fish() -> FishData:
	var f := FishData.new()
	f.id = &"test_fish"
	f.base_value = 100
	f.weight_mean = 5.0000
	f.weight_dev = 1.6667
	return f

func _rarity(mult: float) -> RarityData:
	var r := RarityData.new()
	r.value_mult = mult
	return r

## Preis = Grundwert * Raritaet * Rangfaktor * (1 + 0,08 * Abweichung),
## danach Schimmer und Trankbonus. Die Erwartungswerte sind unabhaengig mit
## python3 nachgerechnet, nicht aus sell_price() abgeleitet.
func test_price_uses_every_factor() -> void:
	var f := _fish()
	var c := CaughtFish.make(&"test_fish", 0.0, false)  # Abweichung 0 -> Rang C
	# 100 * 2.0 * 1.0 * 1.0 = 200
	assert_eq(Economy.sell_price(c, f, _rarity(2.0)), 200)

func test_shiny_quadruples_price() -> void:
	var f := _fish()
	# Abweichung 0: der Grundpreis ist glatt 100, sonst schlaegt das Abrunden
	# vor und nach der Vervierfachung unterschiedlich zu.
	var plain := CaughtFish.make(&"test_fish", 0.0, false)
	var shiny := CaughtFish.make(&"test_fish", 0.0, true)
	assert_eq(Economy.sell_price(shiny, f, _rarity(1.0)), Economy.sell_price(plain, f, _rarity(1.0)) * 4)

## Verankert die Rangfaktor-Tabelle gegen unabhaengig gerechnete Literale.
## Jede Abweichung liegt genau auf ihrer Rangschwelle.
func test_rank_multiplier_table_matches_spec() -> void:
	var f := _fish()
	var r := _rarity(1.0)
	var devs := [-3.0, -1.5, -0.5, 0.5, 1.5, 2.25, 3.0]
	var expected := [45, 70, 96, 135, 190, 283, 434]
	for i in expected.size():
		var c := CaughtFish.make(&"test_fish", devs[i], false)
		assert_eq(c.rank, i, "Abweichung %f muss Rang %d sein" % [devs[i], i])
		assert_eq(Economy.sell_price(c, f, r), expected[i], "Rang %d" % i)

## Zwei Fische desselben Rangs sind nicht exakt gleich viel wert -- sonst
## waere der Rekord innerhalb eines Rangs bedeutungslos.
func test_deviation_still_separates_two_fish_of_the_same_rank() -> void:
	var f := _fish()
	var r := _rarity(1.0)
	var small := CaughtFish.make(&"test_fish", 0.6, false)
	var big := CaughtFish.make(&"test_fish", 1.4, false)
	assert_eq(small.rank, big.rank, "beide muessen Rang B sein")
	assert_true(Economy.sell_price(big, f, r) > Economy.sell_price(small, f, r))

func test_consumable_bonus_applies() -> void:
	var f := _fish()
	var c := CaughtFish.make(&"test_fish", 0.0, false)
	assert_eq(Economy.sell_price(c, f, _rarity(1.0), 2.0), 200)

func test_caught_fish_dict_roundtrip() -> void:
	var c := CaughtFish.make(&"bluegill", 0.42, true)
	c.is_favorite = true
	var back := CaughtFish.from_dict(c.to_dict())
	assert_eq(back.fish_id, c.fish_id)
	assert_almost_eq(back.weight_dev, c.weight_dev)
	assert_eq(back.rank, c.rank, "der Rang wird nicht gespeichert, sondern abgeleitet")
	assert_eq(back.is_shiny, c.is_shiny)
	assert_eq(back.is_favorite, c.is_favorite)
