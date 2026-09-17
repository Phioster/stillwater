extends TestCase

## Der Regen endet an der Wasserkante. Das laesst sich nicht am Bild pruefen,
## wohl aber an der Rechnung dahinter: Rain.strich() gibt die beiden
## Endpunkte eines Tropfens heraus, statt sie nur zu zeichnen.

const RUHE := 400.0

## Eine Wasserkante wie die aus world.gd: 28 Punkte ueber die Breite, um die
## Ruhelage herum gewellt.
func _kante(breite: float, ruhe: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(28)
	for i in 28:
		var anteil := float(i) / 27.0
		pts[i] = Vector2(breite * anteil, ruhe + sin(anteil * 6.0) * 7.0)
	return pts

## Der eigentliche Punkt: kein Strich reicht ins Wasser.
func test_no_drop_is_drawn_below_the_water_edge() -> void:
	for kante in [RUHE - 7.0, RUHE, RUHE + 7.0]:
		for schritt in 400:
			var zeit := float(schritt) * 0.005
			for tropfen in 20:
				var versatz := float(tropfen) / 19.0
				var s := Rain.strich(100.0, versatz, zeit, RUHE, kante)
				if s.is_empty():
					continue
				assert_true(s[1].y <= kante + 0.001,
					"Strich endet auf %f, Kante liegt auf %f" % [s[1].y, kante])
				assert_true(s[0].y <= kante + 0.001,
					"Strich beginnt auf %f, Kante liegt auf %f" % [s[0].y, kante])

## Er wird aber auch wirklich bis dorthin gezeichnet -- Regen, der schon in
## der Luft aufhoert, waere derselbe Fehler in die andere Richtung.
func test_drops_actually_reach_the_water_edge() -> void:
	var tiefster := -9999.0
	for schritt in 400:
		var s := Rain.strich(100.0, 0.5, float(schritt) * 0.005, RUHE, RUHE - 7.0)
		if not s.is_empty():
			tiefster = maxf(tiefster, s[1].y)
	assert_almost_eq(tiefster, RUHE - 7.0, 0.001,
		"kein Tropfen erreicht die Kante")

## Ein Tropfen, der ganz unter der Kante steckt, wird gar nicht gezeichnet.
func test_a_drop_below_the_edge_is_not_drawn_at_all() -> void:
	var leer := 0
	for schritt in 400:
		var s := Rain.strich(100.0, 0.5, float(schritt) * 0.005, RUHE, 0.0)
		if s.is_empty():
			leer += 1
		else:
			assert_true(s[1].y <= 0.001, "Strich unter der Kante bei y=%f" % s[1].y)
	assert_true(leer > 0, "kein einziger Tropfen wurde ausgelassen")

## Beim Eintauchen wird er kuerzer, kippt aber nicht auf.
func test_a_shortened_drop_keeps_its_slant() -> void:
	for schritt in 400:
		var s := Rain.strich(100.0, 0.5, float(schritt) * 0.005, RUHE, RUHE - 7.0)
		if s.is_empty():
			continue
		var laenge := s[1].y - s[0].y
		assert_true(laenge > 0.0, "Strich der Laenge %f" % laenge)
		assert_true(laenge <= Rain.LENGTH + 0.001,
			"Strich laenger als LENGTH: %f" % laenge)
		assert_almost_eq(s[0].x - s[1].x, laenge * Rain.SLANT, 0.001,
			"Neigung stimmt bei Laenge %f nicht" % laenge)

## Die Kante wird zwischen ihren Stuetzpunkten interpoliert, sonst endete der
## Regen auf Stufen statt auf einer Welle.
func test_the_edge_is_interpolated_between_its_points() -> void:
	var pts := _kante(280.0, RUHE)
	for i in 27:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var mitte := Rain.kante_bei(pts, 280.0, (a.x + b.x) * 0.5)
		assert_almost_eq(mitte, (a.y + b.y) * 0.5, 0.001,
			"zwischen Punkt %d und %d nicht interpoliert" % [i, i + 1])

## Und ausserhalb der Breite klemmt sie, statt hinauszulaufen: der Regen faellt
## bis an beide Bildraender.
func test_the_edge_clamps_outside_the_width() -> void:
	var pts := _kante(280.0, RUHE)
	assert_almost_eq(Rain.kante_bei(pts, 280.0, -50.0), pts[0].y, 0.001)
	assert_almost_eq(Rain.kante_bei(pts, 280.0, 999.0), pts[27].y, 0.001)

## Ohne gemeldete Kante gibt es keine Hoehe zum Zeichnen -- _draw haelt sich
## in dem Fall ganz heraus.
func test_an_unknown_edge_is_not_guessed() -> void:
	assert_eq(Rain.kante_bei(PackedVector2Array(), 280.0, 100.0), 0.0)
