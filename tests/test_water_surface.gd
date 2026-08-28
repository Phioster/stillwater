extends TestCase

func test_new_surface_starts_flat() -> void:
	var w := WaterSurface.new(10)
	for h in w.heights:
		assert_almost_eq(h, 0.0, 0.0)
	assert_almost_eq(w.max_abs_height(), 0.0, 0.0)

func test_disturb_moves_the_struck_point_after_one_step() -> void:
	var w := WaterSurface.new(10)
	w.disturb(5, 4.0)
	w.step(1.0 / 60.0)
	assert_true(w.heights[5] > 0.0, "Der gestossene Punkt muss sich in Stossrichtung bewegen")

func test_disturbance_spreads_to_neighbors() -> void:
	var w := WaterSurface.new(10)
	w.disturb(5, 4.0)
	for i in 10:
		w.step(1.0 / 60.0)
	assert_true(w.heights[4] != 0.0, "Nachbar links haette sich nach mehreren Schritten bewegen muessen")
	assert_true(w.heights[6] != 0.0, "Nachbar rechts haette sich nach mehreren Schritten bewegen muessen")

## Nachweis "klingt ab": eine starke Stoerung darf nicht dauerhaft stehen bleiben.
func test_disturbance_decays_to_rest() -> void:
	var w := WaterSurface.new(24)
	w.disturb(12, 20.0)
	for i in 300: # 5 Sekunden bei 60Hz
		w.step(1.0 / 60.0)
	assert_true(w.max_abs_height() < 0.01, "Nach 5s muss eine starke Stoerung praktisch abgeklungen sein, blieb bei %f" % w.max_abs_height())

## Vergleicht Spitzenwerte ueber ganze Fenster statt Einzelmomente -- eine
## gedaempfte Schwingung darf zwischen zwei Zeitpunkten zufaellig gerade durch
## einen Nulldurchgang laufen, das waere sonst ein falscher Fehlschlag.
func test_decay_shrinks_not_grows() -> void:
	var w := WaterSurface.new(24)
	w.disturb(12, 20.0)
	var early_peak := 0.0
	for i in 90: # 1.5s -- deckt mindestens eine volle Schwingung ab
		w.step(1.0 / 60.0)
		early_peak = maxf(early_peak, w.max_abs_height())
	var later_peak := 0.0
	for i in 300: # die naechsten 5s
		w.step(1.0 / 60.0)
		later_peak = maxf(later_peak, w.max_abs_height())
	assert_true(later_peak < early_peak, "Spitzenwert muss sinken (frueh=%f, spaet=%f)" % [early_peak, later_peak])

## Nachweis "stabil bei grossem Delta": ein einzelner grosser Zeitschritt
## (z.B. nach einem Frame-Ruckler) darf die Stoerung nicht verstaerken.
func test_stable_with_large_single_delta() -> void:
	var w := WaterSurface.new(24)
	w.disturb(12, 20.0)
	w.step(2.0)
	assert_true(is_finite(w.max_abs_height()), "Ergebnis darf nicht NaN/Inf werden")
	assert_true(w.max_abs_height() < 20.0, "Ein grosser Zeitschritt darf die Stoerung nicht verstaerken, war %f" % w.max_abs_height())

## Die interne Zerlegung in feste Teilschritte darf das Ergebnis nicht davon
## abhaengig machen, wie der Aufrufer delta zerstueckelt.
func test_large_delta_matches_many_small_steps() -> void:
	var a := WaterSurface.new(16)
	var b := WaterSurface.new(16)
	a.disturb(8, 10.0)
	b.disturb(8, 10.0)
	a.step(0.5) # ein Aufruf
	for i in 30:
		b.step(1.0 / 60.0) # dieselbe Gesamtzeit in vielen kleinen Aufrufen
	for i in a.point_count:
		assert_almost_eq(a.heights[i], b.heights[i], 0.001, "Punkt %d" % i)

func test_disturb_at_maps_fraction_to_index() -> void:
	var w := WaterSurface.new(11)
	w.disturb_at(0.0, 5.0)
	assert_true(w.velocities[0] > 0.0)
	w.disturb_at(1.0, 5.0)
	assert_true(w.velocities[10] > 0.0)
	w.disturb_at(0.5, 5.0)
	assert_true(w.velocities[5] > 0.0)

func test_disturb_ignores_out_of_range_index() -> void:
	var w := WaterSurface.new(5)
	w.disturb(-1, 5.0)
	w.disturb(5, 5.0)
	assert_almost_eq(w.max_abs_height(), 0.0, 0.0, "Ausserhalb des Bereichs darf nichts passieren")

func test_ambient_offset_matches_formula() -> void:
	var fraction := 0.25
	var time := 1.3
	var expected: float = sin((fraction / WaterSurface.AMBIENT_WAVELENGTH - time * WaterSurface.AMBIENT_SPEED) * TAU) * WaterSurface.AMBIENT_AMPLITUDE
	assert_almost_eq(WaterSurface.ambient_offset(fraction, time), expected, 0.0001)

func test_ambient_offset_stays_within_amplitude() -> void:
	for i in 20:
		var v := WaterSurface.ambient_offset(float(i) / 19.0, float(i) * 0.37)
		assert_between(v, -WaterSurface.AMBIENT_AMPLITUDE, WaterSurface.AMBIENT_AMPLITUDE)
