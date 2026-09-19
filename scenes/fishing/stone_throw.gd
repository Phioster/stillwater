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
class_name StoneThrow
extends Control

## Ein Aufsetzer des Steins auf dem Wasser -- world.gd macht daraus einen Ring.
signal aufsetzer(anteil_x: float, tiefe: float)
## Der Stein ist versunken: Sprungzahl und die Stelle, an der sie aufsteigt.
signal geworfen(spruenge: int, stelle: Vector2)

const SKALA := 2.16
## Abstand zwischen zwei Aufsetzern.
const SPRUNG_ABSTAND := 0.13
## Wie weit der Stein je Sprung nach rechts kommt, als Anteil der Breite.
const SPRUNG_WEITE := 0.055

var _bild: Texture2D
var _zeit := 0.0
var _wert := 0.0
var _laeuft := false
## Wo der Balken gezeichnet wird -- der Knoten selbst deckt die ganze Szene.
var _balken_pos := Vector2.ZERO

## Der Flug, nachdem geworfen wurde.
var _fliegt := false
var _flug_zeit := 0.0
var _offen := 0
var _gesamt := 0
var _start_x := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_bild = TextureLoader.load_texture(Stones.BALKEN_BILD)

func starte(bei: Vector2) -> void:
	_balken_pos = bei
	_zeit = 0.0
	_wert = 0.0
	_laeuft = true
	_fliegt = false
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
	var treffer := Stones.im_band(_wert, _zeit)
	_gesamt = Stones.spruenge(_wert, treffer)
	_offen = maxi(_gesamt, 1)
	_flug_zeit = 0.0
	_start_x = clampf(_balken_pos.x / maxf(size.x, 1.0), 0.0, 1.0)
	_fliegt = true
	schliesse()

## Je SPRUNG_ABSTAND ein Aufsetzer, jeder weiter draussen und flacher. Ein
## Plumps hat genau einen.
func _flug(delta: float) -> void:
	_flug_zeit += delta
	while _offen > 0 and _flug_zeit >= SPRUNG_ABSTAND:
		_flug_zeit -= SPRUNG_ABSTAND
		var nummer := maxi(_gesamt, 1) - _offen
		var x := clampf(_start_x + float(nummer + 1) * SPRUNG_WEITE, 0.0, 1.0)
		var tiefe := clampf(0.15 + float(nummer) * 0.12, 0.0, 0.8)
		aufsetzer.emit(x, tiefe)
		_offen -= 1
	if _offen <= 0:
		_fliegt = false
		visible = false
		geworfen.emit(_gesamt, Vector2(_start_x * size.x, _balken_pos.y))

func _draw() -> void:
	if _bild == null or not _laeuft:
		return
	var g := Stones.balken_groesse()
	var band := Stones.band_mitte(_zeit)
	var leer := Palette.get_color(&"peat_dark")
	var voll := Palette.get_color(&"torch")
	var gold := Palette.get_color(&"rod_brass")
	for y in g.y:
		var von_unten := 1.0 - (float(y) + 0.5) / float(g.y)
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
