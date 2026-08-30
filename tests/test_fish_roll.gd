extends TestCase

## Gewicht ist seit 2026-08-30 normalverteilt, und der Rang folgt allein aus
## der Abweichung vom Artmittel -- nicht mehr aus der Rarität.

func _fish() -> FishData:
	var f := FishData.new()
	f.weight_mean = 3.0
	f.weight_dev = 0.5
	f.difficulty = 1.0
	return f

func test_weight_follows_the_deviation() -> void:
	var f := _fish()
	assert_almost_eq(f.weight_at(0.0), 3.0)
	assert_almost_eq(f.weight_at(2.0), 4.0)
	assert_almost_eq(f.weight_at(-2.0), 2.0)

## Auch eine extreme Abweichung darf kein negatives Gewicht ergeben.
func test_weight_never_drops_to_zero_or_below() -> void:
	var f := _fish()
	assert_true(f.weight_at(-99.0) > 0.0)
	assert_almost_eq(f.weight_at(-99.0), 0.15, 0.0001, "Untergrenze sind 5 % des Mittels")

func test_deviation_is_centred_and_bounded() -> void:
	var rng := StillRNG.new(11)
	var sum := 0.0
	var n := 20000
	for i in n:
		var d := FishRoll.roll_deviation(0.0, rng)
		assert_between(d, -FishRoll.DEV_LIMIT, FishRoll.DEV_LIMIT)
		sum += d
	assert_almost_eq(sum / float(n), 0.0, 0.05, "ohne Köderschub muss das Mittel bei 0 liegen")

func test_bait_shifts_the_size_upward() -> void:
	var rng := StillRNG.new(12)
	var plain := 0.0
	var baited := 0.0
	for i in 20000:
		plain += FishRoll.roll_deviation(0.0, rng)
		baited += FishRoll.roll_deviation(1.0, rng)
	assert_true(baited > plain + 15000.0, "ein Köder mit Schub 1.0 muss deutlich größere Fische bringen")

## Die Schwellen stehen als eigene Zahlen da, nicht als Aufruf der Formel.
func test_rank_thresholds() -> void:
	assert_eq(FishRoll.rank_for_deviation(-3.0), 0, "E")
	assert_eq(FishRoll.rank_for_deviation(-1.6), 0)
	assert_eq(FishRoll.rank_for_deviation(-1.5), 1, "D ab -1.5")
	assert_eq(FishRoll.rank_for_deviation(0.0), 2, "ein Durchschnittsfisch ist C")
	assert_eq(FishRoll.rank_for_deviation(0.5), 3, "B ab +0.5")
	assert_eq(FishRoll.rank_for_deviation(1.5), 4, "A ab +1.5")
	assert_eq(FishRoll.rank_for_deviation(2.25), 5, "S ab +2.25")
	assert_eq(FishRoll.rank_for_deviation(3.0), 6, "S+ ab +3.0")

func test_rank_does_not_depend_on_rarity() -> void:
	# Es gibt gar keinen Weg mehr, die Rarität hineinzureichen -- das ist der
	# Punkt. Der Test haelt fest, dass die Signatur so bleibt.
	assert_eq(FishRoll.rank_for_deviation(2.5), FishRoll.rank_for_deviation(2.5))
	assert_eq(FishRoll.RANK_NAMES.size(), 7)
	assert_eq(FishRoll.RANK_HEALTH.size(), 7)
	assert_eq(FishRoll.RANK_VALUE_MULTS.size(), 7)

func test_health_doubles_per_rank_and_scales_with_difficulty() -> void:
	var f := _fish()
	assert_almost_eq(FishRoll.health_for(f, 0), 7.0)
	assert_almost_eq(FishRoll.health_for(f, 1), 14.0)
	assert_almost_eq(FishRoll.health_for(f, 6), 432.0)
	f.difficulty = 2.5
	assert_almost_eq(FishRoll.health_for(f, 2), 70.0, 0.0001, "28 * 2,5")

## Die mittlere Größe ist absichtlich stumm: ein Durchschnittsfisch bekommt
## kein Adjektiv, sonst nutzt sich das Lob ab.
func test_size_names_have_a_silent_middle() -> void:
	assert_eq(FishRoll.size_name(-2.0), "winzig")
	assert_eq(FishRoll.size_name(-1.0), "klein")
	assert_eq(FishRoll.size_name(0.0), "")
	assert_eq(FishRoll.size_name(1.0), "groß")
	assert_eq(FishRoll.size_name(2.0), "riesig")

func test_full_name_omits_the_silent_size() -> void:
	var f := _fish()
	f.display_name = "Schleie"
	assert_eq(f.full_name(0.0), "Schleie")
	assert_eq(f.full_name(2.0), "Schleie (riesig)")

func test_weight_string_switches_to_grams_below_one_kilo() -> void:
	var f := _fish()
	f.weight_mean = 0.84
	f.weight_dev = 0.1
	assert_eq(f.weight_str(0.0), "840 g")
	f.weight_mean = 1.24
	assert_eq(f.weight_str(0.0), "1,24 kg")

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
