extends TestCase

## Das Theme ist die einzige Stelle, an der die Oberflaeche ihr Aussehen
## bekommt -- und genau deshalb faellt hier nichts auf, wenn es kaputt ist:
## ein fehlendes Zeichen wird ein leeres Kaestchen, und das sieht man erst
## auf dem Geraet.

const WURZELN := ["res://scenes", "res://autoload", "res://core", "res://data"]
const ENDUNGEN := [".gd", ".tscn", ".tres"]

func _sammle(pfad: String, out: Array) -> void:
	var d := DirAccess.open(pfad)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if not n.begins_with("."):
			var voll := pfad.path_join(n)
			if d.current_is_dir():
				_sammle(voll, out)
			else:
				for e in ENDUNGEN:
					if n.ends_with(e):
						out.append(voll)
						break
		n = d.get_next()
	d.list_dir_end()

## Jedes Zeichen, das irgendwo auf dem Schirm landen kann. Reine
## Kommentarzeilen bleiben draussen -- dort steht Prosa, die nie gezeichnet
## wird, und ein Gedankenstrich im Kommentar soll keinen Test rot machen.
func _zeichen_der_oberflaeche() -> Dictionary:
	var dateien: Array = []
	for w in WURZELN:
		_sammle(w, dateien)
	var gefunden: Dictionary = {}
	for p in dateien:
		var text := FileAccess.get_file_as_string(p)
		for zeile in text.split("\n"):
			if zeile.strip_edges().begins_with("#"):
				continue
			for i in zeile.length():
				var c := zeile.unicode_at(i)
				if c > 127:
					gefunden[c] = p
	return {"dateien": dateien.size(), "zeichen": gefunden}

## DER Test: kein Zeichen der Oberflaeche darf als leeres Kaestchen enden.
func test_the_ui_font_can_draw_every_character_the_ui_uses() -> void:
	var fund := _zeichen_der_oberflaeche()
	assert_true(int(fund["dateien"]) > 100,
		"nur %s Dateien durchsucht -- der Test greift ins Leere" % fund["dateien"])
	var schrift := UiTheme.build().default_font
	assert_true(schrift != null, "das Theme hat gar keine Schrift")
	var zeichen: Dictionary = fund["zeichen"]
	assert_true(zeichen.size() > 10,
		"nur %d Sonderzeichen gefunden -- das kann nicht stimmen" % zeichen.size())
	for c in zeichen:
		assert_true(schrift.has_char(int(c)),
			"U+%04X (%s) fehlt in der Schrift, benutzt in %s"
				% [c, char(int(c)), zeichen[c]])

## Die Ersatzschrift muss wirklich haengen -- ohne sie faellt der Test oben
## zwar auch um, aber mit einer viel unklareren Meldung.
func test_the_symbol_font_is_attached_as_a_fallback() -> void:
	var schrift := UiTheme.build().default_font
	assert_true(schrift is FontFile, "die Schrift ist keine FontFile")
	var f: FontFile = schrift
	assert_eq(f.fallbacks.size(), 1, "keine oder zu viele Ersatzschriften")
	assert_false(f.has_char("A".unicode_at(0)) and f.fallbacks[0].has_char("A".unicode_at(0)),
		"die Ersatzschrift bringt Buchstaben mit -- sie soll nur Zeichen liefern")

## Silkscreen ist auf acht Pixel gezeichnet. Bei einer krummen Groesse
## bekommt ein Teil der Buchstaben ein Pixel mehr als der andere.
func test_the_font_size_is_a_whole_multiple_of_the_pixel_grid() -> void:
	assert_eq(UiTheme.SCHRIFT_GROESSE % 8, 0,
		"%d ist kein Vielfaches von 8" % UiTheme.SCHRIFT_GROESSE)
	assert_eq(UiTheme.OUTLINE, UiTheme.SCHRIFT_GROESSE / 8,
		"der Umriss ist nicht genau ein gezeichnetes Pixel breit")

## Die 9-Slice-Raender muessen zum Bild passen: sind sie zu gross, ueber-
## lappen die Ecken und der Rahmen franst aus.
func test_the_frame_margins_fit_the_frame_image() -> void:
	var bild := TextureLoader.load_texture(UiTheme.RAHMEN)
	assert_true(bild != null, "das Rahmenbild fehlt")
	assert_true(bild.get_width() > UiTheme.RAHMEN_SEITE * 2,
		"Rahmenbild %d breit, Raender 2x%d" % [bild.get_width(), UiTheme.RAHMEN_SEITE])
	assert_true(bild.get_height() > UiTheme.RAHMEN_OBEN * 2,
		"Rahmenbild %d hoch, Raender 2x%d" % [bild.get_height(), UiTheme.RAHMEN_OBEN])

## Runde Ecken waren das Erkennungszeichen der alten Oberflaeche.
func test_nothing_in_the_theme_has_rounded_corners() -> void:
	var t := UiTheme.build()
	var geprueft := 0
	for typ in t.get_stylebox_type_list():
		for name in t.get_stylebox_list(typ):
			var box := t.get_stylebox(name, typ)
			if box is StyleBoxFlat:
				geprueft += 1
				assert_eq(box.corner_radius_top_left, 0,
					"%s/%s hat runde Ecken" % [typ, name])
				assert_eq(box.shadow_size, 0, "%s/%s wirft einen Schatten" % [typ, name])
	assert_true(geprueft > 0, "kein einziger StyleBoxFlat im Theme gefunden")

## Die Reiterleiste ist auf eine feste Breite genagelt, und genau daran ist
## die groessere Schrift zuerst gescheitert: "Optionen" lief rechts aus dem
## Bild. Silkscreen ist je Zeichen deutlich breiter als Godots Standard-
## schrift, das faellt beim Schriftwechsel nicht von selbst auf.
func test_every_tab_label_fits_the_rail() -> void:
	var schrift := UiTheme.build().default_font
	var breite: float = MAIN.RAIL_WIDTH
	# Vom Rand der Leiste bleibt uebrig: Rahmeninnenabstand und Knopfrand.
	var platz := breite - 2.0 * float(UiTheme.RAHMEN_SEITE + 2) \
		- 2.0 * float(UiTheme.KNOPF_RAND)
	assert_true(platz > 0.0, "die Leiste ist schmaler als ihre Raender")
	for reiter in TabRail.TABS:
		var w: float = schrift.get_string_size(reiter,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SCHRIFT_GROESSE).x
		assert_true(w <= platz,
			"Reiter '%s' ist %d breit, in die Leiste passen %d"
				% [reiter, w, platz])

## Godots Vorgabe fuer den Abstand zwischen zwei Kindern einer HBox. Die
## Reiterzeile setzt nichts anderes, also gilt der hier.
const HBOX_ABSTAND: float = 4.0

func _gruppen(node: Node, out: Array) -> void:
	if node is TabGroup:
		var g: TabGroup = node
		if g.labels.size() > 1:
			out.append(g.labels)
	for kind in node.get_children():
		_gruppen(kind, out)

## Dieselbe Falle wie bei der Reiterleiste, nur eine Ebene tiefer: die
## Unterreiterzeile eines Panels ("Inventar Vitrine Beutel Auftraege Geheim")
## steht waagerecht und wird mit der Schrift breiter. Passt sie nicht mehr,
## bleibt sie nicht etwa stehen -- ein PanelContainer darf nicht schmaler
## werden als sein Inhalt, also waechst er nach rechts und schiebt sich ueber
## die Leiste daneben. Genau so ist es beim ersten Anlauf passiert.
func test_every_tab_group_row_fits_the_side_panel() -> void:
	var szene: PackedScene = load("res://scenes/main.tscn")
	assert_true(szene != null, "main.tscn laesst sich nicht laden")
	if szene == null:
		return
	var haupt: Node = szene.instantiate()
	var breite: float = MAIN.PANEL_WIDTH
	var gruppen: Array = []
	_gruppen(haupt, gruppen)
	haupt.free()
	assert_true(gruppen.size() > 0, "keine einzige Reitergruppe gefunden")
	var schrift := UiTheme.build().default_font
	var platz := breite - 2.0 * float(UiTheme.RAHMEN_SEITE + 2)
	for labels in gruppen:
		var noetig := HBOX_ABSTAND * float(labels.size() - 1)
		for l in labels:
			noetig += schrift.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT,
				-1, UiTheme.SCHRIFT_GROESSE).x + 2.0 * float(UiTheme.KNOPF_RAND)
		assert_true(noetig <= platz,
			"Reiterzeile %s braucht %d, im Panel sind %d"
				% [", ".join(labels), noetig, platz])

## Der Erfahrungsbalken war Godots heller runder Standard und auf dem
## Sandpanel praktisch unsichtbar.
func test_the_progress_bar_is_styled_at_all() -> void:
	var t := UiTheme.build()
	for name in ["background", "fill"]:
		var box := t.get_stylebox(name, "ProgressBar")
		assert_true(box is StyleBoxFlat, "ProgressBar/%s ist nicht gesetzt" % name)
	var rinne: StyleBoxFlat = t.get_stylebox("background", "ProgressBar")
	var fuellung: StyleBoxFlat = t.get_stylebox("fill", "ProgressBar")
	assert_false(rinne.bg_color.is_equal_approx(fuellung.bg_color),
		"Rinne und Fuellung haben dieselbe Farbe")

## Der Umriss haengt daran, WORAUF der Text sitzt: Beschriftungen auf dem
## hellen Sandpanel, Knoepfe auf dunklem Holz. Gleiche Farbe fuer beide hiesse,
## dass eines von beidem ersaeuft.
func test_labels_and_buttons_outline_in_opposite_directions() -> void:
	var t := UiTheme.build()
	var label_umriss: Color = t.get_color("font_outline_color", "Label")
	var knopf_umriss: Color = t.get_color("font_outline_color", "Button")
	assert_true(label_umriss.get_luminance() > 0.5,
		"der Umriss der Beschriftungen ist nicht hell")
	assert_true(knopf_umriss.get_luminance() < 0.5,
		"der Umriss der Knoepfe ist nicht dunkel")

## Die Breite des Seitenpanels. Sie kommt aus main.gd und NICHT aus der
## Szene: _layout() dort schreibt die Offsets jeden Durchlauf neu, was in
## main.tscn steht ist nur der Anfangswert. Genau daran ist eine Korrektur
## schon einmal wirkungslos verpufft -- und dieser Test war gruen dabei, weil
## er die falsche Quelle las.
const MAIN := preload("res://scenes/main.gd")

func _panel_breite() -> float:
	return MAIN.PANEL_WIDTH

## Die Fischzeile ist die breiteste Zeile der Oberflaeche: Name und zwei
## Knoepfe in Daumengroesse. Ohne Umbruch war ihre MINDESTBREITE der ganze
## Name -- und weil ein Container nicht schmaler wird als sein Inhalt, schob
## sie sich ueber die Reiterleiste daneben, statt umzubrechen. Geprueft wird
## deshalb das laengste unteilbare Wort, denn das ist die Untergrenze.
func test_the_widest_fish_row_fits_the_side_panel() -> void:
	var schrift := UiTheme.build().default_font
	var breitestes := 0.0
	var wer := ""
	for f in Database.fish.values():
		for dev in [-0.9, -0.4, 0.0, 0.4, 0.9]:
			for wort in ("✦ " + f.full_name(dev)).split(" "):
				var w: float = schrift.get_string_size(wort,
					HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SCHRIFT_GROESSE).x
				if w > breitestes:
					breitestes = w
					wer = wort
	assert_true(breitestes > 0.0, "kein einziger Fischname gefunden")
	var noetig := breitestes + FishRow.FAV_WIDTH + FishRow.SELL_WIDTH \
		+ 2.0 * HBOX_ABSTAND
	var platz := _panel_breite() - 2.0 * float(UiTheme.RAHMEN_SEITE + 2)
	assert_true(noetig <= platz,
		"Zeile mit '%s' braucht %d, im Panel sind %d" % [wer, noetig, platz])

## WCAG-Kontrast: das Verhaeltnis der relativen Helligkeiten, 4.5 ist die
## uebliche Schwelle fuer Fliesstext.
func _kontrast(a: Color, b: Color) -> float:
	var la := _linear(a)
	var lb := _linear(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

func _linear(c: Color) -> float:
	var k := func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * k.call(c.r) + 0.7152 * k.call(c.g) + 0.0722 * k.call(c.b)

## Der eigentliche Grund fuer die abgesenkte Grundfarbe: die Oberflaeche
## faerbt per modulate ein, und modulate MULTIPLIZIERT. Mit heller Grundfarbe
## landete jede Seltenheitsfarbe hell auf hellem Sand -- keine kam ueber einen
## Kontrast von 1,9, und man konnte die Liste schlicht nicht lesen.
func test_every_rarity_colour_stays_readable_on_the_sand_panel() -> void:
	var sand := Palette.get_color(&"sand_light")
	var grund: Color = UiTheme.build().get_color("font_color", "Label")
	var geprueft := 0
	for r in Database.rarities.values():
		var gemalt := Color(grund.r * r.color.r, grund.g * r.color.g,
			grund.b * r.color.b)
		geprueft += 1
		assert_true(_kontrast(gemalt, sand) >= 4.0,
			"%s hat auf Sand nur Kontrast %.1f" % [r.id, _kontrast(gemalt, sand)])
	assert_true(geprueft >= 5, "nur %d Seltenheiten geprueft" % geprueft)
	# Und die Akzentfarbe, die Ueberschriften und Preise tragen.
	var akzent := Palette.get_color(&"accent")
	var gemalt2 := Color(grund.r * akzent.r, grund.g * akzent.g, grund.b * akzent.b)
	assert_true(_kontrast(gemalt2, sand) >= 4.0,
		"die Akzentfarbe hat auf Sand nur Kontrast %.1f" % _kontrast(gemalt2, sand))

## Zwei Quellen fuer dasselbe Mass sind eine Falle, und sie hat zugeschnappt:
## main.tscn wurde geaendert, main.gd nicht -- und weil _layout() die Offsets
## jeden Durchlauf neu schreibt, blieb im Spiel alles beim Alten. Der Test
## haelt beide zusammen, damit das nicht noch einmal stumm passiert.
func test_the_layout_constants_and_the_scenes_agree() -> void:
	var haupt: Node = load("res://scenes/main.tscn").instantiate()
	var seite: Control = haupt.get_node_or_null("SidePanel")
	assert_true(seite != null, "SidePanel steht nicht mehr in main.tscn")
	if seite != null:
		assert_almost_eq(seite.offset_right - seite.offset_left,
			MAIN.PANEL_WIDTH, 0.5,
			"main.tscn und PANEL_WIDTH laufen auseinander")
		assert_almost_eq(-seite.offset_right, MAIN.RAIL_WIDTH, 0.5,
			"das Panel endet nicht genau an der Leiste")
	var leiste: Control = haupt.get_node_or_null("Row/TabRail")
	assert_true(leiste != null, "TabRail steht nicht mehr in main.tscn")
	if leiste != null:
		assert_almost_eq(leiste.custom_minimum_size.x, MAIN.RAIL_WIDTH, 0.5,
			"tab_rail.tscn und RAIL_WIDTH laufen auseinander")
	haupt.free()

## Die Fischzeile hat zwei Zusicherungen, und beide sind schon gebrochen
## worden: sie darf nicht breiter werden als das Panel (sonst schiebt sie sich
## ueber die Leiste, denn ein Container wird nicht schmaler als sein Inhalt),
## und sie muss GENAU FishRow.HEIGHT hoch bleiben -- VirtualList rechnet die
## sichtbaren Zeilen aus der Scrollposition aus und setzt ueberall dieselbe
## Hoehe voraus. Zu hohe Zeilen sind kein Schoenheitsfehler, sondern Ruckeln.
func test_the_fish_row_keeps_its_size_contract() -> void:
	Game.new_game()
	var schrift := UiTheme.build().default_font
	var laengste := 0.0
	var id: StringName = &""
	for f in Database.fish.values():
		for dev in [-0.95, 0.0, 0.95]:
			var w: float = schrift.get_string_size("✦ " + f.full_name(dev),
				HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.SCHRIFT_GROESSE).x
			if w > laengste:
				laengste = w
				id = f.id
	assert_true(id != &"", "kein Fisch in der Datenbank")
	Game.ctx.inventory.capacity = 10
	Game.ctx.inventory.fish.clear()
	var c := CaughtFish.make(id, -0.95)
	c.is_shiny = true
	Game.ctx.inventory.add(c)
	var platz := MAIN.PANEL_WIDTH - 2.0 * float(UiTheme.RAHMEN_SEITE + 2)
	var halter := Control.new()
	# Ohne das Theme misst die Zeile in Godots Standardschrift -- und die ist
	# schmaler als Silkscreen, der Test waere damit wertlos.
	halter.theme = UiTheme.build()
	halter.size = Vector2(platz, 720.0)
	(Engine.get_main_loop() as SceneTree).root.add_child(halter)
	var zeile: Control = FishRow.build(0, false)
	halter.add_child(zeile)
	var mn := zeile.get_combined_minimum_size()
	halter.free()
	assert_true(mn.x <= platz,
		"Zeile ist %d breit, im Panel sind %d" % [mn.x, platz])
	assert_almost_eq(mn.y, FishRow.HEIGHT, 0.5,
		"Zeile ist %d hoch statt %d -- VirtualList rechnet dann falsch"
			% [mn.y, FishRow.HEIGHT])

## Die Fanganzeige verschwand hinter der Kopfzeile. Beide sitzen oben, und in
## main.tscn kommt die Kopfzeile NACH der Welt -- sie wird also darueber
## gezeichnet. Ausgeloest hat es der Kontostand: mit echten Zahlen war die
## Kopfzeile 640 Punkte breit und reichte bis in die Bildmitte, wo die
## Fanganzeige steht. Der Test rechnet deshalb mit einem grossen Betrag und
## dem schmalsten Querformat, mit dem wir rechnen.
func test_the_catch_panel_never_hides_behind_the_hud() -> void:
	Game.new_game()
	Game.coins = 999999999
	var tree := Engine.get_main_loop() as SceneTree
	var halter := Control.new()
	# Ohne Theme misst beides in Godots Standardschrift -- die ist schmaler
	# als Silkscreen, der Test waere damit wertlos.
	halter.theme = UiTheme.build()
	tree.root.add_child(halter)

	var hud: Control = load("res://scenes/ui/hud.tscn").instantiate()
	halter.add_child(hud)
	hud.call("refresh")
	var kopf := hud.get_combined_minimum_size()

	var cv: Control = load("res://scenes/fishing/catch_view.tscn").instantiate()
	halter.add_child(cv)
	var panel: Control = cv.get_node("Panel")
	var panel_breite: float = maxf(panel.offset_right - panel.offset_left,
		panel.get_combined_minimum_size().x)
	var panel_oben: float = panel.offset_top
	var panel_links: float = panel.offset_left
	halter.free()

	# Die Kopfzeile sitzt 16 Punkte von links und von oben (main.gd::_layout).
	var kopf_rechts := 16.0 + kopf.x
	var kopf_unten := 16.0 + kopf.y
	# Die Fanganzeige steht links, wie die Kopfzeile -- geprueft wird also,
	# dass sie UNTER ihr beginnt.
	assert_true(panel_oben >= kopf_unten or panel_links >= kopf_rechts,
		"Kopfzeile geht bis x=%d y=%d, Fanganzeige beginnt bei x=%d y=%d"
			% [kopf_rechts, kopf_unten, panel_links, panel_oben])
	# Und sie darf nicht unter das Seitenpanel geraten, wenn das offen ist.
	# Das Panel haengt rechts; frei bleibt alles links davon.
	var frei := 1280.0 - MAIN.RAIL_WIDTH - MAIN.PANEL_WIDTH
	assert_true(panel_links + panel_breite <= frei,
		"Fanganzeige geht bis x=%d, das offene Menue beginnt bei x=%d"
			% [panel_links + panel_breite, frei])

## Und die Kopfzeile selbst darf nicht wieder ueber das halbe Bild laufen.
func test_the_hud_stays_narrow_even_with_a_huge_balance() -> void:
	Game.new_game()
	Game.coins = 999999999
	var halter := Control.new()
	halter.theme = UiTheme.build()
	(Engine.get_main_loop() as SceneTree).root.add_child(halter)
	var hud: Control = load("res://scenes/ui/hud.tscn").instantiate()
	halter.add_child(hud)
	hud.call("refresh")
	var breite := hud.get_combined_minimum_size().x
	halter.free()
	# Ein Drittel des schmalsten Querformats. Darueber deckt sie zu viel zu.
	assert_true(breite <= 1280.0 / 3.0,
		"Kopfzeile ist %d Punkte breit, erlaubt sind %d" % [breite, 1280.0 / 3.0])

## Die Fangmeldung setzt ihre Lage im CODE, weil die Anker einer Szenenwurzel
## den Export nicht ueberleben (siehe catch_toast.gd). Damit gibt es zwei
## Stellen fuer dasselbe Mass -- und genau daran ist eine Korrektur schon
## einmal wirkungslos verpufft: ich hatte nur die Szene geaendert, und im
## Spiel stand die Karte weiter mittig hinter dem Zopf.
func test_the_catch_toast_code_and_scene_agree() -> void:
	var szene: PackedScene = load("res://scenes/ui/catch_toast.tscn")
	assert_true(szene != null, "catch_toast.tscn laesst sich nicht laden")
	var karte: Control = szene.instantiate()
	var links: float = karte.offset_left
	var oben: float = karte.offset_top
	var breite: float = karte.offset_right - karte.offset_left
	var hoehe: float = karte.offset_bottom - karte.offset_top
	var soll: Rect2 = karte.RECT
	karte.free()
	assert_almost_eq(links, soll.position.x, 0.5, "linke Kante laeuft auseinander")
	assert_almost_eq(oben, soll.position.y, 0.5, "obere Kante laeuft auseinander")
	assert_almost_eq(breite, soll.size.x, 0.5, "Breite laeuft auseinander")
	assert_almost_eq(hoehe, soll.size.y, 0.5, "Hoehe laeuft auseinander")

## Und sie muss in derselben freien Spalte stehen wie die Kampfanzeige:
## links, unter der Kopfzeile, neben dem offenen Menue vorbei.
func test_the_catch_toast_stays_in_the_free_column() -> void:
	var szene: PackedScene = load("res://scenes/ui/catch_toast.tscn")
	var karte: Control = szene.instantiate()
	var soll: Rect2 = karte.RECT
	karte.free()
	var frei := 1280.0 - MAIN.RAIL_WIDTH - MAIN.PANEL_WIDTH
	assert_true(soll.position.x + soll.size.x <= frei,
		"die Karte geht bis x=%d, das offene Menue beginnt bei x=%d"
			% [soll.position.x + soll.size.x, frei])
	assert_true(soll.position.y >= 116.0,
		"die Karte beginnt bei y=%d und liegt damit in der Kopfzeile"
			% soll.position.y)
