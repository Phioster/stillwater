## Die Anglerin. Wird aus beweglichen Teilen zusammengesetzt statt als
## fertige Bilderreihe gezeigt -- nur so kann die Weite des Beinschwungs je
## Schwung neu gezogen werden. Rahmen und Anker je Teil stehen gemessen in
## AnglerParts, das tools/teile_bauen.py erzeugt.
extends Node2D

## Reihenfolge innerhalb eines Teils: Haut, Hose, Pullover, Haar,
## Grundebene. "base" traegt Umriss, Auge und Kragen und wird nie
## umgefaerbt -- deshalb liegt es ueber der Kleidung. Die Ebenen eines Teils
## ueberschneiden sich nicht (tests/test_character_layers.gd), die
## Reihenfolge ist also eine Frage der Lesbarkeit und keine der Deckung.
const LAYER_ORDER: Array[StringName] = [&"skin", &"pants", &"shirt", &"hair",
	&"base"]
## Welche Kosmetikkategorie welche Toene hat, als Namen aus core/palette.gd --
## die Hexwerte stehen dort und nicht hier ein zweites Mal.
##
## Der leere Name heisst: NICHT toenen. Variante 0 ist bei Haut, Pullover und
## Hose die gezeichnete Farbe; durch den Shader geschickt kaeme sie um bis zu
## einen Wert je Kanal verschoben heraus.
##
## Die Haarfarbe kennt diese Ausnahme nicht: es gibt keine "gezeichnete
## Haarfarbe", die man behalten wollte, also toent auch ihre Variante 0.
##
## Die Reihenfolge IST die Variantennummer der Kategorie. Eine Variante mehr
## in data/cosmetics/ verlangt einen Ton mehr hier, sonst waehlt man stumm
## dieselbe Farbe -- dagegen steht test_jede_variante_hat_einen_ton.
const TINTS := {
	&"skin": [&"", &"skin_2", &"skin_3", &"skin_0", &"skin_4", &"skin_moss",
		&"skin_ice", &"skin_ash", &"skin_white"],
	&"shirt": [&"", &"cloth_red", &"cloth_green", &"cloth_ochre", &"cloth_plum",
		&"cloth_grey", &"leather", &"oilskin", &"denim"],
	&"pants": [&"", &"wood_dark", &"oilskin", &"cloth_plum", &"denim",
		&"cloth_red"],
	&"boots": [&"", &"leather", &"wood_dark", &"cloth_red", &"cloth_grey",
		&"bone"],
	&"hair_color": [&"hair_dark", &"hair_warm", &"hair_pale", &"hair_moss",
		&"hair_snow", &"hair_teal", &"hair_violet", &"hair_pink"],
}

## Welche Ebene der Teileblaetter eine Kategorie einfaerbt. Die Stiefel haben
## ihre eigene Ebene und gehen die Hose nichts an -- deshalb sind sie eine
## eigene Kategorie. Die Grundebene traegt Umriss, Auge und Kragen und wird
## nie umgefaerbt; sie steht in keiner Zeile hier.
const TINT_LAYER := {
	&"skin": &"skin",
	&"shirt": &"shirt",
	&"pants": &"pants",
	&"boots": &"boots",
	&"hair_color": &"hair",
}

var _atem: int = 0
var _zopf: int = 0
var _seit: int = 0
var _bein: int = 0
var _auge: StringName = &"open"
var _arm: int = 0

func _ready() -> void:
	set_cosmetics(Game.cosmetics)
	if not Game.bite.is_connected(_on_bite):
		Game.bite.connect(_on_bite)
	if not Game.caught.is_connected(_on_caught):
		Game.caught.connect(_on_caught)
	if not Game.escaped.is_connected(_on_escaped):
		Game.escaped.connect(_on_escaped)
	add_to_group("angler")

func set_cosmetics(c: Dictionary) -> void:
	_load_parts()
	_set_single(&"Hat", "char_hat", int(c.get("hat", 0)))
	_set_single(&"Rod", "char_rod", int(c.get("rod", 0)))
	for kategorie in TINTS:
		_tint(kategorie, int(c.get(String(kategorie), 0)))
	set_pose(_atem, _zopf, _seit, _bein, _auge, _arm)

## Jedes Teileblatt an sein Sprite. Die Blaetter heissen nach Teil und Ebene,
## und welche Ebene in welchem Teil ueberhaupt vorkommt, sagt AnglerParts --
## der Zopf hat kein Hemd, die Beine kein Haar.
func _load_parts() -> void:
	for name in AnglerParts.ORDER:
		var gruppe: Node2D = get_node(NodePath(String(name)))
		for ebene in AnglerParts.LAYERS[name]:
			var s: Sprite2D = gruppe.get_node(NodePath(String(ebene)))
			s.texture = TextureLoader.load_texture(
				"res://assets/art/teil_%s_%s.png" % [name, ebene])
			s.hframes = int(AnglerParts.STATES[name])

func _set_single(node: StringName, prefix: String, index: int) -> void:
	var sprite: Sprite2D = get_node(NodePath(String(node)))
	var tex := TextureLoader.load_texture(
		"res://assets/art/%s_%d.png" % [prefix, index])
	if tex != null:
		sprite.texture = tex

## Eine Kosmetikebene einfaerben -- an JEDEM Teil, das sie hat. Der Pullover
## liegt in Rumpf, Arm und fernem Arm; faerbte man nur den Rumpf, traege sie
## zwei verschiedene Aermel.
##
## Der Shader behaelt die Helligkeit und ersetzt den Farbton
## (assets/art/palette_swap.gdshader). Nachgerechnet gegen die frueher
## gebackenen Blaetter: bei Haut und Pullover kein einziger Pixel Unterschied.
func _tint(category: StringName, index: int) -> void:
	var toene: Array = TINTS[category]
	var name: StringName = toene[clampi(index, 0, toene.size() - 1)]
	var mat: ShaderMaterial = null
	if name != &"":
		mat = ShaderMaterial.new()
		mat.shader = load("res://assets/art/palette_swap.gdshader")
		mat.set_shader_parameter("tint", Palette.get_color(name))
		mat.set_shader_parameter("strength", 1.0)
	var ebene: StringName = TINT_LAYER[category]
	for teil in AnglerParts.ORDER:
		if not (AnglerParts.LAYERS[teil] as Array).has(ebene):
			continue
		(get_node(NodePath("%s/%s" % [teil, ebene])) as Sprite2D).material = mat

## Die Bewegung in Zahlen, und daraus die Bildnummern und Versaetze. Atem und
## Kopfversatz stecken NICHT in den Blaettern: sie sind Versatz der Gruppe.
## Nur die Scherungen von Zopf und Beinen sind gebacken -- eine Scherung
## verschiebt jede Zeile anders und laesst sich nicht als Position ausdruecken.
func set_pose(atem: int, zopf: int, seit: int, bein: int, auge: StringName,
		arm: int) -> void:
	_atem = atem
	_zopf = zopf
	_seit = seit
	_bein = bein
	_auge = auge
	_arm = arm
	var zopf_i := AnglerParts.zopf_index(atem, zopf, seit)
	if zopf_i < 0:
		# Darf nicht vorkommen: das Bauwerkzeug zaehlt alle erreichbaren
		# Tripel auf. Wenn doch, lieber der naechstbeste Zustand als ein
		# leerer Hinterkopf -- und eine Meldung, die den Fall benennt.
		push_error("Zopfzustand %d/%d/%d nicht gebacken" % [atem, zopf, seit])
		zopf_i = maxi(0, AnglerParts.zopf_index(atem, clampi(zopf, -2, 2), 0))
	for name in AnglerParts.ORDER:
		var gruppe: Node2D = get_node(NodePath(String(name)))
		var box: Rect2i = AnglerParts.BOX[name]
		var versatz := Vector2(box.position)
		if AnglerParts.AT_HEAD.has(name):
			versatz += Vector2(seit, atem)
		gruppe.position = versatz
		var i := 0
		match name:
			&"zopf": i = zopf_i
			&"beine": i = AnglerParts.leg_index(bein)
			&"auge": i = AnglerParts.eye_index(auge)
			&"arm": i = clampi(arm, 0, int(AnglerParts.STATES[name]) - 1)
		for ebene in AnglerParts.LAYERS[name]:
			(gruppe.get_node(NodePath(String(ebene))) as Sprite2D).frame = i
	_place_hat()
	_place_rod()

## Der Ruhelauf zaehlt in sich selbst weiter, der Wurf haengt am Zaehler des
## Kerns: eine zweite Uhr fuer den Wurf koennte davon abdriften, und dann
## stuende die Figur noch beim Ausholen, waehrend der Koeder schon im Wasser
## liegt.
##
## Ein Atemzug dauert so lange wie in der Vorschau: 32 Schritte zu 100 ms.
## Frueher standen hier neun Bilder zu drei je Sekunde -- die Zahl kam aus der
## Bilderreihe, nicht aus der Figur. Der Zopf schwingt rund zwanzig Pixel aus,
## und ein Ausschlag dieser Groesse braucht Zeit; schneller schlug er wie eine
## Peitsche.
const BREATH_TIME: float = 3.2
## Ein voller Beinschwung: 24 Schritte zu 100 ms.
const LEG_TIME: float = 2.4
## Wie weit die Beine schwingen. Im Umkehrpunkt neu gezogen -- DAS ist der
## Grund, warum im Spiel gerechnet und nicht gebacken wird. Ein fester Wert
## sieht nach Uhrwerk aus.
const LEG_SPREAD_MIN: int = 2
const LEG_SPREAD_MAX: int = 6

## Wie lange ein Blinzeln dauert und wie oft es kommt. Nicht im Atemtakt:
## ein Atemzug dauert gut drei Sekunden, so oft blinzelt niemand.
const BLINK_MIN: float = 2.5
const BLINK_MAX: float = 6.0
## Halb, zu, halb -- dieselben Zeiten wie tools/wurf_lauf.BLINZELN.
const BLINK_PHASES: Array[float] = [0.055, 0.090, 0.055]
const BLINK_EYES: Array[StringName] = [&"half", &"closed", &"half"]

var _idle_time: float = 0.0
var _leg_time: float = 0.0
var _leg_spread: int = 4
var _leg_sign: int = 0
var _blink_in: float = 3.0
var _blink_left: float = 0.0

## Atem und Zopfweite aus der Phase des Atemzugs. Dieselben Formeln wie
## tools/wurf_lauf.atem_und_zopf() -- tests/test_angler_motion.gd haelt beide
## Reihen gegeneinander.
func breath_at(t: float) -> Vector2i:
	var p := fposmod(t, 1.0)
	return Vector2i(1 if sin(TAU * p) < 0.0 else 0,
		int(round(2.0 * sin(TAU * (p - 0.12)))))

func leg_at(spread: int, t: float) -> int:
	return int(round(float(spread) * sin(TAU * fposmod(t, 1.0))))

## Der Beinschwung, und die Weite im Umkehrpunkt neu gezogen. Mittendrin
## gezogen spraenge das Bein sichtbar.
func _legs(delta: float) -> int:
	_leg_time += delta
	var t := fposmod(_leg_time / LEG_TIME, 1.0)
	var schwung := sin(TAU * t)
	var richtung := 1 if schwung >= 0.0 else -1
	if _leg_sign != 0 and richtung != _leg_sign:
		_leg_spread = randi_range(LEG_SPREAD_MIN, LEG_SPREAD_MAX)
	_leg_sign = richtung
	return leg_at(_leg_spread, t)

## Welches Auge gerade dran ist. Gibt &"open" zurueck, wenn gerade nicht
## geblinzelt wird.
func _blink(delta: float) -> StringName:
	if _blink_left > 0.0:
		_blink_left -= delta
		var rest := _blink_left
		for i in range(BLINK_PHASES.size() - 1, -1, -1):
			if rest <= BLINK_PHASES[i]:
				return BLINK_EYES[i]
			rest -= BLINK_PHASES[i]
		return BLINK_EYES[0]
	_blink_in -= delta
	if _blink_in <= 0.0:
		var ganz := 0.0
		for ph in BLINK_PHASES:
			ganz += ph
		_blink_left = ganz
		_blink_in = randf_range(BLINK_MIN, BLINK_MAX)
	return &"open"

## Wie weit der Hut von dem Platz abweicht, an dem er gemalt ist. Null
## heisst: genau dort. Rutscht ein Hut, ist das die eine Zahl, die ihn
## nachfuehrt -- fuer alle gemeinsam, denn ihre Krempen sitzen verschieden
## tief, aber alle am selben Kopf.
const HAT_OFFSET: Vector2i = Vector2i(0, 0)

## Der Hut folgt dem Kopf, ist aber kein Kind von ihm: gezeichnet wird er
## NACH den Armen, die Kopfgruppe aber davor. Sein Bild traegt ihn schon an
## der richtigen Stelle im 128er Feld; hier kommt nur die Bewegung des Kopfes
## dazu, also (Kopfversatz, Atem).
func _place_hat() -> void:
	var kopf: Node2D = get_node("kopf")
	var ruhe := Vector2(AnglerParts.BOX[&"kopf"].position)
	($Hat as Sprite2D).position = kopf.position - ruhe + Vector2(HAT_OFFSET)

## Die Rute an den Griff dieses Armzustands schieben. Sie hat ein eigenes
## Raster -- groesser als das der Figur, weil sie beim Ausholen weit
## hinausragt -- und zehn Bilder: die Ruhe teilt sich eines mit Wurfbild 0.
##
## Ein Pixel Atem: im Ruhelauf hat der Arm nur einen Zustand, die Faust steht
## also still, und ohne diesen Versatz haengt die Rute reglos an einer
## atmenden Figur. Weil die Spitze 76 Pixel entfernt liegt, wird aus dem einen
## Pixel am Griff eine sichtbare Bewegung am Ende.
const ROD_BREATH: int = 1

func _place_rod() -> void:
	var rod: Sprite2D = $Rod
	rod.frame = AnglerPose.ROD_FRAME[AnglerPose.frame_of(_arm)]
	rod.position = Vector2(AnglerPose.rod_offset(_arm)) \
		+ Vector2(0, float(_atem * ROD_BREATH))

func _process(delta: float) -> void:
	_idle_time += delta
	var atem := breath_at(_idle_time / BREATH_TIME)
	match Game.sim.state:
		FishingSim.State.CASTING:
			var left: float = clampf(Game.sim.timer / FishingSim.CAST_TIME,
				0.0, 1.0)
			var n := AnglerParts.CAST_ZOPF.size()
			var f: int = clampi(int((1.0 - left) * float(n)), 0, n - 1)
			_cast_pose(atem, f)
		FishingSim.State.FIGHT:
			# Arm vorn, Rute unter Zug -- das letzte Wurfbild.
			_cast_pose(atem, AnglerParts.CAST_ZOPF.size() - 1)
		_:
			# Stillstehen sieht tot aus: ein Atemzug hin und zurueck, die
			# Beine baumeln, und hin und wieder ein Blinzeln dazwischen.
			set_pose(atem.x, atem.y, 0, _legs(delta), _blink(delta), 0)

## Beim Werfen schwingen die Beine nach dem gemessenen Muster; Atem und Zopf
## laufen weiter, und der Kopf lehnt zurueck.
func _cast_pose(atem: Vector2i, f: int) -> void:
	set_pose(atem.x, atem.y + int(AnglerParts.CAST_ZOPF[f]),
		int(AnglerParts.CAST_HEAD[f]), int(AnglerParts.CAST_LEGS[f]),
		&"open", f + 1)

func _on_bite(_fish: FishData) -> void:
	_cast_pose(breath_at(_idle_time / BREATH_TIME),
		AnglerParts.CAST_ZOPF.size() - 1)

func _on_caught(_c: CaughtFish, _f: FishData, _d: bool, _r: bool) -> void:
	set_pose(0, 0, 0, 0, &"open", 0)

func _on_escaped(_f: FishData) -> void:
	set_pose(0, 0, 0, 0, &"open", 0)

## Die Rutenspitze in Weltkoordinaten -- fuer das aktuelle Bild. Beim Wurf
## liegt sie tiefer als im Ruhebild; eine Konstante in der Welt konnte das
## nicht abbilden, und die Schnur begann daneben.
func rod_tip() -> Vector2:
	return position + (Vector2(AnglerPose.rod_tip(_arm))
		+ Vector2(0, float(_atem * ROD_BREATH))) * scale
