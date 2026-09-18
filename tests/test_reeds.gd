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
