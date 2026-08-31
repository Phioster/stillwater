extends TestCase

## Regen hängt an der Uhr, nicht an einem Zustand. Er ist immer ein Vorteil:
## ein Wetter, das bestraft, treibt den Spieler nur weg.

func test_the_same_hour_and_zone_always_give_the_same_weather() -> void:
	for h in 20:
		var now := float(h) * Weather.INTERVAL + 30.0
		var a := Weather.is_raining(now, &"willow_lake")
		var b := Weather.is_raining(now + 3000.0, &"willow_lake")
		assert_eq(a, b, "innerhalb der Stunde darf das Wetter nicht umschlagen")

## Die Kernregel: nie zwei nasse Zonen gleichzeitig.
func test_it_only_ever_rains_in_one_zone() -> void:
	var zones := Database.zones_in_order()
	assert_true(zones.size() > 1, "der Test braucht mehrere Zonen")
	for h in 300:
		var now := float(h) * Weather.INTERVAL
		var wet := 0
		for z in zones:
			if Weather.is_raining(now, z.id):
				wet += 1
		assert_true(wet <= 1, "in Stunde %d regnet es in %d Zonen" % [h, wet])

## Und jede Zone kommt auch mal dran, statt dass es immer dieselbe trifft.
func test_every_zone_gets_its_turn() -> void:
	var seen: Dictionary = {}
	for h in 2000:
		var id := Weather.rain_zone(float(h) * Weather.INTERVAL)
		if id != &"":
			seen[id] = true
	assert_eq(seen.size(), Database.zones_in_order().size(),
		"nur %d Zonen wurden je nass" % seen.size())

## Die Abklingzeit: nach einer Regenstunde bleibt es eine Weile trocken.
func test_rain_has_a_cooldown() -> void:
	var last := -999
	for h in 2000:
		if Weather.rain_zone(float(h) * Weather.INTERVAL) == &"":
			continue
		assert_true(h - last > Weather.DRY_TAIL,
			"Stunde %d regnet zu kurz nach %d" % [h, last])
		last = h

## Nicht dauernd und nicht nie -- sonst ist es entweder Alltag oder Deko.
func test_rain_is_occasional() -> void:
	var wet := 0
	for h in 2000:
		if Weather.rain_zone(float(h) * Weather.INTERVAL) != &"":
			wet += 1
	var share := float(wet) / 2000.0
	assert_between(share, 0.04, 0.16, "es regnet in %d %% der Stunden" % int(share * 100.0))

func test_rain_only_ever_helps() -> void:
	assert_true(Weather.BITE_FACTOR < 1.0, "Regen muss die Wartezeit kürzen")
	assert_true(Weather.FIGHT_FACTOR > 1.0, "Regen muss mehr Kampfzeit geben")

func test_rain_reaches_the_simulation() -> void:
	var zone := ZoneData.new()
	zone.bite_time_min = 40.0
	zone.bite_time_max = 40.0
	zone.fight_window = 20.0
	var bait := BaitData.new()
	bait.unlimited = true
	bait.rank_probabilities = {0: 1.0}
	var ctx := SimContext.new()
	ctx.zone = zone
	ctx.bait = bait

	var sim := FishingSim.new()
	ctx.raining = false
	sim._begin_wait(ctx, StillRNG.new(1))
	var dry := sim.timer
	ctx.raining = true
	sim._begin_wait(ctx, StillRNG.new(1))
	assert_almost_eq(sim.timer, dry * Weather.BITE_FACTOR, 0.001,
		"bei Regen muss es schneller beissen")

func test_the_hud_says_when_it_rains() -> void:
	Game.new_game()
	var tree := Engine.get_main_loop() as SceneTree
	var m: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	var hud := m.get_node("Hud")
	Game.ctx.raining = false
	hud.refresh()
	var dry: String = hud.get_node("Box/Zone").text
	Game.ctx.raining = true
	hud.refresh()
	assert_true(hud.get_node("Box/Zone").text != dry, "der Regen wird nicht angesagt")
	m.free()
