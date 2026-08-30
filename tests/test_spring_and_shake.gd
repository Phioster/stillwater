extends TestCase

## Feder und Erschütterung sind Lehrbuchphysik -- geprüft wird deshalb nicht
## die Formel, sondern das Verhalten, auf das die Oberfläche baut.

func test_a_nudged_spring_swings_and_comes_back() -> void:
	var s := Spring.new(1.0)
	s.nudge(-6.0)
	s.update(0.016)
	assert_true(s.value < 1.0, "der Stoß muss den Wert bewegen")
	for i in 400:
		s.update(0.016)
	assert_almost_eq(s.value, 1.0, 0.001, "sie muss zum Ziel zurückkehren")

func test_it_comes_to_rest_instead_of_jittering_forever() -> void:
	var s := Spring.new(1.0)
	s.nudge(-4.0)
	var steps := 0
	while not s.resting and steps < 10000:
		s.update(0.016)
		steps += 1
	assert_true(s.resting, "die Feder ruht nach %d Schritten immer noch nicht" % steps)
	assert_almost_eq(s.value, 1.0, 0.0001)

## Ohne Deckel sprengt ein langes Bild die Feder. Der Test gibt ihr absichtlich
## eine halbe Sekunde am Stück.
func test_a_frame_hitch_does_not_blow_it_up() -> void:
	var s := Spring.new(1.0)
	s.nudge(-8.0)
	for i in 60:
		s.update(0.5)
	assert_true(absf(s.value) < 100.0, "die Feder ist explodiert: %f" % s.value)
	assert_between(s.value, 0.5, 1.5, "nach einem Ruckler muss sie nahe am Ziel sein")

func test_move_to_pulls_the_spring_to_a_new_target() -> void:
	var s := Spring.new(0.0)
	s.move_to(5.0)
	for i in 600:
		s.update(0.016)
	assert_almost_eq(s.value, 5.0, 0.001)

## Der Ausschlag muss abklingen und enden -- eine Erschütterung, die bleibt,
## ist ein Fehler.
## Verglichen wird die HUELLKURVE, nicht eine einzelne Stichprobe: das
## Rauschen kann zufaellig gerade nahe null liegen, und dann waere ein
## spaeterer Wert groesser, obwohl die Erschuetterung abklingt.
func test_a_shake_decays_and_ends() -> void:
	var sh := Shake.new(10.0, 0.4, 20.0)
	assert_true(sh.alive())
	var early := 0.0
	for i in 10:
		early = maxf(early, absf(sh.amplitude()))
		sh.update(0.01)
	var late := 0.0
	sh.update(0.25)
	for i in 4:
		late = maxf(late, absf(sh.amplitude()))
		sh.update(0.01)
	assert_true(late < early, "der Ausschlag muss abklingen: %f gegen %f" % [late, early])
	sh.update(0.2)
	assert_false(sh.alive())
	assert_almost_eq(sh.amplitude(), 0.0, 0.0001, "danach muss Ruhe sein")

func test_the_shake_stays_within_its_magnitude() -> void:
	var sh := Shake.new(7.0, 1.0, 30.0)
	for i in 100:
		assert_between(sh.amplitude(), -7.0001, 7.0001)
		sh.update(0.01)

## Vorab gezogenes Rauschen heißt: derselbe Zeitpunkt gibt denselben Wert.
## Bei Würfeln pro Bild wäre der Ausschlag von der Bildrate abhängig.
func test_the_noise_is_drawn_in_advance_not_per_frame() -> void:
	var sh := Shake.new(5.0, 1.0, 20.0)
	sh.update(0.3)
	var a := sh.amplitude()
	var b := sh.amplitude()
	assert_almost_eq(a, b, 0.0000001, "zweimal derselbe Zeitpunkt, zweimal derselbe Wert")
