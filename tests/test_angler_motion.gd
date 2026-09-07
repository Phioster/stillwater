extends TestCase

## Die Formeln stehen zweimal: in Python fuer die Vorschau (tools/wurf_lauf.py)
## und in scenes/fishing/angler.gd fuers Spiel. Das ist bewusst in Kauf
## genommen -- es sind fuenf Zeilen Arithmetik ohne Pixelzugriff. Damit sie
## nicht auseinanderlaufen, legt das Bauwerkzeug die Zahlen der Vorschau in
## AnglerParts ab, und diese Tests rechnen sie nach. Laufen sie auseinander,
## atmet die Figur im Spiel anders als in der Vorschau -- und die Vorschau ist
## das, was der Mensch abnimmt.

func _angler() -> Node2D:
	## TestCase erbt von RefCounted und hat kein get_tree(). Der Baum kommt
	## deshalb ueber die Hauptschleife -- wie in tests/test_cosmetics.gd.
	var a: Node2D = load("res://scenes/fishing/angler.tscn").instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(a)
	return a

func test_der_atem_stimmt_mit_der_vorschau_ueberein() -> void:
	var a := _angler()
	for i in AnglerParts.BREATH_STEPS:
		var t := float(i) / float(AnglerParts.BREATH_STEPS)
		assert_eq(a.breath_at(t), AnglerParts.BREATH_REF[i],
			"Schritt %d: Atem und Zopf laufen auseinander" % i)
	a.free()

func test_der_beinschwung_stimmt_mit_der_vorschau_ueberein() -> void:
	var a := _angler()
	for i in AnglerParts.LEG_STEPS:
		var t := float(i) / float(AnglerParts.LEG_STEPS)
		assert_eq(a.leg_at(4, t), AnglerParts.LEG_REF[i],
			"Schritt %d: der Beinschwung laeuft auseinander" % i)
	a.free()

## Jeder Zustand, den die Bewegung erreicht, muss ein Blatt haben. Das ist
## dieselbe Zusicherung wie in tools/tests/test_teile_bauen.py, nur von der
## anderen Seite: dort wird aufgezaehlt, hier wird gefahren.
func test_kein_zustand_ohne_blatt() -> void:
	var a := _angler()
	for i in AnglerParts.BREATH_STEPS:
		var t := float(i) / float(AnglerParts.BREATH_STEPS)
		var b: Vector2i = a.breath_at(t)
		assert_true(AnglerParts.zopf_index(b.x, b.y, 0) >= 0,
			"Ruhe, Schritt %d: %s fehlt" % [i, b])
		for f in AnglerParts.CAST_ZOPF.size():
			var w: int = b.y + int(AnglerParts.CAST_ZOPF[f])
			var s: int = int(AnglerParts.CAST_HEAD[f])
			assert_true(AnglerParts.zopf_index(b.x, w, s) >= 0,
				"Wurf %d bei Schritt %d: %d/%d/%d fehlt" % [f, i, b.x, w, s])
	a.free()

func test_der_beinausschlag_bleibt_im_gebackenen_bereich() -> void:
	var a := _angler()
	for spread in range(2, 7):
		for i in AnglerParts.LEG_STEPS:
			var v: int = a.leg_at(spread, float(i) / float(AnglerParts.LEG_STEPS))
			assert_true(AnglerParts.LEG_SPREADS.has(v),
				"Weite %d, Schritt %d: %d ist nicht gebacken" % [spread, i, v])
	for f in AnglerParts.CAST_LEGS.size():
		assert_true(AnglerParts.LEG_SPREADS.has(int(AnglerParts.CAST_LEGS[f])),
			"Wurfbild %d: Beinwert nicht gebacken" % f)
	a.free()

## Das Blinzeln laeuft halb, zu, halb -- in dieser Reihenfolge und mit diesen
## Dauern. Die Zuordnung von Restzeit auf Phase ist von Hand geschrieben und
## laeuft rueckwaerts durch die Liste; ohne Probe waere sie still falsch, und
## ein Blinzeln, das mit dem geschlossenen Auge anfaengt, sieht aus wie ein
## Zucken.
func test_das_blinzeln_laeuft_halb_zu_halb() -> void:
	var a := _angler()
	var ganz := 0.0
	for ph in a.BLINK_PHASES:
		ganz += ph
	var gesehen: Array[StringName] = []
	# Das Blinzeln von Hand ausloesen, statt auf den Zufall zu warten.
	a._blink_left = ganz
	var t := 0.0
	while t < ganz:
		var auge: StringName = a._blink(0.005)
		if gesehen.is_empty() or gesehen[gesehen.size() - 1] != auge:
			gesehen.append(auge)
		t += 0.005
	assert_eq(gesehen, [&"half", &"closed", &"half"] as Array[StringName],
		"das Blinzeln laeuft in dieser Folge: %s" % [gesehen])
	a.free()

## Ausserhalb des Blinzelns ist das Auge offen -- und es blinzelt nicht in
## jedem Bild, sondern hoechstens alle BLINK_MIN Sekunden.
func test_zwischen_den_blinzlern_ist_das_auge_offen() -> void:
	var a := _angler()
	a._blink_left = 0.0
	a._blink_in = a.BLINK_MIN
	var zu := 0
	for i in 100:
		if a._blink(0.01) != &"open":
			zu += 1
	assert_eq(zu, 0, "sie blinzelt in %d von 100 Schritten der Wartezeit" % zu)
	a.free()
