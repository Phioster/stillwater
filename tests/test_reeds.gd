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
	var mitte := Vector2(400.0, 300.0)
	var reichweite := 50.0
	# Genau vor der Schneide, dicht dran.
	assert_true(Reeds.trifft(mitte + Vector2(30.0, 0.0), mitte, 0.0, reichweite))
	# Genauso nah, aber hinter ihr.
	assert_false(Reeds.trifft(mitte + Vector2(-30.0, 0.0), mitte, 0.0, reichweite),
		"die Sichel schneidet nach hinten")
	# Direkt vor ihr, aber ausserhalb der Reichweite.
	assert_false(Reeds.trifft(mitte + Vector2(70.0, 0.0), mitte, 0.0, reichweite),
		"die Sichel greift weiter, als sie reicht")
	# Am Rand des Ausschnitts, drinnen und knapp draussen.
	var knapp_drin := Reeds.SEKTOR * 0.5 - 0.02
	var knapp_raus := Reeds.SEKTOR * 0.5 + 0.02
	assert_true(Reeds.trifft(mitte + Vector2(30.0, 0.0).rotated(knapp_drin),
		mitte, 0.0, reichweite))
	assert_false(Reeds.trifft(mitte + Vector2(30.0, 0.0).rotated(knapp_raus),
		mitte, 0.0, reichweite))

## Die Klinge dreht sich, also dreht sich auch, was sie trifft.
func test_the_cut_sector_turns_with_the_blade() -> void:
	var mitte := Vector2(400.0, 300.0)
	var ziel := mitte + Vector2(0.0, 30.0)
	assert_false(Reeds.trifft(ziel, mitte, 0.0, 50.0))
	assert_true(Reeds.trifft(ziel, mitte, PI * 0.5, 50.0),
		"gedreht trifft sie ihr Ziel nicht")

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
	assert_eq(horst.get_width(), Reeds.HALM_B * Reeds.HALM_STUFEN,
		"der Horst hat nicht drei Bilder nebeneinander")

## Und die drei Bilder muessen sich unterscheiden, sonst sieht man vom
## Schneiden nichts.
func test_the_three_cutting_stages_really_differ() -> void:
	var horst := TextureLoader.load_texture("res://assets/art/schilf_horst.png")
	var bild := horst.get_image()
	var gefuellt: Array[int] = []
	for stufe in Reeds.HALM_STUFEN:
		var zahl := 0
		for x in range(stufe * Reeds.HALM_B, (stufe + 1) * Reeds.HALM_B):
			for y in bild.get_height():
				if bild.get_pixel(x, y).a > 0.0:
					zahl += 1
		gefuellt.append(zahl)
	for i in gefuellt.size() - 1:
		assert_true(gefuellt[i] > gefuellt[i + 1],
			"Stufe %d hat %d Pixel, Stufe %d aber %d -- es wird nicht kuerzer"
				% [i, gefuellt[i], i + 1, gefuellt[i + 1]])

## Der Horst steht zwischen dem Uferschilf und muss dessen Groesse haben. Als
## er halb so hoch war, sah er aus wie Gras vor echtem Schilf.
func test_the_cut_clump_is_as_tall_as_the_shore_reeds() -> void:
	var horst := TextureLoader.load_texture("res://assets/art/schilf_horst.png")
	assert_true(float(horst.get_height()) >= WORLD.REED_SIZE.y * 0.75,
		"der Horst ist %d hoch, das Uferband %d" % [horst.get_height(),
			int(WORLD.REED_SIZE.y)])

# --- Entwicklerhilfen -------------------------------------------------------
#
# Beim Ausprobieren laeuft alles voll, und danach laesst sich nichts mehr
# pruefen. Diese drei muessen wirklich leeren, nicht nur die Anzeige.

func test_the_developer_switch_empties_the_fish_box() -> void:
	Game.new_game()
	for i in 5:
		var c := CaughtFish.new()
		c.fish_id = &"bluegill"
		Game.ctx.inventory.add(c)
	assert_eq(Game.ctx.inventory.fish.size(), 5, "der Aufbau ging schief")
	assert_eq(Game.dev_clear_fish(), 5, "er meldet die falsche Zahl")
	assert_eq(Game.ctx.inventory.fish.size(), 0, "die Kiste ist noch voll")

## Eine volle Kiste haelt das Angeln an -- nach dem Leeren muss es weitergehen.
func test_emptying_the_box_lets_fishing_continue() -> void:
	Game.new_game()
	Game.sim.state = FishingSim.State.INVENTORY_FULL
	Game.dev_clear_fish()
	assert_true(Game.sim.state != FishingSim.State.INVENTORY_FULL,
		"das Angeln haengt weiter an der vollen Kiste")

func test_the_developer_switch_empties_the_bait_bag() -> void:
	Game.new_game()
	Game.upgrade_levels[&"bait_capacity"] = 9
	Game.gain_bait(&"pond_grub", 12)
	assert_true(Game.bait_used() >= 12, "der Aufbau ging schief")
	var weg := Game.dev_clear_bait()
	assert_true(weg >= 12, "er meldet %d statt mindestens 12" % weg)
	assert_eq(Game.bait_used(), 0, "die Tasche ist noch voll")

func test_the_developer_switch_makes_the_reeds_stand_again() -> void:
	Game.new_game()
	Game.finish_reed_cut(30)
	assert_false(Game.reeds_ready(), "der Aufbau ging schief")
	Game.dev_grow_reeds()
	assert_true(Game.reeds_ready(), "das Schilf steht nicht wieder")

# --- Der Wind am Ufer -------------------------------------------------------
#
# Der Horst schaltet zwischen GEZEICHNETEN Stellungen um. Zwei Versuche davor
# haben das Bild stattdessen verschoben -- gedreht, dann zeilenweise geschert
# -- und beide sahen falsch aus, das zweite wie verrutschte Bildzeilen.

## Das Bild darf sich nicht in Spruengen aendern. Mit sechs Stellungen
## wechselten je Schritt rund 390 von 770 Pixeln -- mehr als die halbe Pflanze
## auf einmal, und genau das ruckelt. Mit den feinen Zwischenstellungen sind
## es unter hundert. Das ist, was "interpolieren" in Pixelgrafik heisst:
## mehr gezeichnete Bilder, kein Ueberblenden.
func test_a_pose_change_never_redraws_a_quarter_of_the_clump() -> void:
	var bild := TextureLoader.load_texture(
		"res://assets/art/schilf_wind.png").get_image()
	var hoehe := bild.get_height()
	var gefuellt := 0
	for y in hoehe:
		for x in Reeds.HALM_B:
			if bild.get_pixel(x, y).a > 0.0:
				gefuellt += 1
	assert_true(gefuellt > 100, "die erste Stellung ist fast leer")
	var groesste := 0
	for stellung in Reeds.WIND_BILDER - 1:
		var anders := 0
		for y in hoehe:
			for x in Reeds.HALM_B:
				if bild.get_pixel(stellung * Reeds.HALM_B + x, y) \
						!= bild.get_pixel((stellung + 1) * Reeds.HALM_B + x, y):
					anders += 1
		assert_true(anders > 0,
			"Stellung %d und %d sind dasselbe Bild" % [stellung, stellung + 1])
		groesste = maxi(groesste, anders)
	var anteil := float(groesste) / float(gefuellt)
	assert_true(anteil <= 0.25,
		"ein Wechsel malt bis zu %.0f%% der Pflanze neu" % (anteil * 100.0))

## Und er darf nicht rasen. Gemessen wird, wie viele Pixel sich je Sekunde
## aendern -- das ist Tempo MAL Schrittweite, also die Zahl, die beides
## zusammenfasst. Mit dem schnellen Flattern von damals lag sie bei ueber
## 2500 und sah aus wie Zittern.
func test_the_wind_does_not_race() -> void:
	var bild := TextureLoader.load_texture(
		"res://assets/art/schilf_wind.png").get_image()
	# Wie viel sich je Schritt aendert, einmal vorab ausgerechnet.
	var kosten: Array[int] = []
	for stellung in Reeds.WIND_BILDER - 1:
		var anders := 0
		for y in bild.get_height():
			for x in Reeds.HALM_B:
				if bild.get_pixel(stellung * Reeds.HALM_B + x, y) \
						!= bild.get_pixel((stellung + 1) * Reeds.HALM_B + x, y):
					anders += 1
		kosten.append(anders)
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
	assert_true(je_sekunde <= 800.0,
		"es aendern sich %.0f Pixel je Sekunde -- das rast" % je_sekunde)
	assert_true(je_sekunde >= 100.0,
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
	var blatt := TextureLoader.load_texture("res://assets/art/schilf_wind.png")
	assert_true(blatt != null, "das Windblatt fehlt")
	var bild := blatt.get_image()
	var drittel := bild.get_height() / 3
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
