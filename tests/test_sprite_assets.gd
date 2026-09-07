extends TestCase

const ART_DIR := "res://assets/art"

# char_hat_0 ist die "kein Hut"-Variante (index == 0 in gen_sprites.gd::_hat)
# und deshalb absichtlich komplett transparent.
const EXPECTED_EMPTY := [&"char_hat_0.png"]

## Die Teileblaetter haben je Teil ihren eigenen Rahmen -- das ist der Sinn
## der Uebung: der Zopf ist 21x33 Pixel gross, ihn als volles 128er Bild
## abzulegen verschenkt das Sechzehnfache. Die Masse kann dieser Test also
## nicht raten; sie stehen gemessen in AnglerParts, das
## tools/teile_bauen.py erzeugt.
func _teil_name(filename: String) -> StringName:
	var rest := filename.trim_prefix("teil_").trim_suffix(".png")
	for name in AnglerParts.ORDER:
		if rest.begins_with("%s_" % name):
			return name
	return &""

func _expected_size(filename: String) -> Vector2i:
	if filename.begins_with("bg_"):
		return Vector2i(320, 180)
	if filename == "dock.png":
		# 256x96 gezeichnet, plus der Versatz der hinteren Haelfte
		# (tools/steg_bauen.py: TIEFE 6 nach rechts, HOCH 2 nach oben).
		return Vector2i(262, 98)
	# Die Rute hat ihr eigenes, groesseres Raster und nur ein Bild je Winkel.
	if filename.begins_with("char_rod_"):
		return Vector2i(AnglerPose.ROD_FRAME_SIZE * AnglerPose.ROD_FRAMES,
			AnglerPose.ROD_FRAME_SIZE)
	# Der Hut wird einmal gemalt und haengt am Kopf -- kein Bilderstreifen.
	if filename.begins_with("char_hat_"):
		return Vector2i(AnglerPose.FRAME_SIZE, AnglerPose.FRAME_SIZE)
	# Die alten gebackenen Posenreihen: 24 Bilder im 128er Raster. Sie laedt
	# niemand mehr -- die Figur kommt aus teil_*.png -- und sie fallen in der
	# naechsten Aufgabe. Bis dahin die feste Zahl: die Konstante, die sie
	# beschrieb (AnglerPose.FRAMES), gibt es schon nicht mehr.
	if filename.begins_with("char_"):
		return Vector2i(AnglerPose.FRAME_SIZE * 24, AnglerPose.FRAME_SIZE)
	if filename.begins_with("teil_"):
		var name := _teil_name(filename)
		if name == &"":
			return Vector2i(-1, -1)
		var box: Rect2i = AnglerParts.BOX[name]
		return Vector2i(box.size.x * int(AnglerParts.STATES[name]), box.size.y)
	if filename.begins_with("fish_"):
		return Vector2i(32, 16)
	if filename == "raven.png":
		return Vector2i(18, 15)
	if filename == "trader.png":
		return Vector2i(18, 13)
	if filename == "orb.png":
		return Vector2i(16, 16)
	# Schwimmer und Koeder laufen im Massstab der Figur (tools/koeder_bauen.py).
	if filename == "bobber.png":
		return Vector2i(10, 13)
	if filename == "bait_pond_grub.png":
		return Vector2i(10, 6)
	return Vector2i(-1, -1)

func _count_opaque(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				n += 1
	return n

func test_all_sprites_have_correct_size_and_are_not_empty() -> void:
	var dir := DirAccess.open(ART_DIR)
	assert_true(dir != null, "assets/art fehlt oder ist nicht lesbar")
	if dir == null:
		return
	var checked := 0
	for file in dir.get_files():
		if not file.ends_with(".png"):
			continue
		checked += 1
		var expected := _expected_size(file)
		assert_true(expected.x > 0, "%s: kein bekanntes Groessenmuster" % file)
		var full_path := ProjectSettings.globalize_path("%s/%s" % [ART_DIR, file])
		var img := Image.load_from_file(full_path)
		assert_true(img != null and not img.is_empty(), "%s laesst sich nicht laden" % file)
		if img == null or img.is_empty():
			continue
		assert_eq(img.get_width(), expected.x, "%s Breite" % file)
		assert_eq(img.get_height(), expected.y, "%s Hoehe" % file)
		if file.begins_with("teil_"):
			# Ein Teileblatt kann winzig sein: teil_auge_hair.png traegt drei
			# Pixel, eine Wimper je Augenzustand. Eine feste Untergrenze passt
			# darauf nicht. Geprueft wird deshalb, was gemeint ist -- kein
			# Zustand darf leer sein, sonst fehlt der Figur dort ein Bild.
			var name := _teil_name(file)
			var w: int = AnglerParts.BOX[name].size.x
			for i in int(AnglerParts.STATES[name]):
				var n := 0
				for y in img.get_height():
					for x in w:
						if img.get_pixel(i * w + x, y).a > 0.0:
							n += 1
				assert_true(n > 0, "%s: Zustand %d ist leer" % [file, i])
			continue
		var opaque := _count_opaque(img)
		if file in EXPECTED_EMPTY:
			assert_eq(opaque, 0, "%s sollte die leere Platzhalter-Variante sein" % file)
		else:
			assert_true(opaque >= 8, "%s hat kaum sichtbare Pixel (%d)" % [file, opaque])
	assert_true(checked > 0, "keine PNGs unter assets/art gefunden")

## Die Rute lief über den Rahmenrand hinaus: sie wurde vorne abgeschnitten
## und blutete in den nächsten Rahmen, was beim Wurf als zweite, falsche Rute
## zu sehen war.
##
## Geprüft wird jetzt der Rand selbst und nicht mehr die Pixelzahl je Rahmen:
## seit jede Pose anders aussieht, sind unterschiedliche Zahlen normal.
func test_no_character_frame_bleeds_into_the_next() -> void:
	var dir := DirAccess.open(ART_DIR)
	assert_true(dir != null)
	if dir == null:
		return
	var checked := 0
	for file in dir.get_files():
		if not file.begins_with("char_") or not file.ends_with(".png"):
			continue
		var tex := TextureLoader.load_texture("%s/%s" % [ART_DIR, file])
		assert_true(tex != null, "%s nicht ladbar" % file)
		if tex == null:
			continue
		var img := tex.get_image()
		var size := img.get_height()
		var frames := img.get_width() / size
		checked += 1
		for f in frames:
			for y in size:
				for x in [f * size, (f + 1) * size - 1]:
					assert_eq(img.get_pixel(x, y).a, 0.0,
						"%s: Rahmen %d beruehrt in Zeile %d seinen Rand" % [file, f, y])
	assert_true(checked > 0, "keine Figurenbilder geprueft")

## Die Rute lief über den Rahmenrand hinaus: sie wurde vorne abgeschnitten
## und blutete in den nächsten Rahmen, was beim Wurf als zweite, falsche Rute
## zu sehen war.
##
## Geprüft wird jetzt der Rand selbst und nicht mehr die Pixelzahl je Rahmen:
## seit jede Pose anders aussieht, sind unterschiedliche Zahlen normal.
func test_no_rod_frame_bleeds_into_the_next() -> void:
	var dir := DirAccess.open(ART_DIR)
	assert_true(dir != null)
	if dir == null:
		return
	var checked := 0
	for file in dir.get_files():
		if not file.begins_with("char_rod_") or not file.ends_with(".png"):
			continue
		var tex := TextureLoader.load_texture("%s/%s" % [ART_DIR, file])
		assert_true(tex != null, "%s nicht ladbar" % file)
		if tex == null:
			continue
		var img := tex.get_image()
		var size := AnglerPose.ROD_FRAME_SIZE
		var frames := img.get_width() / size
		checked += 1
		for f in frames:
			for y in size:
				for x in [f * size, (f + 1) * size - 1]:
					assert_eq(img.get_pixel(x, y).a, 0.0,
						"%s: Rahmen %d beruehrt in Zeile %d seinen Rand" % [file, f, y])
	assert_true(checked > 0, "keine Rutenbilder geprueft")

## Die berechnete Rutenspitze muss in JEDEM Bild auf echte Rutenpixel zeigen.
## Jede Pose hat ihren eigenen Griff und ihre eigene Richtung -- eine feste
## Konstante konnte das nie treffen, und die Schnur hing in der Luft.
func test_the_rod_tip_is_where_the_pixels_are_in_every_frame() -> void:
	var tex := TextureLoader.load_texture("%s/char_rod_0.png" % ART_DIR)
	assert_true(tex != null)
	if tex == null:
		return
	var img := tex.get_image()
	for f in AnglerPose.ROD_STATES:
		# Im eigenen Rutenbild liegt der Griff IMMER auf ROD_GRIP -- die
		# Spitze also dort plus dem Versatz dieser Pose.
		var r: int = AnglerPose.ROD_FRAME[f]
		var tip: Vector2i = AnglerPose.ROD_GRIP + AnglerPose.ROD_TIP_OFF[f]
		var px := Vector2i(r * AnglerPose.ROD_FRAME_SIZE + tip.x, tip.y)
		assert_true(px.x >= 0 and px.x < img.get_width() and px.y >= 0 and px.y < img.get_height(),
			"Bild %d: die Spitze %s liegt ausserhalb" % [f, tip])
		assert_true(img.get_pixel(px.x, px.y).a > 0.0,
			"Bild %d: an der berechneten Spitze %s ist keine Rute" % [f, tip])
		# Am Griff selbst steht absichtlich nichts: dort ist die Faust, und
		# die Rute wird darunter weggenommen (tools/import_rod.py::cut_hand).
		# Rundherum muss sie aber liegen, sonst haelt die Hand nichts.
		var around := 0
		for dy in range(-14, 15):
			for dx in range(-14, 15):
				var q := Vector2i(r * AnglerPose.ROD_FRAME_SIZE + AnglerPose.ROD_GRIP.x + dx,
					AnglerPose.ROD_GRIP.y + dy)
				if img.get_pixel(q.x, q.y).a > 0.0:
					around += 1
		assert_true(around > 40,
			"Bild %d: um die Hand liegt kaum Rute (%d Pixel)" % [f, around])
func test_der_griff_sitzt_in_der_hand_jedes_armzustands() -> void:
	var tex := TextureLoader.load_texture("%s/teil_arm_skin.png" % ART_DIR)
	assert_true(tex != null, "teil_arm_skin.png nicht ladbar")
	if tex == null:
		return
	var img := tex.get_image()
	var box: Rect2i = AnglerParts.BOX[&"arm"]
	for f in AnglerPose.ROD_STATES:
		var grip: Vector2i = AnglerPose.rod_grip(f)
		var p := Vector2i(f * box.size.x + grip.x - box.position.x,
			grip.y - box.position.y)
		assert_true(p.x >= 0 and p.x < img.get_width()
			and p.y >= 0 and p.y < img.get_height(),
			"Zustand %d: der Griff %s liegt ausserhalb des Armblatts" % [f, grip])
		if p.x < 0 or p.x >= img.get_width() or p.y < 0 or p.y >= img.get_height():
			continue
		# Um den Griff herum, nicht auf ihm: dort ist die Faust, und die Rute
		# wird darunter weggenommen.
		var herum := 0
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var q := Vector2i(p.x + dx, p.y + dy)
				if q.x < 0 or q.x >= img.get_width() \
					or q.y < 0 or q.y >= img.get_height():
					continue
				if img.get_pixel(q.x, q.y).a > 0.0:
					herum += 1
		assert_true(herum > 8,
			"Zustand %d: um den Griff liegt kaum Hand (%d Pixel)" % [f, herum])

func test_die_rute_hat_elf_zustaende() -> void:
	assert_eq(AnglerPose.ROD_ANCHOR.size(), AnglerPose.ROD_STATES)
	assert_eq(AnglerPose.ROD_TIP_OFF.size(), AnglerPose.ROD_STATES)
	assert_eq(AnglerPose.ROD_FRAME.size(), AnglerPose.ROD_STATES)

## Es ist EINE gezeichnete Rute, nur anders gehalten -- alle Zustaende tragen
## dieselbe Laenge. Frueher streckte jede Wurfpose sie auf ihren eigenen
## Versatz, und sie wurde waehrend des Wurfs sichtbar laenger und kuerzer.
func test_die_rute_behaelt_ihre_laenge() -> void:
	var erste := Vector2(AnglerPose.ROD_TIP_OFF[0]).length()
	for f in AnglerPose.ROD_STATES:
		assert_between(Vector2(AnglerPose.ROD_TIP_OFF[f]).length(),
			erste - 1.5, erste + 1.5,
			"Zustand %d: die Rute ist %.1f statt %.1f Pixel lang"
			% [f, Vector2(AnglerPose.ROD_TIP_OFF[f]).length(), erste])

## Die Rute muss eine durchgehende Linie sein, kein Punktmuster. Vorne ist
## der Schaft nur noch einen Pixel dick, und eine Ein-Pixel-Linie zerfaellt
## beim Drehen: gemessen drei bis vier Loecher in den letzten zwanzig Pixeln
## jeder gedrehten Rute (tools/import_rod.py::close_gaps schliesst sie).
func test_the_rod_is_an_unbroken_line() -> void:
	var tex := TextureLoader.load_texture("%s/char_rod_0.png" % ART_DIR)
	assert_true(tex != null)
	if tex == null:
		return
	var img := tex.get_image()
	for f in AnglerPose.ROD_STATES:
		var r: int = AnglerPose.ROD_FRAME[f]
		var off := Vector2(AnglerPose.ROD_TIP_OFF[f])
		var length := off.length()
		var dir := off / length
		var holes := 0
		# Ab acht Pixel: davor liegt die Faust, dort ist absichtlich nichts.
		for k in range(8, int(length) + 1):
			var p := Vector2(AnglerPose.ROD_GRIP) + dir * float(k)
			var hit := false
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var q := Vector2i(r * AnglerPose.ROD_FRAME_SIZE + int(round(p.x)) + dx,
						int(round(p.y)) + dy)
					if q.x >= 0 and q.x < img.get_width() and q.y >= 0 and q.y < img.get_height() \
						and img.get_pixel(q.x, q.y).a > 0.0:
						hit = true
			if not hit:
				holes += 1
		assert_eq(holes, 0, "Bild %d: die Rute hat %d Loecher auf ihrer Achse" % [f, holes])
