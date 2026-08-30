extends TestCase

## Der ganze Sinn der Leiste ist das richtungsabhängige Verhalten. Ein Test,
## der nur "der Wert kommt an" prüft, würde eine gewöhnliche Leiste
## durchwinken — deshalb wird hier auf beide Hälften einzeln geschaut.

func _bar() -> GhostBar:
	var b := GhostBar.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(b)
	b.set_max(100.0)
	b.reset_to(100.0)
	return b

func test_a_loss_drops_the_front_at_once_and_the_ghost_lags() -> void:
	var b := _bar()
	b.set_value(60.0)
	assert_almost_eq(b._front.value, 60.0, 0.001, "vorn muss sofort fallen")
	assert_almost_eq(b._ghost.value, 100.0, 0.001, "hinten muss stehen bleiben")
	b._process(0.05)
	assert_true(b._ghost.value < 100.0, "hinten muss nachziehen")
	assert_true(b._ghost.value > 60.0, "aber noch nicht angekommen sein")
	b.free()

func test_a_gain_pushes_the_ghost_first() -> void:
	var b := _bar()
	b.reset_to(20.0)
	b.set_value(80.0)
	assert_almost_eq(b._ghost.value, 80.0, 0.001, "hinten muss sofort vorspringen")
	assert_almost_eq(b._front.value, 20.0, 0.001, "vorn muss nachziehen")
	b.free()

func test_both_halves_arrive_exactly() -> void:
	var b := _bar()
	b.set_value(37.5)
	for i in 200:
		b._process(0.016)
	assert_almost_eq(b._front.value, 37.5, 0.0001)
	assert_almost_eq(b._ghost.value, 37.5, 0.0001)
	b.free()

## Ohne Einrast-Schwelle naehert sich ein Lerp dem Ziel ewig. Der Test
## bestimmt die Zahl der Schritte, nicht die Formel.
func test_it_snaps_instead_of_converging_forever() -> void:
	var b := _bar()
	b.set_value(0.0)
	var steps := 0
	while b._front.value != 0.0 and steps < 5000:
		b._process(0.016)
		steps += 1
	assert_true(steps < 200, "die Leiste braucht %d Schritte statt einzurasten" % steps)
	b.free()

func test_reset_moves_both_halves_without_animation() -> void:
	var b := _bar()
	b.set_value(10.0)
	b.reset_to(90.0)
	assert_almost_eq(b._front.value, 90.0, 0.001)
	assert_almost_eq(b._ghost.value, 90.0, 0.001, "beim Zuruecksetzen darf nichts hinterherlaufen")
	b.free()
