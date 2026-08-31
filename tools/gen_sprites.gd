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

## Doppelt so fein wie frueher, damit er zur Figur passt: dieselbe
## Vergroesserung gilt fuer alles in der Welt.
func _dock() -> void:
	var img := _new_image(128, 48)
	_rect(img, 0, 0, 128, 12, _c(&"wood_light"))
	# Bretterfugen -- ohne sie ist das Deck ein Farbstreifen.
	for i in 8:
		_rect(img, i * 16, 0, 1, 12, _c(&"wood"))
	_rect(img, 0, 12, 128, 6, _c(&"wood"))
	_rect(img, 0, 16, 128, 2, _c(&"wood_dark"))
	for i in 4:
		_rect(img, 12 + i * 32, 18, 8, 30, _c(&"wood_dark"))
		_rect(img, 12 + i * 32, 18, 2, 30, _c(&"wood"))
	_save(img, "dock")

# --- Charakterebenen ------------------------------------------------------
# Drei Frames nebeneinander: 0 ruhig, 1 Ausholen, 2 Wurf.
#
# SEITENANSICHT, Blick nach rechts aufs Wasser (Kunstrichtung in TODO.md:
# Anime-Maedchen im Profil, nicht die alte Frontalfigur). Im Profil ist die
# Figur schmal, dafuer liest man Pose und Wurf ueberhaupt erst -- frontal
# stand sie steif da und die Rute ragte seitlich weg.
#
# 64 Pixel je Frame. Alle Ebenen rechnen gegen dieselben Zeilen und dieselbe
# Mittelachse, sonst sitzt das Oberteil neben dem Rumpf.

const FRAME := AnglerPose.FRAME_SIZE
const FRAMES := AnglerPose.FRAMES

## Mittelachse und die Zeilen, an denen alle Ebenen haengen.
const CX := 33
const HEAD_Y := 16
const NECK_Y := 22
const CHEST_Y := 29
const WAIST_Y := 34
const HIP_Y := 41
const LEG_TOP := 45
const BOOT_Y := 56
const FEET_Y := 61

func _char_sheet() -> Image:
	return _new_image(FRAME * FRAMES, FRAME)

func _arm_offset(frame: int) -> int:
	return AnglerPose.arm_offset(frame)

## Licht und Schatten werden aus der Grundfarbe gerechnet, statt fuer jede
## Flaeche drei Palettenwerte zu fuehren: die Palette bleibt die Quelle, die
## Abstufung ist Arithmetik. Ohne sie ist jede Flaeche ein flacher Klotz.
func _light(c: Color) -> Color:
	return c.lightened(0.20)

func _shadow(c: Color) -> Color:
	return c.darkened(0.26)

## Ein Koerperteil als Rechteck: Licht auf der Sonnenseite (links, von wo das
## Abendlicht kommt), Schatten auf der Wasserseite.
func _limb(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	_rect(img, x, y, w, h, c)
	_rect(img, x, y, 1, h, _light(c))
	_rect(img, x + w - 1, y, 1, h, _shadow(c))

## Eine runde Form mit Glanzlicht oben links und dunklem Rand.
func _bulb(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	_ellipse(img, cx, cy, rx, ry, _shadow(c))
	_ellipse(img, cx - 0.5, cy - 0.5, rx - 1.0, ry - 1.0, c)
	_ellipse(img, cx - rx * 0.3, cy - ry * 0.35, rx * 0.45, ry * 0.4, _light(c))

func _erase(img: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	_ellipse(img, cx, cy, rx, ry, Color(0, 0, 0, 0))

## Der Kopf im Profil: rundes Schaedeldach, spitzes Kinn nach vorn, eine
## kleine Nasenkante. Das Auge sitzt weit vorn und ist gross -- daran haengt
## der Anime-Eindruck mehr als an allem anderen.
func _profile_head(img: Image, ox: int, c: Color) -> void:
	_bulb(img, ox + CX, HEAD_Y, 6.0, 6.5, c)
	# Kinn: hinten unten weg, vorn unten eine Spitze stehen lassen.
	_erase(img, ox + CX - 5.0, HEAD_Y + 5.0, 3.5, 3.0)
	_rect(img, ox + CX + 4, HEAD_Y + 4, 2, 2, c)
	# Nase
	_rect(img, ox + CX + 6, HEAD_Y + 1, 1, 2, c)
	# Auge: Wimpernstrich, dunkle Iris, ein Lichtpunkt.
	_rect(img, ox + CX + 2, HEAD_Y - 2, 4, 1, _c(&"outline"))
	_rect(img, ox + CX + 3, HEAD_Y - 1, 3, 3, _c(&"outline"))
	_rect(img, ox + CX + 3, HEAD_Y - 1, 1, 1, _c(&"foam"))
	# Mund, ein Pixel
	_rect(img, ox + CX + 5, HEAD_Y + 3, 1, 1, _shadow(c))

## Die ersten fuenf sind echte Hauttoene und kosten nichts -- niemand soll
## fuer sein Aussehen zahlen. Was danach kommt, ist Fantasie und kostet.
func _skin(index: int) -> void:
	var tone: StringName = [&"skin_1", &"skin_2", &"skin_3", &"skin_0", &"skin_4",
		&"skin_moss", &"skin_ice", &"skin_ash", &"skin_white"][index]
	var c := _c(tone)
	var img := _char_sheet()
	for f in FRAMES:
		var ox := f * FRAME
		var arm := _arm_offset(f)
		_profile_head(img, ox, c)
		_limb(img, ox + CX - 2, NECK_Y, 3, 4, _shadow(c))
		# Rumpf im Profil: schmal, vorn die Brust, hinten der Ruecken.
		_bulb(img, ox + CX, CHEST_Y, 5.5, 5.0, c)
		_limb(img, ox + CX - 4, WAIST_Y, 7, 8, c)
		_bulb(img, ox + CX - 1, HIP_Y, 6.5, 4.5, c)
		# Beine: das hintere dunkler, damit die Tiefe stimmt.
		_limb(img, ox + CX - 5, LEG_TOP, 4, FEET_Y - LEG_TOP, _shadow(c))
		_limb(img, ox + CX - 1, LEG_TOP, 4, FEET_Y - LEG_TOP, c)
		# Hinterer Arm haengt am Koerper, vorderer haelt die Rute. Die Hand
		# liegt auf AnglerPose.ROD_START -- dort setzt die Rute an.
		_limb(img, ox + CX - 4, CHEST_Y - 3, 3, 11, _shadow(c))
		_limb(img, ox + CX + 1, CHEST_Y - 3 + arm, 4, 6, c)
		_limb(img, ox + CX + 4, CHEST_Y + 2 + arm, 4, 4, c)
		_bulb(img, ox + AnglerPose.ROD_START.x, AnglerPose.ROD_START.y + arm, 2.5, 2.5, c)
	_save(img, "char_skin_%d" % index)

## Die Frisuren unterscheiden sich in der Form, nicht in der Farbe -- die
## kommt aus der eigenen Kategorie und wird als Toenung darueber gelegt.
func _hair(index: int) -> void:
	var c := _c(&"hair_dark")
	var img := _char_sheet()
	for f in FRAMES:
		var ox := f * FRAME
		# Schaedeldach und Pony ueber der Stirn -- fuer alle gleich.
		_bulb(img, ox + CX - 1, HEAD_Y - 3, 6.5, 5.0, c)
		_rect(img, ox + CX + 2, HEAD_Y - 5, 5, 3, c)
		_rect(img, ox + CX + 5, HEAD_Y - 3, 2, 2, _shadow(c))
		match index:
			0:  # Kurzhaar: endet am Kiefer
				_limb(img, ox + CX - 7, HEAD_Y - 4, 4, 8, c)
			1:  # Zopf: laengeres Deckhaar, Zopf im Nacken
				_limb(img, ox + CX - 7, HEAD_Y - 4, 4, 10, c)
				_limb(img, ox + CX - 9, HEAD_Y + 5, 3, 10, c)
				_bulb(img, ox + CX - 8, HEAD_Y + 15, 2.0, 2.0, c)
			2:  # Wuschelkopf: rundum voller
				_bulb(img, ox + CX - 6, HEAD_Y - 2, 4.0, 5.0, c)
				_limb(img, ox + CX - 8, HEAD_Y - 3, 4, 9, c)
				_bulb(img, ox + CX + 4, HEAD_Y - 7, 3.0, 2.5, c)
			3:  # Pferdeschwanz: hoch gebunden, faellt nach hinten
				_limb(img, ox + CX - 7, HEAD_Y - 4, 4, 7, c)
				_bulb(img, ox + CX - 8, HEAD_Y - 6, 2.5, 2.5, c)
				_limb(img, ox + CX - 12, HEAD_Y - 5, 4, 14, c)
				_bulb(img, ox + CX - 11, HEAD_Y + 9, 2.5, 2.5, c)
			4:  # Kurzgeschoren: nur das Deckhaar
				_rect(img, ox + CX - 6, HEAD_Y - 8, 10, 3, _shadow(c))
	_save(img, "char_hair_%d" % index)

## Oberteile: Grundform ist Rumpf plus zwei Aermel, das Muster liegt darauf.
## Ohne eigenes Muster waeren mehrere davon dieselbe Flaeche in anderer Farbe.
func _shirt(index: int) -> void:
	var tone: StringName = [&"cloth_blue", &"cloth_red", &"cloth_green",
		&"cloth_ochre", &"cloth_plum", &"cloth_grey", &"leather", &"oilskin",
		&"denim"][index]
	var c := _c(tone)
	var img := _char_sheet()
	for f in FRAMES:
		var ox := f * FRAME
		var arm := _arm_offset(f)
		_bulb(img, ox + CX, CHEST_Y, 6.0, 5.5, c)
		_limb(img, ox + CX - 4, WAIST_Y, 7, 7, c)
		_limb(img, ox + CX - 4, CHEST_Y - 3, 3, 8, _shadow(c))
		_limb(img, ox + CX + 1, CHEST_Y - 3 + arm, 4, 5, c)
		match index:
			2:  # Kariert
				for y in range(CHEST_Y - 4, WAIST_Y + 7, 4):
					_rect(img, ox + CX - 5, y, 11, 1, _c(&"cloth_grey"))
			5:  # Kapuzenpulli: die Kapuze liegt im Nacken
				_bulb(img, ox + CX - 4, NECK_Y, 4.5, 3.5, c)
				_rect(img, ox + CX + 2, CHEST_Y, 1, 8, _c(&"foam"))
			6:  # Lederjacke: Kragen und Reissverschluss
				_rect(img, ox + CX - 3, CHEST_Y - 5, 7, 2, _shadow(c))
				_rect(img, ox + CX + 3, CHEST_Y - 3, 1, 12, _c(&"silver"))
			7:  # Anglerweste: aufgesetzte Taschen
				_limb(img, ox + CX, CHEST_Y + 3, 5, 6, _c(&"wood_dark"))
			8:  # Streifenpulli
				for y in range(CHEST_Y - 5, WAIST_Y + 7, 4):
					_rect(img, ox + CX - 5, y, 11, 2, _c(&"foam"))
	_save(img, "char_shirt_%d" % index)

func _pants(index: int) -> void:
	var tone: StringName = [&"cloth_grey", &"wood_dark", &"oilskin",
		&"cloth_plum", &"denim", &"cloth_red"][index]
	var c := _c(tone)
	var img := _char_sheet()
	for f in FRAMES:
		var ox := f * FRAME
		_bulb(img, ox + CX - 1, HIP_Y, 7.0, 4.5, c)
		# Die Shorts enden ueber dem Knie -- darunter schaut das Bein heraus.
		var length := 5 if index == 4 else BOOT_Y - LEG_TOP
		_limb(img, ox + CX - 5, LEG_TOP, 4, length, _shadow(c))
		_limb(img, ox + CX - 1, LEG_TOP, 4, length, c)
		# Stiefel: die Spitze zeigt nach vorn.
		_limb(img, ox + CX - 6, BOOT_Y, 7, FEET_Y - BOOT_Y, _shadow(_c(&"outline")))
		_limb(img, ox + CX - 2, BOOT_Y, 8, FEET_Y - BOOT_Y, _c(&"outline"))
		if index == 5:  # Karohose
			for y in range(LEG_TOP, BOOT_Y, 3):
				_rect(img, ox + CX - 5, y, 9, 1, _c(&"outline"))
	_save(img, "char_pants_%d" % index)

## Variante 0 bleibt leer -- das ist "ohne Hut". Der Kopfplatz traegt Huete
## UND Kopfschmuck: Hoerner, Heiligenschein und Kopfhoerer sitzen an derselben
## Stelle, also teilen sie sich einen Platz. Ein zweiter haette bei jeder
## Kombination eine neue Ueberdeckungsfrage aufgeworfen.
func _hat(index: int) -> void:
	var img := _char_sheet()
	var top := HEAD_Y - 9   # Oberkante des Kopfes samt Haar
	for f in FRAMES:
		var ox := f * FRAME
		match index:
			1:  # Kappe: Schirm nach vorn
				_limb(img, ox + CX - 6, top, 12, 5, _c(&"cloth_grey"))
				_limb(img, ox + CX + 5, top + 3, 6, 2, _c(&"cloth_grey"))
			2:  # Strohhut: breite Krempe
				_limb(img, ox + CX - 10, top + 4, 21, 2, _c(&"accent"))
				_limb(img, ox + CX - 5, top, 10, 5, _c(&"accent"))
			3:  # Suedwester: Krempe hinten lang
				_limb(img, ox + CX - 9, top + 3, 18, 3, _c(&"cloth_ochre"))
				_limb(img, ox + CX - 5, top - 1, 10, 5, _c(&"cloth_ochre"))
				_limb(img, ox + CX - 12, top + 5, 5, 3, _c(&"cloth_ochre"))
			4:  # Wollmuetze: keine Krempe, Bommel
				_limb(img, ox + CX - 6, top - 1, 12, 6, _c(&"cloth_red"))
				_bulb(img, ox + CX - 1, top - 3, 2.5, 2.0, _c(&"foam"))
			5:  # Filzhut: breite Krempe, hoher Kopf
				_limb(img, ox + CX - 10, top + 3, 20, 3, _c(&"wood_dark"))
				_limb(img, ox + CX - 5, top - 4, 10, 7, _c(&"wood_dark"))
			6:  # Teufelshoerner
				_limb(img, ox + CX - 6, top - 2, 3, 5, _c(&"cloth_red"))
				_limb(img, ox + CX + 3, top - 2, 3, 5, _c(&"cloth_red"))
				_rect(img, ox + CX - 8, top - 5, 2, 4, _c(&"cloth_red"))
				_rect(img, ox + CX + 5, top - 5, 2, 4, _c(&"cloth_red"))
			7:  # Ziegenhoerner: nach hinten gebogen
				_limb(img, ox + CX - 6, top - 3, 4, 4, _c(&"bone"))
				_limb(img, ox + CX + 2, top - 3, 4, 4, _c(&"bone"))
				_limb(img, ox + CX - 10, top - 2, 4, 4, _c(&"bone"))
				_rect(img, ox + CX - 12, top + 2, 3, 4, _c(&"bone"))
			8:  # Heiligenschein: schwebt frei ueber dem Kopf
				_ellipse(img, ox + CX, top - 4, 7.5, 2.5, _c(&"accent"))
				_erase(img, ox + CX, top - 4, 5.0, 1.2)
			9:  # Kopfhoerer: Buegel oben, Muschel am Ohr
				_limb(img, ox + CX - 6, top - 1, 12, 2, _c(&"outline"))
				_limb(img, ox + CX - 3, top + 5, 5, 7, _c(&"outline"))
				_rect(img, ox + CX - 2, top + 7, 3, 3, _c(&"cloth_blue"))
			10:  # Eimerhut: gerade Krempe, hoher Topf
				_limb(img, ox + CX - 9, top + 4, 18, 3, _c(&"reed"))
				_limb(img, ox + CX - 5, top - 2, 11, 6, _c(&"reed"))
	_save(img, "char_hat_%d" % index)

## Geometrie aus AnglerPose, nicht hier: sie stand doppelt, und beim
## Verschieben der Rute wanderte die Schnur nicht mit.
func _rod(index: int) -> void:
	var tone: StringName = [&"wood_light", &"wood_dark", &"silver"][index]
	var img := _char_sheet()
	for f in FRAMES:
		var ox := f * FRAME
		for i in AnglerPose.ROD_LENGTH:
			var p := AnglerPose.rod_pixel(f, i)
			# Der Griff bleibt Holz, egal woraus die Rute ist.
			var c: Color = _c(&"wood_dark") if i < 4 else _c(tone)
			# Zwei Pixel stark -- ausser der Spitze: hinter ihr muss der
			# Rahmen leer bleiben, sonst zeigt die Schnur ins Nichts
			# (tests/test_sprite_assets.gd).
			if i == AnglerPose.ROD_LENGTH - 1:
				_rect(img, ox + p.x, p.y, 1, 1, c)
			else:
				_rect(img, ox + p.x, p.y, 2, 2, c)
	_save(img, "char_rod_%d" % index)

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

## Besucher am Steg. Bewusst KEINE Maus und keine Möwe: die Mechanik ist eine
## Idee, eine bestimmte Figur ist es nicht. Ein Waschbär lebt am Wasser und
## greift Dinge mit den Händen, ein Rabe bringt wirklich Sachen zu Menschen,
## die ihn füttern — beides passt besser als geborgte Figuren.
func _visitors() -> void:
	# Waschbär: Körper, dunkle Augenbinde, geringelter Schwanz.
	var coon := _new_image(18, 13)
	_ellipse(coon, 9.0, 8.0, 6.0, 4.0, _c(&"fur"))
	_ellipse(coon, 4.0, 5.0, 3.5, 3.0, _c(&"fur_light"))
	_rect(coon, 1, 4, 7, 2, _c(&"fur_dark"))
	coon.set_pixel(2, 4, _c(&"outline"))
	coon.set_pixel(6, 4, _c(&"outline"))
	_rect(coon, 1, 2, 2, 2, _c(&"fur_dark"))
	_rect(coon, 6, 2, 2, 2, _c(&"fur_dark"))
	for i in 6:
		_rect(coon, 13 + i / 2, 9 - i, 2, 1, _c(&"fur_dark") if i % 2 == 0 else _c(&"fur_light"))
	_rect(coon, 5, 11, 2, 2, _c(&"fur_dark"))
	_rect(coon, 10, 11, 2, 2, _c(&"fur_dark"))
	_save(coon, "trader")

	# Rabe mit einem Bündel im Schnabel.
	var raven := _new_image(18, 15)
	_ellipse(raven, 10.0, 8.0, 5.0, 4.0, _c(&"raven"))
	_ellipse(raven, 11.0, 7.0, 3.0, 2.0, _c(&"raven_sheen"))
	_ellipse(raven, 5.0, 5.0, 3.0, 2.5, _c(&"raven"))
	_rect(raven, 0, 5, 3, 2, _c(&"beak"))
	raven.set_pixel(5, 4, _c(&"star"))
	for i in 5:
		_rect(raven, 13 + i / 2, 6 + i, 2, 1, _c(&"raven"))
	_rect(raven, 8, 12, 2, 3, _c(&"beak"))
	_rect(raven, 11, 12, 2, 3, _c(&"beak"))
	# Das Bündel, das er mitgebracht hat.
	_rect(raven, 0, 8, 5, 5, _c(&"wood"))
	_rect(raven, 0, 8, 5, 1, _c(&"wood_light"))
	_rect(raven, 2, 8, 1, 5, _c(&"cloth_red"))
	_save(raven, "raven")

# --- Kleinkram ------------------------------------------------------------

func _orb() -> void:
	var img := _new_image(16, 16)
	_ellipse(img, 8.0, 8.0, 7.0, 7.0, _c(&"accent"))
	_ellipse(img, 8.0, 8.0, 4.5, 4.5, _c(&"foam"))
	_save(img, "orb")

func _bobber() -> void:
	var img := _new_image(16, 16)
	_bulb(img, 8.0, 8.0, 7.0, 7.0, _c(&"cloth_red"))
	_rect(img, 0, 8, 16, 8, _c(&"foam"))
	_rect(img, 0, 8, 16, 1, _c(&"outline"))
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
	_visitors()
	_dock()
	print("Charakter")
	for i in 9:
		_skin(i)
	for i in 5:
		_hair(i)
	for i in 9:
		_shirt(i)
	for i in 11:
		_hat(i)
	for i in 6:
		_pants(i)
	for i in 3:
		_rod(i)
	print("Fische")
	_fishes()
	print("Kleinkram")
	_orb()
	_bobber()
	print("fertig")
	quit(0)
