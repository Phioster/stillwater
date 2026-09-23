extends TestCase

## Jeder Trank braucht ein Bild -- ein fehlendes faellt sonst erst als leere
## Stelle in der Trankreihe auf.
func test_jeder_trank_hat_ein_bild() -> void:
	assert_true(Database.consumables.size() >= 18, "Traenke nicht geladen")
	for id in Database.consumables:
		var tex := TextureLoader.load_texture("res://assets/art/potion_%s.png" % id)
		assert_true(tex != null, "%s: kein Bild" % id)
		if tex == null:
			continue
		var img := tex.get_image()
		assert_eq(img.get_size(), Vector2i(32, 32), "%s: falsche Groesse" % id)
		var voll := 0
		for y in 32:
			for x in 32:
				if img.get_pixel(x, y).a > 0.0:
					voll += 1
		assert_true(voll > 40, "%s: fast leer (%d Pixel)" % [id, voll])
