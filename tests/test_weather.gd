extends TestCase

## Regen hängt an der Uhr, nicht an einem Zustand. Er ist immer ein Vorteil:
## ein Wetter, das bestraft, treibt den Spieler nur weg.

func test_the_same_hour_and_zone_always_give_the_same_weather() -> void:
	for h in 20:
		var now := float(h) * Weather.INTERVAL + 30.0
		var a := Weather.is_raining(now, &"willow_lake")
		var b := Weather.is_raining(now + 3000.0, &"willow_lake")
		assert_eq(a, b, "innerhalb der Stunde darf das Wetter nicht umschlagen")

func test_zones_have_their_own_weather() -> void:
	var differ := 0
	for h in 60:
		var now := float(h) * Weather.INTERVAL
		if Weather.is_raining(now, &"willow_lake") != Weather.is_raining(now, &"star_lake"):
			differ += 1
	assert_true(differ > 5, "es regnet überall gleichzeitig (%d von 60 verschieden)" % differ)

## Nicht dauernd und nicht nie -- sonst ist es entweder Alltag oder Deko.
func test_rain_is_occasional() -> void:
	var wet := 0
	for h in 400:
		if Weather.is_raining(float(h) * Weather.INTERVAL, &"willow_lake"):
			wet += 1
	var share := float(wet) / 400.0
	assert_between(share, 0.15, 0.45, "es regnet in %d %% der Stunden" % int(share * 100.0))

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
