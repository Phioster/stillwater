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

## Wind statt Uhrwerk.
##
## Eine einzelne Sinuswelle sah mechanisch aus, und zwar aus drei Gruenden,
## die echtes Gras alle anders macht:
##
## 1. Die Bewegung LAEUFT DEN HALM HINAUF. Die Spitze hinkt dem Fuss nach,
##    dadurch biegt sich der Halm, statt starr zu kippen. Das ist der
##    groesste Unterschied -- vorher schwang jede Reihe im selben Takt und nur
##    der Ausschlag wuchs nach oben, also kippte der Horst als Brett.
## 2. Es liegen ZWEI Schwingungen uebereinander: eine lange Boe und ein
##    kurzes Flattern darauf. Weil ihre Perioden nicht ineinander aufgehen,
##    wiederholt sich das Bild fuers Auge nie.
## 3. Der Wind DRAENGT IN EINE RICHTUNG und laesst zurueckfedern, statt
##    symmetrisch nach beiden Seiten zu ziehen. Der Horst steht deshalb auch
##    in Ruhe leicht geneigt.
##
## Alles bleibt in ganzen Pixeln -- gedreht waere er das einzige weiche Ding
## im Bild.
const BOE := 0.51
const FLATTERN := 1.73
## Wie stark das Flattern gegenueber der Boe zu Wort kommt.
const FLATTER_ANTEIL := 0.32
## Wie viele Sekunden die Spitze dem Fuss nachhinkt. Daran haengt, ob sich der
## Halm biegt oder kippt. Bei 0,35 blieb das Profil praktisch immer glatt --
## der Horst neigte sich nur. Bei 0,9 liegt fast eine halbe Boe dazwischen:
## die Spitze zieht noch nach links, waehrend die Mitte schon nach rechts
## geht, und das ist der Knick, der es wie einen Halm aussehen laesst.
const NACHLAUF := 0.9
## Wie weit der Wind in seine Richtung draengt. 0 waere symmetrisch.
const DRANG := 0.35
## Spitzenausschlag in Bildpixeln.
const AUSSCHLAG := 4.0
## Wie schnell der Ausschlag nach unten abnimmt.
const POTENZ := 1.6

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
	# Die Bewegung laeuft nach oben: je hoeher, desto spaeter kommt sie an.
	var spaet := zeit - t * NACHLAUF
	var wind := (1.0 - FLATTER_ANTEIL) * sin(spaet * BOE * TAU) \
		+ FLATTER_ANTEIL * sin(spaet * FLATTERN * TAU + 1.7)
	# In eine Richtung draengen, in die andere nur zurueckfedern.
	wind = (wind + DRANG) / (1.0 + DRANG)
	# Nach oben zunehmend, unten steht der Halm im Boden fest. Der Exponent
	# ist gemessen, nicht gewaehlt: bei 2 bewegt sich die Mitte in ganzen
	# Pixeln fast nie, und ohne Mitte gibt es keinen Knick.
	return int(round(wind * AUSSCHLAG * pow(t, POTENZ)))

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
