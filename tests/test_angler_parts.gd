extends TestCase

## Die Figur wird aus Teilen zusammengesetzt. Jedes Teil muss an der Stelle
## sitzen, an der das Bauwerkzeug es gemessen hat -- sonst steht der Kopf
## neben dem Hals, und zwar in jedem einzelnen Bild.

func _angler() -> Node2D:
	## TestCase erbt von RefCounted und hat kein get_tree(). Der Baum kommt
	## deshalb ueber die Hauptschleife -- wie in tests/test_cosmetics.gd.
	var a: Node2D = load("res://scenes/fishing/angler.tscn").instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(a)
	return a

func test_jedes_teil_hat_seine_gruppe_mit_seinen_ebenen() -> void:
	var a := _angler()
	for name in AnglerParts.ORDER:
		var gruppe := a.get_node_or_null(NodePath(String(name)))
		assert_true(gruppe != null, "Gruppe %s fehlt" % name)
		if gruppe == null:
			continue
		for ebene in AnglerParts.LAYERS[name]:
			var sprite := gruppe.get_node_or_null(NodePath(String(ebene)))
			assert_true(sprite is Sprite2D,
				"%s/%s fehlt oder ist kein Sprite2D" % [name, ebene])
	a.free()

func test_jedes_teil_sitzt_auf_seinem_anker() -> void:
	var a := _angler()
	a.set_pose(0, 0, 0, 0, &"open", 0)
	for name in AnglerParts.ORDER:
		var gruppe: Node2D = a.get_node(NodePath(String(name)))
		var box: Rect2i = AnglerParts.BOX[name]
		assert_eq(gruppe.position, Vector2(box.position),
			"%s sitzt nicht auf seinem Anker" % name)
	a.free()

func test_die_am_kopf_haengenden_teile_gehen_mit_dem_atem_mit() -> void:
	## Ein Pixel Atem und zwei Pixel Kopfversatz: Zopf, Kopf, Hals und Auge
	## muessen beides mitmachen, der Rumpf keines von beidem.
	##
	## 1/1/-2 und nicht etwa 1/0/-2: Kopfversatz -2 gibt es nur im Wurfbild 4,
	## und dort steht der Zopf um drei weiter. Ein erfundenes Tripel liefe in
	## die Ersatzwahl und pruefte nichts.
	var a := _angler()
	a.set_pose(1, 1, -2, 0, &"open", 0)
	for name in AnglerParts.ORDER:
		var gruppe: Node2D = a.get_node(NodePath(String(name)))
		var box: Rect2i = AnglerParts.BOX[name]
		var erwartet := Vector2(box.position)
		if AnglerParts.AT_HEAD.has(name):
			erwartet += Vector2(-2, 1)
		assert_eq(gruppe.position, erwartet, "%s steht falsch" % name)
	a.free()

func test_die_blaetter_haengen_an_den_sprites() -> void:
	var a := _angler()
	a.set_pose(0, 0, 0, 0, &"open", 0)
	for name in AnglerParts.ORDER:
		var gruppe: Node2D = a.get_node(NodePath(String(name)))
		for ebene in AnglerParts.LAYERS[name]:
			var s: Sprite2D = gruppe.get_node(NodePath(String(ebene)))
			assert_true(s.texture != null, "%s/%s ohne Textur" % [name, ebene])
			assert_eq(s.hframes, int(AnglerParts.STATES[name]),
				"%s/%s: falsche Bildzahl" % [name, ebene])
			assert_false(s.centered, "%s/%s muss centered=false sein"
				% [name, ebene])
	a.free()

## Die Reihenfolge im Baum IST die Zeichenreihenfolge. Steht sie falsch,
## liegt der Zopf ueber dem Gesicht -- und das faellt erst im Spiel auf.
func test_die_zeichenreihenfolge_stimmt() -> void:
	var a := _angler()
	var gesehen: Array[StringName] = []
	for kind in a.get_children():
		var n := StringName(kind.name)
		if AnglerParts.ORDER.has(n):
			gesehen.append(n)
	assert_eq(gesehen, AnglerParts.ORDER, "die Teile stehen falsch im Baum")
	a.free()

## Der Hut sitzt auf dem Kopf und geht mit dem Atem mit. Er ist trotzdem kein
## Kind der Kopfgruppe: gezeichnet wird er NACH den Armen, die Gruppe aber
## davor. Also folgt er ihr rechnerisch.
func test_der_hut_folgt_dem_kopf() -> void:
	var a := _angler()
	var kopf: Node2D = a.get_node("kopf")
	var hut: Sprite2D = a.get_node("Hat")
	a.set_pose(0, 0, 0, 0, &"open", 0)
	var ruhe := hut.position - kopf.position
	a.set_pose(1, 1, -2, 0, &"open", 0)
	assert_eq(hut.position - kopf.position, ruhe,
		"der Hut haelt seinen Abstand zum Kopf nicht")
	## In Ruhe sitzt er da, wo er gemalt ist; bewegt sich der Kopf um
	## (seit, atem), geht er genau so weit mit.
	assert_eq(hut.position, Vector2(-2, 1) + Vector2(a.HAT_OFFSET),
		"der Hut geht nicht mit Atem und Kopfversatz mit")
	a.free()

## Ein Bild, kein Bilderstreifen: der Hut haengt am Kopf, und der Kopf ist
## eine Gruppe mit einer Position. Die 24 gemessenen Kopfmitten in
## gen_sprites.gd waren nur noetig, solange jede Pose ein eigenes Bild war.
func test_der_hut_ist_ein_einzelnes_bild() -> void:
	var a := _angler()
	var hut: Sprite2D = a.get_node("Hat")
	assert_eq(hut.hframes, 1, "der Hut hat noch einen Bilderstreifen")
	if hut.texture != null:
		assert_eq(hut.texture.get_width(), AnglerParts.FRAME,
			"das Hutbild ist keine 128 breit")
	a.free()

## Die Rute liegt HINTER dem nahen Arm: die Faust haelt sie, also gehoert die
## Hand davor. Der Entwurf hatte sie zuletzt einsortiert; gemessen gegen
## tools/wurf_lauf.py wichen dadurch ueber die zehn Wurfbilder 13 Pixel ab,
## alle an der Faust. Mit der Rute vor dem Arm sind es null.
func test_die_rute_liegt_hinter_dem_nahen_arm() -> void:
	var a := _angler()
	var namen: Array[StringName] = []
	for kind in a.get_children():
		namen.append(StringName(kind.name))
	var rute := namen.find(&"Rod")
	var arm := namen.find(&"arm")
	var fern := namen.find(&"armfern")
	assert_true(rute >= 0 and arm >= 0 and fern >= 0,
		"Rod, arm oder armfern fehlt im Baum")
	assert_true(fern < rute, "die Rute liegt vor dem fernen Arm")
	assert_true(rute < arm, "die Rute liegt vor dem nahen Arm statt dahinter")
	a.free()
