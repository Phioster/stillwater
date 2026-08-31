extends TestCase

## Die Reihenfolge kam dreimal aus der Ordner-Auflistung des Dateisystems --
## im Journal repariert, in Welt und Geheimreiter vergessen. Jetzt an einer
## Stelle, und das wird hier festgehalten.

func _main() -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	var m: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(m)
	return m

func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		out.append_array(_texts(c))
	return out

func _positions(texts: Array[String], names: Array[String]) -> Array[int]:
	var out: Array[int] = []
	for n in names:
		for i in texts.size():
			if texts[i].begins_with(n):
				out.append(i)
				break
	return out

func test_zones_are_ordered_by_unlock_everywhere() -> void:
	var zones := Database.zones_in_order()
	assert_eq(zones[0].id, &"willow_lake", "die Startzone muss zuerst kommen")
	for i in range(1, zones.size()):
		assert_true(zones[i - 1].unlock_level <= zones[i].unlock_level,
			"%s steht vor %s" % [zones[i - 1].id, zones[i].id])

	var names: Array[String] = []
	for z in zones:
		names.append(z.display_name)

	Game.new_game()
	Game.unlocked_zones = []
	for z in zones:
		Game.unlocked_zones.append(z.id)
	var m := _main()

	# Weltliste
	m.show_tab(3)
	var world := _positions(_texts(m.get_node("SidePanel/Panels/WorldGroup/WorldScroll/WorldPanel")), names)
	assert_eq(world.size(), names.size(), "in der Weltliste fehlt eine Zone")
	for i in range(1, world.size()):
		assert_true(world[i - 1] < world[i], "Weltliste steht falsch herum")

	# Journal
	m.show_tab(1)
	var journal := _positions(_texts(m.get_node("SidePanel/Panels/JournalGroup/JournalScroll/JournalPanel")), names)
	for i in range(1, journal.size()):
		assert_true(journal[i - 1] < journal[i], "Journal steht falsch herum")
	m.free()

func test_the_secret_tab_lists_zones_in_the_same_order() -> void:
	Game.new_game()
	for id in Database.fish:
		var f: FishData = Database.fish[id]
		if f.is_secret:
			Game.ctx.journal.record(CaughtFish.make(f.id, 0.0, false), true)
	var m := _main()
	m.show_tab(0)
	m.get_node("SidePanel/Panels/FishGroup").select_sub(3)
	var names: Array[String] = []
	for z in Database.zones_in_order():
		names.append(z.display_name)
	var seen := _positions(_texts(m.get_node("SidePanel/Panels/FishGroup/SecretScroll/SecretPanel")), names)
	assert_eq(seen.size(), names.size(), "im Geheimreiter fehlt eine Zone")
	for i in range(1, seen.size()):
		assert_true(seen[i - 1] < seen[i], "Geheimreiter steht falsch herum")
	m.free()

func test_baits_are_ordered_by_unlock() -> void:
	var baits := Database.baits_in_order()
	assert_true(baits[0].unlimited, "der Grundköder muss zuerst kommen")
	for i in range(1, baits.size()):
		assert_true(baits[i - 1].unlock_level <= baits[i].unlock_level,
			"%s steht vor %s" % [baits[i - 1].id, baits[i].id])

## Der Köder bestimmt die Wartezeit, die Zone gibt den Grundwert.
func test_a_better_bait_shortens_the_wait() -> void:
	var slow := BaitData.new()
	slow.id = &"slow"
	slow.unlimited = true
	slow.bite_time_mult = 1.0
	var fast := BaitData.new()
	fast.id = &"fast"
	fast.unlimited = true
	fast.bite_time_mult = 0.5

	var zone := ZoneData.new()
	zone.id = &"z"
	zone.bite_time_min = 40.0
	zone.bite_time_max = 40.0
	var ctx := SimContext.new()
	ctx.zone = zone

	var sim := FishingSim.new()
	ctx.bait = slow
	sim._begin_wait(ctx, StillRNG.new(1))
	assert_almost_eq(sim.timer, 40.0, 0.001)
	ctx.bait = fast
	sim._begin_wait(ctx, StillRNG.new(1))
	assert_almost_eq(sim.timer, 20.0, 0.001, "der bessere Köder muss halbieren")

## Zone und Köder multiplizieren sich -- ohne Klammern zöge das die Wartezeit
## ins Absurde.
func test_the_wait_stays_within_bounds() -> void:
	var zone := ZoneData.new()
	zone.bite_time_min = 1000.0
	zone.bite_time_max = 1000.0
	var bait := BaitData.new()
	bait.unlimited = true
	bait.bite_time_mult = 1.0
	var ctx := SimContext.new()
	ctx.zone = zone
	ctx.bait = bait
	var sim := FishingSim.new()
	sim._begin_wait(ctx, StillRNG.new(1))
	assert_almost_eq(sim.timer, FishingSim.MAX_BITE_TIME, 0.001)

	zone.bite_time_min = 10.0
	zone.bite_time_max = 10.0
	bait.bite_time_mult = 0.05
	sim._begin_wait(ctx, StillRNG.new(1))
	assert_almost_eq(sim.timer, FishingSim.MIN_BITE_TIME, 0.001)

## Die Wartezeit darf NICHT mit dem Fortschritt wachsen. Das hatte ich falsch
## gebaut: bis 70-120 s im Sternensee. Spätere Zonen sind über die
## Lebenspunkte der Fische schwerer, nicht über längeres Warten --
## die Referenz würfelt die Bisszeit sogar überall identisch.
func test_later_zones_do_not_make_you_wait_longer() -> void:
	var zones := Database.zones_in_order()
	var first := zones[0]
	for z in zones:
		assert_true(z.bite_time_max <= first.bite_time_max * 1.35,
			"%s lässt %.0f s warten, die Startzone nur %.0f" % [z.id, z.bite_time_max, first.bite_time_max])

## Jeder gekaufte Köder muss schneller sein als der Grundköder, sonst zahlt
## man für nichts.
func test_every_bought_bait_is_faster_than_the_free_one() -> void:
	var basic := Database.basic_bait()
	for b in Database.baits_in_order():
		if b.unlimited:
			continue
		assert_true(b.bite_time_mult < basic.bite_time_mult,
			"%s ist nicht schneller als der Grundköder" % b.id)

func test_a_locked_bait_cannot_be_bought() -> void:
	Game.new_game()
	Game.coins = 1000000
	var late: BaitData = null
	for b in Database.baits_in_order():
		if b.unlock_level > 5:
			late = b
			break
	assert_true(late != null, "es muss einen späten Köder geben")
	Game.ctx.player_level = 1
	assert_false(Game.buy_bait(late.id, 1), "gesperrter Köder darf nicht gekauft werden")
	Game.ctx.player_level = late.unlock_level
	assert_true(Game.buy_bait(late.id, 1), "ab der Stufe muss es gehen")
