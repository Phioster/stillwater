## Wolken, die am Himmel vorbeiziehen -- und bei Regen mehr werden und
## nachdunkeln.
##
## Sie sind GEZEICHNET und nicht gemalt: als Rechtecke im Pixelraster des
## Hintergrunds, damit ihre Kanten genauso gross sind wie die des Himmels
## dahinter. Ein Bild waere billiger, koennte aber weder mitziehen noch die
## Farbe wechseln.
##
## Sie bleiben oberhalb der Schilfspitzen (REIHE_OBEN/REIHE_UNTEN zaehlen in
## Hintergrundpixeln ueber der Wasserlinie, das Schilf reicht 28 hoch): das
## Schilf steckt im Hintergrundbild, alles hier Gezeichnete liegt also davor
## und wuerde sonst vor den Halmen haengen statt dahinter.
class_name Clouds
extends Node2D

## Jede Form ist eine Liste von Laeufen: Vector3i(dx, dy, Breite), in
## Hintergrundpixeln. Unten flach, oben bauschig -- so liest sich ein
## Haufen und kein Klotz.
const FORMEN: Array = [
	# Ein Fetzen, kaum mehr als ein Strich.
	[Vector3i(1, 0, 4), Vector3i(0, 1, 7)],
	[Vector3i(3, 0, 4), Vector3i(0, 1, 9), Vector3i(0, 2, 11)],
	[Vector3i(4, 0, 6), Vector3i(1, 1, 12), Vector3i(0, 2, 16),
		Vector3i(0, 3, 15)],
	# Schief: der Bausch sitzt rechts, nicht in der Mitte.
	[Vector3i(9, 0, 6), Vector3i(6, 1, 11), Vector3i(1, 2, 17),
		Vector3i(0, 3, 19)],
	[Vector3i(7, 0, 5), Vector3i(3, 1, 12), Vector3i(1, 2, 19),
		Vector3i(0, 3, 22), Vector3i(1, 4, 19)],
	[Vector3i(9, 0, 7), Vector3i(4, 1, 14), Vector3i(1, 2, 24),
		Vector3i(0, 3, 30), Vector3i(2, 4, 26)],
	[Vector3i(12, 0, 8), Vector3i(6, 1, 17), Vector3i(2, 2, 28),
		Vector3i(0, 3, 34), Vector3i(3, 4, 28)],
	# Eine lange, flache Bank -- liegt anders da als die bauschigen.
	[Vector3i(14, 0, 9), Vector3i(5, 1, 24), Vector3i(0, 2, 44),
		Vector3i(2, 3, 39)],
]

## Wieviele Wolken am Himmel stehen -- trocken und im Regen. Bei Regen soll
## er sich zuziehen, nicht nur ein paar Wolken mehr tragen.
const ZAHL_KLAR := 5
const ZAHL_REGEN := 20
## So viele halten wir ueberhaupt vor; die ueberzaehligen sind nur
## durchsichtig, damit im Regen keine aus dem Nichts erscheint.
const VORRAT := ZAHL_REGEN

## Hoehenband, in Hintergrundpixeln ueber der Wasserlinie gezaehlt: weit
## oben am Himmel. Wie weit davon wirklich zu sehen ist, haengt am
## Seitenverhaeltnis -- `setze` deckelt das Band auf den sichtbaren Himmel.
const REIHE_OBEN := 80
const REIHE_UNTEN := 56
## Wieviele Zeilen unter dem Bildrand die oberste Wolke mindestens bleibt.
const RAND_OBEN := 6

## Pixelzeilen je Sekunde -- gemaechlich, es ist ein stiller See.
const TEMPO_MIN := 1.2
const TEMPO_MAX := 3.0

## Wie schnell der Himmel auf einsetzenden Regen umstellt. Ueber Sekunden,
## nicht schlagartig: ein Wetterwechsel im selben Bild sieht nach Fehler aus.
const WECHSEL := 6.0

const KLAR_HELL := Color("d2e4f0")
const KLAR_DUNKEL := Color("a8c4dc")
const REGEN_HELL := Color("7c8796")
const REGEN_DUNKEL := Color("5a6473")

var _zelle: float = 0.0
var _horizont: float = 0.0
var _breite: float = 0.0
## Die hoechste Reihe, die im Fenster noch zu sehen ist.
var _reihe_max: float = float(REIHE_OBEN)
## Je Wolke: Form, Reihe ueber der Wasserlinie, Tempo, Lage in Pixeln.
var _wolken: Array = []
## 0 = trocken, 1 = Regen. Laeuft ueber WECHSEL Sekunden hinueber.
var _nass: float = 0.0

## Die Breite einer Form in Pixelspalten -- der aeusserste Lauf gibt sie.
static func _breite_von(form: Array) -> int:
	var b := 0
	for lauf in form:
		var v: Vector3i = lauf
		b = maxi(b, v.x + v.z)
	return b

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260915
	var schmal := _breite_von(FORMEN[0])
	var breit := _breite_von(FORMEN[FORMEN.size() - 1])
	# Sichtbar sind bei klarem Wetter nur die ersten ZAHL_KLAR Wolken. Wuerfelte
	# man ihre Formen, koennten das fuenf aehnliche sein -- die Reihe steht
	# deshalb fest und beginnt mit den am weitesten auseinanderliegenden.
	var reihenfolge := [0, 7, 3, 5, 1, 6, 2, 4]
	for i in VORRAT:
		# Die ersten sind die Schoenwetterwolken, die spaeteren kommen erst
		# im Regen dazu -- und das sind bewusst die grossen und tiefen: so
		# zieht sich der Himmel zu, statt nur mehr Tupfer zu tragen.
		var regenwolke := i >= ZAHL_KLAR
		var f: int = reihenfolge[i % reihenfolge.size()]
		if regenwolke:
			f = FORMEN.size() - 1 - (i % 3)
		# Groesse, Hoehe, Tempo und Blaesse haengen zusammen, statt einzeln
		# zu wuerfeln: eine kleine, blasse, langsame Wolke tief am Himmel
		# liest sich als weit weg, eine grosse, satte, schnelle weiter oben
		# als nah. Gewuerfelt sieht dieselbe Zahl Wolken nur unordentlich
		# aus, gekoppelt ergibt sie Tiefe.
		var g: float = clampf(float(_breite_von(FORMEN[f]) - schmal)
			/ maxf(float(breit - schmal), 1.0), 0.0, 1.0)
		_wolken.append({
			"form": f,
			# Regenwolken haengen tiefer und streuen weiter: ein zugezogener
			# Himmel hat keinen freien Streifen ueber dem Horizont.
			"reihe": (rng.randf_range(float(REIHE_UNTEN) - 14.0,
					float(REIHE_OBEN)) if regenwolke
				else lerpf(float(REIHE_UNTEN), float(REIHE_OBEN), g)
					+ rng.randf_range(-4.0, 4.0)),
			"tempo": lerpf(TEMPO_MIN, TEMPO_MAX, g) * rng.randf_range(0.85, 1.15),
			"deckung": 1.0 if regenwolke else lerpf(0.68, 1.0, g),
			"x": rng.randf_range(-60.0, 360.0),
		})

## Wo der Himmel liegt und wie gross ein Hintergrundpixel auf dem Schirm
## ist -- dasselbe Raster, das world.gd dem Hintergrund gibt.
func setze(zelle: float, horizont: float, breite: float) -> void:
	_zelle = zelle
	_horizont = horizont
	_breite = breite
	# Ueber der Wasserlinie ist nur so viel Himmel zu sehen, wie zwischen ihr
	# und dem Bildrand liegt. Bei einem schmalen Fenster wird der Hintergrund
	# staerker vergroessert und oben beschnitten -- dann muessen die Wolken
	# mit herunter, sonst ziehen sie ausserhalb des Bildes.
	_reihe_max = horizont / maxf(zelle, 0.001) - float(RAND_OBEN)
	queue_redraw()

func _process(delta: float) -> void:
	if _breite <= 0.0 or _zelle <= 0.0:
		return
	var regnet := Game.ctx != null and Game.ctx.raining
	_nass = move_toward(_nass, 1.0 if regnet else 0.0, delta / WECHSEL)
	var rand := _breite / _zelle
	for w in _wolken:
		w["x"] = float(w["x"]) + float(w["tempo"]) * delta
		# Rechts hinaus, links wieder herein. Der Vorlauf ist so breit wie
		# die groesste Form, sonst blitzt sie am Rand auf.
		if float(w["x"]) > rand + 60.0:
			w["x"] = -60.0
	queue_redraw()

## Wie sehr es gerade nach Regen aussieht, 0 bis 1. world.gd faerbt den
## Himmel damit ein -- eine Quelle fuer den Wetterwechsel, nicht zwei.
func nass() -> float:
	return _nass

func _draw() -> void:
	if _breite <= 0.0 or _zelle <= 0.0:
		return
	var hell := KLAR_HELL.lerp(REGEN_HELL, _nass)
	var dunkel := KLAR_DUNKEL.lerp(REGEN_DUNKEL, _nass)
	var zahl: float = lerpf(float(ZAHL_KLAR), float(ZAHL_REGEN), _nass)
	for i in _wolken.size():
		# Die ueberzaehligen blenden sich ein, statt zu erscheinen.
		var sicht: float = clampf(zahl - float(i), 0.0, 1.0)
		if sicht <= 0.0:
			continue
		var w: Dictionary = _wolken[i]
		var form: Array = FORMEN[int(w["form"])]
		# NICHT aufs Pixelraster rasten: bei ein bis drei Zeilen je Sekunde
		# spraenge eine Wolke sonst nur alle paar Sekunden um eine ganze
		# Zelle weiter, und genau das sah aus wie Ruckeln. Die Form bleibt
		# im Raster, nur ihre Lage laeuft stufenlos.
		var x0 := float(w["x"]) * _zelle
		var reihe: float = minf(float(w["reihe"]), _reihe_max)
		var y0 := _horizont - reihe * _zelle
		for lauf in form:
			var v: Vector3i = lauf
			# Die unterste Zeile ist die Schattenseite.
			var ton := dunkel if v.y == form.size() - 1 else hell
			# Die blassen lassen den Himmel durchscheinen -- das ist der
			# Dunst, der ferne Wolken verschluckt.
			ton.a = sicht * float(w["deckung"])
			draw_rect(Rect2(x0 + float(v.x) * _zelle,
				y0 + float(v.y) * _zelle, float(v.z) * _zelle, _zelle), ton)
