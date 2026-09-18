extends TestCase

## Das Schilfschneiden. Geprueft wird die Rechnung dahinter, nicht das Bild:
## wann Schilf reif ist, was ein Schnitt einbringt und ob die Sichel mit den
## Zonen mithaelt.

const STUNDE := 3600.0
## world.gd hat keinen class_name -- die Masse kommen ueber das Skript selbst.
const WORLD := preload("res://scenes/fishing/world.gd")

## Der Kern: Schilf haengt an der Uhr, nicht an einem Countdown. Wer einen Tag
## wegbleibt, findet EIN Schilf vor -- nicht zwoelf.
func test_a_long_absence_leaves_one_patch_not_twelve() -> void:
	var r := Reeds.new()
	var jetzt := 1000000.0
	assert_true(r.ready_at(jetzt), "am Anfang steht kein Schilf")
	r.cut(jetzt)
	assert_false(r.ready_at(jetzt), "frisch geschnitten und trotzdem reif")
	# Einen ganzen Tag weg.
	var spaeter := jetzt + 24.0 * STUNDE
	assert_true(r.ready_at(spaeter), "nach einem Tag ist nichts nachgewachsen")
	r.cut(spaeter)
	assert_false(r.ready_at(spaeter),
		"ein Tag Abwesenheit gibt mehr als einen Schnitt")

## Innerhalb derselben Zeitspanne waechst nichts nach -- sonst waere Zusehen
## eine Strategie.
func test_nothing_regrows_inside_the_same_window() -> void:
	var r := Reeds.new()
	var jetzt := 1000000.0
	r.cut(jetzt)
	for schritt in 20:
		var t := jetzt + float(schritt) * Reeds.INTERVAL / 24.0
		if Reeds.slot(t) != Reeds.slot(jetzt):
			continue
		assert_false(r.ready_at(t), "innerhalb der Zeitspanne nachgewachsen")

## Eine Sichel, der nichts entgegensteht, nimmt dem Schneiden den Sinn.
func test_a_stalk_always_takes_at_least_one_hit() -> void:
	for zaeh in range(1, 60):
		for schaerfe in [0.0, 0.5, 1.0, 12.0, 999.0]:
			assert_true(Reeds.treffer_noetig(zaeh, schaerfe) >= 1,
				"Zaehigkeit %d gegen Schaerfe %f braucht null Treffer"
					% [zaeh, schaerfe])

## Die Grundwerte sind die vom Geraet: fuenf Treffer im ersten See, ohne
## jeden Ausbau. Wer das aendert, aendert den Spielanfang.
func test_the_first_lake_takes_five_hits_without_any_upgrade() -> void:
	var zone: ZoneData = Database.zones[&"willow_lake"]
	assert_eq(Reeds.treffer_noetig(zone.reed_toughness, Reeds.SCHNEIDE), 5)

## Und der Ausbau haelt mit: in der letzten Zone mit voll ausgebauter Sichel
## darf es nicht zaeher sein als am Anfang ohne. Sonst waere Fortschritt
## Rueckschritt.
func test_a_maxed_scythe_keeps_up_with_the_last_zone() -> void:
	var u: UpgradeData = Database.upgrades[&"scythe_edge"]
	var voll := u.value_at(u.max_level)
	var anfang: ZoneData = Database.zones[&"willow_lake"]
	var zuerst := Reeds.treffer_noetig(anfang.reed_toughness, Reeds.SCHNEIDE)
	for id in Database.zones:
		var z: ZoneData = Database.zones[id]
		var noetig := Reeds.treffer_noetig(z.reed_toughness, voll)
		assert_true(noetig <= zuerst,
			"%s braucht mit voller Sichel %d Treffer, der Anfang nur %d"
				% [id, noetig, zuerst])

## Das Schilf wird mit jeder Zone zaeher -- das ist die Fortschrittsachse,
## nicht eine Zahl, die irgendwo steht.
func test_reeds_get_tougher_the_later_the_zone() -> void:
	var paare: Array = []
	for id in Database.zones:
		var z: ZoneData = Database.zones[id]
		paare.append([z.unlock_level, z.reed_toughness, id])
	paare.sort_custom(func(a, b): return a[0] < b[0])
	for i in paare.size() - 1:
		assert_true(paare[i][1] < paare[i + 1][1],
			"%s (Stufe %d) ist nicht weicher als %s (Stufe %d)"
				% [paare[i][2], paare[i][0], paare[i + 1][2], paare[i + 1][0]])

## Jede Zone muss ihre Schilfkoeder auch wirklich haben -- ein Tippfehler
## waere sonst erst im Spiel als leerer Ertrag sichtbar.
func test_every_zone_has_reed_baits_that_exist() -> void:
	for id in Database.zones:
		var z: ZoneData = Database.zones[id]
		assert_false(z.reed_baits.is_empty(), "%s hat kein Schilf" % id)
		for b in z.reed_baits:
			assert_true(Database.baits.has(b),
				"%s verweist auf den unbekannten Koeder %s" % [id, b])

func test_stalks_turn_into_bait() -> void:
	assert_eq(Reeds.koeder_aus(0), 0)
	assert_eq(Reeds.koeder_aus(Reeds.HALME_JE_KOEDER - 1), 0)
	assert_eq(Reeds.koeder_aus(Reeds.HALME_JE_KOEDER), 1)
	assert_eq(Reeds.koeder_aus(Reeds.HALME_JE_KOEDER * 7), 7)

## Ein Fund bleibt ein Fund: die Chance waechst mit der Ernte, aber gedeckelt.
func test_a_find_stays_rare_however_much_is_cut() -> void:
	var vorher := -1.0
	for halme in range(0, 600, 7):
		var c := Reeds.fund_chance(halme)
		assert_true(c >= vorher, "die Chance faellt bei %d Halmen" % halme)
		assert_true(c <= Reeds.FUND_DECKEL + 0.0001,
			"bei %d Halmen liegt die Chance bei %f" % [halme, c])
		vorher = c
	assert_almost_eq(Reeds.fund_chance(0), Reeds.FUND_BASIS, 0.0001)

## Die Sichel muss vorbeikommen: was hinter ihr steht, wird nicht geschnitten,
## auch wenn es nah genug ist. Ein voller Kreis waere ein Rasenmaeher.
func test_the_blade_only_cuts_in_front_of_its_edge() -> void:
	var hand := Vector2(400.0, 300.0)
	var reichweite := 50.0
	var tiefe := 20.0
	# Im Ring und genau vor der Schneide.
	assert_true(Reeds.trifft(hand + Vector2(45.0, 0.0), hand, 0.0, reichweite,
		tiefe))
	# Genauso weit, aber hinter ihr.
	assert_false(Reeds.trifft(hand + Vector2(-45.0, 0.0), hand, 0.0,
		reichweite, tiefe), "die Sichel schneidet nach hinten")
	# Direkt vor ihr, aber weiter als sie reicht.
	assert_false(Reeds.trifft(hand + Vector2(70.0, 0.0), hand, 0.0, reichweite,
		tiefe), "die Sichel greift weiter, als sie reicht")
	# Am Rand des Ausschnitts, drinnen und knapp draussen.
	var knapp_drin := Reeds.SEKTOR * 0.5 - 0.02
	var knapp_raus := Reeds.SEKTOR * 0.5 + 0.02
	assert_true(Reeds.trifft(hand + Vector2(45.0, 0.0).rotated(knapp_drin),
		hand, 0.0, reichweite, tiefe))
	assert_false(Reeds.trifft(hand + Vector2(45.0, 0.0).rotated(knapp_raus),
		hand, 0.0, reichweite, tiefe))

## Und sie schneidet NUR DA, WO SIE IST. Zwischen Hand und Klinge passiert
## nichts mehr -- vorher galt der ganze Keil bis zur Hand, und alles darin
## wurde von nichts Sichtbarem geschnitten.
func test_nothing_is_cut_between_the_hand_and_the_blade() -> void:
	var hand := Vector2(400.0, 300.0)
	var reichweite := 50.0
	var tiefe := 20.0
	for weit in [0.0, 5.0, 15.0, 29.0]:
		assert_false(Reeds.trifft(hand + Vector2(weit, 0.0), hand, 0.0,
			reichweite, tiefe),
			"bei %f von der Hand wird geschnitten, die Klinge ist bei %f"
				% [weit, reichweite])
	# Und am inneren Rand des Rings faengt es an.
	assert_true(Reeds.trifft(hand + Vector2(31.0, 0.0), hand, 0.0, reichweite,
		tiefe), "am inneren Rand des Rings wird nicht geschnitten")

## Die Klinge dreht sich, also dreht sich auch, was sie trifft.
func test_the_cut_sector_turns_with_the_blade() -> void:
	var hand := Vector2(400.0, 300.0)
	var ziel := hand + Vector2(0.0, 45.0)
	assert_false(Reeds.trifft(ziel, hand, 0.0, 50.0, 20.0))
	assert_true(Reeds.trifft(ziel, hand, PI * 0.5, 50.0, 20.0),
		"gedreht trifft sie ihr Ziel nicht")

## Der Ring darf nicht tiefer sein als die Klinge dick ist -- sonst schnitte
## sie wieder, wo nichts gezeichnet ist.
func test_the_cut_ring_is_no_deeper_than_the_drawn_blade() -> void:
	var bild := TextureLoader.load_texture(
		"res://assets/art/sichel.png").get_image()
	var mitte := bild.get_height() / 2
	# Am Bauch, also waagerecht durch die Mitte nach rechts.
	var dick := 0
	for x in range(mitte, bild.get_width()):
		if bild.get_pixel(x, mitte).a > 0.0:
			dick += 1
	assert_true(dick > 2, "die Klinge ist am Bauch nur %d Pixel dick" % dick)
	assert_true(Reeds.KLINGE_PIXEL <= float(dick),
		"der Ring ist %.0f Pixel tief, die Klinge nur %d dick"
			% [Reeds.KLINGE_PIXEL, dick])

# --- Was ein Schnitt einbringt --------------------------------------------

func test_a_cut_gives_bait_and_uses_up_the_patch() -> void:
	Game.new_game()
	Game.upgrade_levels[&"bait_capacity"] = 9
	var vorher := Game.bait_used()
	assert_true(Game.reeds_ready(), "am Anfang steht kein Schilf")
	var e := Game.finish_reed_cut(Reeds.HALME_JE_KOEDER * 4)
	assert_eq(int(e["wanted"]), 4)
	assert_eq(int(e["got"]), 4, "die Koeder kamen nicht an")
	assert_eq(Game.bait_used(), vorher + 4)
	assert_false(Game.reeds_ready(), "das Schilf steht nach dem Schnitt noch")

## Schneiden ist kein Weg, die Koedertasche zu umgehen -- sonst waere ihr
## Ausbau umsonst.
func test_the_harvest_respects_the_bait_bag() -> void:
	Game.new_game()
	var platz := Game.bait_capacity() - Game.bait_used()
	var e := Game.finish_reed_cut(Reeds.HALME_JE_KOEDER * (platz + 12))
	assert_eq(int(e["got"]), platz,
		"es passten %d hinein, %d waren frei" % [int(e["got"]), platz])
	assert_true(int(e["wanted"]) > int(e["got"]), "die Tasche lief nicht ueber")
	assert_eq(Game.bait_used(), Game.bait_capacity())

## Eine magere Runde gibt nichts -- aber sie darf auch nichts kaputt machen.
func test_a_thin_cut_gives_nothing_and_breaks_nothing() -> void:
	Game.new_game()
	var vorher := Game.bait_used()
	var e := Game.finish_reed_cut(1)
	assert_eq(int(e["got"]), 0)
	assert_eq(Game.bait_used(), vorher)

## Der Schnitt ueberlebt einen Neustart: sonst waere Schliessen und Oeffnen
## der Weg zu beliebig viel Schilf.
func test_the_cut_survives_a_save_and_load() -> void:
	var r := Reeds.new()
	var jetzt := 1234567.0
	r.cut(jetzt)
	var zweite := Reeds.new()
	zweite.load_dict(r.to_dict())
	assert_false(zweite.ready_at(jetzt), "nach dem Laden steht es wieder da")
	# Ein Spielstand ohne das Feld ist ein alter -- dann steht Schilf.
	var alt := Reeds.new()
	alt.load_dict({})
	assert_true(alt.ready_at(jetzt))

## Die drei Sichel-Ausbauten muessen den Grundwerten entsprechen, mit denen
## das Spiel ohne sie rechnet. Zwei Quellen fuer dieselbe Zahl laufen sonst
## auseinander, und gemerkt haette man es erst am Geraet.
func test_the_upgrades_start_at_the_measured_base_values() -> void:
	Game.new_game()
	assert_almost_eq(Game.scythe_edge(), Reeds.SCHNEIDE, 0.0001)
	assert_almost_eq(Game.scythe_reach(), Reeds.REICHWEITE, 0.0001)
	assert_almost_eq(Game.scythe_speed(), Reeds.DREHUNG, 0.0001)

## Und sie muessen wirklich etwas tun.
func test_every_scythe_upgrade_actually_grows() -> void:
	for id in [&"scythe_edge", &"scythe_reach", &"scythe_speed"]:
		var u: UpgradeData = Database.upgrades[id]
		assert_true(u.value_at(1) > u.value_at(0), "%s waechst nicht" % id)
		assert_true(u.max_level > 0, "%s hat keine Stufen" % id)

## Das Uferband und der schneidbare Horst sind ZWEI Blaetter. Beim Bauen habe
## ich das eine mit dem anderen ueberschrieben -- und weil ich dem Sprite-Test
## danach die neue Groesse als richtig eintrug, blieb der dabei gruen.
func test_the_shore_band_and_the_cut_clump_stay_two_sheets() -> void:
	var band := TextureLoader.load_texture("res://assets/art/schilf.png")
	var horst := TextureLoader.load_texture("res://assets/art/schilf_horst.png")
	assert_true(band != null, "das Uferband fehlt")
	assert_true(horst != null, "der Horst fehlt")
	# Das Band muss das Mass behalten, mit dem world.gd rechnet -- sonst
	# kachelt die Uferlinie falsch.
	assert_eq(Vector2(band.get_width(), band.get_height()), WORLD.REED_SIZE,
		"das Uferband passt nicht mehr zu REED_SIZE in world.gd")
	assert_eq(horst.get_width(), Reeds.HALM_B * Reeds.WIND_BILDER,
		"das Blatt hat nicht eine Spalte je Windstellung")
	assert_eq(horst.get_height(), Reeds.HALM_H * Reeds.HALM_STUFEN,
		"das Blatt hat nicht eine Zeile je Schnittstufe")

## Und die drei Schnittstufen muessen sich unterscheiden, sonst sieht man vom
## Schneiden nichts. Sie stehen jetzt als ZEILEN im Blatt, nicht als Spalten --
## die Spalten sind die Windstellungen.
func test_the_three_cutting_stages_really_differ() -> void:
	var horst := TextureLoader.load_texture("res://assets/art/schilf_horst.png")
	var bild := horst.get_image()
	var gefuellt: Array[int] = []
	for stufe in Reeds.HALM_STUFEN:
		var zahl := 0
		for y in range(stufe * Reeds.HALM_H, (stufe + 1) * Reeds.HALM_H):
			for x in bild.get_width():
				if bild.get_pixel(x, y).a > 0.0:
					zahl += 1
		gefuellt.append(zahl)
	for i in gefuellt.size() - 1:
		assert_true(gefuellt[i] > gefuellt[i + 1],
			"Stufe %d hat %d Pixel, Stufe %d aber %d -- es wird nicht kuerzer"
				% [i, gefuellt[i], i + 1, gefuellt[i + 1]])

# --- Der Wind am Ufer -------------------------------------------------------
#
# Der Horst schaltet zwischen GEZEICHNETEN Stellungen um. Zwei Versuche davor
# haben das Bild stattdessen verschoben -- gedreht, dann zeilenweise geschert
# -- und beide sahen falsch aus, das zweite wie verrutschte Bildzeilen.

## Wie viele Pixel der SILHOUETTE sich zwischen zwei Stellungen aendern.
##
## Verglichen wird nur, ob ein Pixel gesetzt ist -- nicht seine Farbe. In der
## CI werden die Bilder importiert und dabei VRAM-komprimiert, auf diesem
## Geraet nicht (dort gibt es keinen Import-Cache). Ein Vergleich auf exakte
## Farbe zaehlte deshalb in der CI Unterschiede mit, die es gar nicht gibt --
## der Test war lokal gruen und dort rot.
##
## Gezaehlt wird nur die OBERSTE Zeile des Blattes: das ist der ungeschnittene
## Horst, und nur der wiegt sich am Ufer.
func _silhouetten_unterschied(bild: Image, a: int, b: int) -> int:
	var anders := 0
	for y in Reeds.HALM_H:
		for x in Reeds.HALM_B:
			var links := bild.get_pixel(a * Reeds.HALM_B + x, y).a > 0.0
			var rechts := bild.get_pixel(b * Reeds.HALM_B + x, y).a > 0.0
			if links != rechts:
				anders += 1
	return anders

## Das Bild darf sich nicht in Spruengen aendern. Mit sechs Stellungen
## wechselten je Schritt rund 390 von 770 Pixeln -- mehr als die halbe Pflanze
## auf einmal, und genau das ruckelt. Mit den feinen Zwischenstellungen sind
## es unter hundert. Das ist, was "interpolieren" in Pixelgrafik heisst:
## mehr gezeichnete Bilder, kein Ueberblenden.
func test_a_pose_change_never_redraws_a_quarter_of_the_clump() -> void:
	var bild := TextureLoader.load_texture(
		"res://assets/art/schilf_horst.png").get_image()
	var gefuellt := 0
	for y in Reeds.HALM_H:
		for x in Reeds.HALM_B:
			if bild.get_pixel(x, y).a > 0.0:
				gefuellt += 1
	assert_true(gefuellt > 100, "die erste Stellung ist fast leer")
	var groesste := 0
	for stellung in Reeds.WIND_BILDER - 1:
		var anders := _silhouetten_unterschied(bild, stellung, stellung + 1)
		assert_true(anders > 0,
			"Stellung %d und %d sind dasselbe Bild" % [stellung, stellung + 1])
		groesste = maxi(groesste, anders)
	var anteil := float(groesste) / float(gefuellt)
	assert_true(anteil <= 0.20,
		"ein Wechsel aendert bis zu %.0f%% der Pflanze" % (anteil * 100.0))

## Und er darf nicht rasen. Gemessen wird, wie viele Pixel sich je Sekunde
## aendern -- das ist Tempo MAL Schrittweite, also die Zahl, die beides
## zusammenfasst. Mit dem schnellen Flattern von damals lag sie bei ueber
## 2500 und sah aus wie Zittern.
func test_the_wind_does_not_race() -> void:
	var bild := TextureLoader.load_texture(
		"res://assets/art/schilf_horst.png").get_image()
	# Wie viel sich je Schritt aendert, einmal vorab ausgerechnet.
	var kosten: Array[int] = []
	for stellung in Reeds.WIND_BILDER - 1:
		kosten.append(_silhouetten_unterschied(bild, stellung, stellung + 1))
	const SCHRITTE := 3000
	const DT := 0.02
	var summe := 0
	var vorher := ReedPatch.stellung(0.0, Reeds.WIND_BILDER)
	for i in range(1, SCHRITTE):
		var jetzt := ReedPatch.stellung(float(i) * DT, Reeds.WIND_BILDER)
		while jetzt != vorher:
			var schritt := 1 if jetzt > vorher else -1
			summe += kosten[mini(vorher, vorher + schritt)]
			vorher += schritt
	var je_sekunde := float(summe) / (float(SCHRITTE) * DT)
	assert_true(je_sekunde <= 550.0,
		"es aendern sich %.0f Pixel je Sekunde -- das rast" % je_sekunde)
	assert_true(je_sekunde >= 60.0,
		"es aendern sich nur %.0f Pixel je Sekunde -- das steht" % je_sekunde)

## Und er nutzt alle gezeichneten Stellungen. Wer nur zwischen zweien hin und
## her springt, haette sich die anderen sparen koennen.
func test_the_wind_uses_every_drawn_pose() -> void:
	var gesehen := {}
	for i in 6000:
		gesehen[ReedPatch.stellung(float(i) * 0.01, Reeds.WIND_BILDER)] = true
	assert_eq(gesehen.size(), Reeds.WIND_BILDER,
		"nur %d von %d Stellungen kommen vor" % [gesehen.size(), Reeds.WIND_BILDER])

## Es wiederholt sich nicht sichtbar: zwei Boen uebereinander, deren Perioden
## nicht ineinander aufgehen.
func test_the_wind_does_not_repeat_after_one_gust() -> void:
	var periode := 1.0 / ReedPatch.BOE
	var erste: Array[int] = []
	var zweite: Array[int] = []
	for i in 40:
		var t := float(i) / 40.0 * periode
		erste.append(ReedPatch.stellung(t, Reeds.WIND_BILDER))
		zweite.append(ReedPatch.stellung(t + periode, Reeds.WIND_BILDER))
	assert_true(erste != zweite,
		"nach einer Boe faengt dasselbe Bild wieder von vorn an")

## Die gezeichneten Stellungen muessen sich der Reihe nach weiter neigen und
## duerfen nie zurueckgehen -- sonst springt der Horst beim Wechsel hin und
## her, statt sich zu biegen.
##
## Gemessen am Schwerpunkt des oberen Drittels, aber NICHT streng steigend:
## bei den feinen Zwischenstellungen aendert sich manchmal nur der untere
## Teil des Halms, und dann bleibt die Spitze stehen. Das ist richtig so -- so
## laeuft eine Biegung vom Fuss nach oben.
func test_the_drawn_poses_lean_further_and_further() -> void:
	var blatt := TextureLoader.load_texture("res://assets/art/schilf_horst.png")
	assert_true(blatt != null, "das Windblatt fehlt")
	var bild := blatt.get_image()
	# Oberes Drittel EINER Stellung -- das Blatt ist jetzt drei Zeilen hoch.
	var drittel := Reeds.HALM_H / 3
	var mitten: Array[float] = []
	for stellung in Reeds.WIND_BILDER:
		var summe := 0.0
		var zahl := 0
		for x in range(stellung * Reeds.HALM_B, (stellung + 1) * Reeds.HALM_B):
			for y in drittel:
				if bild.get_pixel(x, y).a > 0.0:
					summe += float(x - stellung * Reeds.HALM_B)
					zahl += 1
		assert_true(zahl > 0, "Stellung %d ist oben leer" % stellung)
		mitten.append(summe / float(zahl))
	for i in mitten.size() - 1:
		assert_true(mitten[i + 1] >= mitten[i] - 0.001,
			"Stellung %d neigt sich zurueck (%.2f nach %.2f)"
				% [i + 1, mitten[i], mitten[i + 1]])
	assert_true(mitten[mitten.size() - 1] > mitten[0] + 1.0,
		"die letzte Stellung steht kaum anders als die erste (%.2f zu %.2f)"
			% [mitten[mitten.size() - 1], mitten[0]])

## Die eingeblendete Trefferzone muss dieselbe sein, nach der auch wirklich
## geschnitten wird -- und sie liegt auf der KLINGE, nicht um die Hand. Zwei
## Anlaeufe davor zogen sie um die Hand, und ein Kreis um die Hand kann einen
## Kreis um die Klingenmitte nur an einer Stelle beruehren.
func test_the_shown_hitbox_is_the_one_that_cuts() -> void:
	Game.new_game()
	Game.dev_scythe_box = true
	var tree := Engine.get_main_loop() as SceneTree
	var schnitt: Control = load("res://scenes/fishing/reed_cut.tscn").instantiate()
	tree.root.add_child(schnitt)
	await tree.process_frame
	schnitt.starte()
	schnitt._process(0.05)
	assert_true(schnitt._zone.visible, "die Zone wird nicht gezeigt")
	assert_true(schnitt._zone.mitte.is_equal_approx(schnitt._sichel.position),
		"die Zone liegt nicht auf der Klinge")
	var radius: float = schnitt.SICHEL_RADIUS * schnitt.SKALA
	assert_almost_eq(schnitt._zone.reichweite, radius, 0.001,
		"die gezeigte Zone ist nicht so gross wie die Klinge")
	assert_almost_eq(schnitt._zone.tiefe, Reeds.KLINGE_PIXEL * schnitt.SKALA,
		0.001, "die gezeigte Tiefe ist nicht die Dicke der Klinge")
	assert_almost_eq(schnitt._zone.winkel, schnitt._winkel, 0.001,
		"die gezeigte Richtung ist nicht die der Klinge")
	# Und an den Kanten der gezeichneten Zone muss die Regel kippen.
	var mitte: Vector2 = schnitt._zone.mitte
	var tiefe: float = schnitt._zone.tiefe
	var halb := Reeds.SEKTOR * 0.5
	var mittig := radius - tiefe * 0.5
	for probe in [
		[Vector2(mittig, 0.0).rotated(schnitt._winkel + halb - 0.02), true],
		[Vector2(mittig, 0.0).rotated(schnitt._winkel + halb + 0.02), false],
		[Vector2(radius - tiefe * 0.2, 0.0).rotated(schnitt._winkel), true],
		[Vector2(radius - tiefe * 1.5, 0.0).rotated(schnitt._winkel), false],
		[Vector2(radius * 1.2, 0.0).rotated(schnitt._winkel), false],
	]:
		var stelle: Vector2 = mitte + (probe[0] as Vector2)
		assert_eq(Reeds.trifft(stelle, mitte, schnitt._winkel, radius, tiefe),
			probe[1] as bool,
			"bei %s stimmt Bild und Regel nicht ueberein" % str(probe[0]))
	Game.dev_scythe_box = false
	schnitt.free()

## Die Anzeige im Schilfschneiden steht UEBER der Welt, nicht auf dem
## Sandpanel. Das Theme faerbt Beschriftungen dunkel und umrandet sie hell --
## fuer die Panels richtig, ueber dem Nachtwasser unlesbar. Genau so war
## "HALME" kaum zu erkennen.
func test_the_reed_hud_is_written_for_the_dark_world() -> void:
	Game.new_game()
	var tree := Engine.get_main_loop() as SceneTree
	var schnitt: Control = load("res://scenes/fishing/reed_cut.tscn").instantiate()
	tree.root.add_child(schnitt)
	await tree.process_frame
	var gefunden := 0
	for l in _labels(schnitt):
		if not l.has_theme_color_override(&"font_color"):
			continue
		gefunden += 1
		var schrift: Color = l.get_theme_color(&"font_color")
		var umriss: Color = l.get_theme_color(&"font_outline_color")
		assert_true(_helligkeit(schrift) > _helligkeit(umriss) + 0.25,
			"%s steht dunkel auf hellem Umriss (%.2f gegen %.2f)"
				% [l.text, _helligkeit(schrift), _helligkeit(umriss)])
		assert_true(l.get_theme_constant(&"outline_size") >= 4,
			"%s hat kaum Umriss" % l.text)
	assert_true(gefunden >= 3,
		"nur %d Beschriftungen gefunden -- der Test sucht falsch" % gefunden)
	schnitt.free()

func _labels(n: Node) -> Array[Label]:
	var raus: Array[Label] = []
	if n is Label:
		raus.append(n as Label)
	for k in n.get_children():
		raus.append_array(_labels(k))
	return raus

func _helligkeit(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

## Die gezeichnete Sichel darf nicht viel weiter reichen als ihre
## Trefferzone. Sie spannte 222 Grad, geschnitten wurde in 80 -- zwei Drittel
## der sichtbaren Klinge waren eine Luege, und genau deshalb blieben Halme
## stehen, ueber die sie hinwegzugehen schien. Gesehen hat man das erst, als
## die Zone einblendbar war; diese Zahl haelt es fest.
func test_the_drawn_blade_matches_what_it_cuts() -> void:
	var bild := TextureLoader.load_texture(
		"res://assets/art/sichel.png").get_image()
	var mitte := Vector2(bild.get_width(), bild.get_height()) * 0.5
	var winkel: Array[float] = []
	for y in bild.get_height():
		for x in bild.get_width():
			if bild.get_pixel(x, y).a > 0.0:
				winkel.append((Vector2(x, y) + Vector2(0.5, 0.5) - mitte).angle())
	assert_true(winkel.size() > 50, "die Sichel ist fast leer")
	winkel.sort()
	# Die groesste Luecke im Kreis ist die Seite, an der die Sichel offen ist.
	var luecke := winkel[0] + TAU - winkel[winkel.size() - 1]
	for i in winkel.size() - 1:
		luecke = maxf(luecke, winkel[i + 1] - winkel[i])
	var spanne := TAU - luecke
	assert_true(spanne <= Reeds.SEKTOR * 1.6,
		"die Klinge spannt %.0f Grad, geschnitten wird in %.0f"
			% [rad_to_deg(spanne), rad_to_deg(Reeds.SEKTOR)])
	# Und sie darf auch nicht SCHMALER sein als die Zone -- dann traefe sie
	# Halme, die sie gar nicht beruehrt.
	assert_true(spanne >= Reeds.SEKTOR,
		"die Klinge spannt nur %.0f Grad, geschnitten wird in %.0f"
			% [rad_to_deg(spanne), rad_to_deg(Reeds.SEKTOR)])

## Die Klinge waechst NICHT mit der Reichweite, sie kreist weiter aussen.
##
## Skaliert war ein Klingenpixel voll ausgebaut 6,2 Punkte gross, waehrend die
## ganze uebrige Welt mit 2,16 zeichnet -- fast dreimal so grob wie alles
## daneben. Gepruefte Zusicherung: der Massstab bleibt der der Welt, UND die
## Schneide liegt trotzdem immer genau auf der Reichweite.
func test_the_blade_keeps_the_world_pixel_size() -> void:
	Game.new_game()
	var tree := Engine.get_main_loop() as SceneTree
	var schnitt: Control = load("res://scenes/fishing/reed_cut.tscn").instantiate()
	tree.root.add_child(schnitt)
	await tree.process_frame
	schnitt.starte()
	var u: UpgradeData = Database.upgrades[&"scythe_reach"]
	for stufe in [0, u.max_level / 2, u.max_level]:
		Game.upgrade_levels[&"scythe_reach"] = stufe
		# Zweimal, damit die Hand am Ziel angekommen ist.
		for i in 40:
			schnitt._process(0.05)
		var reichweite := Game.scythe_reach()
		assert_almost_eq(schnitt._sichel.scale.x, schnitt.SKALA, 0.001,
			"bei Reichweite %.0f ist die Klinge skaliert" % reichweite)
		var bahn: float = (schnitt._sichel.position - schnitt._hand).length()
		var schneide: float = bahn + schnitt.SICHEL_RADIUS * schnitt.SKALA
		assert_almost_eq(schneide, reichweite, 1.0,
			"die Schneide liegt auf %.0f, die Reichweite ist %.0f"
				% [schneide, reichweite])
	Game.upgrade_levels[&"scythe_reach"] = 0
	schnitt.free()

## Ausbaustufen lassen sich EINZELN zuruecksetzen -- beim Ausprobieren will
## man einen Regler wieder am Anfang haben, nicht den Spielstand verlieren.
func test_a_single_upgrade_can_be_reset_without_touching_the_others() -> void:
	Game.new_game()
	for id in Database.upgrades:
		Game.upgrade_levels[id] = 4
	Game.apply_upgrades()
	assert_eq(Game.dev_reset_upgrade(&"scythe_reach"), 4,
		"er meldet die falsche vorige Stufe")
	assert_eq(int(Game.upgrade_levels[&"scythe_reach"]), 0,
		"die Stufe steht noch")
	for id in Database.upgrades:
		if id == &"scythe_reach":
			continue
		assert_eq(int(Game.upgrade_levels[id]), 4,
			"%s wurde mit zurueckgesetzt" % id)
	# Und die abgeleiteten Werte muessen mitgehen, nicht erst beim Laden.
	Game.dev_reset_upgrade(&"fish_inventory")
	var u: UpgradeData = Database.upgrades[&"fish_inventory"]
	assert_eq(Game.ctx.inventory.capacity, int(u.value_at(0)),
		"die Kistengroesse haengt noch an der alten Stufe")

## Ein unbekannter Ausbau darf nichts kaputtmachen.
func test_resetting_an_unknown_upgrade_does_nothing() -> void:
	Game.new_game()
	Game.upgrade_levels[&"rod_power"] = 3
	assert_eq(Game.dev_reset_upgrade(&"gibt_es_nicht"), 0)
	assert_eq(int(Game.upgrade_levels[&"rod_power"]), 3)

## Und es muss auch WIRKLICH die Klinge sein, die schneidet -- nicht nur im
## Bild. Ein Versuch, bei dem die Zone auf der Klinge lag und geschnitten
## weiter um die Hand wurde, ist durch alle anderen Zusicherungen gerutscht:
## die pruefen die Regel, nicht die Verdrahtung.
##
## Geprueft wird bei VOLLER Reichweite. Auf Stufe 0 sitzt die Klinge fast auf
## der Hand, da tun beide Verdrahtungen dasselbe -- der erste Anlauf dieses
## Tests war deshalb ebenfalls blind.
func test_it_really_is_the_blade_that_does_the_cutting() -> void:
	Game.new_game()
	var u: UpgradeData = Database.upgrades[&"scythe_reach"]
	Game.upgrade_levels[&"scythe_reach"] = u.max_level
	var tree := Engine.get_main_loop() as SceneTree
	var schnitt: Control = load("res://scenes/fishing/reed_cut.tscn").instantiate()
	tree.root.add_child(schnitt)
	await tree.process_frame
	schnitt.starte()
	for i in 40:
		schnitt._process(0.02)
	var radius: float = schnitt.SICHEL_RADIUS * schnitt.SKALA
	var tiefe: float = Reeds.KLINGE_PIXEL * schnitt.SKALA
	var bahn: float = (schnitt._sichel.position - schnitt._hand).length()
	assert_true(bahn > radius,
		"die Bahn (%.0f) ist nicht weiter als die Klinge gross (%.0f) -- der"
			% [bahn, radius] + " Test kann die beiden Faelle nicht trennen")
	var mittig := radius - tiefe * 0.5
	var schluessel: Array = schnitt._halme.keys()
	assert_true(schluessel.size() >= 2, "zu wenige Halme zum Pruefen")
	var getroffen: Sprite2D = schnitt._halme[schluessel[0]]
	var verschont: Sprite2D = schnitt._halme[schluessel[1]]
	for i in range(2, schluessel.size()):
		var weg: Sprite2D = schnitt._halme[schluessel[i]]
		schnitt._halme.erase(schluessel[i])
		weg.get_parent().remove_child(weg)
		weg.free()
	# Auf der Kreisbahn der KLINGENMITTE -- dort kommt die Klinge vorbei.
	getroffen.position = schnitt._hand + Vector2(bahn + mittig, 0.0)
	# Und dort, wo eine Zone um die HAND treffen wuerde: nah an der Hand, weit
	# weg von jeder Klinge.
	verschont.position = schnitt._hand + Vector2(mittig, 0.0)
	for i in 50:
		schnitt._ziel = schnitt._hand
		schnitt._process(0.02)
	assert_true(int(getroffen.get_meta(&"leben")) < schnitt._noetig,
		"der Halm auf der Klingenbahn bekam keinen Treffer")
	assert_eq(int(verschont.get_meta(&"leben")), schnitt._noetig,
		"der Halm bei der Hand wurde geschnitten, obwohl dort keine Klinge ist")
	Game.upgrade_levels[&"scythe_reach"] = 0
	schnitt.free()
