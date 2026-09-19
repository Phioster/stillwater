extends TestCase

## Steine flitschen. Geprueft wird die Rechnung, nicht das Bild: wie die
## Ladung schwingt, wo das goldene Band steht und was ein Wurf einbringt.

## Die Ladung schwingt dreieckig: gleichmaessig hoch, gleichmaessig runter.
## Ein Sinus haengt oben fest, und dann wird das Zielen zaeh.
func test_the_charge_rises_and_falls_evenly() -> void:
	assert_almost_eq(Stones.ladung(0.0), 0.0, 0.001, "faengt nicht unten an")
	assert_almost_eq(Stones.ladung(Stones.ZYKLUS * 0.5), 1.0, 0.001,
		"ist nach der halben Runde nicht oben")
	assert_almost_eq(Stones.ladung(Stones.ZYKLUS), 0.0, 0.001,
		"ist nach einer vollen Runde nicht wieder unten")
	# Gleichmaessig: ein Viertel hoch ist die Haelfte.
	assert_almost_eq(Stones.ladung(Stones.ZYKLUS * 0.25), 0.5, 0.001)
	assert_almost_eq(Stones.ladung(Stones.ZYKLUS * 0.75), 0.5, 0.001)

## Und sie bleibt oben nicht stehen -- wer zu spaet loslaesst, bekommt den
## naechsten Anlauf statt einer Strafe.
func test_the_charge_never_sticks_at_the_top() -> void:
	var oben := 0
	var schritte := 600
	for i in schritte:
		if Stones.ladung(float(i) * 0.01) > 0.98:
			oben += 1
	assert_true(oben < schritte / 8,
		"die Ladung steht in %d von %d Messungen oben" % [oben, schritte])

## Das Band wandert in seinem Bereich und kehrt an den Enden um.
func test_the_band_wanders_between_its_bounds() -> void:
	var tief := 2.0
	var hoch := -1.0
	for i in 400:
		var m := Stones.band_mitte(float(i) * 0.05)
		tief = minf(tief, m)
		hoch = maxf(hoch, m)
	assert_almost_eq(tief, Stones.BAND_UNTEN, 0.02, "kommt nicht tief genug")
	assert_almost_eq(hoch, Stones.BAND_OBEN, 0.02, "kommt nicht hoch genug")

## Und es wandert LANGSAMER als die Ladung schwingt -- sonst ist es Glueck
## statt Zielen. Gemessen wird, was die Funktionen ueber dasselbe Zeitfenster
## tun: zwei Konstanten zu vergleichen prueft keine davon.
func test_the_band_moves_slower_than_the_charge() -> void:
	var schritt := 0.01
	var band_kehren := 0
	var ladung_kehren := 0
	var band_vor := Stones.band_mitte(0.0)
	var ladung_vor := Stones.ladung(0.0)
	var band_steigt := Stones.band_mitte(schritt) > band_vor
	var ladung_steigt := Stones.ladung(schritt) > ladung_vor
	for i in range(1, 6001):
		var t := float(i) * schritt
		var b := Stones.band_mitte(t)
		var l := Stones.ladung(t)
		if b != band_vor:
			var steigt_b := b > band_vor
			if steigt_b != band_steigt:
				band_kehren += 1
			band_steigt = steigt_b
		if l != ladung_vor:
			var steigt_l := l > ladung_vor
			if steigt_l != ladung_steigt:
				ladung_kehren += 1
			ladung_steigt = steigt_l
		band_vor = b
		ladung_vor = l
	assert_true(band_kehren >= 2,
		"das Band kehrt in 60 s nur %d mal um" % band_kehren)
	assert_true(ladung_kehren > band_kehren * 3,
		"die Ladung kehrt %d mal um, das Band %d mal -- das Band ist nicht deutlich langsamer"
			% [ladung_kehren, band_kehren])

## Im Band heisst: die Ladung liegt hoechstens eine halbe Bandhoehe von
## seiner Mitte entfernt.
func test_the_band_catches_only_what_is_inside_it() -> void:
	var zeit := 3.0
	var m := Stones.band_mitte(zeit)
	assert_true(Stones.im_band(m, zeit), "die Mitte des Bandes zaehlt nicht")
	assert_true(Stones.im_band(m + Stones.BAND_HOEHE * 0.45, zeit),
		"der obere Rand zaehlt nicht")
	assert_false(Stones.im_band(m + Stones.BAND_HOEHE * 0.75, zeit),
		"knapp ausserhalb zaehlt trotzdem")

## Die Sprungtabelle aus der Spec, an jeder Grenze.
func test_the_skip_table_holds_at_every_edge() -> void:
	assert_eq(Stones.spruenge(0.0, false), 0, "ganz unten gibt es Spruenge")
	assert_eq(Stones.spruenge(Stones.PLUMPS - 0.01, false), 0,
		"knapp unter der Grenze gibt es Spruenge")
	assert_eq(Stones.spruenge(Stones.PLUMPS, false), 1,
		"an der Grenze gibt es keinen Sprung")
	assert_eq(Stones.spruenge(1.0, false), Stones.GRUND_MAX,
		"voll aufgeladen gibt nicht das Maximum")
	assert_eq(Stones.spruenge(1.0, true), Stones.GRUND_MAX + Stones.BAND_BONUS,
		"das Band gibt seinen Zuschlag nicht")

## Ein Plumps bleibt ein Plumps, auch im Band -- sonst waere die schwaechste
## Ladung die beste, wenn das Band gerade unten steht.
func test_a_dud_stays_a_dud_even_inside_the_band() -> void:
	assert_eq(Stones.spruenge(0.0, true), 0)

## Mehr Ladung gibt nie weniger Spruenge.
func test_more_charge_is_never_worse() -> void:
	var vorher := -1
	for i in 101:
		var s := Stones.spruenge(float(i) / 100.0, false)
		assert_true(s >= vorher, "bei Ladung %f faellt die Zahl" % (float(i) / 100.0))
		vorher = s

## Beim besten moeglichen Wurf -- volle Ladung PLUS Bandtreffer -- darf kein
## Aufsetzer auf einem anderen liegen. Mit festen Schrittweiten fielen die
## letzten beiden am rechten Bildrand zusammen: der beste Wurf sah damit
## schlechter aus als der zweitbeste.
func test_no_skip_lands_on_another_at_the_highest_count() -> void:
	var hoechste := Stones.GRUND_MAX + Stones.BAND_BONUS
	var start := 0.62
	var vorher := Stones.aufsetzer_ort(start, 0)
	assert_almost_eq(vorher.y, Stones.TIEFE_VON, 0.0001,
		"der erste Aufsetzer liegt nicht an der vorderen Kante")
	for nummer in range(1, hoechste):
		var ort := Stones.aufsetzer_ort(start, nummer)
		assert_true(ort.x > vorher.x,
			"Aufsetzer %d liegt bei x=%f, der davor schon bei %f"
				% [nummer, ort.x, vorher.x])
		assert_true(ort.y > vorher.y,
			"Aufsetzer %d liegt bei Tiefe %f, der davor schon bei %f"
				% [nummer, ort.y, vorher.y])
		vorher = ort
	assert_almost_eq(vorher.y, Stones.TIEFE_BIS, 0.0001,
		"der letzte Aufsetzer erreicht die hinterste Tiefe nicht")

## Und keiner faellt in den Streifen, den clip_contents am rechten Rand
## abschneidet -- dort waere sein Ring nur halb zu sehen.
func test_no_skip_reaches_the_clipped_edge() -> void:
	for start in [0.0, 0.3, 0.62, 0.9]:
		for nummer in Stones.GRUND_MAX + Stones.BAND_BONUS:
			var ort := Stones.aufsetzer_ort(float(start), nummer)
			assert_true(ort.x <= 1.0 - Stones.RAND + 0.0001,
				"Start %f, Aufsetzer %d liegt bei x=%f" % [start, nummer, ort.x])
			assert_true(ort.y >= Stones.TIEFE_VON - 0.0001
				and ort.y <= Stones.TIEFE_BIS + 0.0001,
				"Start %f, Aufsetzer %d liegt bei Tiefe %f"
					% [start, nummer, ort.y])

## Der Abstand zwischen zwei Aufsetzern haengt nicht davon ab, wie viele
## Spruenge der Wurf hat -- die Orte kennen die Sprungzahl gar nicht.
func test_the_spacing_does_not_depend_on_the_number_of_skips() -> void:
	var a := Stones.aufsetzer_ort(0.62, 0)
	var b := Stones.aufsetzer_ort(0.62, 1)
	var c := Stones.aufsetzer_ort(0.62, 2)
	assert_almost_eq(b.x - a.x, c.x - b.x, 0.0001, "der Schritt ist ungleich")
	assert_almost_eq(b.y - a.y, c.y - b.y, 0.0001, "die Tiefe springt ungleich")

## Der gezeichnete Balken ist die Form, mit der gerechnet wird. Bei der
## Klinge hat genau das vier Anlaeufe gekostet, weil die Form zweimal
## gerechnet wurde -- hier gibt es sie von Anfang an nur einmal.
func test_the_bar_is_its_own_shape() -> void:
	var g := Stones.balken_groesse()
	assert_true(g.x > 8 and g.y > 8, "der Balken ist leer")
	var gemalt := 0
	for y in g.y:
		for x in g.x:
			if Stones.maske().get_bit(x, y):
				gemalt += 1
	assert_true(gemalt > 200, "der Balken hat fast keine Flaeche")

## Oben ist er breit, unten laeuft er spitz aus -- das ist die Form aus der
## Vorlage, und daran haengt, dass sich das Fuellen von unten gut liest.
func test_the_bar_is_wide_on_top_and_pointed_below() -> void:
	var g := Stones.balken_groesse()
	var oben := 0
	var unten := 0
	for x in g.x:
		if Stones.maske().get_bit(x, 0):
			oben += 1
		if Stones.maske().get_bit(x, g.y - 1):
			unten += 1
	assert_true(oben > unten,
		"oben %d Punkte breit, unten %d -- die Spitze sitzt falsch"
			% [oben, unten])

## Gefuellt wird von UNTEN nach oben: Zeile 0 ist oben im Bild.
func test_the_bar_fills_from_the_bottom() -> void:
	var g := Stones.balken_groesse()
	assert_true(Stones.gefuellt(g.y - 1, 0.5), "unten ist bei halb leer")
	assert_false(Stones.gefuellt(0, 0.5), "oben ist bei halb schon voll")
	assert_true(Stones.gefuellt(0, 1.0), "voll ist oben nicht gefuellt")
	assert_false(Stones.gefuellt(g.y - 1, 0.0), "leer ist unten gefuellt")

## Der Balken laeuft erst, wenn man ihn startet, und ein zweiter Tipp wirft.
func test_the_bar_runs_only_after_it_is_started() -> void:
	var wurf := StoneThrow.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(wurf)
	await tree.process_frame
	assert_false(wurf._laeuft, "der Balken laeuft ungefragt")
	wurf.starte(Vector2(200.0, 200.0), 0.3)
	assert_true(wurf._laeuft, "der Balken laeuft nach dem Start nicht")
	wurf._process(0.1)
	assert_true(wurf._zeit > 0.0, "die Zeit steht still")
	wurf.free()

## Ein Wurf aendert nichts am Spielstand -- das ist die wichtigste
## Zusicherung des ganzen Zeitvertreibs.
##
## Achtung, dieser Test kann weniger, als er aussieht: er bliebe auch gruen,
## wenn es den ganzen Produktionscode nicht gaebe. Die eigentliche Zusicherung
## ist strukturell -- ausser Game.melde_wurf darf in stones.gd, pebble_pile.gd
## und stone_throw.gd kein Schreibzugriff auf Game stehen, und das sieht man
## nur beim Lesen dieser drei Dateien.
func test_a_throw_changes_nothing_in_the_save() -> void:
	Game.new_game()
	var muenzen := Game.coins
	var koeder := Game.bait_used()
	var stufe: int = Game.ctx.player_level
	var fische: int = Game.ctx.inventory.fish.size()
	var wurf := StoneThrow.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(wurf)
	await tree.process_frame
	wurf.starte(Vector2(200.0, 200.0), 0.3)
	for i in 30:
		wurf._process(0.05)
	wurf.wirf()
	assert_eq(Game.coins, muenzen, "ein Wurf kostet oder bringt Muenzen")
	assert_eq(Game.bait_used(), koeder, "ein Wurf aendert die Koeder")
	assert_eq(Game.ctx.player_level, stufe, "ein Wurf gibt Erfahrung")
	assert_eq(Game.ctx.inventory.fish.size(), fische,
		"ein Wurf aendert das Inventar")
	wurf.free()

## Und beim Anbiss verschwindet der Balken, ohne zu werfen.
func test_a_bite_closes_the_bar_without_throwing() -> void:
	Game.new_game()
	var wurf := StoneThrow.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(wurf)
	await tree.process_frame
	wurf.starte(Vector2(200.0, 200.0), 0.3)
	Game.sim.state = FishingSim.State.FIGHT
	wurf._process(0.05)
	assert_false(wurf._laeuft, "der Balken laeuft im Kampf weiter")
	assert_false(wurf.visible, "der Balken bleibt im Kampf sichtbar")
	wurf.free()

## Der beste Wurf wird still mitgezaehlt -- und nur er.
func test_the_best_throw_is_remembered() -> void:
	Game.new_game()
	assert_eq(Game.records.best_skips, 0, "ein neues Spiel kennt schon Wuerfe")
	Game.melde_wurf(5)
	assert_eq(Game.records.best_skips, 5)
	Game.melde_wurf(3)
	assert_eq(Game.records.best_skips, 5, "ein schlechterer Wurf zaehlt mit")
	Game.melde_wurf(8)
	assert_eq(Game.records.best_skips, 8, "ein besserer Wurf zaehlt nicht")

## Eine Weltszene im Baum -- Wasserflaeche, Effekte und die Verdrahtung des
## Wurfs stecken darin, einzeln waeren sie nicht dieselbe Sache.
func _welt() -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	var welt: Control = load("res://scenes/fishing/world.tscn").instantiate()
	tree.root.add_child(welt)
	welt._process(0.016)
	return welt

## Waehrend des Fluges sieht man den Stein. Ohne ihn erscheinen nur Ringe aus
## dem Nichts, und der Bandbonus liegt auf einer Zahl, die sich mit nichts
## vergleichen laesst.
func test_the_flying_stone_is_drawn_on_the_water() -> void:
	var w: WaterView = load("res://scenes/fishing/water_view.gd").new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(w)
	var punkte := PackedVector2Array([Vector2(0.0, 400.0),
		Vector2(1280.0, 400.0)])
	w.setze(punkte, 1280.0, 720.0, 0.0)
	assert_eq(w.stein_rechteck(w._laeufe()).size.x, 0.0,
		"ohne Wurf liegt ein Stein auf dem Wasser")
	w.zeige_stein(0.7, Stones.TIEFE_VON, 0.0, false)
	var auf := w.stein_rechteck(w._laeufe())
	assert_true(auf.size.x > 0.0, "der fliegende Stein wird nicht gezeichnet")
	w.zeige_stein(0.7, Stones.TIEFE_VON, StoneThrow.BOGEN_HOCH, false)
	var oben := w.stein_rechteck(w._laeufe())
	assert_true(oben.position.y < auf.position.y,
		"der Bogen hebt den Stein nicht vom Wasser ab")
	# Wie die Ringe geklemmt: nie halb unter dem Bildrand.
	w.zeige_stein(0.7, WaterView.RING_FELD, 0.0, false)
	var vorn := w.stein_rechteck(w._laeufe())
	assert_true(vorn.position.y + vorn.size.y <= 720.0 + 0.001,
		"der Stein haengt bei %f unter dem Bildrand" % vorn.position.y)
	# Und nie darueber: ein uebertriebener Bogen wird geklemmt, statt den Stein
	# in den Himmel zu heben. Heute reicht die Marge, aber nur zufaellig.
	w.zeige_stein(0.7, Stones.TIEFE_VON, 400.0, false)
	var luft := w.stein_rechteck(w._laeufe())
	# Gemessen wird seine Unterkante: der Stein SITZT auf dem Wasser, sein
	# Koerper steht darueber.
	assert_true(luft.position.y + luft.size.y >= 400.0,
		"der Stein sitzt bei %f ueber der Wellenlinie" % luft.position.y)
	w.stein_weg()
	assert_eq(w.stein_rechteck(w._laeufe()).size.x, 0.0,
		"der Stein bleibt nach dem Versinken liegen")
	w.free()

## Der Wurf meldet den Flug Bild fuer Bild -- und nach einem Bandtreffer blitzt
## der Stein kurz auf. Ohne diese Rueckmeldung fuehlt sich das goldene Band wie
## Zufall an.
func test_the_throw_reports_its_flight_and_its_hit() -> void:
	Game.new_game()
	var wurf := StoneThrow.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(wurf)
	var gemeldet: Array = []
	wurf.flug.connect(func(x, tiefe, hoehe, blitzt, _deckung):
		gemeldet.append([x, tiefe, hoehe, blitzt]))
	var endete := [false]
	wurf.flug_endet.connect(func(): endete[0] = true)
	wurf.starte(Vector2(200.0, 200.0), 0.3)
	# Die Ladung auf die Mitte des Bandes legen, statt sie zu treffen: geprueft
	# wird die Rueckmeldung, nicht das Zielen.
	wurf._zeit = 2.0
	wurf._wert = Stones.band_mitte(2.0)
	wurf.wirf()
	# Bis der Flug wirklich vorbei ist, statt eine feste Bildzahl zu raten --
	# sonst haengt der Test an SPRUNG_ABSTAND und SINKEN.
	for i in 500:
		wurf._process(0.01)
		if endete[0]:
			break
	assert_true(gemeldet.size() > 20,
		"der Flug wurde nur %d mal gemeldet" % gemeldet.size())
	assert_true(bool(gemeldet[0][3]), "der Stein blitzt nach dem Treffer nicht")
	assert_false(bool(gemeldet[gemeldet.size() - 1][3]),
		"der Stein blitzt bis zum Schluss")
	var hoechste := 0.0
	for m in gemeldet:
		hoechste = maxf(hoechste, float(m[2]))
	assert_true(hoechste > 0.0, "der Stein fliegt ohne Bogen")
	assert_true(endete[0], "das Ende des Fluges wird nicht gemeldet")
	wurf.free()

## Beim letzten Aufsetzer verschwindet der Stein nicht, er geht unter -- und
## erst danach steigt die Zahl auf, damit sie dort steht, wo er blieb.
func test_the_last_skip_sinks_the_stone_before_the_number_rises() -> void:
	Game.new_game()
	var wurf := StoneThrow.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(wurf)
	var tiefste := [0.0]
	var deckung := [1.0]
	wurf.flug.connect(func(_x, _t, hoehe, _b, d):
		tiefste[0] = minf(tiefste[0], hoehe)
		deckung[0] = d)
	var zahl_kam := [false]
	wurf.geworfen.connect(func(_s, _x, _t): zahl_kam[0] = true)
	wurf.starte(Vector2(200.0, 200.0), 0.3)
	wurf._zeit = 2.0
	wurf._wert = 1.0
	wurf.wirf()
	for i in 300:
		wurf._process(0.01)
		if wurf._sinkt:
			break
	assert_true(wurf._sinkt, "der Stein sinkt nach dem letzten Aufsetzer nicht")
	assert_false(zahl_kam[0], "die Zahl kommt, bevor der Stein unten ist")
	for i in 100:
		wurf._process(0.01)
	assert_true(tiefste[0] < 0.0, "der Stein sinkt nicht unter die Oberflaeche")
	assert_true(deckung[0] <= 0.0, "der Stein bleibt beim Sinken sichtbar")
	assert_true(zahl_kam[0], "nach dem Sinken kam keine Zahl")
	wurf.free()

## Und ohne Bandtreffer blitzt gar nichts -- sonst waere die Rueckmeldung keine.
func test_a_miss_never_makes_the_stone_flash() -> void:
	Game.new_game()
	var wurf := StoneThrow.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(wurf)
	var blitze := [0]
	wurf.flug.connect(func(_x, _t, _h, blitzt, _d):
		if blitzt:
			blitze[0] += 1)
	wurf.starte(Vector2(200.0, 200.0), 0.3)
	# Volle Ladung, das Band steht bei dieser Zeit tief -- also kein Treffer.
	wurf._zeit = 2.0
	wurf._wert = 1.0
	assert_false(Stones.im_band(1.0, 2.0), "die volle Ladung liegt im Band")
	wurf.wirf()
	for i in 100:
		wurf._process(0.01)
	assert_eq(blitze[0], 0, "der Stein blitzt ohne Treffer im Band")
	wurf.free()

## Derselbe Tipp darf den Balken nicht oeffnen und sofort wieder leer werfen.
## Godot schickt zu jeder Beruehrung noch einen Mausklick hinterher, und der
## kam frueher im selben Bild an -- am Geraet gab es dadurch nur "plumps".
func test_the_tap_that_opens_the_bar_cannot_throw_it() -> void:
	Game.new_game()
	var wurf := StoneThrow.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(wurf)
	await tree.process_frame
	wurf.starte(Vector2(200.0, 200.0), 0.3)
	var klick := InputEventMouseButton.new()
	klick.button_index = MOUSE_BUTTON_LEFT
	klick.pressed = true
	wurf._gui_input(klick)
	assert_true(wurf._laeuft,
		"der Tipp, der den Balken oeffnet, wirft ihn sofort wieder")
	# Nach der Sperre nimmt derselbe Klick den Wurf an.
	wurf._process(StoneThrow.SCHARF_AB + 0.01)
	wurf._gui_input(klick)
	assert_false(wurf._laeuft, "nach der Sperre wirft der Balken nicht mehr")
	wurf.free()

## Ein zweiter Tipp waehrend des Fluges darf ihn nicht abbrechen: sonst
## verschwinden die offenen Aufsetzer, und es kommt weder Ring noch Zahl.
func test_a_second_tap_does_not_cut_the_flight_short() -> void:
	Game.new_game()
	var wurf := StoneThrow.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(wurf)
	var aufsetzer := [0]
	wurf.aufsetzer.connect(func(_x, _t): aufsetzer[0] += 1)
	var zahlen := [-1]
	wurf.geworfen.connect(func(spruenge, _x, _t): zahlen[0] = spruenge)
	wurf.starte(Vector2(200.0, 200.0), 0.3)
	wurf._zeit = 2.0
	wurf._wert = 1.0
	wurf.wirf()
	var erwartet := Stones.spruenge(1.0, false)
	wurf._process(0.2)
	# Der Kieselhaufen ist waehrend des Fluges wieder ansprechbar.
	wurf.starte(Vector2(200.0, 200.0), 0.3)
	assert_false(wurf._laeuft, "der Balken startet mitten im Flug neu")
	for i in 500:
		wurf._process(0.01)
		if zahlen[0] >= 0:
			break
	assert_eq(aufsetzer[0], erwartet,
		"es kamen %d statt %d Aufsetzer" % [aufsetzer[0], erwartet])
	assert_eq(zahlen[0], erwartet, "die Sprungzahl kam nicht")
	wurf.free()

## Die Sprungzahl steigt dort auf, wo der Stein VERSUNKEN ist. Gemessen stand
## sie einmal 550 Punkte links und 200 ueber dem letzten Aufsetzer, oben im
## Himmel ueber dem Kieselhaufen.
func test_the_number_rises_where_the_stone_sank() -> void:
	Game.new_game()
	var welt := _welt()
	var wasser: WaterView = welt.get_node("Water")
	var ort := wasser.ring_mitte(0.9, Stones.TIEFE_BIS)
	assert_true(ort != Vector2.INF,
		"an der Aufsetzstelle liegt gar kein Wasser im Bild")
	var stelle: Vector2 = welt._wurf_zahl_stelle(0.9, Stones.TIEFE_BIS)
	assert_almost_eq(stelle.x, ort.x, 1.0,
		"die Zahl steht seitlich neben der Aufsetzstelle")
	assert_true(stelle.y < ort.y, "die Zahl steht nicht ueber dem Wasser")
	assert_true(ort.y - stelle.y < 80.0,
		"die Zahl steht %f Punkte ueber der Aufsetzstelle" % (ort.y - stelle.y))
	assert_true(stelle.y > welt._balken_stelle().y,
		"die Zahl steht immer noch oben am Balken")
	welt.free()

## Beisst ein Fisch, waehrend der Stein noch fliegt, laege die Zahl mitten im
## Streufeld der Orbs. Dann keine Zahl -- der Bestwert zaehlt trotzdem.
func test_no_number_appears_while_a_fish_is_on_the_hook() -> void:
	Game.new_game()
	var welt := _welt()
	var effekte: Control = welt.get_node("Effects")
	Game.sim.state = FishingSim.State.FIGHT
	welt._on_stone_thrown(5, 0.9, Stones.TIEFE_BIS)
	assert_eq(effekte.get_child_count(), 0,
		"die Zahl liegt im Kampf mitten im Orb-Feld")
	assert_eq(Game.records.best_skips, 5,
		"der Bestwert zaehlt im Kampf nicht mit")
	welt.free()

## Und ohne Kampf erscheint sie -- ueber die oeffentliche Methode von
## effects.gd, und sie raeumt sich nach ihrer Lebenszeit selbst aus dem Baum.
func test_the_number_appears_and_removes_itself_again() -> void:
	Game.new_game()
	var welt := _welt()
	var effekte: Control = welt.get_node("Effects")
	Game.sim.state = FishingSim.State.WAITING
	welt._on_stone_thrown(6, 0.9, Stones.TIEFE_BIS)
	assert_eq(effekte.get_child_count(), 1, "die Sprungzahl erscheint nicht")
	for kind in effekte.get_children():
		kind._process(5.0)
	for kind in effekte.get_children():
		assert_true(kind.is_queued_for_deletion(),
			"nach ihrer Lebenszeit haengt die Zahl noch im Baum")
	welt.free()

## Der Bestwert wird nicht nur gespeichert, sondern auch gemeldet -- sonst
## stuende in der Rekordansicht bis zum naechsten Fang die alte Zahl.
func test_a_new_best_throw_announces_itself() -> void:
	Game.new_game()
	var gemeldet := [0]
	var horcher := func(): gemeldet[0] += 1
	Game.state_changed.connect(horcher)
	Game.melde_wurf(4)
	assert_eq(gemeldet[0], 1, "ein neuer Bestwert meldet keine Aenderung")
	Game.melde_wurf(2)
	assert_eq(gemeldet[0], 1, "ein schlechterer Wurf meldet eine Aenderung")
	Game.state_changed.disconnect(horcher)
