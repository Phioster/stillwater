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
## Die Reihenfolge ist die Variantennummer der Kategorie hair_color -- ein
## Ton mehr hier verlangt eine .tres mehr, sonst zeigt die Auswahl weniger
## Farben als es gibt (dagegen steht test_every_hair_colour_has_a_tint).
const HAIR_TINTS := [&"hair_dark", &"hair_warm", &"hair_pale", &"hair_moss",
	&"hair_snow", &"hair_teal", &"hair_violet", &"hair_pink"]

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
	_tint_hair(int(c.get("hair_color", 0)))
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

## Getoent wird jedes Haarblatt -- Zopf, Kopf und die Wimper im Auge. Frueher
## war Haar EIN Sprite; jetzt liegt es in drei Teilen.
func _tint_hair(color_index: int) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/art/palette_swap.gdshader")
	mat.set_shader_parameter("tint", Palette.get_color(HAIR_TINTS[clampi(color_index, 0, HAIR_TINTS.size() - 1)]))
	mat.set_shader_parameter("strength", 1.0)
	for name in AnglerParts.ORDER:
		if not AnglerParts.LAYERS[name].has(&"hair"):
			continue
		var s: Sprite2D = get_node(NodePath("%s/hair" % name))
		s.material = mat

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
	_place_rod()

## Der Ruhelauf zaehlt in sich selbst weiter, der Wurf haengt am Zaehler des
## Kerns: eine zweite Uhr fuer den Wurf koennte davon abdriften, und dann
## stuende die Figur noch beim Ausholen, waehrend der Koeder schon im Wasser
## liegt.
## Drei Bilder je Sekunde: der Ruhelauf hat neun Schritte (Index 0-8), das macht
## drei Sekunden je Atemzug. Der Zopf schwingt rund zwanzig Pixel aus, und ein
## Ausschlag dieser Groesse braucht Zeit -- schneller schlug er wie eine Peitsche.
const IDLE_FPS: float = 3.0
## Wie lange ein Blinzeln dauert und wie oft es kommt. Nicht im Atemtakt:
## ein Atemzug dauert drei Sekunden, so oft blinzelt niemand.
const BLINK_TIME: float = 0.12
const BLINK_MIN: float = 2.5
const BLINK_MAX: float = 6.0

var _idle_time: float = 0.0
var _blink_in: float = 3.0
var _blink_left: float = 0.0

func play_state(frame: int) -> void:
	## Bleibt bis Aufgabe 3, damit die alten Aufrufer nicht brechen.
	set_pose(0, 0, 0, 0, &"open",
		0 if frame < AnglerPose.CAST_START else 1)

## Die Rute an den Griff dieser Pose schieben. Sie hat ein eigenes Raster --
## groesser als das der Figur, weil sie beim Ausholen weit hinausragt.
##
## Vorlaeufig: sie haengt noch an der alten 24er-Posengeometrie. Aufgabe 5
## stellt sie auf die elf Armzustaende um.
func _place_rod() -> void:
	var rod: Sprite2D = $Rod
	var pose := 0 if _arm == 0 else AnglerPose.CAST_START
	rod.frame = AnglerPose.ROD_FRAME[pose]
	rod.position = Vector2(AnglerPose.rod_offset(pose))

func _process(delta: float) -> void:
	match Game.sim.state:
		FishingSim.State.CASTING:
			var left: float = clampf(Game.sim.timer / FishingSim.CAST_TIME, 0.0, 1.0)
			var span := AnglerPose.FRAMES - AnglerPose.CAST_START
			play_state(AnglerPose.CAST_START + int((1.0 - left) * float(span)))
		FishingSim.State.FIGHT:
			# Arm vorn, Rute unter Zug -- das letzte Wurfbild.
			play_state(AnglerPose.FRAMES - 1)
		_:
			# Stillstehen sieht tot aus: ein Atemzug hin und zurueck, und
			# hin und wieder ein Blinzeln dazwischen.
			_idle_time += delta
			var step := int(_idle_time * IDLE_FPS) % AnglerPose.IDLE_ORDER.size()
			var pose: int = AnglerPose.IDLE_ORDER[step]
			if _blink_left > 0.0:
				_blink_left -= delta
				# Der Blinzelzwilling DIESES Ruhebildes, nicht ein fester:
				# sonst spraenge der Kopf fuer den Augenblick zurueck.
				play_state(AnglerPose.BLINK_START + pose)
				return
			_blink_in -= delta
			if _blink_in <= 0.0:
				_blink_left = BLINK_TIME
				_blink_in = randf_range(BLINK_MIN, BLINK_MAX)
			play_state(pose)

func _on_bite(_fish: FishData) -> void:
	play_state(AnglerPose.FRAMES - 1)

func _on_caught(_c: CaughtFish, _f: FishData, _d: bool, _r: bool) -> void:
	play_state(0)

func _on_escaped(_f: FishData) -> void:
	play_state(0)

## Die Rutenspitze in Weltkoordinaten -- fuer das aktuelle Bild. Beim Wurf
## liegt sie tiefer als im Ruhebild; eine Konstante in der Welt konnte das
## nicht abbilden, und die Schnur begann daneben.
func rod_tip() -> Vector2:
	var pose := 0 if _arm == 0 else AnglerPose.CAST_START
	return position + Vector2(AnglerPose.rod_tip(pose)) * scale
