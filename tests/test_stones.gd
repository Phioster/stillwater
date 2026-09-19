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
## statt Zielen.
func test_the_band_moves_slower_than_the_charge() -> void:
	assert_true(Stones.BAND_WEG * 2.0 > Stones.ZYKLUS * 2.0,
		"das Band ist nicht deutlich langsamer als die Ladung")

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
	wurf.starte(Vector2(200.0, 200.0))
	assert_true(wurf._laeuft, "der Balken laeuft nach dem Start nicht")
	wurf._process(0.1)
	assert_true(wurf._zeit > 0.0, "die Zeit steht still")
	wurf.free()

## Ein Wurf aendert nichts am Spielstand -- das ist die wichtigste
## Zusicherung des ganzen Zeitvertreibs.
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
	wurf.starte(Vector2(200.0, 200.0))
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
	wurf.starte(Vector2(200.0, 200.0))
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
