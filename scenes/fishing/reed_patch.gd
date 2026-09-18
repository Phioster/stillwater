## Der antippbare Schilfhorst am Ufer.
##
## Er hat GEZEICHNETE Windstellungen (tools/schilfschneiden_bauen.py: WIND), zwischen
## denen umgeschaltet wird -- so wie die Anglerin gezeichnete Posen hat und
## die Rute elf gezeichnete Winkel.
##
## Zwei Versuche davor waren falsch, und beide auf dieselbe Weise: das Bild
## wurde VERSCHOBEN statt neu gemalt. Erst gedreht, was weiche Kanten und
## Zwischenfarben gab; dann zeilenweise geschert, wobei ganze waagerechte
## Baender gemeinsam ruecken und quer durch die Halme eine Naht laeuft. Das
## sah aus wie die verrutschten Bildzeilen eines alten Fernsehers. Ein Halm
## muss sich als GANZE Linie bewegen, und dafuer muss er gemalt sein.
##
## Der Wind selbst: zwei langsame Boen uebereinander, deren Perioden nicht
## ineinander aufgehen, also wiederholt sich das Bild fuers Auge nie. Und er
## draengt in eine Richtung und laesst zurueckfedern, statt symmetrisch nach
## beiden Seiten zu ziehen -- der Horst steht deshalb auch in Ruhe leicht
## geneigt.
class_name ReedPatch
extends Control

signal tapped

## Die beiden Boen, in Schwingungen je Sekunde. Langsam: jeder Bildwechsel
## ist sichtbar, und zu viele davon lesen sich als Zittern statt als Wind.
const BOE := 0.17
const ZWEITE_BOE := 0.29
## Wie stark die zweite gegenueber der ersten zu Wort kommt.
const ZWEIT_ANTEIL := 0.28
## Wie weit der Wind in seine Richtung draengt. 0 waere symmetrisch.
const DRANG := 0.35

var _bild: Texture2D
var _bild_groesse := Vector2.ZERO
var _anzahl := 1
var _skala := 1.0
var _zeit := 0.0
var _stellung := 0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

## Das Blatt mit den Windstellungen nebeneinander, die Groesse EINER Stellung
## und wie viele es sind.
func setze(bild: Texture2D, bild_groesse: Vector2, anzahl: int,
		skala: float) -> void:
	_bild = bild
	_bild_groesse = bild_groesse
	_anzahl = maxi(anzahl, 1)
	_skala = skala
	size = bild_groesse * skala
	queue_redraw()

## Welche Stellung zu diesem Zeitpunkt gilt.
static func stellung(zeit: float, anzahl: int) -> int:
	if anzahl <= 1:
		return 0
	var wind := (1.0 - ZWEIT_ANTEIL) * sin(zeit * BOE * TAU) \
		+ ZWEIT_ANTEIL * sin(zeit * ZWEITE_BOE * TAU + 1.7)
	# In eine Richtung draengen, in die andere nur zurueckfedern. Danach
	# reicht der Wind von hier bis 1 -- daran wird die Stellung gemessen.
	wind = (wind + DRANG) / (1.0 + DRANG)
	var unten := -(1.0 - DRANG) / (1.0 + DRANG)
	var anteil := clampf((wind - unten) / (1.0 - unten), 0.0, 1.0)
	return clampi(int(round(anteil * float(anzahl - 1))), 0, anzahl - 1)

func _process(delta: float) -> void:
	if not visible:
		return
	_zeit += delta
	var neu := stellung(_zeit, _anzahl)
	# Nur bei einem Wechsel neu zeichnen: dazwischen steht das Bild still,
	# und genau das soll es auch.
	if neu != _stellung:
		_stellung = neu
		queue_redraw()

func _draw() -> void:
	if _bild == null or _bild_groesse.x < 1.0:
		return
	var quelle := Rect2(Vector2(float(_stellung) * _bild_groesse.x, 0.0),
		_bild_groesse)
	draw_texture_rect_region(_bild, Rect2(Vector2.ZERO, _bild_groesse * _skala),
		quelle)

func _gui_input(event: InputEvent) -> void:
	var getippt: bool = (event is InputEventScreenTouch \
		and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton \
		and (event as InputEventMouseButton).pressed)
	if getippt:
		accept_event()
		tapped.emit()
