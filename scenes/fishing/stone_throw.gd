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
signal flug(anteil_x: float, tiefe: float, hoehe: float, blitzt: bool,
	deckung: float)
## Der Stein ist weg -- ab hier zeichnet ihn niemand mehr.
signal flug_endet
## Der Stein ist versunken: Sprungzahl und die Stelle, an der er es tat.
signal geworfen(spruenge: int, anteil_x: float, tiefe: float)

const SKALA := 2.16
## Abstand zwischen zwei Aufsetzern. Der Flug ist das, was man sich ansieht --
## bei 0,13 s war er vorbei, bevor man die Spruenge mitzaehlen konnte.
const SPRUNG_ABSTAND := 0.20
## Wie hoch der Stein zwischen zwei Aufsetzern steigt, in Wasserpixeln.
const BOGEN_HOCH := 6.0
## Wie lange der Stein nach einem Treffer im Band aufleuchtet. Kurz: es ist
## eine Rueckmeldung, kein zweiter Effekt.
const BLITZ_DAUER := 0.3
## Wie lange der Stein nach dem letzten Aufsetzer untergeht, und wie tief er
## dabei sinkt. Ohne das verschwindet er im Sprung, und der letzte Aufsetzer
## sieht aus wie ein Aussetzer.
const SINKEN := 0.22
const SINK_TIEF := 6.0
## Wie lange der Balken nach dem Start keinen Wurf annimmt. Godot schickt zu
## jeder Beruehrung noch einen Mausklick hinterher -- ohne die Sperre wirft
## derselbe Tipp, der den Balken oeffnet, ihn sofort wieder leer.
const SCHARF_AB := 0.15

var _zeit := 0.0
## Zeitversatz des goldenen Bandes, je Aufnahme neu gewuerfelt. Ohne ihn faengt
## es jedes Mal an derselben Stelle an und laeuft in dieselbe Richtung los --
## dann uebt man den Wurf einmal ein und wiederholt ihn beliebig.
var _band_versatz := 0.0
var _wert := 0.0
var _laeuft := false
## Wo der Balken gezeichnet wird -- der Knoten selbst deckt die ganze Szene.
var _balken_pos := Vector2.ZERO

## Der Flug, nachdem geworfen wurde.
var _fliegt := false
## Der Nachlauf danach: der Stein ist aufgekommen und geht unter.
var _sinkt := false
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

## bei ist die linke obere Ecke des Balkens, von_x der Anteil der Breite, an
## dem der Stein ins Wasser geht -- die Stegkante, nicht der Kieselhaufen.
func starte(bei: Vector2, von_x: float) -> void:
	# Ein fliegender Stein laesst sich nicht nachladen: der zweite Tipp haette
	# sonst die offenen Aufsetzer verschluckt, ohne dass je eine Zahl kommt.
	if _fliegt:
		return
	_balken_pos = bei
	_start_x = clampf(von_x, 0.0, 1.0)
	_sinkt = false
	# Ueber den GANZEN Weg gewuerfelt: das trifft Stelle und Richtung zugleich.
	_band_versatz = randf() * Stones.BAND_WEG * 2.0
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
	if not _laeuft or _zeit < SCHARF_AB:
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

## Die Uhr, nach der sich das Band richtet. Zeichnung und Regel fragen
## dieselbe -- zwei waeren zwei Baender.
func _band_zeit() -> float:
	return _zeit + _band_versatz

## Wirft den Stein mit dem gerade anliegenden Ladestand.
func wirf() -> void:
	if not _laeuft:
		return
	_treffer = Stones.im_band(_wert, _band_zeit())
	_gesamt = Stones.spruenge(_wert, _treffer)
	_offen = maxi(_gesamt, 1)
	_flug_zeit = 0.0
	_flug_alter = 0.0
	_letzt_x = _start_x
	_letzt_tiefe = Stones.TIEFE_VON
	_fliegt = true
	schliesse()

## Je SPRUNG_ABSTAND ein Aufsetzer; wo er liegt, sagt Stones.aufsetzer_ort().
## Ein Plumps hat genau einen.
func _flug(delta: float) -> void:
	_flug_zeit += delta
	_flug_alter += delta
	if _sinkt:
		_sinken()
		return
	while _offen > 0 and _flug_zeit >= SPRUNG_ABSTAND:
		_flug_zeit -= SPRUNG_ABSTAND
		var ort := Stones.aufsetzer_ort(_start_x, maxi(_gesamt, 1) - _offen)
		_letzt_x = ort.x
		_letzt_tiefe = ort.y
		aufsetzer.emit(ort.x, ort.y)
		_offen -= 1
	if _offen <= 0:
		_sinkt = true
		_flug_zeit = 0.0
		_sinken()
		return
	_melde_flug()

## Der letzte Aufsetzer ist kein Sprung mehr: der Stein geht an Ort und Stelle
## unter. Erst danach steigt die Zahl auf, damit sie dort steht, wo er blieb.
func _sinken() -> void:
	var p := clampf(_flug_zeit / SINKEN, 0.0, 1.0)
	# Nicht gleichmaessig: erst der Einschlag, dann laeuft er im Wasser aus.
	# Mit gleicher Geschwindigkeit sah das Absinken aus wie ein Fahrstuhl.
	var tiefe := 1.0 - pow(1.0 - p, 3.0)
	flug.emit(_letzt_x, _letzt_tiefe, -SINK_TIEF * tiefe, false,
		pow(1.0 - p, 2.0))
	if p < 1.0:
		return
	_fliegt = false
	_sinkt = false
	visible = false
	flug_endet.emit()
	geworfen.emit(_gesamt, _letzt_x, _letzt_tiefe)

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
		BOGEN_HOCH * sin(p * PI), _treffer and _flug_alter < BLITZ_DAUER, 1.0)

func _draw() -> void:
	if not _laeuft:
		return
	var g := Stones.balken_groesse()
	var band := Stones.band_mitte(_band_zeit())
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
