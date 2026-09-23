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
	if not Game.fight_tapped.is_connected(zug_tipp):
		Game.fight_tapped.connect(zug_tipp)
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
## Der Armzustand der Does-Pose (volle Koedertasche, siehe
## tools/rute_anheften.py). Kopf, Hals und Zopf bekommen dabei ihren eigenen
## zweiten bzw. letzten Zustand statt der Atem/Weite-Formel -- eine feste
## Neigung, keine Bewegung.
const DOES_ARM: int = 11

func set_pose(atem: int, zopf: int, seit: int, bein: int, auge: StringName,
		arm: int) -> void:
	_atem = atem
	_zopf = zopf
	_seit = seit
	_bein = bein
	_auge = auge
	_arm = arm
	var does := arm == DOES_ARM
	var zopf_i := AnglerParts.zopf_index(atem, zopf, seit)
	if zopf_i < 0 and not does:
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
			&"zopf": i = int(AnglerParts.STATES[name]) - 1 if does else zopf_i
			&"beine": i = AnglerParts.leg_index(bein)
			&"auge": i = AnglerParts.eye_index(auge)
			&"kopf", &"hals": i = 1 if does else 0
			&"arm": i = clampi(arm, 0, int(AnglerParts.STATES[name]) - 1)
		for ebene in AnglerParts.LAYERS[name]:
			(gruppe.get_node(NodePath(String(ebene))) as Sprite2D).frame = i
		match name:
			# Das gemalte Auge sitzt schon im Kopf-Blatt der Does-Pose --
			# eine zweite Auflage laege an den alten, ungedrehten Fenster-
			# koordinaten daneben.
			&"auge": gruppe.visible = not does
			# Der Zopf haengt beim Nicken vor dem Gesicht, nicht dahinter --
			# umgekehrt zu jeder anderen Haltung.
			&"zopf": gruppe.z_index = 1 if does else 0
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
## Die Does-Pose baumelt kaum -- geklammert, nicht neu gezogen, damit es
## sofort greift statt erst am naechsten Umkehrpunkt.
const DOES_LEG_SPREAD: int = 2

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
##
## Bei der Does-Pose gilt das NICHT: die Rute liegt auf dem Schoss, nicht in
## der frei schwebenden Faust -- sie darf mit dem Atem nicht mitwandern.
const ROD_BREATH: int = 1

func _rod_atem() -> int:
	return 0 if _arm == DOES_ARM else _atem * ROD_BREATH

func _place_rod() -> void:
	var rod: Sprite2D = $Rod
	rod.frame = AnglerPose.ROD_FRAME[AnglerPose.frame_of(_arm)]
	rod.position = Vector2(AnglerPose.rod_offset(_arm)) \
		+ Vector2(0, float(_rod_atem()))

func _process(delta: float) -> void:
	_idle_time += delta
	var atem := breath_at(_idle_time / BREATH_TIME)
	match Game.sim.state:
		FishingSim.State.CASTING when _absetzen \
				and Game.sim.timer > FishingSim.CAST_TIME:
			absetz_schritt(delta)
		FishingSim.State.CASTING:
			_absetzen = false
			var left: float = clampf(Game.sim.timer / FishingSim.CAST_TIME,
				0.0, 1.0)
			var n := AnglerParts.CAST_ZOPF.size()
			# Der Schwung laeuft nur im ERSTEN Teil des Wurfs ab, danach
			# steht sie und sieht dem Schwimmer nach. Frueher waren es zehn
			# Bilder ueber die ganze Sekunde -- zehn Bilder je Sekunde, also
			# sichtbar stufig, waehrend alles andere mit sechzig laeuft. Auf
			# dem kuerzeren Stueck sind es rund zwanzig.
			var schwung := clampf((1.0 - left) / CAST_SWING, 0.0, 1.0)
			_cast_pose(atem, _swing_frame(schwung, n))
		FishingSim.State.FIGHT:
			if Game.sim.rod_hits > _schuebe:
				rute_zug()
			_schuebe = Game.sim.rod_hits
			zug_schritt(delta)
			_weg_pose(atem, ZUG_WEG, _zug_stelle())
		FishingSim.State.INVENTORY_FULL:
			# Doest: Rute quer im Schoss statt hochgehalten, Auge zu. Zustand
			# 11 ist die elfte Armhaltung (siehe tools/rute_anheften.py).
			# Die Beine baumeln kaum -- ein Doeschen sitzt still, kein Schwung
			# wie im wartenden Stehen.
			set_pose(atem.x, atem.y, 0, clampi(_legs(delta), -DOES_LEG_SPREAD,
				DOES_LEG_SPREAD), &"closed", 11)
		_:
			# Stillstehen sieht tot aus: ein Atemzug hin und zurueck, die
			# Beine baumeln, und hin und wieder ein Blinzeln dazwischen.
			set_pose(atem.x, atem.y, 0, _legs(delta), _blink(delta), 0)

## Welcher Anteil des Wurfs auf den Schwung entfaellt. Der Rest ist
## Nachschwung: sie sitzt still, waehrend der Schwimmer fliegt.
const CAST_SWING: float = 0.45
## Das Bild, in dem sie am weitesten hinten steht -- der Umkehrpunkt. Steht
## so in den gemessenen Daten: bei Bild 4 sind Zopf, Kopf und Beine alle drei
## am staerksten ausgeschlagen (AnglerParts.CAST_*).
const CAST_PEAK: int = 4
## Welcher Anteil der SCHWUNGZEIT auf das Ausholen bis dorthin entfaellt.
## Vorher lief der Schwung gleichmaessig durch, Ausholen und Wurf also gleich
## schnell -- und ein Wurf, der so aussieht, sieht nach nichts aus. Ausholen
## ist eine langsame, gesammelte Bewegung, der Wurf danach ein Schnalzen.
const CAST_WINDUP: float = 0.7

## Wo im Bilderbogen der Schwung gerade steht. Die Zeit ist UNGLEICH
## verteilt: CAST_WINDUP davon geht auf das Ausholen bis zum Umkehrpunkt, der
## kurze Rest auf den Wurf.
static func _swing_frame(schwung: float, n: int) -> float:
	if schwung <= CAST_WINDUP:
		return schwung / CAST_WINDUP * float(CAST_PEAK)
	var rest := (schwung - CAST_WINDUP) / maxf(1.0 - CAST_WINDUP, 0.001)
	return float(CAST_PEAK) + rest * float(n - 1 - CAST_PEAK)

## Beim Werfen schwingen die Beine nach dem gemessenen Muster; Atem und Zopf
## laufen weiter, und der Kopf lehnt zurueck.
##
## `pos` ist eine Stelle ZWISCHEN den gemessenen Bildern. Zopf, Kopf und Beine
## werden dazwischen interpoliert und laufen dadurch stufenlos; nur die Rute
## springt weiter, die hat elf gezeichnete Winkel und keinen zwoelften.
func _cast_pose(atem: Vector2i, pos: float) -> void:
	var n := AnglerParts.CAST_ZOPF.size()
	var i := clampi(int(floor(pos)), 0, n - 1)
	var j := clampi(i + 1, 0, n - 1)
	var k := clampf(pos - float(i), 0.0, 1.0)
	var zopf := lerpf(float(AnglerParts.CAST_ZOPF[i]), float(AnglerParts.CAST_ZOPF[j]), k)
	var kopf := lerpf(float(AnglerParts.CAST_HEAD[i]), float(AnglerParts.CAST_HEAD[j]), k)
	var bein := lerpf(float(AnglerParts.CAST_LEGS[i]), float(AnglerParts.CAST_LEGS[j]), k)
	set_pose(atem.x, atem.y + int(round(zopf)), int(round(kopf)),
		int(round(bein)), &"open", i + 1)

func _on_bite(_fish: FishData) -> void:
	_zug = 0.0
	_zug_halt = 0.0
	_zitter = 0.0
	_schuebe = 0
	_weg_pose(breath_at(_idle_time / BREATH_TIME), ZUG_WEG, _zug_stelle())

func _on_caught(_c: CaughtFish, _f: FishData, _d: bool, _r: bool) -> void:
	absetzen_beginnen()

func _on_escaped(_f: FishData) -> void:
	absetzen_beginnen()

## --- Der Zug im Kampf -------------------------------------------------------
##
## Nur vorhandene Wurfbilder: 9 ist die Kampfhaltung, 8 zieht der Fisch die
## Rute zum Wasser, ueber 7 reisst sie sie auf 6 hoch. Der Weg geht nicht
## 9-8-7-6 entlang der Wurfreihe, sonst tauchte die Rute vor jedem Hochreissen
## erst ab.
const ZUG_WEG: Array[int] = [8, 9, 7, 6]
## Nach dem Kampf: wieder runter ueber 9 in die Ruhehaltung (Wurfbild 0).
const ABSETZ_WEG: Array[int] = [0, 9, 7, 6]
## So lange bleibt die Rute nach einem Tipp oben. Wer weiter tippt, haelt sie.
const ZUG_HALT: float = 0.35
## Ohne Tipp zieht die Rute allein, einmal je Rutenschub (jede Sekunde): nur
## halb hoch und kurz, damit dazwischen noch gezittert wird und der Tipp der
## staerkere Zug bleibt.
const RUTE_ZUG: float = 0.5
const RUTE_HALT: float = 0.1
const ZUG_HOCH: float = 0.12
const ZUG_RUNTER: float = 0.3
## Der letzte Schritt von der Kampfhaltung in die Ruhe.
const RUHE_ZEIT: float = 0.15
## Ein Zupfer des Fischs; der Ausschlag wird je Zupfer neu gezogen, sonst
## zappelt er wie ein Uhrwerk. Unter 0,5 bleibt die Rute auf Bild 9.
const ZITTER_TAKT: float = 0.38
const ZITTER_MIN: float = 0.3

var _zug: float = 0.0
var _zug_halt: float = 0.0
var _zug_ziel: float = 1.0
var _schuebe: int = 0
var _zitter: float = 0.0
var _zitter_weite: float = 1.0
var _absetzen: bool = false
var _ruhe: float = 0.0

func zug_tipp() -> void:
	_zug_ziel = 1.0
	_zug_halt = ZUG_HALT

func rute_zug() -> void:
	if _zug_halt > 0.0 and _zug_ziel > RUTE_ZUG:
		return
	_zug_ziel = RUTE_ZUG
	_zug_halt = RUTE_HALT

func zug_schritt(delta: float) -> void:
	if _zug_halt > 0.0:
		_zug = move_toward(_zug, _zug_ziel, delta / ZUG_HOCH)
		_zug_halt = maxf(0.0, _zug_halt - delta)
	else:
		_zug = move_toward(_zug, 0.0, delta / ZUG_RUNTER)
	_zitter += delta / ZITTER_TAKT
	if _zitter >= 1.0:
		_zitter = fmod(_zitter, 1.0)
		_zitter_weite = randf_range(ZITTER_MIN, 1.0)

## Stelle auf ZUG_WEG: 1 ist Bild 9, 3 ganz oben. Gezittert wird nur unten --
## wer die Rute hochgerissen hat, haelt sie ruhig.
func _zug_stelle() -> float:
	var hoch := smoothstep(0.0, 1.0, _zug)
	var zupf := _zitter_weite * (0.5 - 0.5 * cos(TAU * _zitter))
	return 1.0 + 2.0 * hoch - zupf * (1.0 - hoch)

## Welches Wurfbild bei dieser Hoehe und diesem Zupfer zu sehen ist.
func zug_bild(zug: float, zupf: float) -> int:
	var hoch := smoothstep(0.0, 1.0, zug)
	return _weg_bild(ZUG_WEG, 1.0 + 2.0 * hoch - zupf * (1.0 - hoch))

func absetzen_beginnen() -> void:
	_absetzen = true
	_ruhe = 0.0

## Ohne Fisch kein Zittern mehr; ein letzter Tipp haelt die Rute noch kurz
## oben, dann sinkt sie auf 9 und von dort in die Ruhe.
func absetz_schritt(delta: float) -> void:
	_zug_halt = minf(_zug_halt, ZUG_HALT)
	if _zug_halt > 0.0:
		_zug = move_toward(_zug, _zug_ziel, delta / ZUG_HOCH)
		_zug_halt = maxf(0.0, _zug_halt - delta)
	elif _zug > 0.0:
		_zug = move_toward(_zug, 0.0, delta / ZUG_RUNTER)
	else:
		_ruhe = move_toward(_ruhe, 1.0, delta / RUHE_ZEIT)
	var stelle := 1.0 + 2.0 * smoothstep(0.0, 1.0, _zug) \
		- smoothstep(0.0, 1.0, _ruhe)
	_weg_pose(breath_at(_idle_time / BREATH_TIME), ABSETZ_WEG, stelle)

func absetz_dauer() -> float:
	return ZUG_HALT + ZUG_RUNTER + RUHE_ZEIT

func _weg_bild(weg: Array[int], stelle: float) -> int:
	var a := clampi(int(floor(stelle)), 0, weg.size() - 1)
	var b := mini(a + 1, weg.size() - 1)
	return weg[a] if stelle - float(a) < 0.5 else weg[b]

## Zopf, Kopf und Beine zwischen zwei Wurfbildern des Wegs, stufenlos wie im
## Wurf; als (Zopf, Kopf, Bein).
func weg_werte(weg: Array[int], stelle: float) -> Vector3i:
	var a := clampi(int(floor(stelle)), 0, weg.size() - 1)
	var b := mini(a + 1, weg.size() - 1)
	var k := clampf(stelle - float(a), 0.0, 1.0)
	var i: int = weg[a]
	var j: int = weg[b]
	return Vector3i(
		int(round(lerpf(AnglerParts.CAST_ZOPF[i], AnglerParts.CAST_ZOPF[j], k))),
		int(round(lerpf(AnglerParts.CAST_HEAD[i], AnglerParts.CAST_HEAD[j], k))),
		int(round(lerpf(AnglerParts.CAST_LEGS[i], AnglerParts.CAST_LEGS[j], k))))

## Die Rute hat nur gezeichnete Winkel: sie nimmt das naehere Bild.
func _weg_pose(atem: Vector2i, weg: Array[int], stelle: float) -> void:
	var w := weg_werte(weg, stelle)
	set_pose(atem.x, atem.y + w.x, w.y, w.z, &"open", _weg_bild(weg, stelle) + 1)

## Die Rutenspitze in Weltkoordinaten -- fuer das aktuelle Bild. Beim Wurf
## liegt sie tiefer als im Ruhebild; eine Konstante in der Welt konnte das
## nicht abbilden, und die Schnur begann daneben.
func rod_tip() -> Vector2:
	return position + (Vector2(AnglerPose.rod_tip(_arm))
		+ Vector2(0, float(_rod_atem()))) * scale
