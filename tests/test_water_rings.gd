extends TestCase

## Die Regenringe auf dem Wasser. Wie beim Regen laesst sich am fertigen Bild
## nichts pruefen -- wohl aber an der Rechnung dahinter: ring_rechtecke() gibt
## heraus, was gezeichnet wuerde, ring_form() den nackten Umriss.

const BREITE := 1200.0
const OBEN := 430.0
const UNTEN := 720.0

## Eine Wasserkante wie die aus world.gd: 28 Punkte, um die Ruhelage gewellt.
func _sicht() -> WaterView:
	var v := WaterView.new()
	var pts := PackedVector2Array()
	pts.resize(28)
	for i in 28:
		var anteil := float(i) / 27.0
		pts[i] = Vector2(BREITE * anteil, OBEN + sin(anteil * 6.0) * 7.0)
	v.setze(pts, BREITE, UNTEN, 0.0)
	return v

## Der eigentliche Punkt: kein Ring liegt ueber der Welle oder unter dem
## Bildrand. Ueber der Welle haengt er in der Luft, darunter ist er halb weg.
func test_no_ring_leaves_the_water() -> void:
	var v := _sicht()
	v.regnet = true
	var gesehen := 0
	for schritt in 300:
		v.setze(v._punkte, BREITE, UNTEN, float(schritt) * 0.02)
		var laeufe := v._laeufe()
		for eintrag in v.ring_rechtecke(laeufe):
			var r: Rect2 = eintrag[0]
			gesehen += 1
			# Die tiefste Kante unter diesem Rechteck -- ueber einer Welle
			# genuegt es nicht, nur in seiner Mitte nachzusehen.
			var kante := -INF
			var px := r.position.x
			while px <= r.position.x + r.size.x:
				var o := v._oberflaeche_bei(laeufe,
					clampf(px, 0.0, BREITE - 0.001))
				if o != INF:
					kante = maxf(kante, o)
				px += WaterView.PIXEL * 0.5
			assert_true(r.position.y >= kante,
				"Ring auf %f, Wasser beginnt erst bei %f" % [r.position.y, kante])
			assert_true(r.position.y + r.size.y <= UNTEN + 0.001,
				"Ring reicht bis %f, Bild endet bei %f"
					% [r.position.y + r.size.y, UNTEN])
	assert_true(gesehen > 1000, "es wurden fast keine Ringe gezeichnet: %d" % gesehen)

## Ohne Regen keine Ringe. Sonst tropfte es bei Sonnenschein.
func test_dry_weather_draws_nothing() -> void:
	var v := _sicht()
	v.regnet = false
	for schritt in 50:
		v.setze(v._punkte, BREITE, UNTEN, float(schritt) * 0.05)
		assert_true(v.ring_rechtecke(v._laeufe()).is_empty(),
			"Ringe bei trockenem Wetter")

## Sie liegen ueber die ganze Flaeche verteilt -- die Striche des Regens enden
## alle an der fernen Kante, eine Reihe Ringe dort waere kein Regen auf einen
## See, sondern ein Zaun am Horizont.
func test_rings_cover_the_whole_surface() -> void:
	var v := _sicht()
	v.regnet = true
	var spalten := {}
	var zeilen := {}
	for schritt in 300:
		var zeit := float(schritt) * 0.02
		for i in WaterView.RINGE:
			var z := WaterView.ring_zustand(i, zeit)
			spalten[int(float(z[0]) * 8.0)] = true
			zeilen[int(float(z[1]) / WaterView.RING_FELD * 4.0)] = true
	assert_eq(spalten.size(), 8, "es tropft nicht ueber die ganze Breite")
	assert_eq(zeilen.size(), 4, "es tropft nicht ueber die ganze Tiefe")

## Hinten dichter als vorn: in dieser Ansicht draengt sich die halbe
## Wasserflaeche in den obersten Zeilen, gleichmaessig verteilt saehe das
## vorn nach Regen und hinten nach ruhigem Wasser aus.
func test_more_rings_land_far_away_than_close_by() -> void:
	var fern := 0
	var nah := 0
	for schritt in 400:
		for i in WaterView.RINGE:
			var tiefe: float = WaterView.ring_zustand(i, float(schritt) * 0.02)[1]
			if tiefe < WaterView.RING_FELD * 0.5:
				fern += 1
			else:
				nah += 1
	assert_true(fern > nah * 2,
		"%d hinten zu %d vorn -- die Tiefe ist zu gleichmaessig" % [fern, nah])

## Jeder Durchgang setzt den Ring woanders hin. Sonst tropfte es ewig auf
## dieselben zwanzig Stellen, und das faellt auf, lange bevor man es benennt.
func test_a_ring_does_not_reappear_in_the_same_spot() -> void:
	for i in WaterView.RINGE:
		var stellen := {}
		for zyklus in 40:
			var zeit := (float(zyklus) + 0.5 - float(i) * 0.6180339887) \
				* WaterView.RING_LEBEN
			var z := WaterView.ring_zustand(i, zeit)
			stellen[Vector2i(int(float(z[0]) * 40.0), int(float(z[1]) * 40.0))] = true
		assert_true(stellen.size() >= 35,
			"Ring %d nutzt in 40 Durchgaengen nur %d Stellen" % [i, stellen.size()])

## Er waechst schnell und wird langsamer, so laeuft eine Welle auf dem Wasser
## aus -- und er waechst wirklich, statt gleich gross aufzutauchen.
func test_a_ring_grows_quickly_and_then_slows_down() -> void:
	var vorher := -1
	var erste := 0
	var letzte := 0
	for schritt in 21:
		var alter := float(schritt) / 20.0
		var r := WaterView.ring_radius(WaterView.RING_FELD, alter)
		assert_true(r >= vorher, "der Ring schrumpft bei alter=%f" % alter)
		if schritt <= 10:
			erste = r
		else:
			letzte = r - erste
		vorher = r
	assert_eq(vorher, WaterView.RING_NAH, "er erreicht seinen Endradius nicht")
	assert_true(erste > letzte,
		"erste Haelfte %d, zweite %d -- er waechst nicht aus" % [erste, letzte])

## Vorn groessere Ringe als hinten. Das ist die einzige Perspektive, die diese
## Ansicht hat.
func test_close_rings_are_bigger_than_distant_ones() -> void:
	for alter in [0.3, 0.6, 1.0]:
		var nah := WaterView.ring_radius(WaterView.RING_FELD, alter)
		var fern := WaterView.ring_radius(0.0, alter)
		assert_true(nah > fern,
			"bei alter=%f sind nah %d und fern %d" % [alter, nah, fern])

## Und er klingt aus, statt zu verschwinden.
func test_a_ring_fades_out_before_it_ends() -> void:
	var vorher := 99.0
	for schritt in 21:
		var d := WaterView.ring_deckung(float(schritt) / 20.0)
		assert_true(d <= vorher + 0.0001, "die Deckung steigt wieder")
		vorher = d
	assert_almost_eq(WaterView.ring_deckung(1.0), 0.0, 0.0001,
		"am Ende ist der Ring noch sichtbar")
	assert_almost_eq(WaterView.ring_deckung(0.0), WaterView.RING_DECKUNG, 0.0001)

## Der Umriss ist geschlossen: keine Zeile ohne Pixel, und in jeder Zeile
## liegt links und rechts etwas. Riss er oben und unten auf, saehe man zwei
## Striche statt eines Rings.
func test_the_outline_is_closed_at_every_radius() -> void:
	for rx in range(0, WaterView.RING_NAH + 1):
		var ry := int(round(float(rx) * WaterView.RING_FLACH))
		var belegt := {}
		for lauf in WaterView.ring_form(rx, ry):
			for k in int(lauf[2]):
				belegt[Vector2i(int(lauf[0]) + k, int(lauf[1]))] = true
		for dy in range(-ry, ry + 1):
			var links := 9999
			var rechts := -9999
			for pixel in belegt:
				if pixel.y == dy:
					links = mini(links, pixel.x)
					rechts = maxi(rechts, pixel.x)
			assert_true(rechts >= links, "rx=%d: Zeile %d ist leer" % [rx, dy])
			if rx >= 2:
				assert_true(links < 0 and rechts > 0,
					"rx=%d: Zeile %d liegt nur auf einer Seite" % [rx, dy])
		assert_true(belegt.has(Vector2i(rx, 0)) or belegt.has(Vector2i(rx - 1, 0)),
			"rx=%d wird nicht so breit, wie er soll" % rx)

## Ein Ring, keine Scheibe: die Mitte bleibt leer, sobald er Platz dafuer hat.
func test_the_ring_is_hollow() -> void:
	for rx in range(3, WaterView.RING_NAH + 1):
		var ry := int(round(float(rx) * WaterView.RING_FLACH))
		for lauf in WaterView.ring_form(rx, ry):
			if int(lauf[1]) != 0:
				continue
			var von := int(lauf[0])
			assert_false(von <= 0 and von + int(lauf[2]) > 0,
				"rx=%d ist in der Mitte gefuellt" % rx)

## Flacher als breit: wir schauen flach auf das Wasser, ein runder Ring saehe
## aus wie eine Blase darin.
func test_the_ring_is_flatter_than_it_is_wide() -> void:
	for rx in range(2, WaterView.RING_NAH + 1):
		var ry := int(round(float(rx) * WaterView.RING_FLACH))
		assert_true(ry >= 1 and ry * 2 <= rx,
			"rx=%d hat ry=%d -- das ist keine Aufsicht" % [rx, ry])

## Und er bleibt billig. Die Flaeche zeichnet schon Laeufe und Glitzerstriche;
## die Ringe duerfen nicht die Zahl der Rechtecke je Bild vervielfachen.
func test_the_rings_stay_cheap_to_draw() -> void:
	var v := _sicht()
	v.regnet = true
	var hoechste := 0
	for schritt in 200:
		v.setze(v._punkte, BREITE, UNTEN, float(schritt) * 0.03)
		hoechste = maxi(hoechste, v.ring_rechtecke(v._laeufe()).size())
	assert_true(hoechste <= WaterView.RINGE * 8,
		"%d Rechtecke fuer %d Ringe" % [hoechste, WaterView.RINGE])

## Die Formen liegen in einer Tabelle, damit sie nicht jedes Bild neu
## gerechnet werden. Ihr Schluessel muss jeden Radius auseinanderhalten --
## bei einer Kollision bekaeme ein Ring die Form eines anderen.
func test_every_radius_gets_its_own_shape() -> void:
	var gesehen := {}
	for rx in range(0, WaterView.RING_NAH + 1):
		var ry := int(round(float(rx) * WaterView.RING_FLACH))
		var bild := ""
		for lauf in WaterView.ring_form(rx, ry):
			bild += "%d/%d/%d " % [lauf[0], lauf[1], lauf[2]]
		assert_false(gesehen.has(bild),
			"rx=%d hat dieselbe Form wie rx=%s" % [rx, gesehen.get(bild)])
		gesehen[bild] = rx

## Regen und Ringe kommen aus derselben Quelle. Zwei getrennte Abfragen waeren
## zwei Wetter, und eines davon bliebe irgendwann haengen.
func test_the_world_switches_the_rings_with_the_rain() -> void:
	Game.new_game()
	var tree := Engine.get_main_loop() as SceneTree
	var world: Control = load("res://scenes/fishing/world.tscn").instantiate()
	tree.root.add_child(world)
	var wasser: WaterView = world.get_node("Water")
	Game.ctx.raining = false
	world._process(0.016)
	assert_false(wasser.regnet, "Ringe bei trockenem Wetter")
	Game.ctx.raining = true
	world._process(0.016)
	assert_true(wasser.regnet, "kein Ring im Regen")
	world.free()

## Der Stein macht seine eigenen Ringe, und die duerfen die Regenringe nicht
## verdraengen -- es sind zwei Quellen fuer dieselbe Zeichnung.
func test_a_thrown_ring_appears_without_rain() -> void:
	var w: WaterView = load("res://scenes/fishing/water_view.gd").new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(w)
	w.setze(PackedVector2Array([Vector2(0.0, 0.0), Vector2(1280.0, 0.0)]),
		1280.0, 320.0, 0.0)
	w.regnet = false
	assert_eq(w.ring_rechtecke(w._laeufe()).size(), 0,
		"ohne Regen und ohne Wurf liegen Ringe auf dem Wasser")
	w.wirf_ring(0.5, 0.4)
	assert_true(w.ring_rechtecke(w._laeufe()).size() > 0,
		"der geworfene Ring erscheint nicht")
	w.free()

## Und ein alter Ring verschwindet wieder von selbst.
func test_a_thrown_ring_fades_away() -> void:
	var w: WaterView = load("res://scenes/fishing/water_view.gd").new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(w)
	w.setze(PackedVector2Array([Vector2(0.0, 0.0), Vector2(1280.0, 0.0)]),
		1280.0, 320.0, 0.0)
	w.regnet = false
	w.wirf_ring(0.5, 0.4)
	for i in 120:
		w._process(0.05)
	assert_eq(w.ring_rechtecke(w._laeufe()).size(), 0,
		"der geworfene Ring bleibt liegen")
	w.free()
