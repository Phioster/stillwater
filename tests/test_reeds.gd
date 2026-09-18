extends TestCase

## Das Schilfschneiden. Geprueft wird die Rechnung dahinter, nicht das Bild:
## wann Schilf reif ist, was ein Schnitt einbringt und ob die Klinge mit den
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

## Eine Klinge, der nichts entgegensteht, nimmt dem Schneiden den Sinn.
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

## Und der Ausbau haelt mit: in der letzten Zone mit voll ausgebauter Klinge
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
			"%s braucht mit voller Klinge %d Treffer, der Anfang nur %d"
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

## Getroffen wird nur, wo die Klinge WIRKLICH ist. Das Messer haengt mit dem
## Griff nach innen an der Hand, seine Spitze liegt auf der Reichweite -- vor
## der Spitze und hinter dem Griff ist nichts.
func test_the_knife_only_cuts_where_it_is() -> void:
	var hand := Vector2(400.0, 300.0)
	var weit := 200.0
	var skala := 2.0
	var lang := float(Reeds.klinge_groesse().x) * skala
	var dick := float(Reeds.klinge_groesse().y) * skala
	assert_true(Reeds.trifft(hand + Vector2(weit - lang * 0.25, 0.0), hand,
		0.0, weit, skala), "die Klinge trifft auf ihrer eigenen Achse nicht")
	assert_false(Reeds.trifft(hand + Vector2(weit + 4.0, 0.0), hand, 0.0,
		weit, skala), "sie greift ueber ihre Spitze hinaus")
	assert_false(Reeds.trifft(hand + Vector2(weit - lang - 4.0, 0.0), hand,
		0.0, weit, skala), "sie schneidet hinter ihrem Griff")
	assert_false(Reeds.trifft(hand + Vector2(weit - lang * 0.25, dick), hand,
		0.0, weit, skala), "sie schneidet neben sich")

## Und nichts zwischen Hand und Klinge -- dort ist keine.
func test_nothing_is_cut_between_the_hand_and_the_knife() -> void:
	var hand := Vector2(400.0, 300.0)
	var weit := 300.0
	var skala := 2.0
	var lang := float(Reeds.klinge_groesse().x) * skala
	for nah in [0.0, 20.0, lang * 0.5, weit - lang - 6.0]:
		assert_false(Reeds.trifft(hand + Vector2(nah, 0.0), hand, 0.0, weit,
			skala), "bei %f vor der Hand wird geschnitten" % nah)

## Die Klinge dreht sich, also dreht sich auch, was sie trifft.
func test_what_is_cut_turns_with_the_knife() -> void:
	var hand := Vector2(400.0, 300.0)
	var weit := 200.0
	var skala := 2.0
	var lang := float(Reeds.klinge_groesse().x) * skala
	var ziel := hand + Vector2(0.0, weit - lang * 0.25)
	assert_false(Reeds.trifft(ziel, hand, 0.0, weit, skala))
	assert_true(Reeds.trifft(ziel, hand, PI * 0.5, weit, skala),
		"gedreht trifft sie ihr Ziel nicht")

## Der entscheidende Test: was gezeichnet ist, schneidet -- und was nicht
## gezeichnet ist, schneidet nicht. Jedes Bildpixel wird durch DIESELBE
## Rechnung an seinen Platz in der Welt gesetzt, mit der reed_cut.gd die
## Klinge hinstellt, und dort muss die Regel dasselbe sagen wie das Bild.
##
## Vier Anlaeufe davor rechneten die Form nach, statt sie zu benutzen, und
## drei davon rechneten eine andere. Am Bild sah man es jedes Mal sofort.
func test_every_drawn_pixel_cuts_and_no_other() -> void:
	var bild := TextureLoader.load_texture(Reeds.KLINGE_BILD).get_image()
	if bild.is_compressed():
		bild.decompress()
	if bild.get_format() != Image.FORMAT_RGBA8:
		bild.convert(Image.FORMAT_RGBA8)
	var hand := Vector2(500.0, 400.0)
	var weit := 260.0
	var skala := 2.16
	var winkel := 0.7
	var g := Vector2(bild.get_width(), bild.get_height())
	var fuss := weit - g.x * skala
	var gemalt := 0
	var daneben := 0
	for y in bild.get_height():
		for x in bild.get_width():
			var lokal := Vector2(fuss + (float(x) + 0.5) * skala,
				(float(y) + 0.5 - g.y * 0.5) * skala)
			var stelle := hand + lokal.rotated(winkel)
			var ist := bild.get_pixel(x, y).a > Reeds.MASKE_SCHWELLE
			if ist:
				gemalt += 1
			if Reeds.trifft(stelle, hand, winkel, weit, skala) != ist:
				daneben += 1
	assert_true(gemalt > 200, "die Klinge ist fast leer")
	assert_eq(daneben, 0,
		"%d von %d Bildpunkten schneiden anders, als sie aussehen"
			% [daneben, bild.get_width() * bild.get_height()])

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

## Die drei Klingen-Ausbauten muessen den Grundwerten entsprechen, mit denen
## das Spiel ohne sie rechnet. Zwei Quellen fuer dieselbe Zahl laufen sonst
## auseinander, und gemerkt haette man es erst am Geraet.
func test_the_upgrades_start_at_the_measured_base_values() -> void:
	Game.new_game()
	assert_almost_eq(Game.scythe_edge(), Reeds.SCHNEIDE, 0.0001)
	assert_almost_eq(Game.scythe_reach(), Reeds.REICHWEITE, 0.0001)
	assert_almost_eq(Game.scythe_speed(), Reeds.DREHUNG, 0.0001)

## Und sie muessen wirklich etwas tun.
func test_every_knife_upgrade_actually_grows() -> void:
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
## geschnitten wird. Sie ist es jetzt buchstaeblich: gezeichnet wird der
## Umriss DERSELBEN Bitmap, die auch trifft. Was dieser Test noch pruefen
## kann, ist die Verdrahtung -- dass die Zone an derselben Hand, demselben
## Winkel und derselben Reichweite haengt wie der Schnitt.
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
	assert_true(schnitt._zone.hand.is_equal_approx(schnitt._hand),
		"die Zone haengt nicht an der Hand")
	assert_almost_eq(schnitt._zone.reichweite, Game.scythe_reach(), 0.001,
		"die gezeigte Reichweite ist nicht die, mit der geschnitten wird")
	assert_almost_eq(schnitt._zone.winkel, schnitt._winkel, 0.001,
		"die gezeigte Richtung ist nicht die der Klinge")
	assert_almost_eq(schnitt._zone.skala, schnitt.SKALA, 0.001,
		"die Zone rechnet mit einem anderen Massstab als die Klinge")
	# Und der Umriss stammt aus der Maske, nicht aus einer zweiten Rechnung.
	var g := Reeds.klinge_groesse()
	var teile := Reeds.maske().opaque_to_polygons(Rect2i(Vector2i.ZERO, g), 0.5)
	assert_true(teile.size() > 0, "die Maske hat keinen Umriss")
	Game.dev_scythe_box = false
	schnitt.free()

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

## Die Spitze der gezeichneten Klinge liegt genau auf der Reichweite. Daran
## haengt, dass der blasse Kreis in der Entwickleransicht die Wahrheit sagt --
## und dass "Reichweite" ueberhaupt etwas Messbares bedeutet.
func test_the_tip_sits_exactly_on_the_reach() -> void:
	var skala := 2.16
	var halb := float(Reeds.klinge_groesse().x) * 0.5 * skala
	for weit in [110.0, 170.0, 230.0]:
		var bahn := Reeds.klinge_bahn(weit, skala)
		assert_almost_eq(bahn + halb, weit, 0.001,
			"bei Reichweite %.0f endet das Bild auf %.0f" % [weit, bahn + halb])
	# Und es schneidet dort auch wirklich noch: das aeusserste Pixel auf der
	# Achse darf nur um die Rundung der Spitze hinter der Reichweite liegen.
	var weit := 200.0
	var aussen := -1.0
	for i in 200:
		var r := weit - float(i) * 0.5
		if Reeds.trifft(Vector2(r, 0.0), Vector2.ZERO, 0.0, weit, skala):
			aussen = r
			break
	assert_true(aussen > 0.0, "auf der Achse schneidet gar nichts")
	assert_true(weit - aussen < 5.0 * skala,
		"das aeusserste schneidende Pixel liegt %.0f vor der Reichweite"
			% (weit - aussen))

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
		assert_almost_eq(schnitt._klinge.scale.x, schnitt.SKALA, 0.001,
			"bei Reichweite %.0f ist die Klinge skaliert" % reichweite)
		var bahn: float = (schnitt._klinge.position - schnitt._hand).length()
		var spitze: float = bahn + float(Reeds.klinge_groesse().x) * 0.5 \
			* schnitt.SKALA
		assert_almost_eq(spitze, reichweite, 1.0,
			"die Spitze liegt auf %.0f, die Reichweite ist %.0f"
				% [spitze, reichweite])
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
	var lang: float = float(Reeds.klinge_groesse().x) * schnitt.SKALA
	var reichweite := Game.scythe_reach()
	var bahn: float = (schnitt._klinge.position - schnitt._hand).length()
	assert_true(bahn > lang * 0.5,
		"die Bahn (%.0f) ist nicht weiter als die halbe Klinge (%.0f) -- der"
			% [bahn, lang * 0.5] + " Test kann die beiden Faelle nicht trennen")
	var schluessel: Array = schnitt._halme.keys()
	assert_true(schluessel.size() >= 2, "zu wenige Halme zum Pruefen")
	var getroffen: Sprite2D = schnitt._halme[schluessel[0]]
	var verschont: Sprite2D = schnitt._halme[schluessel[1]]
	for i in range(2, schluessel.size()):
		var weg: Sprite2D = schnitt._halme[schluessel[i]]
		schnitt._halme.erase(schluessel[i])
		weg.get_parent().remove_child(weg)
		weg.free()
	# Auf der Bahn der KLINGE -- dort kommt sie vorbei.
	getroffen.position = schnitt._hand + Vector2(reichweite - lang * 0.3, 0.0)
	# Und dort, wo eine Zone um die HAND treffen wuerde: nah an der Hand, weit
	# weg von jeder Klinge.
	verschont.position = schnitt._hand + Vector2(lang * 0.3, 0.0)
	for i in 60:
		schnitt._ziel = schnitt._hand
		schnitt._process(0.02)
	assert_true(int(getroffen.get_meta(&"leben")) < schnitt._noetig,
		"der Halm auf der Klingenbahn bekam keinen Treffer")
	assert_eq(int(verschont.get_meta(&"leben")), schnitt._noetig,
		"der Halm bei der Hand wurde geschnitten, obwohl dort keine Klinge ist")
	Game.upgrade_levels[&"scythe_reach"] = 0
	schnitt.free()
