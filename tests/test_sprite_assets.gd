extends TestCase

const ART_DIR := "res://assets/art"

# char_hat_0 ist die "kein Hut"-Variante (index == 0 in gen_sprites.gd::_hat)
# und deshalb absichtlich komplett transparent.
const EXPECTED_EMPTY := [&"char_hat_0.png"]

func _expected_size(filename: String) -> Vector2i:
	if filename.begins_with("bg_"):
		return Vector2i(320, 180)
	if filename == "dock.png":
		return Vector2i(64, 24)
	if filename.begins_with("char_"):
		return Vector2i(96, 32)
	if filename.begins_with("fish_"):
		return Vector2i(32, 16)
	if filename == "orb.png":
		return Vector2i(16, 16)
	if filename == "bobber.png":
		return Vector2i(8, 8)
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
## zu sehen war. Ein Bild pro Rahmen zu prüfen fängt genau diese Klasse.
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
		var frame := img.get_height()
		var frames := img.get_width() / frame
		var counts: Array[int] = []
		for f in frames:
			var n := 0
			for x in range(f * frame, (f + 1) * frame):
				for y in img.get_height():
					if img.get_pixel(x, y).a > 0.0:
						n += 1
			counts.append(n)
		checked += 1
		# Ein Element, das über den Rand läuft, hinterlässt in einem Rahmen
		# weniger und im nächsten mehr Pixel. Gleich viele heißt: es passt.
		if file == "char_rod_0.png":
			for f in range(1, counts.size()):
				assert_eq(counts[f], counts[0],
					"%s: Rahmen %d hat %d Pixel, Rahmen 0 aber %d -- läuft über den Rand"
					% [file, f, counts[f], counts[0]])
	assert_true(checked > 0, "keine Figurenbilder geprüft")

## Die Schnur muss an der Rutenspitze beginnen, nicht daneben.
func test_the_line_starts_at_the_actual_rod_tip() -> void:
	var tex := TextureLoader.load_texture("%s/char_rod_0.png" % ART_DIR)
	assert_true(tex != null)
	if tex == null:
		return
	var img := tex.get_image()
	var tip := Vector2i(-1, 99)
	for x in 32:
		for y in img.get_height():
			if img.get_pixel(x, y).a > 0.0 and y < tip.y:
				tip = Vector2i(x, y)
	# ROD_TIP ist in Weltpixeln, das Bild in Sprite-Pixeln.
	var world := load("res://scenes/fishing/world.gd")
	var expected: Vector2 = Vector2(tip) * world.PIXEL_SCALE
	assert_true(world.ROD_TIP.distance_to(expected) < world.PIXEL_SCALE * 1.5,
		"ROD_TIP zeigt auf %s, die Spitze liegt aber bei %s" % [world.ROD_TIP, expected])
