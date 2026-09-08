extends TestCase

const ART_DIR := "res://assets/art"

## Ein Pixel gehoert genau EINER Kosmetikebene. Vorher lag derselbe Pixel in
## mehreren: der Rock steckte gleichzeitig in "hair" und in "base", weil die
## Zuordnung ueber Bildzeilen abgestimmt statt nachgeschlagen wurde.
##
## Geprueft wird jetzt je TEIL: die Blaetter sind auf ihren eigenen Rahmen
## zugeschnitten, ein gemeinsames Feld gibt es nicht mehr.
func test_die_ebenen_eines_teils_ueberlappen_sich_nirgends() -> void:
	for name in AnglerParts.ORDER:
		var bilder: Array[Image] = []
		for ebene in AnglerParts.LAYERS[name]:
			var tex := TextureLoader.load_texture(
				"%s/teil_%s_%s.png" % [ART_DIR, name, ebene])
			assert_true(tex != null, "teil_%s_%s.png nicht ladbar"
				% [name, ebene])
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
		assert_eq(doppelt, 0,
			"%s: %d Pixel liegen in mehr als einer Ebene" % [name, doppelt])

## Die Grundebene traegt Umriss, Auge und Kragen -- nicht die halbe Figur.
## Sie wird nie umgefaerbt; was in ihr liegt, bleibt bei jeder Kosmetik gleich.
## Gemessen liegt ihr Anteil bei rund einem Fuenftel.
func test_die_grundebene_ist_nicht_die_halbe_figur() -> void:
	var gesamt := 0
	var basis := 0
	for name in AnglerParts.ORDER:
		for ebene in AnglerParts.LAYERS[name]:
			var tex := TextureLoader.load_texture(
				"%s/teil_%s_%s.png" % [ART_DIR, name, ebene])
			if tex == null:
				continue
			var img := tex.get_image()
			var sichtbar := 0
			for y in img.get_height():
				for x in img.get_width():
					if img.get_pixel(x, y).a > 0.0:
						sichtbar += 1
			gesamt += sichtbar
			if ebene == &"base":
				basis += sichtbar
	assert_true(gesamt > 0, "keine Teileblaetter gefunden")
	assert_true(float(basis) / float(gesamt) < 0.35,
		"die Grundebene traegt %d von %d Pixeln" % [basis, gesamt])
