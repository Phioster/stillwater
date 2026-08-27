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

func _rod() -> void:
	var img := _char_sheet()
	for f in FRAMES:
		var ox := f * FRAME
		var lift := _arm_offset(f)
		for i in 14:
			_rect(img, ox + 21 + i, 16 + lift - i, 1, 1, _c(&"wood_light"))
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
