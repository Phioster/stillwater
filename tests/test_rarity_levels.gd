extends TestCase

## Seltene Stufen laufen mit der Spielerstufe an. Vorher war ein Ungewoehnlicher
## als allererster Fang moeglich (25 % ab Stufe 1), was sich falsch anfuehlte.

func test_availability_is_zero_before_unlock() -> void:
	var r := RarityData.new()
	r.unlock_level = 4
	r.ramp_levels = 10
	assert_almost_eq(r.availability(1), 0.0, 0.0001)
	assert_almost_eq(r.availability(3), 0.0, 0.0001)
	assert_true(r.availability(4) > 0.0, "ab der Freischaltstufe muss etwas ankommen")

func test_availability_ramps_and_caps_at_one() -> void:
	var r := RarityData.new()
	r.unlock_level = 1
	r.ramp_levels = 8
	assert_almost_eq(r.availability(1), 1.0 / 8.0, 0.0001)
	assert_almost_eq(r.availability(4), 4.0 / 8.0, 0.0001)
	assert_almost_eq(r.availability(8), 1.0, 0.0001)
	assert_almost_eq(r.availability(99), 1.0, 0.0001, "darf nie ueber das volle Gewicht steigen")

func test_ramp_of_one_is_immediately_full() -> void:
	var r := RarityData.new()
	r.unlock_level = 1
	r.ramp_levels = 1
	assert_almost_eq(r.availability(1), 1.0, 0.0001)

## Der Fall, der die Aenderung ausgeloest hat.
func test_rare_cannot_be_caught_at_level_one() -> void:
	var rare: RarityData = Database.rarities[&"rare"]
	assert_true(rare.unlock_level > 1, "Selten darf auf Stufe 1 nicht beissen")
	assert_almost_eq(rare.availability(1), 0.0, 0.0001)

func test_full_spread_is_reached_at_high_level() -> void:
	var zone: ZoneData = Database.zones[&"willow_lake"]
	for id in zone.rarity_weights:
		var r: RarityData = Database.rarities[id]
		assert_almost_eq(r.availability(30), 1.0, 0.0001,
			"bei hoher Stufe muss die ursprueng+liche Balance stehen: %s" % id)
