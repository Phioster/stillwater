extends TestCase

func _rarity() -> RarityData:
	var r := RarityData.new()
	r.id = &"common"
	return r

func _fish() -> FishData:
	var f := FishData.new()
	f.id = &"testfish"
	f.rarity_id = &"common"
	f.base_value = 10
	f.strength = 20.0
	f.xp = 10
	f.weight_mean = 2.5000
	f.weight_dev = 0.5000
	f.spawn_weight = 1.0
	return f

func _ctx(capacity: int = 10000) -> SimContext:
	var zone := ZoneData.new()
	zone.id = &"willow_lake"
	zone.fish = [_fish()]
	zone.rarity_weights = {&"common": 1.0}
	zone.bite_time_min = 25.0
	zone.bite_time_max = 45.0
	zone.fight_window = 20.0
	var bait := BaitData.new()
	bait.id = &"pond_grub"
	bait.unlimited = true
	# Eindeutiger Rang: der Koeder bestimmt ihn, nicht der Zufall. Rang A mit
	# difficulty 4 ergibt 432 LP -- lang genug, um mitten im Kampf zu vergleichen.
	bait.rank_probabilities = {4: 1.0}
	var ctx := SimContext.new()
	ctx.zone = zone
	ctx.bait = bait
	ctx.fallback_bait = bait
	ctx.rarities = {&"common": _rarity()}
	ctx.inventory = Inventory.new()
	ctx.inventory.capacity = capacity
	ctx.journal = Journal.new()
	ctx.rod_power = 4.0
	return ctx

func _fish_by_id() -> Dictionary:
	var f := _fish()
	return {f.id: f}

## Der wichtigste Test des Projekts. Vergleicht alles, was zwischen den
## beiden Wegen (ein großes Delta vs. viele kleine) auseinanderdriften
## könnte -- nicht nur die Fangzahl, sonst übersieht der Test genau die
## Drift, um die es geht.
func test_offline_equals_online() -> void:
	var seconds := 1800.0

	var online_sim := FishingSim.new()
	var online_ctx := _ctx()
	var online_rng := StillRNG.new(2026)
	var online_ids: Array = []
	var online_escaped := 0
	var steps := int(seconds / 0.1)
	for i in steps:
		for e in online_sim.tick(0.1, online_ctx, online_rng):
			if e["type"] == "caught":
				online_ids.append(e["caught"].fish_id)
			elif e["type"] == "escaped":
				online_escaped += 1

	var offline_sim := FishingSim.new()
	var offline_ctx := _ctx()
	var offline_rng := StillRNG.new(2026)
	var offline_ids: Array = []
	var offline_escaped := 0
	for e in offline_sim.tick(seconds, offline_ctx, offline_rng):
		if e["type"] == "caught":
			offline_ids.append(e["caught"].fish_id)
		elif e["type"] == "escaped":
			offline_escaped += 1

	assert_eq(offline_ids.size(), online_ids.size(), "gleich viele Fänge")
	assert_eq(offline_ids, online_ids, "gleiche Fangreihenfolge")
	assert_eq(offline_escaped, online_escaped, "gleich viele Entkommene")
	assert_eq(offline_ctx.player_level, online_ctx.player_level, "gleiches Level")
	assert_eq(offline_ctx.player_xp, online_ctx.player_xp, "gleiche XP")
	assert_eq(offline_ctx.journal.entry(&"testfish"), online_ctx.journal.entry(&"testfish"),
		"gleicher Journalstand (Bestgewicht, Qualität, Shiny)")
	assert_eq(offline_ctx.inventory.to_array(), online_ctx.inventory.to_array(),
		"gleiches Inventar (jeder Fisch mit Gewicht/Qualität/Shiny)")
	assert_eq(offline_sim.state, online_sim.state, "gleicher Sim-Zustand")
	assert_almost_eq(offline_sim.timer, online_sim.timer, 0.0001, "gleicher Timer")
	# Nach einem abgeschlossenen Kampf setzt fishing_sim.gd diese Felder zurueck
	# -- der Vergleich ist deshalb unbedingt moeglich, nicht nur waehrend FIGHT.
	assert_almost_eq(offline_sim.hooked_health, online_sim.hooked_health, 0.0001, "gleiche Lebenspunkte")
	assert_almost_eq(offline_sim.hooked_dev, online_sim.hooked_dev, 0.0001, "gleiche Gewichtsabweichung")
	assert_eq(offline_sim.hooked_rank, online_sim.hooked_rank, "gleicher Rang")
	assert_eq(offline_sim.hooked_shiny, online_sim.hooked_shiny, "gleicher Shiny-Status")
	assert_eq(offline_rng.get_state(), online_rng.get_state(), "gleicher RNG-Zustand")

## Wie oben, aber mit fester Bisszeit und fester Gewichtsspanne extra so
## dimensioniert, dass beide Wege garantiert mitten in einem Kampf enden --
## nur dann prüft der Vergleich oben wirklich hooked_health, den einzigen
## Wert, in dem im Kampf tatsächlich gerechnet wird.
func test_offline_equals_online_mid_fight() -> void:
	var fish := FishData.new()
	fish.id = &"testfish"
	fish.rarity_id = &"common"
	fish.base_value = 10
	fish.difficulty = 4.0
	fish.xp = 10
	fish.weight_mean = 1.0000
	fish.weight_dev = 0.0100
	fish.spawn_weight = 1.0
	var zone := ZoneData.new()
	zone.id = &"willow_lake"
	zone.fish = [fish]
	zone.rarity_weights = {&"common": 1.0}
	zone.bite_time_min = 10.0
	zone.bite_time_max = 10.0   # feste Bisszeit macht den Zeitpunkt exakt
	zone.fight_window = 20.0
	var bait := BaitData.new()
	bait.id = &"pond_grub"
	bait.unlimited = true
	# Eindeutiger Rang: der Koeder bestimmt ihn, nicht der Zufall. Rang A mit
	# difficulty 4 ergibt 432 LP -- lang genug, um mitten im Kampf zu vergleichen.
	bait.rank_probabilities = {4: 1.0}

	var make_ctx := func() -> SimContext:
		var c := SimContext.new()
		c.zone = zone
		c.bait = bait
		c.fallback_bait = bait
		c.rarities = {&"common": _rarity()}
		c.inventory = Inventory.new()
		c.inventory.capacity = 10000
		c.journal = Journal.new()
		c.rod_power = 4.0
		return c

	# Rang A mit difficulty 4 hat 432 LP; die Rute schafft in ihrem
	# 30-Sekunden-Fenster nur 120. Der Fisch entkommt also jedes Mal, und
	# ein Zyklus ist Wurf + Warten + volles Fenster. Die Dauer wird aus den
	# Konstanten abgeleitet statt hingeschrieben -- sonst veraltet sie beim
	# naechsten Balance-Schritt still.
	var window := 20.0 * FishRoll.RANK_TIME_MULTS[4]
	var cycle := FishingSim.ESCAPE_COOLDOWN + 10.0 + window
	# Erster Zyklus, dann 20 weitere, dann 15 s in den naechsten Kampf hinein.
	var seconds := FishingSim.CAST_TIME + 10.0 + window + 20.0 * cycle \
		+ FishingSim.ESCAPE_COOLDOWN + 10.0 + 15.0

	var offline_sim := FishingSim.new()
	var offline_ctx: SimContext = make_ctx.call()
	var offline_rng := StillRNG.new(2026)
	offline_sim.tick(seconds, offline_ctx, offline_rng)

	var online_sim := FishingSim.new()
	var online_ctx: SimContext = make_ctx.call()
	var online_rng := StillRNG.new(2026)
	var steps := int(seconds / 0.1)
	for i in steps:
		online_sim.tick(0.1, online_ctx, online_rng)

	assert_eq(offline_sim.state, FishingSim.State.FIGHT, "Vergleich ist nur aussagekräftig, wenn beide noch kämpfen")
	assert_eq(offline_sim.state, online_sim.state, "gleicher Sim-Zustand")
	assert_almost_eq(offline_sim.timer, online_sim.timer, 0.0001, "gleicher Timer")
	assert_almost_eq(offline_sim.hooked_health, online_sim.hooked_health, 0.0001, "gleiche Lebenspunkte")
	assert_almost_eq(offline_sim.hooked_dev, online_sim.hooked_dev, 0.0001, "gleiche Gewichtsabweichung")
	assert_eq(offline_sim.hooked_rank, online_sim.hooked_rank, "gleicher Rang")
	assert_eq(offline_sim.hooked_shiny, online_sim.hooked_shiny, "gleicher Shiny-Status")

func test_offline_is_capped_at_twelve_hours() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx()
	var out := OfflineSim.run(48.0 * 3600.0, sim, ctx, StillRNG.new(5), _fish_by_id())
	assert_almost_eq(float(out["elapsed"]), OfflineSim.MAX_OFFLINE_SECONDS)
	assert_true(out["was_capped"])

## Die Grenze exakt: genau am Maximum wird nicht gedeckelt, knapp darüber schon.
func test_offline_cap_boundary_is_exact() -> void:
	var at_max := OfflineSim.run(OfflineSim.MAX_OFFLINE_SECONDS, FishingSim.new(), _ctx(), StillRNG.new(9), _fish_by_id())
	assert_almost_eq(float(at_max["elapsed"]), OfflineSim.MAX_OFFLINE_SECONDS)
	assert_false(at_max["was_capped"], "am Maximum selbst ist noch nichts gedeckelt worden")

	var just_under := OfflineSim.run(OfflineSim.MAX_OFFLINE_SECONDS - 1.0, FishingSim.new(), _ctx(), StillRNG.new(9), _fish_by_id())
	assert_almost_eq(float(just_under["elapsed"]), OfflineSim.MAX_OFFLINE_SECONDS - 1.0)
	assert_false(just_under["was_capped"])

	var just_over := OfflineSim.run(OfflineSim.MAX_OFFLINE_SECONDS + 1.0, FishingSim.new(), _ctx(), StillRNG.new(9), _fish_by_id())
	assert_almost_eq(float(just_over["elapsed"]), OfflineSim.MAX_OFFLINE_SECONDS)
	assert_true(just_over["was_capped"])

func test_offline_stops_at_a_full_inventory() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(5)
	var out := OfflineSim.run(12.0 * 3600.0, sim, ctx, StillRNG.new(6), _fish_by_id())
	assert_eq(ctx.inventory.fish.size(), 5)
	assert_eq(int(out["caught"]), 5)
	assert_true(out["inventory_full"])
	assert_almost_eq(float(out["elapsed"]), 12.0 * 3600.0, 0.0001,
		"elapsed bleibt die volle angefragte Zeit, auch wenn das Inventar vorher voll wurde")

func test_offline_reports_potential_coins() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(20)
	var out := OfflineSim.run(3600.0, sim, ctx, StillRNG.new(7), _fish_by_id())
	assert_true(int(out["potential_coins"]) > 0, "gefangene Fische müssen einen Wert haben")
	assert_eq(ctx.inventory.fish.size(), int(out["caught"]),
		"potential_coins ist eine Vorschau -- kein Fisch wurde verkauft oder entfernt")

func test_zero_elapsed_changes_nothing() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx()
	var out := OfflineSim.run(0.0, sim, ctx, StillRNG.new(8), _fish_by_id())
	assert_eq(int(out["caught"]), 0)
	assert_eq(ctx.inventory.fish.size(), 0)
