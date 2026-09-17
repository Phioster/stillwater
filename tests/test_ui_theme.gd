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
	var szene: PackedScene = load("res://scenes/ui/tab_rail.tscn")
	assert_true(szene != null, "tab_rail.tscn laesst sich nicht laden")
	var leiste: Control = szene.instantiate()
	var breite: float = leiste.custom_minimum_size.x
	leiste.free()
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
