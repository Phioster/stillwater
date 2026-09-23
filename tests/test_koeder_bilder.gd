extends TestCase

## Jeder Koeder hat ein Symbol fuer die Listen und ein Bild fuer den Haken --
## sonst haengt am Haken stumm die Teichmade (world.gd faellt auf sie zurueck).

func _silhouette(pfad: String) -> Vector3i:
	var tex := TextureLoader.load_texture(pfad)
	if tex == null:
		return Vector3i(-1, -1, 0)
	var img := tex.get_image()
	var voll := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				voll += 1
	return Vector3i(img.get_width(), img.get_height(), voll)

func test_jeder_koeder_hat_ein_symbol() -> void:
	assert_true(Database.baits.size() >= 8, "Koeder nicht geladen")
	for id in Database.baits:
		var s := _silhouette("res://assets/art/bait_icon_%s.png" % id)
		assert_eq(Vector2i(s.x, s.y), Vector2i(32, 32), "%s: Symbol fehlt oder falsche Groesse" % id)
		assert_true(s.z > 40, "%s: Symbol fast leer" % id)

func test_jeder_koeder_hat_ein_hakenbild() -> void:
	for id in Database.baits:
		var s := _silhouette("res://assets/art/bait_%s.png" % id)
		assert_true(s.x > 0, "%s: kein Hakenbild" % id)
		assert_true(s.x <= 12 and s.y <= 8, "%s: Hakenbild %dx%d zu gross" % [id, s.x, s.y])
		assert_true(s.z > 10, "%s: Hakenbild fast leer" % id)

func test_die_koederzeile_zeigt_ihr_bild() -> void:
	Game.new_game()
	var p = load("res://scenes/ui/panels/shop_panel.gd").new()
	p.nur_kaufen = false
	(Engine.get_main_loop() as SceneTree).root.add_child(p)
	p.refresh()
	var bilder: Array = p.find_children("*", "TextureRect", true, false)
	assert_true(bilder.size() >= 1, "kein Koederbild in der Ausruestung")
	p.free()
