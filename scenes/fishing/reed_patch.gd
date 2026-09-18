## Der antippbare Schilfhorst am Ufer.
##
## Er wiegt sich, indem ganze PIXELREIHEN nach links und rechts ruecken -- so
## wie die Beine der Anglerin versetzt werden, nicht als gedrehtes Bild. Eine
## Drehung waere kein Pixelbild mehr: die Halme bekaemen Treppen und
## Zwischenfarben, die in keiner Palette stehen, und der Horst haette als
## einziges Ding im Bild weiche Kanten.
##
## Unten ruehrt sich nichts und oben am meisten -- ein Halm steht im Boden
## fest. Der Ausschlag waechst quadratisch nach oben, sonst kippt der ganze
## Horst wie ein Brett.
class_name ReedPatch
extends Control

signal tapped

## Wie schnell er sich wiegt und wie weit die Spitze hoechstens ausschlaegt,
## in Bildpixeln. Zwei ist genug: bei drei sieht es nach Sturm aus.
const TEMPO := 1.5
const AUSSCHLAG := 2.0

var _bild: Texture2D
var _ausschnitt := Rect2()
var _skala := 1.0
var _zeit := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func setze(bild: Texture2D, ausschnitt: Rect2, skala: float) -> void:
	_bild = bild
	_ausschnitt = ausschnitt
	_skala = skala
	size = ausschnitt.size * skala
	queue_redraw()

## Um wie viele PIXEL diese Bildzeile nach rechts rueckt. Ganze Zahlen, sonst
## waere es wieder ein weicher Versatz.
static func versatz(reihe: int, hoehe: int, zeit: float) -> int:
	if hoehe <= 1:
		return 0
	# reihe 0 ist oben. Unten null, oben voll.
	var t := 1.0 - float(reihe) / float(hoehe - 1)
	return int(round(sin(zeit * TEMPO) * AUSSCHLAG * t * t))

## Die Zeilen zu Baendern gleichen Versatzes zusammenfassen: bei zwei Pixeln
## Ausschlag sind das eine Handvoll statt sechzig Zeichenbefehlen -- und
## genau so sieht Pixelanimation aus, ganze Baender ruecken gemeinsam.
static func baender(hoehe: int, zeit: float) -> Array:
	var raus: Array = []
	var von := 0
	var wert := versatz(0, hoehe, zeit)
	for r in range(1, hoehe):
		var v := versatz(r, hoehe, zeit)
		if v != wert:
			raus.append([von, r - von, wert])
			von = r
			wert = v
	raus.append([von, hoehe - von, wert])
	return raus

func _process(delta: float) -> void:
	if not visible:
		return
	_zeit += delta
	queue_redraw()

func _draw() -> void:
	if _bild == null or _ausschnitt.size.y < 1.0:
		return
	var hoehe := int(_ausschnitt.size.y)
	for band in baender(hoehe, _zeit):
		var von: int = band[0]
		var zahl: int = band[1]
		var dx: float = float(band[2]) * _skala
		var quelle := Rect2(_ausschnitt.position.x,
			_ausschnitt.position.y + float(von), _ausschnitt.size.x, float(zahl))
		var ziel := Rect2(dx, float(von) * _skala,
			_ausschnitt.size.x * _skala, float(zahl) * _skala)
		draw_texture_rect_region(_bild, ziel, quelle)

func _gui_input(event: InputEvent) -> void:
	var getippt: bool = (event is InputEventScreenTouch \
		and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton \
		and (event as InputEventMouseButton).pressed)
	if getippt:
		accept_event()
		tapped.emit()
