extends TestCase

func _rarity() -> RarityData:
	var r := RarityData.new()
	r.id = &"common"
	return r

func _fish(difficulty: float) -> FishData:
	var f := FishData.new()
	f.id = &"testfish"
	f.rarity_id = &"common"
	f.base_value = 10
	f.difficulty = difficulty
	f.xp = 10
	f.weight_mean = 1.0000
	f.weight_dev = 0.0100
	f.spawn_weight = 1.0
	return f

## difficulty statt Staerke: der Kampf ist ein Schadensrennen.
## Lebenspunkte = Rangtabelle * difficulty, Zeit = Fenster * Rangzeit.
##
## Der Rang kommt seit 2026-08-30 vom KOEDER. Ein Koeder mit genau einem
## Eintrag macht ihn eindeutig -- das ersetzt die frueheren gemessenen Seeds
## und ist unabhaengig vom Zufallsgenerator.
func _ctx(difficulty: float, capacity: int = 100, rank: int = 0) -> SimContext:
	var zone := ZoneData.new()
	zone.id = &"willow_lake"
	zone.fish = [_fish(difficulty)]
	zone.rarity_weights = {&"common": 1.0}
	zone.bite_time_min = 10.0
	zone.bite_time_max = 10.0   # feste Bisszeit macht den Test exakt
	zone.fight_window = 20.0
	var bait := BaitData.new()
	bait.id = &"pond_grub"
	bait.unlimited = true
	bait.rank_probabilities = {rank: 1.0}
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

## Rang E: 7 LP, Fenster 20*0,7 = 14 s, zwei Rutenschuebe = 2 s.
func test_weak_fish_is_landed_automatically() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(1.0, 100, 0)
	var events := sim.tick(11.0 + 2.5, ctx, StillRNG.new(1))
	assert_true("caught" in _types(events))
	assert_eq(ctx.inventory.fish.size(), 1)

func test_strong_fish_escapes_after_the_window() -> void:
	var sim := FishingSim.new()
	# Rang S: 216 LP, Fenster 20*1,9 = 38 s, Rute 4 je Sekunde -> 152.
	# Ohne Tippen ist das nicht zu schaffen -- genau so soll es sein.
	var ctx := _ctx(1.0, 100, 5)
	var events := sim.tick(11.0 + 39.0, ctx, StillRNG.new(1))
	assert_true("escaped" in _types(events))
	assert_eq(ctx.inventory.fish.size(), 0)
	assert_false("caught" in _types(events))

func test_tapping_saves_a_fish_that_would_escape() -> void:
	var sim := FishingSim.new()
	# Derselbe Rang-S-Fisch wie oben, der ohne Zutun entkommt.
	var ctx := _ctx(1.0, 100, 5)
	sim.tick(11.1, ctx, StillRNG.new(1))
	assert_eq(sim.state, FishingSim.State.FIGHT)
	var caught := false
	for i in 40:
		if "caught" in _types(sim.tap(ctx)):
			caught = true
			break
	assert_true(caught, "40 Tipps à 6 Schaden müssen 216 Lebenspunkte brechen")

func test_tap_does_nothing_outside_a_fight() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(1.0)
	assert_eq(sim.tap(ctx).size(), 0)

func test_catch_awards_xp_and_can_level_up() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(1.0, 100, 0)
	var events := sim.tick(11.0 + 2.5, ctx, StillRNG.new(1))
	var xp := 0
	for e in events:
		if e["type"] == "caught":
			xp = int(e["xp"])
	assert_true(xp > 0)
	assert_true(ctx.player_xp > 0 or ctx.player_level > 1)

func test_catch_records_the_journal() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(1.0, 100, 0)
	sim.tick(11.0 + 2.5, ctx, StillRNG.new(1))
	assert_true(ctx.journal.is_discovered(&"testfish"))

func test_full_inventory_pauses_fishing() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(0.1, 1)
	sim.tick(3600.0, ctx, StillRNG.new(1))
	assert_eq(ctx.inventory.fish.size(), 1)
	assert_eq(sim.state, FishingSim.State.INVENTORY_FULL)

func test_fishing_resumes_after_inventory_is_emptied() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(0.1, 1)
	sim.tick(3600.0, ctx, StillRNG.new(1))
	assert_eq(sim.state, FishingSim.State.INVENTORY_FULL)
	ctx.inventory.take_sellable()
	assert_eq(ctx.inventory.fish.size(), 0, "das Inventar muss vorher leer sein")
	sim.tick(11.0 + 12.0, ctx, StillRNG.new(1))
	assert_eq(ctx.inventory.fish.size(), 1)

func test_many_catches_over_an_hour() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(0.01, 10000)
	sim.tick(3600.0, ctx, StillRNG.new(3))
	# Der Zyklus ist nicht exakt: der Rang wuerfelt mit. 1 s Wurf + 10 s
	# Warten + Kampf. Die Rute schlaegt in Schueben von 1 s, bei difficulty
	# 0,01 braucht selbst Rang S+ (4,32 LP) nur zwei Schuebe = 2 s, Rang E
	# einen = 1 s. Also 12 bis 13 s je Zyklus: floor(3600/13) = 276 bis
	# floor(3600/12) = 300.
	assert_between(float(ctx.inventory.fish.size()), 276.0, 300.0)

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
	assert_almost_eq(sim_big.hooked_health, sim_small.hooked_health)
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
	sim.hooked_dev = weight
	sim.hooked_rank = 2
	sim.hooked_shiny = false
	sim.hooked_health = 0.01
	sim.hooked_max_health = 0.01
	var events := sim.tick(0.05, ctx, StillRNG.new(7))
	for e in events:
		if e["type"] == "caught":
			return e
	return {}

## Fangpunkte haengen am Geschehen, nicht an einer Uhr: faellt einer weg,
## rueckt der naechste nach. Vorher wartete er stur die volle Pause ab.
func test_orbs_follow_up_when_one_disappears() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	# Die Fangansicht arbeitet nur waehrend eines Kampfes.
	Game.new_game()
	Game.paused = true
	Game.sim.state = FishingSim.State.FIGHT
	Game.sim.hooked = Database.fish[&"bluegill"]
	Game.sim.hooked_max_health = 100.0
	Game.sim.hooked_health = 50.0
	var cv: Control = load("res://scenes/fishing/catch_view.tscn").instantiate()
	tree.root.add_child(cv)
	cv.size = Vector2(800, 600)
	await tree.process_frame
	var area: Control = cv.spawn_area
	var target: int = cv.get_script().get_script_constant_map()["ORB_TARGET"]
	assert_true(target >= 1, "es muss mindestens ein Punkt gleichzeitig da sein")

	# Bis zum Sollbestand auffuellen
	for i in 40:
		cv._process(0.05)
		await tree.process_frame
	assert_eq(cv._living_orbs(), target, "der Sollbestand muss erreicht werden")

	# Einen entfernen -- der Ersatz muss von selbst nachruecken, ohne dass
	# jemand eine feste Pause abwartet.
	var removed := area.get_child(0)
	var removed_id := removed.get_instance_id()
	removed.queue_free()
	var respawn: float = cv.get_script().get_script_constant_map()["ORB_RESPAWN"]
	assert_true(respawn <= 0.3, "das Nachruecken darf sich nicht traege anfuehlen: %f s" % respawn)
	for i in 6:
		cv._process(respawn)
		await tree.process_frame
	assert_eq(cv._living_orbs(), target, "der Bestand muss sich von selbst wieder auffuellen")
	for child in area.get_children():
		assert_true(child.get_instance_id() != removed_id, "der entfernte Punkt darf nicht zurueckkommen")
	cv.queue_free()

## Die Rute schlaegt in Schueben. Der Offline-Fortschritt faehrt denselben
## tick() mit riesigem Delta -- ergaebe ein grosser Schritt andere Treffer
## als viele kleine, waere Offline ein anderes Spiel.
func test_rod_pulses_are_delta_independent() -> void:
	var big := FishingSim.new()
	var ctx_big := _ctx(3.0, 100, 4)
	big.tick(11.1, ctx_big, StillRNG.new(1))
	assert_eq(big.state, FishingSim.State.FIGHT, "der Testfisch muss noch kaempfen")
	big.tick(7.0, ctx_big, StillRNG.new(1))

	var small := FishingSim.new()
	var ctx_small := _ctx(3.0, 100, 4)
	small.tick(11.1, ctx_small, StillRNG.new(1))
	for i in 70:
		small.tick(0.1, ctx_small, StillRNG.new(1))

	assert_eq(big.rod_hits, small.rod_hits,
		"gleiche Zeit, gleiche Treffer: %d gegen %d" % [big.rod_hits, small.rod_hits])
	assert_almost_eq(big.hooked_health, small.hooked_health, 0.001)
	assert_almost_eq(big.rod_timer, small.rod_timer, 0.001)

## Sieben Sekunden Kampf sind sieben Schuebe -- nicht sechs, nicht acht.
func test_the_rod_hits_once_per_interval() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(3.0)
	# Der Biss faellt bei 11,0 s -- nach tick(11.1) laeuft der Kampf also
	# schon 0,1 s. Alle folgenden Zeiten rechnen ab dort.
	sim.tick(11.1, ctx, StillRNG.new(11))
	assert_eq(sim.rod_hits, 0, "beim Anbiss hat die Rute noch nicht geschlagen")
	sim.tick(0.85, ctx, StillRNG.new(1))
	assert_eq(sim.rod_hits, 0, "bei 0,95 s noch nicht")
	sim.tick(0.1, ctx, StillRNG.new(1))
	assert_eq(sim.rod_hits, 1, "bei 1,05 s genau einmal")
	sim.tick(3.0, ctx, StillRNG.new(1))
	assert_eq(sim.rod_hits, 4, "bei 4,05 s viermal")

func test_each_pulse_takes_exactly_rod_power() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(3.0, 100, 4)
	sim.tick(11.1, ctx, StillRNG.new(1))
	var full := sim.hooked_max_health
	sim.tick(3.0, ctx, StillRNG.new(1))
	assert_almost_eq(sim.hooked_health, full - 3.0 * ctx.rod_power, 0.001,
		"drei Schuebe muessen dreimal rod_power abziehen")

## Die Idle-Grenze wird beim Anbiss bestimmt, damit die Anzeige sie ansagen
## kann. Ein Fisch, den die Rute nicht schafft, muss als solcher markiert sein.
func test_a_fish_the_rod_cannot_land_is_flagged() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(1.0, 100, 5)
	sim.tick(11.1, ctx, StillRNG.new(1))
	assert_eq(sim.hooked_rank, 5, "der Testfisch muss Rang S sein")
	assert_true(sim.needs_hands, "216 LP gegen 152 Rutenschaden: das braucht Hände")

func test_a_fish_the_rod_can_land_is_not_flagged() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(1.0, 100, 0)
	sim.tick(11.1, ctx, StillRNG.new(1))
	assert_eq(sim.hooked_rank, 0, "der Testfisch muss Rang E sein")
	assert_false(sim.needs_hands, "7 LP schafft die Rute allein")

## Die Ansage muss zur Wirklichkeit passen: was als schaffbar gilt, muss
## ohne einen einzigen Tipp auch wirklich gelandet werden.
func test_the_promise_holds_without_tapping() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(1.0, 100, 0)
	sim.tick(11.1, ctx, StillRNG.new(1))
	assert_false(sim.needs_hands)
	var events := sim.tick(sim.hooked_max_time, ctx, StillRNG.new(1))
	assert_true("caught" in _types(events), "als schaffbar angesagt, aber entkommen")

func test_a_stronger_rod_moves_the_line() -> void:
	var sim := FishingSim.new()
	var ctx := _ctx(1.0, 100, 5)
	ctx.rod_power = 40.0
	sim.tick(11.1, ctx, StillRNG.new(1))
	assert_eq(sim.hooked_rank, 5)
	assert_false(sim.needs_hands, "mit starker Rute schafft sie auch Rang S")
