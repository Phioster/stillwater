extends TestCase

const ART_DIR := "res://assets/art"

# char_hat_0 ist die "kein Hut"-Variante (index == 0 in gen_sprites.gd::_hat)
# und deshalb absichtlich komplett transparent.
const EXPECTED_EMPTY := [&"char_hat_0.png"]

func _expected_size(filename: String) -> Vector2i:
	if filename.begins_with("bg_"):
		return Vector2i(320, 180)
	if filename == "dock.png":
		return Vector2i(512, 192)
	if filename.begins_with("char_"):
		return Vector2i(AnglerPose.FRAME_SIZE * AnglerPose.FRAMES, AnglerPose.FRAME_SIZE)
	if filename.begins_with("fish_"):
		return Vector2i(32, 16)
	if filename == "raven.png":
		return Vector2i(18, 15)
	if filename == "trader.png":
		return Vector2i(18, 13)
	if filename == "orb.png":
		return Vector2i(16, 16)
	if filename == "bobber.png":
		return Vector2i(64, 64)
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

## Die berechnete Rutenspitze muss in JEDEM Bild auf echte Rutenpixel zeigen.
## Jede Pose hat ihren eigenen Griff und ihre eigene Richtung -- eine feste
## Konstante konnte das nie treffen, und die Schnur hing in der Luft.
func test_the_rod_tip_is_where_the_pixels_are_in_every_frame() -> void:
	var tex := TextureLoader.load_texture("%s/char_rod_0.png" % ART_DIR)
	assert_true(tex != null)
	if tex == null:
		return
	var img := tex.get_image()
	for f in AnglerPose.FRAMES:
		var tip := AnglerPose.rod_tip(f)
		var px := Vector2i(f * AnglerPose.FRAME_SIZE + tip.x, tip.y)
		assert_true(px.x >= 0 and px.x < img.get_width() and px.y >= 0 and px.y < img.get_height(),
			"Bild %d: die Spitze %s liegt ausserhalb" % [f, tip])
		assert_true(img.get_pixel(px.x, px.y).a > 0.0,
			"Bild %d: an der berechneten Spitze %s ist keine Rute" % [f, tip])
		# Und der Griff liegt an der Hand, nicht irgendwo im Rahmen.
		var grip := AnglerPose.rod_grip(f)
		var gp := Vector2i(f * AnglerPose.FRAME_SIZE + grip.x, grip.y)
		assert_true(img.get_pixel(gp.x, gp.y).a > 0.0,
			"Bild %d: am Griff %s ist keine Rute" % [f, grip])

## Die Rute muss in jedem Bild vollstaendig in ihren Rahmen passen -- sonst
## blutet sie in den naechsten und ist dort als zweite Rute zu sehen.
func test_the_rod_fits_inside_its_frame_in_every_frame() -> void:
	var limit := float(AnglerPose.FRAME_SIZE - 1)
	for f in AnglerPose.FRAMES:
		for i in 33:
			var p := AnglerPose.rod_point(f, float(i) / 32.0)
			assert_between(p.x, 2.0, limit - 2.0,
				"Bild %d: die Rute laeuft waagerecht aus dem Rahmen (%s)" % [f, p])
			assert_between(p.y, 2.0, limit - 2.0,
				"Bild %d: die Rute laeuft senkrecht aus dem Rahmen (%s)" % [f, p])
