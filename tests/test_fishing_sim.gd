extends TestCase

func _rarity() -> RarityData:
	var r := RarityData.new()
	r.id = &"common"
	return r

func _fish(strength: float) -> FishData:
	var f := FishData.new()
	f.id = &"testfish"
	f.rarity_id = &"common"
	f.base_value = 10
	f.strength = strength
	f.xp = 10
	f.weight_min = 1.0
	f.weight_max = 1.0   # Perzentil immer 0 → Stärke exakt vorhersagbar
	f.spawn_weight = 1.0
	return f

func _ctx(strength: float, capacity: int = 100) -> SimContext:
	var zone := ZoneData.new()
	zone.id = &"willow_lake"
	zone.fish = [_fish(strength)]
	zone.rarity_weights = {&"common": 1.0}
	zone.bite_time_min = 10.0
	zone.bite_time_max = 10.0   # feste Bisszeit macht den Test exakt
	zone.fight_window = 20.0
	var bait := BaitData.new()
	bait.id = &"pond_grub"
	bait.unlimited = true
	var ctx := SimContext.new()
	ctx.zone = zone
	ctx.bait = bait
	ctx.fallback_bait = bait
	ctx.rarities = {&"common": _rarity()}
	ctx.inventory = Inventory.new()
	ctx.inventory.capacity = capacity
	ctx.journal = Journal.new()
	ctx.rod_power = 4.0
	ctx.orb_power = 6.0
	return ctx

func _types(events: Array) -> Array:
	var out := []
	for e in events:
		out.append(e["type"])
	return out

func test_first_tick_starts_casting() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(10.0)
	sim.tick(0.1, ctx, StillRNG.new(1))
	assert_eq(sim.state, FishingSim.State.CASTING)

func test_bite_happens_after_cast_and_wait() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(10.0)
	# 1 s Wurf + 10 s Warten = 11 s
	var events := sim.tick(10.9, ctx, StillRNG.new(1))
	assert_false("bite" in _types(events), "bei 10.9 s darf noch nichts beißen")
	events = sim.tick(0.2, ctx, StillRNG.new(1))
	assert_true("bite" in _types(events))
	assert_eq(sim.state, FishingSim.State.FIGHT)

func test_weak_fish_is_landed_automatically() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(20.0)   # 20 Stärke bei Rod Power 4 = 5 s
	var events := sim.tick(11.0 + 5.1, ctx, StillRNG.new(1))
	assert_true("caught" in _types(events))
	assert_eq(ctx.inventory.fish.size(), 1)

func test_strong_fish_escapes_after_the_window() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(200.0)  # 200 / 4 = 50 s, Fenster ist 20 s
	var events := sim.tick(11.0 + 20.1, ctx, StillRNG.new(1))
	assert_true("escaped" in _types(events))
	assert_eq(ctx.inventory.fish.size(), 0)
	assert_false("caught" in _types(events))

func test_tapping_saves_a_fish_that_would_escape() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(100.0)  # 100 / 4 = 25 s > 20 s Fenster
	sim.tick(11.1, ctx, StillRNG.new(1))
	assert_eq(sim.state, FishingSim.State.FIGHT)
	var caught := false
	for i in 20:
		if "caught" in _types(sim.tap(ctx)):
			caught = true
			break
	assert_true(caught, "20 Taps à 6 müssen 100 Stärke brechen")

func test_tap_does_nothing_outside_a_fight() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(10.0)
	assert_eq(sim.tap(ctx).size(), 0)

func test_catch_awards_xp_and_can_level_up() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(20.0)
	var events := sim.tick(11.0 + 5.1, ctx, StillRNG.new(1))
	var xp := 0
	for e in events:
		if e["type"] == "caught":
			xp = int(e["xp"])
	assert_true(xp > 0)
	assert_true(ctx.player_xp > 0 or ctx.player_level > 1)

func test_catch_records_the_journal() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(20.0)
	sim.tick(11.0 + 5.1, ctx, StillRNG.new(1))
	assert_true(ctx.journal.is_discovered(&"testfish"))

func test_full_inventory_pauses_fishing() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(20.0, 1)
	sim.tick(3600.0, ctx, StillRNG.new(1))
	assert_eq(ctx.inventory.fish.size(), 1)
	assert_eq(sim.state, FishingSim.State.INVENTORY_FULL)

func test_fishing_resumes_after_inventory_is_emptied() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(20.0, 1)
	sim.tick(3600.0, ctx, StillRNG.new(1))
	assert_eq(sim.state, FishingSim.State.INVENTORY_FULL)
	ctx.inventory.take_sellable()
	sim.tick(11.0 + 5.1, ctx, StillRNG.new(2))
	assert_eq(ctx.inventory.fish.size(), 1)

func test_many_catches_over_an_hour() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(20.0, 10000)
	sim.tick(3600.0, ctx, StillRNG.new(3))
	# Zyklus ist bei diesem Setup deterministisch (feste Bisszeit, feste
	# Gewichtsspanne -> Perzentil immer 0): 1 s Wurf + 10 s Warten +
	# 20 * 1.0 * (0.75 + 0.5*0) / 4 s Kampf = 1 + 10 + 3.75 = 14.75 s.
	# floor(3600 / 14.75) = 244, gemessen und bestaetigt. Kein Zufallsband,
	# nur ein kleiner Rand fuer Gleitkomma-Grenzfaelle.
	assert_between(float(ctx.inventory.fish.size()), 242.0, 246.0)

## Ein tick(16.0) muss dieselben Zustandswechsel liefern wie sechzehn
## tick(1.0) hintereinander -- sonst wird derselbe tick() im Offline-
## Fortschritt (grosses Delta) ein anderes System als im laufenden Spiel.
func test_tick_is_delta_independent() -> void:
	var sim_big := FishingSim.new()
	var ctx_big := _ctx(20.0)
	var events_big := sim_big.tick(16.0, ctx_big, StillRNG.new(1))

	var sim_small := FishingSim.new()
	var ctx_small := _ctx(20.0)
	var rng_small := StillRNG.new(1)
	var events_small := []
	for i in 16:
		events_small.append_array(sim_small.tick(1.0, ctx_small, rng_small))

	assert_eq(sim_big.state, sim_small.state)
	assert_almost_eq(sim_big.timer, sim_small.timer)
	assert_eq(ctx_big.inventory.fish.size(), ctx_small.inventory.fish.size())
	assert_eq(_types(events_big), _types(events_small))

## Wie oben, aber das Delta endet mitten im Kampf (Biss bei 11 s, 13,5 s
## liegen 2,5 s in der Stärkereduktion) -- der einzige Zweig, in dem
## tatsächlich mit `remaining` statt nur mit Timern gerechnet wird.
func test_tick_is_delta_independent_mid_fight() -> void:
	var sim_big := FishingSim.new()
	var ctx_big := _ctx(20.0)
	sim_big.tick(13.5, ctx_big, StillRNG.new(1))

	var sim_small := FishingSim.new()
	var ctx_small := _ctx(20.0)
	var rng_small := StillRNG.new(1)
	for i in 13:
		sim_small.tick(1.0, ctx_small, rng_small)
	sim_small.tick(0.5, ctx_small, rng_small)

	assert_eq(sim_big.state, FishingSim.State.FIGHT, "Vergleich ist nur aussagekräftig, wenn beide noch kämpfen")
	assert_eq(sim_big.state, sim_small.state)
	assert_almost_eq(sim_big.hooked_strength, sim_small.hooked_strength)
	assert_almost_eq(sim_big.timer, sim_small.timer)

func _ctx_with_journal() -> SimContext:
	var ctx := _ctx(20.0)
	return ctx

## Die Fangkarte zeigt "neue Art" und "neuer Rekord" -- beides ist nur im
## Moment des Eintragens bekannt, danach IST das Gewicht der Bestwert.
func test_caught_event_reports_new_species_and_record() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx_with_journal()
	var fish: FishData = ctx.zone.fish[0]

	var first := _land_with(sim, ctx, fish, 1.0)
	assert_true(bool(first["discovered"]), "erster Fang der Art ist eine Entdeckung")
	assert_true(bool(first["record"]), "erster Fang ist immer Rekord")

	var lighter := _land_with(sim, ctx, fish, 0.5)
	assert_false(bool(lighter["discovered"]), "zweiter Fang ist keine Entdeckung mehr")
	assert_false(bool(lighter["record"]), "leichter als der Bestwert ist kein Rekord")

	var heavier := _land_with(sim, ctx, fish, 2.0)
	assert_false(bool(heavier["discovered"]), "immer noch keine Entdeckung")
	assert_true(bool(heavier["record"]), "schwerer als der Bestwert ist ein Rekord")

func _land_with(sim: FishingSim, ctx: SimContext, fish: FishData, weight: float) -> Dictionary:
	sim.state = FishingSim.State.FIGHT
	sim.hooked = fish
	sim.hooked_weight = weight
	sim.hooked_quality = 2
	sim.hooked_shiny = false
	sim.hooked_strength = 0.01
	sim.hooked_max_strength = 0.01
	var events := sim.tick(0.05, ctx, StillRNG.new(7))
	for e in events:
		if e["type"] == "caught":
			return e
	return {}
