extends TestCase

func test_same_seed_gives_same_sequence() -> void:
	var a := StillRNG.new(1234)
	var b := StillRNG.new(1234)
	for i in 20:
		assert_almost_eq(a.randf(), b.randf(), 0.0, "Schritt %d" % i)

func test_state_roundtrip_resumes_sequence() -> void:
	var a := StillRNG.new(99)
	for i in 5:
		a.randf()
	var state := a.get_state()
	var expected := a.randf()
	var b := StillRNG.new(5)
	b.set_state(state)
	assert_almost_eq(b.randf(), expected, 0.0)

func test_weighted_pick_respects_weights() -> void:
	var rng := StillRNG.new(7)
	var counts := [0, 0, 0]
	var weights := PackedFloat64Array([0.0, 90.0, 10.0])
	for i in 2000:
		counts[rng.weighted_pick(weights)] += 1
	assert_eq(counts[0], 0, "Gewicht 0 darf nie gezogen werden")
	assert_between(float(counts[1]) / 2000.0, 0.85, 0.95)

func test_weighted_pick_returns_minus_one_on_empty() -> void:
	var rng := StillRNG.new(1)
	assert_eq(rng.weighted_pick(PackedFloat64Array([0.0, 0.0])), -1)
	assert_eq(rng.weighted_pick(PackedFloat64Array([])), -1)

func test_weighted_pick_fallback_never_picks_trailing_zero_weight() -> void:
	# Dieser Zustand ist so gewaehlt, dass der naechste randf()-Aufruf exakt
	# 1.0 liefert (Godots RandomNumberGenerator.randf() ist auf [0, 1]
	# EINSCHLIESSLICH 1.0 definiert). Damit erreicht roll == total und der
	# Fallback-Pfad von weighted_pick greift deterministisch.
	var rng := StillRNG.new(0)
	rng.set_state(2385058005643621617)
	var weights := PackedFloat64Array([90.0, 10.0, 0.0])
	assert_eq(rng.weighted_pick(weights), 1, "Fallback darf nie den Index eines 0-Gewichts liefern")
