extends TestCase

## Die Wolken sind Daten, keine Bilder: ihre Formen lassen sich deshalb
## pruefen, ohne eine Szene zu bauen. Geprueft wird, was man am fertigen
## Himmel nicht mehr nachmessen kann -- dass die Regenwolken WIRKLICH die
## grossen sind und dass keine Form aus ihrem Rahmen faellt.

## So hoch reicht das Schilf ueber der Wasserlinie (in Hintergrundpixeln,
## siehe den Kopf von clouds.gd). Darunter darf keine Wolke haengen.
const SCHILF_HOEHE := 28
## Der Hintergrund ist 320 Pixel breit. Eine einzelne Wolke, die breiter
## waere als ein Viertel davon, liest sich nicht mehr als Wolke.
const HIMMEL_BREITE := 320

func _alle_formen() -> Array:
	var alle: Array = []
	alle.append_array(Clouds.FORMEN)
	alle.append_array(Clouds.REGEN_FORMEN)
	return alle

## Der eigentliche Punkt der zweiten Liste.
func test_every_rain_shape_is_bigger_than_every_fair_weather_shape() -> void:
	var breiteste_klar := 0
	var hoechste_klar := 0
	for form in Clouds.FORMEN:
		breiteste_klar = maxi(breiteste_klar, Clouds._breite_von(form))
		hoechste_klar = maxi(hoechste_klar, form.size())
	for form in Clouds.REGEN_FORMEN:
		assert_true(Clouds._breite_von(form) > breiteste_klar,
			"Regenwolke %d breit, breiteste Schoenwetterwolke %d"
				% [Clouds._breite_von(form), breiteste_klar])
		assert_true(form.size() > hoechste_klar,
			"Regenwolke %d hoch, hoechste Schoenwetterwolke %d"
				% [form.size(), hoechste_klar])

## Bei klarem Wetter darf keine der grossen Baenke dabei sein.
func test_the_fair_weather_sky_uses_only_the_small_shapes() -> void:
	for i in Clouds.ZAHL_KLAR:
		assert_true(Clouds.FORMEN.has(Clouds.form_fuer(i)),
			"Wolke %d ist keine Schoenwetterform" % i)

## Und im Regen ausschliesslich die grossen -- und jede kommt auch dran,
## statt dass eine im Vorrat brachliegt.
func test_the_rain_sky_uses_every_big_shape() -> void:
	var gesehen: Array = []
	for i in range(Clouds.ZAHL_KLAR, Clouds.VORRAT):
		var form: Array = Clouds.form_fuer(i)
		assert_true(Clouds.REGEN_FORMEN.has(form),
			"Regenwolke %d ist keine Regenform" % i)
		if not gesehen.has(form):
			gesehen.append(form)
	assert_eq(gesehen.size(), Clouds.REGEN_FORMEN.size(),
		"nicht jede Regenform kommt im Vorrat vor")

## Die Kopplung Groesse/Hoehe/Tempo in _ready misst an erster und letzter
## Form der Liste -- das stimmt nur, solange sie nach Breite sortiert sind.
func test_both_shape_lists_run_from_narrow_to_wide() -> void:
	for liste in [Clouds.FORMEN, Clouds.REGEN_FORMEN]:
		var vorher := 0
		for form in liste:
			var b := Clouds._breite_von(form)
			assert_true(b >= vorher, "Form %d bricht die Reihenfolge" % b)
			vorher = b

## Jede Form ist ein Stapel luekenloser Zeilen von oben nach unten -- eine
## uebersprungene Zeile risse ein Loch mitten in die Wolke.
func test_every_shape_is_a_solid_stack_of_rows() -> void:
	for form in _alle_formen():
		for y in form.size():
			var lauf: Vector3i = form[y]
			assert_eq(lauf.y, y, "Zeile %d sitzt auf %d" % [y, lauf.y])
			assert_true(lauf.z > 0, "Zeile %d ist leer" % y)
			assert_true(lauf.x >= 0, "Zeile %d beginnt bei %d" % [y, lauf.x])

## Keine Wolke haengt bis ins Schilf und keine deckt den halben Himmel.
func test_the_biggest_shapes_still_fit_the_sky() -> void:
	for form in Clouds.REGEN_FORMEN:
		assert_true(Clouds._breite_von(form) <= HIMMEL_BREITE / 4,
			"Wolke %d breit -- mehr als ein Viertel Himmel"
				% Clouds._breite_von(form))
		# Die Reihe ist die Oberkante, die Zeilen haengen darunter.
		var unterkante: int = (Clouds.REIHE_UNTEN - 8) - (form.size() - 1)
		assert_true(unterkante > SCHILF_HOEHE,
			"tiefste Regenwolke endet auf Zeile %d, Schilf reicht bis %d"
				% [unterkante, SCHILF_HOEHE])
