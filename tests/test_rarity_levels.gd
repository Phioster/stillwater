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

## Entwurfsdecke: ab Stufe 32 ist in JEDER Zone jede Raritaet voll im Spiel.
## Die Zahl steht als Literal da, damit ein verschobener Anstieg den Test
## umwirft, statt sich stillschweigend mitzuverschieben.
const FULL_SPREAD_LEVEL: int = 32

func test_full_spread_is_reached_at_the_design_ceiling() -> void:
	for zone_id in Database.zones:
		var zone: ZoneData = Database.zones[zone_id]
		for id in zone.rarity_weights:
			var r: RarityData = Database.rarities[id]
			assert_almost_eq(r.availability(FULL_SPREAD_LEVEL), 1.0, 0.0001,
				"bei Stufe %d muss die volle Balance stehen: %s in %s"
				% [FULL_SPREAD_LEVEL, id, zone_id])

## Gegenprobe: der lange Schwanz ist echt. Ohne sie waere der Test oben auch
## dann gruen, wenn jede Raritaet sofort voll anliefe.
func test_legendary_is_still_ramping_below_the_ceiling() -> void:
	var legendary: RarityData = Database.rarities[&"legendary"]
	assert_true(legendary.availability(30) < 1.0,
		"Legendary soll erst spaet sein volles Gewicht erreichen")
	assert_almost_eq(legendary.availability(17), 0.0, 0.0001,
		"unter Stufe 18 beisst nichts Legendaeres")
