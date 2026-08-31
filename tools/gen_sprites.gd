extends SceneTree

const OUT := "res://assets/art"

func _c(name: StringName) -> Color:
	return Palette.get_color(name)

func _new_image(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for iy in range(y, mini(y + h, img.get_height())):
		for ix in range(x, mini(x + w, img.get_width())):
			if ix >= 0 and iy >= 0:
				img.set_pixel(ix, iy, c)

func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for iy in img.get_height():
		for ix in img.get_width():
			var dx := (float(ix) + 0.5 - cx) / rx
			var dy := (float(iy) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(ix, iy, c)

func _save(img: Image, name: String) -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var path := "%s/%s.png" % [OUT, name]
	img.save_png(ProjectSettings.globalize_path(path))
	print("  ", path)

# --- Hintergrund ----------------------------------------------------------

func _background() -> void:
	var img := _new_image(320, 180)
	for y in 78:
		var t := float(y) / 78.0
		_rect(img, 0, y, 320, 1, _c(&"sky_high").lerp(_c(&"sky_low"), t))
	_rect(img, 0, 78, 320, 6, _c(&"reed_dark"))
	for y in range(84, 180):
		var t := float(y - 84) / 96.0
		_rect(img, 0, y, 320, 1, _c(&"water_light").lerp(_c(&"water_deep"), t))
	# ruhige Wasserlinien
	for i in 26:
		var y := 92 + (i * 3) % 84
		var x := (i * 37) % 300
		_rect(img, x, y, 10 + (i % 4) * 4, 1, _c(&"foam"))
	# Schilf am Ufer
	for i in 40:
		var x := (i * 8 + (i % 3) * 3) % 318
		var h := 6 + (i % 5) * 3
		_rect(img, x, 78 - h, 1, h, _c(&"reed") if i % 2 == 0 else _c(&"reed_light"))
	_save(img, "bg_lake")

## Sunset Coast. Gleiche Geometrie wie der See -- Horizont bei 78, Wasser ab
## 84 -- damit Steg, Uferkante und Wellenlinie ohne Sonderfall passen.
func _background_coast() -> void:
	var img := _new_image(320, 180)
	for y in 78:
		var t := float(y) / 78.0
		_rect(img, 0, y, 320, 1, _c(&"dusk_high").lerp(_c(&"dusk_low"), t * t))
	# tiefstehende Sonne ueber dem Horizont
	_ellipse(img, 232.0, 70.0, 13.0, 13.0, _c(&"sea_foam"))
	_rect(img, 0, 78, 320, 6, _c(&"sand_dark"))
	for y in range(84, 180):
		var t := float(y - 84) / 96.0
		_rect(img, 0, y, 320, 1, _c(&"sea_light").lerp(_c(&"sea_deep"), t))
	# Sonnenstrasse: zum Betrachter hin breiter und seltener
	for i in 30:
		var y := 88 + i * 3
		var w := 4 + i
		_rect(img, 232 - w / 2, y, w, 1, _c(&"sea_foam").lerp(_c(&"sea_light"), float(i) / 30.0))
	# Duenengras statt Schilf
	for i in 34:
		var x := (i * 9 + (i % 4) * 2) % 318
		var h := 4 + (i % 4) * 2
		_rect(img, x, 78 - h, 1, h, _c(&"sand") if i % 2 == 0 else _c(&"sand_light"))
	_save(img, "bg_coast")

## Nebelmoor bei Nacht. Gleiche Geometrie wie die anderen Zonen -- Horizont
## bei 78, Wasser ab 84 -- damit Steg, Uferkante und Wellenlinie passen.
func _background_moor() -> void:
	var img := _new_image(320, 180)
	for y in 78:
		var t := float(y) / 78.0
		_rect(img, 0, y, 320, 1, _c(&"night_high").lerp(_c(&"night_low"), t))
	# Nebelbaender: waagerecht, nach unten dichter.
	for i in 9:
		var y := 40 + i * 4
		var w := 90 + (i * 53) % 180
		var x := (i * 71) % 260
		_rect(img, x, y, w, 2, _c(&"mist").lerp(_c(&"night_low"), 0.62))
	# Irrlicht: der einzige warme Fleck im Bild.
	# Hof zuerst, Kern darueber -- andersherum uebermalt der Hof das Licht.
	_ellipse(img, 214.0, 58.0, 6.0, 6.0, _c(&"wisp").lerp(_c(&"night_low"), 0.72))
	_ellipse(img, 214.0, 58.0, 3.0, 3.0, _c(&"wisp"))
	_rect(img, 0, 78, 320, 6, _c(&"peat_dark"))
	for y in range(84, 180):
		var t := float(y - 84) / 96.0
		_rect(img, 0, y, 320, 1, _c(&"bog_light").lerp(_c(&"bog_deep"), t))
	# Spiegelung des Irrlichts auf dem Wasser, aufgebrochen.
	for i in 7:
		var y := 90 + i * 6
		_rect(img, 210 - i, y, 8 + i * 2, 1, _c(&"wisp").lerp(_c(&"bog_light"), 0.55 + 0.06 * float(i)))
	# Abgestorbene Weiden und Schilfstoppeln am Ufer.
	for i in 46:
		var x := (i * 7 + (i % 5) * 2) % 318
		var h := 3 + (i % 7) * 4
		_rect(img, x, 78 - h, 1, h, _c(&"willow") if i % 3 == 0 else _c(&"peat"))
	_save(img, "bg_moor")

## Frostbucht. Polarlicht ueber Packeis, kaltes offenes Wasser.
func _background_frost() -> void:
	var img := _new_image(320, 180)
	for y in 78:
		var t := float(y) / 78.0
		_rect(img, 0, y, 320, 1, _c(&"polar_high").lerp(_c(&"polar_low"), t * t))
	# Polarlicht: senkrechte Vorhaenge, nach unten ausblendend.
	for i in 26:
		var x := (i * 13 + (i % 3) * 5) % 316
		var top := 8 + (i * 7) % 22
		var h := 26 + (i % 5) * 9
		for y in range(top, mini(top + h, 74)):
			var f := 1.0 - float(y - top) / float(h)
			_rect(img, x, y, 2, 1, _c(&"aurora").lerp(_c(&"polar_high"), 1.0 - f * 0.75))
	_rect(img, 0, 78, 320, 6, _c(&"snow"))
	for y in range(84, 180):
		var t := float(y - 84) / 96.0
		_rect(img, 0, y, 320, 1, _c(&"ice_light").lerp(_c(&"ice_deep"), t))
	# Treibende Eisschollen: hell, mit dunklerer Unterkante.
	for i in 11:
		var x := (i * 37) % 290
		var y := 92 + (i * 17) % 70
		var w := 14 + (i % 4) * 11
		_rect(img, x, y, w, 3, _c(&"ice_foam"))
		_rect(img, x, y + 3, w, 1, _c(&"snow_dark"))
	for i in 30:
		var x := (i * 11 + (i % 4) * 3) % 318
		_rect(img, x, 78 - (2 + (i % 3) * 2), 1, 2 + (i % 3) * 2, _c(&"snow_dark"))
	_save(img, "bg_frost")

## Tiefe Zisterne. Kein Himmel, nur Gewoelbe und Fackelschein.
func _background_cistern() -> void:
	var img := _new_image(320, 180)
	for y in 78:
		var t := float(y) / 78.0
		_rect(img, 0, y, 320, 1, _c(&"vault_high").lerp(_c(&"vault_low"), t))
	# Saeulen und Boegen, nach hinten dunkler.
	for i in 5:
		var x := 18 + i * 66
		_rect(img, x, 22, 10, 56, _c(&"stone") if i % 2 == 0 else _c(&"stone_light"))
		_rect(img, x - 3, 18, 16, 5, _c(&"stone_light"))
	# Fackeln zwischen den Saeulen.
	for i in 4:
		var x := 51 + i * 66
		_ellipse(img, float(x), 40.0, 5.0, 5.0, _c(&"torch").lerp(_c(&"vault_low"), 0.7))
		_ellipse(img, float(x), 40.0, 2.0, 2.0, _c(&"torch"))
	_rect(img, 0, 78, 320, 6, _c(&"stone"))
	for y in range(84, 180):
		var t := float(y - 84) / 96.0
		_rect(img, 0, y, 320, 1, _c(&"cistern_light").lerp(_c(&"cistern_deep"), t))
	# Spiegelungen der Fackeln, senkrecht aufgebrochen.
	for i in 4:
		var x := 51 + i * 66
		for j in 6:
			_rect(img, x - 1, 88 + j * 7, 3, 1, _c(&"torch").lerp(_c(&"cistern_light"), 0.45 + 0.09 * float(j)))
	_save(img, "bg_cistern")

## Wolkensee. Ueber den Wolken; das Wasser haengt in der Luft.
func _background_sky() -> void:
	var img := _new_image(320, 180)
	for y in 78:
		var t := float(y) / 78.0
		_rect(img, 0, y, 320, 1, _c(&"sky_pale").lerp(_c(&"sky_mid"), t))
	# Wolkenbaenke: unten dichter, oben vereinzelt.
	for i in 16:
		var x := (i * 43) % 300
		var y := 12 + (i * 9) % 58
		var w := 26 + (i % 5) * 16
		_rect(img, x, y, w, 4, _c(&"cloud"))
		_rect(img, x + 3, y + 4, w - 6, 2, _c(&"cloud_dark"))
	_rect(img, 0, 78, 320, 6, _c(&"cloud_dark"))
	for y in range(84, 180):
		var t := float(y - 84) / 96.0
		_rect(img, 0, y, 320, 1, _c(&"high_light").lerp(_c(&"high_deep"), t))
	for i in 22:
		var y := 90 + (i * 4) % 84
		var x := (i * 29) % 296
		_rect(img, x, y, 8 + (i % 5) * 5, 1, _c(&"cloud"))
	for i in 34:
		var x := (i * 9 + (i % 3) * 4) % 318
		_rect(img, x, 78 - (2 + (i % 4) * 2), 1, 2 + (i % 4) * 2, _c(&"cloud"))
	_save(img, "bg_sky")

## Sternensee. Kein Ufer, kein Himmel -- das Licht kommt von unten.
func _background_void() -> void:
	var img := _new_image(320, 180)
	for y in 78:
		var t := float(y) / 78.0
		_rect(img, 0, y, 320, 1, _c(&"void_high").lerp(_c(&"void_low"), t))
	# Sterne: gestreut, unterschiedlich hell.
	for i in 90:
		var x := (i * 53 + (i % 7) * 11) % 318
		var y := (i * 29 + (i % 5) * 7) % 76
		var c := _c(&"star") if i % 4 == 0 else _c(&"star").lerp(_c(&"void_low"), 0.55)
		img.set_pixel(x, y, c)
	# Nebelschwade quer durchs Bild.
	for i in 40:
		var x := (i * 8) % 316
		var y := 26 + int(sin(float(i) * 0.4) * 9.0)
		_rect(img, x, y, 6, 3, _c(&"nebula").lerp(_c(&"void_high"), 0.6))
	_rect(img, 0, 78, 320, 6, _c(&"void_low"))
	for y in range(84, 180):
		var t := float(y - 84) / 96.0
		_rect(img, 0, y, 320, 1, _c(&"void_light").lerp(_c(&"void_deep"), t))
	# Licht von unten: helle Punkte, die nach oben schwaecher werden.
	for i in 46:
		var x := (i * 41 + (i % 6) * 9) % 318
		var y := 88 + (i * 17) % 88
		var f := 1.0 - float(y - 88) / 88.0
		img.set_pixel(x, y, _c(&"void_foam").lerp(_c(&"void_deep"), 1.0 - f))
	_save(img, "bg_void")

func _dock() -> void:
	var img := _new_image(64, 24)
	_rect(img, 0, 0, 64, 6, _c(&"wood_light"))
	_rect(img, 0, 6, 64, 3, _c(&"wood"))
	for i in 4:
		_rect(img, 6 + i * 16, 9, 4, 15, _c(&"wood_dark"))
	_save(img, "dock")

# --- Charakterebenen ------------------------------------------------------
# Drei Frames nebeneinander: 0 ruhig, 1 Ausholen, 2 Wurf.

const FRAME := 32
const FRAMES := 3

func _char_sheet() -> Image:
	return _new_image(FRAME * FRAMES, FRAME)

func _arm_offset(frame: int) -> int:
	return [0, -3, 4][frame]

func _skin(index: int) -> void:
	var tone: StringName = [&"skin_1", &"skin_2", &"skin_3"][index]
	var img := _char_sheet()
	for f in FRAMES:
		var ox := f * FRAME
		_rect(img, ox + 12, 6, 8, 8, _c(tone))          # Kopf
		_rect(img, ox + 13, 14, 6, 10, _c(tone))        # Rumpf
		_rect(img, ox + 19, 15 + _arm_offset(f), 3, 7, _c(tone))  # Wurfarm
		_rect(img, ox + 10, 16, 3, 6, _c(tone))         # Ruhearm
	_save(img, "char_skin_%d" % index)

func _hair(index: int) -> void:
	var tone: StringName = [&"hair_dark", &"hair_warm", &"hair_pale"][index]
	var img := _char_sheet()
	for f in FRAMES:
		var ox := f * FRAME
		_rect(img, ox + 11, 4, 10, 4, _c(tone))
		_rect(img, ox + 11, 8, 2, 4, _c(tone))
		if index == 2:
			_rect(img, ox + 19, 8, 2, 6, _c(tone))
	_save(img, "char_hair_%d" % index)

func _shirt(index: int) -> void:
	var tone: StringName = [&"cloth_red", &"cloth_blue", &"cloth_green"][index]
	var img := _char_sheet()
	for f in FRAMES:
		var ox := f * FRAME
		_rect(img, ox + 12, 14, 8, 7, _c(tone))
		_rect(img, ox + 19, 15 + _arm_offset(f), 3, 4, _c(tone))
		_rect(img, ox + 10, 16, 3, 4, _c(tone))
	_save(img, "char_shirt_%d" % index)

func _pants(index: int) -> void:
	var tone: StringName = [&"cloth_grey", &"wood_dark"][index]
	var img := _char_sheet()
	for f in FRAMES:
		var ox := f * FRAME
		_rect(img, ox + 13, 21, 6, 6, _c(tone))
		_rect(img, ox + 13, 27, 2, 3, _c(&"outline"))
		_rect(img, ox + 17, 27, 2, 3, _c(&"outline"))
	_save(img, "char_pants_%d" % index)

func _hat(index: int) -> void:
	var img := _char_sheet()
	if index > 0:
		var tone: StringName = [&"cloth_grey", &"reed", &"accent"][index]
		for f in FRAMES:
			var ox := f * FRAME
			_rect(img, ox + 9, 3, 14, 2, _c(tone))
			_rect(img, ox + 12, 0, 8, 3, _c(tone))
	_save(img, "char_hat_%d" % index)

## Die Rute lief von x=21 bis x=34 -- der Rahmen ist aber 32 breit. Sie wurde
## dadurch vorne abgeschnitten UND blutete in den naechsten Rahmen aus, was
## beim Wurf als zweite, falsche Rute zu sehen war. Jetzt passt sie hinein.
const ROD_START := 17
const ROD_LENGTH := 14

func _rod() -> void:
	var img := _char_sheet()
	for f in FRAMES:
		var ox := f * FRAME
		var lift := _arm_offset(f)
		for i in ROD_LENGTH:
			_rect(img, ox + ROD_START + i, 16 + lift - i, 1, 1, _c(&"wood_light"))
	_save(img, "char_rod_0")

# --- Fische ---------------------------------------------------------------

func _fish_sprite(id: StringName, body: Color, fin: Color) -> void:
	var img := _new_image(32, 16)
	_ellipse(img, 14.0, 8.0, 10.0, 5.0, body)
	# Schwanz
	for i in 6:
		_rect(img, 24 + i, 8 - i / 2 - 1, 1, 2 + i, fin)
	# Rückenflosse
	_rect(img, 11, 2, 7, 2, fin)
	# Auge
	img.set_pixel(7, 7, _c(&"outline"))
	_save(img, "fish_%s" % id)

	var sil := _new_image(32, 16)
	for y in 16:
		for x in 32:
			if img.get_pixel(x, y).a > 0.0:
				sil.set_pixel(x, y, _c(&"shadow"))
	_save(sil, "fish_%s_silhouette" % id)

func _fishes() -> void:
	# Farbe deterministisch aus der ID: jede Art sieht stabil eigen aus.
	# get_node statt "Database" direkt: das Einstiegsskript kompiliert
	# komplett, bevor Autoloads im Baum stehen, sonst Compile-Fehler.
	var database := root.get_node("Database")
	# Sortiert: Dictionary-Reihenfolge folgt der Ordner-Auflistung des
	# Dateisystems, die ist nicht garantiert stabil zwischen Geraeten/CI.
	var ids: Array = database.fish.keys()
	ids.sort()
	for id in ids:
		var f: FishData = database.fish[id]
		var h := int(String(f.id).hash())
		var hue := float(absi(h) % 1000) / 1000.0
		var body := Color.from_hsv(hue, 0.35, 0.72)
		var fin := body.darkened(0.28)
		if f.is_secret:
			body = _c(&"accent")
			fin = _c(&"wood_dark")
		_fish_sprite(f.id, body, fin)

# --- Kleinkram ------------------------------------------------------------

func _orb() -> void:
	var img := _new_image(16, 16)
	_ellipse(img, 8.0, 8.0, 7.0, 7.0, _c(&"accent"))
	_ellipse(img, 8.0, 8.0, 4.5, 4.5, _c(&"foam"))
	_save(img, "orb")

func _bobber() -> void:
	var img := _new_image(8, 8)
	_ellipse(img, 4.0, 4.0, 3.5, 3.5, _c(&"cloth_red"))
	_rect(img, 0, 4, 8, 4, _c(&"foam"))
	_save(img, "bobber")

func _init() -> void:
	# Wartet auf die Autoloads — _fishes() braucht Database. Siehe die
	# gleichlautende Anmerkung in tests/run_tests.gd.
	await process_frame
	print("Hintergrund")
	_background()
	_background_coast()
	_background_moor()
	_background_frost()
	_background_cistern()
	_background_sky()
	_background_void()
	_dock()
	print("Charakter")
	for i in 3:
		_skin(i)
		_hair(i)
		_shirt(i)
	for i in 2:
		_pants(i)
	for i in 3:
		_hat(i)
	_rod()
	print("Fische")
	_fishes()
	print("Kleinkram")
	_orb()
	_bobber()
	print("fertig")
	quit(0)
