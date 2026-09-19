## Der Ladebalken und der Flug des Steins.
##
## Die Form des Balkens steht NUR im Bild (Stones.maske()); Fuellung und
## goldenes Band werden hier durch diese Maske gemalt. Es gibt die Form also
## genau einmal -- bei der Klinge hat dieselbe Lehre vier Anlaeufe gekostet.
##
## Der Knoten liegt ueber der ganzen Szene und nimmt den zweiten Tipp selbst
## entgegen. Das ist gefahrlos: Tipps erreichen die Simulation ausschliesslich
## ueber die Orbs (scenes/fishing/catch_view.gd), es gibt keinen
## bildschirmweiten Tipp, den wir hier abfangen wuerden. Und beim Anbiss macht
## sich der Knoten von selbst wieder durchlaessig.
##
## Gezeichnet wird hier nur der Balken. Der fliegende Stein gehoert in
## water_view.gd: von dort aus kann er den Schwimmer nicht ueberdecken, von
## hier aus schon.
class_name StoneThrow
extends Control

## Ein Aufsetzer des Steins auf dem Wasser -- world.gd macht daraus einen Ring.
signal aufsetzer(anteil_x: float, tiefe: float)
## Wo der Stein gerade fliegt. tiefe ist die Stelle im Wasserfeld wie beim
## Aufsetzer, hoehe der Bogen darueber in Wasserpixeln, blitzt das kurze
## Aufleuchten nach einem Treffer im goldenen Band.
signal flug(anteil_x: float, tiefe: float, hoehe: float, blitzt: bool)
## Der Stein ist weg -- ab hier zeichnet ihn niemand mehr.
signal flug_endet
## Der Stein ist versunken: Sprungzahl und die Stelle, an der er es tat.
signal geworfen(spruenge: int, anteil_x: float, tiefe: float)

const SKALA := 2.16
## Abstand zwischen zwei Aufsetzern.
const SPRUNG_ABSTAND := 0.13
## Wie hoch der Stein zwischen zwei Aufsetzern steigt, in Wasserpixeln.
const BOGEN_HOCH := 6.0
## Wie lange der Stein nach einem Treffer im Band aufleuchtet. Kurz: es ist
## eine Rueckmeldung, kein zweiter Effekt.
const BLITZ_DAUER := 0.3

var _zeit := 0.0
var _wert := 0.0
var _laeuft := false
## Wo der Balken gezeichnet wird -- der Knoten selbst deckt die ganze Szene.
var _balken_pos := Vector2.ZERO

## Der Flug, nachdem geworfen wurde.
var _fliegt := false
## Zeit seit dem letzten Aufsetzer (der Bogen) und seit dem Wurf (das Blitzen).
var _flug_zeit := 0.0
var _flug_alter := 0.0
var _offen := 0
var _gesamt := 0
var _start_x := 0.0
var _treffer := false
## Der zuletzt gemeldete Aufsetzer -- dort versinkt der Stein, dort steigt die
## Zahl auf.
var _letzt_x := 0.0
var _letzt_tiefe := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func starte(bei: Vector2) -> void:
	# Ein fliegender Stein laesst sich nicht nachladen: der zweite Tipp haette
	# sonst die offenen Aufsetzer verschluckt, ohne dass je eine Zahl kommt.
	if _fliegt:
		return
	_balken_pos = bei
	_zeit = 0.0
	_wert = 0.0
	_laeuft = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func schliesse() -> void:
	_laeuft = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _fliegt:
		visible = false
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not _laeuft:
		return
	var tipp := event is InputEventScreenTouch \
		and (event as InputEventScreenTouch).pressed
	var klick := event is InputEventMouseButton \
		and (event as InputEventMouseButton).pressed
	if tipp or klick:
		wirf()
		accept_event()

func _process(delta: float) -> void:
	if _laeuft:
		# Beim Anbiss gehoert der Finger den Orbs, nicht den Steinen.
		if Game.sim != null and Game.sim.state == FishingSim.State.FIGHT:
			schliesse()
			return
		_zeit += delta
		_wert = Stones.ladung(_zeit)
		queue_redraw()
	elif _fliegt:
		_flug(delta)

## Wirft den Stein mit dem gerade anliegenden Ladestand.
func wirf() -> void:
	if not _laeuft:
		return
	_treffer = Stones.im_band(_wert, _zeit)
	_gesamt = Stones.spruenge(_wert, _treffer)
	_offen = maxi(_gesamt, 1)
	_flug_zeit = 0.0
	_flug_alter = 0.0
	_start_x = clampf(_balken_pos.x / maxf(size.x, 1.0), 0.0, 1.0)
	_letzt_x = _start_x
	_letzt_tiefe = Stones.TIEFE_VON
	_fliegt = true
	schliesse()

## Je SPRUNG_ABSTAND ein Aufsetzer; wo er liegt, sagt Stones.aufsetzer_ort().
## Ein Plumps hat genau einen.
func _flug(delta: float) -> void:
	_flug_zeit += delta
	_flug_alter += delta
	while _offen > 0 and _flug_zeit >= SPRUNG_ABSTAND:
		_flug_zeit -= SPRUNG_ABSTAND
		var ort := Stones.aufsetzer_ort(_start_x, maxi(_gesamt, 1) - _offen)
		_letzt_x = ort.x
		_letzt_tiefe = ort.y
		aufsetzer.emit(ort.x, ort.y)
		_offen -= 1
	if _offen <= 0:
		_fliegt = false
		visible = false
		flug_endet.emit()
		geworfen.emit(_gesamt, _letzt_x, _letzt_tiefe)
		return
	_melde_flug()

## Zwischen zwei Aufsetzern: waagerecht und in der Tiefe gleichmaessig, darueber
## ein Bogen, der an beiden Enden auf null zurueckgeht.
func _melde_flug() -> void:
	var nummer := maxi(_gesamt, 1) - _offen
	var ziel := Stones.aufsetzer_ort(_start_x, nummer)
	# Vor dem ersten Aufsetzer kommt der Stein aus der Hand, nicht vom Wasser.
	var von := Stones.aufsetzer_ort(_start_x, nummer - 1) if nummer > 0 \
		else Vector2(_start_x, ziel.y)
	var p := clampf(_flug_zeit / SPRUNG_ABSTAND, 0.0, 1.0)
	flug.emit(lerpf(von.x, ziel.x, p), lerpf(von.y, ziel.y, p),
		BOGEN_HOCH * sin(p * PI), _treffer and _flug_alter < BLITZ_DAUER)

func _draw() -> void:
	if not _laeuft:
		return
	var g := Stones.balken_groesse()
	var band := Stones.band_mitte(_zeit)
	var leer := Palette.get_color(&"peat_dark")
	var voll := Palette.get_color(&"torch")
	var gold := Palette.get_color(&"rod_brass")
	for y in g.y:
		var von_unten := Stones.zeilen_anteil(y)
		var f := gold if absf(von_unten - band) <= Stones.BAND_HOEHE * 0.5 \
			else (voll if Stones.gefuellt(y, _wert) else leer)
		# Waagerechte Laeufe statt einzelner Punkte: eine Zeile des Balkens
		# ist hoechstens ein zusammenhaengendes Stueck breit.
		var start := -1
		for x in g.x + 1:
			var drin := x < g.x and Stones.maske().get_bit(x, y)
			if drin and start < 0:
				start = x
			elif not drin and start >= 0:
				draw_rect(Rect2(_balken_pos.x + float(start) * SKALA,
					_balken_pos.y + float(y) * SKALA,
					float(x - start) * SKALA, SKALA), f)
				start = -1
