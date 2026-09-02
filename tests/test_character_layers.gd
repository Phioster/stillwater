extends TestCase

const ART_DIR := "res://assets/art"
const EBENEN := ["char_skin_0.png", "char_shirt_0.png", "char_pants_0.png",
	"char_hair_0.png", "char_base_0.png"]

## Ein Pixel gehoert genau EINER Ebene. Vorher lag derselbe Pixel in mehreren:
## der Rock steckte gleichzeitig in "hair" und in "base", weil die Zuordnung
## ueber Bildzeilen abgestimmt statt nachgeschlagen wurde.
func test_die_ebenen_ueberlappen_sich_nirgends() -> void:
	var bilder: Array[Image] = []
	for n in EBENEN:
		var tex := TextureLoader.load_texture("%s/%s" % [ART_DIR, n])
		assert_true(tex != null, "%s nicht ladbar" % n)
		if tex == null:
			return
		bilder.append(tex.get_image())
	var doppelt := 0
	for y in bilder[0].get_height():
		for x in bilder[0].get_width():
			var treffer := 0
			for img in bilder:
				if img.get_pixel(x, y).a > 0.0:
					treffer += 1
			if treffer > 1:
				doppelt += 1
	assert_eq(doppelt, 0, "%d Pixel liegen in mehr als einer Ebene" % doppelt)

## Die Grundebene traegt Umriss und Gesichtszuege -- nicht die halbe Figur.
func test_die_grundebene_ist_nicht_die_halbe_figur() -> void:
	var gesamt := 0
	var basis := 0
	for n in EBENEN:
		var tex := TextureLoader.load_texture("%s/%s" % [ART_DIR, n])
		if tex == null:
			continue
		var img := tex.get_image()
		var sichtbar := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					sichtbar += 1
		gesamt += sichtbar
		if n == "char_base_0.png":
			basis = sichtbar
	assert_true(gesamt > 0, "keine Figurenpixel gefunden")
	assert_true(float(basis) / float(gesamt) < 0.35,
		"die Grundebene traegt %.0f%% der Figur" % (100.0 * float(basis) / float(gesamt)))
