## Die Wasserflaeche als Pixelbild statt als Farbverlauf.
##
## Der Hintergrund ist 320x180 und wird auf die Weltgroesse gestreckt. Seine
## Pixel sind dadurch nie so gross wie die der Figur, und sein Wasser ist ein
## weicher Verlauf ueber 96 Zeilen. Nebeneinander sah das aus wie zwei
## Zeichnungen aus verschiedenen Spielen -- derselbe Fehler wie frueher beim
## Steg und beim Schwimmer.
##
## Hier wird die Flaeche unterhalb der Welle neu gemalt: Kantenlaenge wie bei
## Steg und Anglerin, zwei Toene aus der Zone, eine Krone aus dem Schaumton.
## Tiefe kommt nicht aus einem Verlauf, sondern aus der Dichte der
## Glitzerstriche -- oben viele und kurze, unten wenige und lange.
##
## Die Oberflaeche wird nicht selbst gerechnet: world.gd reicht dieselbe
## Punktfolge herein, die auch die Wellenlinie zeichnet. So koennen Linie und
## Flaeche nicht auseinanderlaufen.
##
## Bei Regen liegen ausserdem Ringe auf dem Wasser. Sie gehoeren hierher und
## nicht zu rain.gd: der Regen ist ein Control ueber der ganzen Szene und
## wuerde seine Ringe auch ueber Steg, Angler und Schwimmer malen. Hier
## liegen sie zwischen Wasserflaeche und Figur, also da, wo Wasser ist.
##
## Sie haengen auch nicht an einzelnen Tropfen. Die Striche des Regens enden
## alle an der fernen Kante -- Ringe nur dort waeren eine Reihe am Horizont.
## Ueber die Flaeche verteilt lesen sie sich als Regen auf einen See.
class_name WaterView
extends Node2D

## Kantenlaenge eines Wasserpixels, wie DOCK_SCALE und ANGLER_SCALE in
## world.gd. Ein Pixel ist ein Pixel.
const PIXEL := 2.16
## Pixelzeilen unter der Oberflaeche: die Krone, dann das helle Band.
const KRONE := 1
const HELL := 4
## Glitzerstriche. TIEFE ist die unterste Zeile, in der noch einer liegt --
## darunter ist die Flaeche ruhig, das liest sich als Entfernung.
const STRICHE := 64
const STRICH_TIEFE := 48
const STRICH_DRIFT := 5.0       # Pixelzeilen je Sekunde, oben langsamer

## Regenringe. RINGE ist die Zahl der Stellen, an denen es gleichzeitig
## tropft -- jede erneuert sich nach RING_LEBEN an einem neuen Ort.
const RINGE := 20
const RING_LEBEN := 0.9
## Endradius in Wasserpixeln: hinten an der Kante klein, vorn gross. Das ist
## die einzige Perspektive, die diese Ansicht hat, und sie traegt das Bild --
## gleich grosse Ringe legten die Flaeche flach.
const RING_FERN := 3
const RING_NAH := 8
## Hoehen- zu Breitenradius. Wir schauen flach auf das Wasser, ein runder
## Ring saehe aus wie eine Blase darin.
const RING_FLACH := 0.34
## Wie weit nach unten Ringe fallen, als Anteil der Wasserhoehe. Knapp unter 1,
## damit der unterste nicht halb aus dem Bild haengt.
const RING_FELD := 0.92
const RING_DECKUNG := 0.5

var _punkte := PackedVector2Array()
var _breite: float = 0.0
var _unterkante: float = 0.0
var _zeit: float = 0.0
## Ob es regnet. world.gd setzt es aus derselben Quelle wie die Sichtbarkeit
## des Regens -- ein Wetter, eine Uhr.
var regnet: bool = false
var _krone := Color.WHITE
var _hell := Color.WHITE
var _tief := Color.BLACK

## Die Oberflaeche als Punktfolge (dieselbe wie die Wellenlinie), die Weite
## der Flaeche und die laufende Zeit fuer die Drift.
func setze(punkte: PackedVector2Array, breite: float, unterkante: float,
		zeit: float) -> void:
	_punkte = punkte
	_breite = breite
	_unterkante = unterkante
	_zeit = zeit
	queue_redraw()

func faerbe(krone: Color, hell: Color, tief: Color) -> void:
	_krone = krone
	_hell = hell
	_tief = tief
	queue_redraw()

## Die Flaeche in Laeufen gleicher Pixelzeile.
##
## Jeder Abschnitt der Wellenlinie ist gerade, also wechselt die gerundete
## Zeile darin nur dort, wo er eine halbe Pixelhoehe kreuzt. Das sind ein paar
## Stellen je Abschnitt statt einer Pruefung je Spalte -- bei 28 Stuetzpunkten
## und einer Welle von wenigen Pixeln Hub sind es ein paar Dutzend Rechtecke
## fuer die ganze Breite.
func _laeufe() -> Array:
	var laeufe: Array = []
	for i in _punkte.size() - 1:
		var a: Vector2 = _punkte[i]
		var b: Vector2 = _punkte[i + 1]
		if b.x <= a.x:
			continue
		var grenzen: Array[float] = [a.x]
		var k0 := int(round(a.y / PIXEL))
		var k1 := int(round(b.y / PIXEL))
		if k1 != k0:
			var schritt := 1 if k1 > k0 else -1
			var k := k0
			while k != k1:
				# Die Zeile wechselt auf halber Pixelhoehe zwischen k und k+1.
				var grenze := (float(k) + 0.5 * float(schritt)) * PIXEL
				grenzen.append(a.x + (b.x - a.x) * (grenze - a.y) / (b.y - a.y))
				k += schritt
		grenzen.append(b.x)
		for j in grenzen.size() - 1:
			var x0 := snappedf(grenzen[j], PIXEL)
			var x1 := snappedf(grenzen[j + 1], PIXEL)
			if x1 <= x0:
				continue
			var mitte := (grenzen[j] + grenzen[j + 1]) * 0.5
			var y := a.y + (b.y - a.y) * (mitte - a.x) / (b.x - a.x)
			laeufe.append([x0, x1, snappedf(y, PIXEL)])
	return laeufe

func _draw() -> void:
	if _punkte.size() < 2 or _unterkante <= 0.0:
		return
	var laeufe := _laeufe()
	for lauf in laeufe:
		var x0: float = lauf[0]
		var w: float = lauf[1] - x0
		var y: float = lauf[2]
		draw_rect(Rect2(x0, y, w, PIXEL * float(KRONE)), _krone)
		draw_rect(Rect2(x0, y + PIXEL * float(KRONE), w, PIXEL * float(HELL)),
			_hell)
		var tief_y := y + PIXEL * float(KRONE + HELL)
		if tief_y < _unterkante:
			draw_rect(Rect2(x0, tief_y, w, _unterkante - tief_y), _tief)
	_striche(laeufe)
	_ringe(laeufe)

## Kurze waagerechte Striche, die mit der Welle mitgehen: ihre Zeile zaehlt ab
## der Oberflaeche, nicht ab dem Bildrand. Sie treiben nach rechts, tiefere
## schneller -- was naeher am Betrachter liegt, zieht schneller vorbei.
func _striche(laeufe: Array) -> void:
	if laeufe.is_empty():
		return
	for i in STRICHE:
		# Quadratisch verteilt: oben dicht, unten vereinzelt.
		var anteil := float((i * 13) % STRICHE) / float(STRICHE)
		var reihe := KRONE + 1 + int(anteil * anteil * float(STRICH_TIEFE))
		var laenge := float(2 + (i % 3) + reihe / 12) * PIXEL
		var tempo := STRICH_DRIFT * (0.4 + 0.06 * float(reihe))
		var x := fposmod(float((i * 197) % 1009) / 1009.0 * _breite
			+ _zeit * tempo * PIXEL, _breite)
		x = snappedf(x, PIXEL)
		var y := _oberflaeche_bei(laeufe, x)
		if y == INF:
			continue
		y += PIXEL * float(reihe)
		if y >= _unterkante:
			continue
		draw_rect(Rect2(x, y, laenge, PIXEL),
			_krone if reihe <= KRONE + HELL else _hell)

## Die gerundete Oberflaechenzeile an dieser Stelle -- aus denselben Laeufen,
## die die Flaeche gemalt haben. Sonst saessen die Striche eine Zeile daneben.
func _oberflaeche_bei(laeufe: Array, x: float) -> float:
	for lauf in laeufe:
		if x >= lauf[0] and x < lauf[1]:
			return lauf[2]
	return INF

## Die tiefste Oberflaechenzeile im Bereich x +- halb. INF, wenn davon nichts
## im Bild liegt.
func _oberflaeche_hoechste(laeufe: Array, x: float, halb: float) -> float:
	var y := INF
	for lauf in laeufe:
		if lauf[1] <= x - halb or lauf[0] > x + halb:
			continue
		if y == INF or lauf[2] > y:
			y = lauf[2]
	return y

## Ein Ring, allein aus der Zeit gerechnet -- wie der Regen selbst und aus
## demselben Grund: es gibt keinen Zustand, der auseinanderlaufen koennte,
## wenn das Spiel pausiert oder lange lief.
##
## Gibt [anteil_x, tiefe, alter] zurueck. alter laeuft von 0 (Aufschlag) bis 1
## (verschwunden), tiefe von 0 an der Wasserkante bis RING_FELD ganz vorn.
static func ring_zustand(i: int, zeit: float) -> Array:
	# Goldener Schnitt als Versatz: die Aufschlaege verteilen sich damit
	# gleichmaessig ueber die Zeit, ohne dass eine Zufallstabelle noetig waere.
	var phase := zeit / RING_LEBEN + float(i) * 0.6180339887
	var zyklus := floori(phase)
	# Quadratisch verteilt, also hinten dichter: in dieser Ansicht draengt
	# sich die halbe Wasserflaeche in den obersten Zeilen.
	var u := _streu(i, zyklus, 1)
	return [_streu(i, zyklus, 2), u * u * RING_FELD, phase - float(zyklus)]

## Ganzzahliger Streuwert aus Nummer, Durchgang und Salz. Jeder Durchgang
## setzt den Ring woanders hin -- sonst tropfte es ewig auf dieselben zwanzig
## Stellen, und das faellt auf, lange bevor man es benennen kann.
static func _streu(i: int, zyklus: int, salz: int) -> float:
	var h: int = (i * 374761393 + zyklus * 668265263 + salz * 1103515245) & 0x7fffffff
	h = ((h >> 13) ^ h) * 1274126177
	return float(h & 0x7fffffff) / 2147483647.0

## Der Radius waechst schnell und wird langsamer -- so laeuft eine Welle auf
## dem Wasser aus, und linear sah es aus wie ein aufgehender Kreis.
static func ring_radius(tiefe: float, alter: float) -> int:
	var voll := lerpf(float(RING_FERN), float(RING_NAH), tiefe / RING_FELD)
	return int(round(voll * sqrt(clampf(alter, 0.0, 1.0))))

## Hell beim Aufschlag, dann ausklingend. Quadratisch, damit der Ring erst
## richtig steht, bevor er geht.
static func ring_deckung(alter: float) -> float:
	return RING_DECKUNG * (1.0 - alter * alter)

## Der Umriss einer Ellipse auf dem Pixelraster, als waagerechte Laeufe
## [dx, dy, breite] in Wasserpixeln um die Mitte.
##
## Je Zeile wird nicht ein Randpixel gesetzt, sondern die Strecke zwischen
## dieser Zeile und der naechsten -- sonst risse der Umriss oben und unten
## auf, wo die Ellipse fast waagerecht liegt. Dort wird daraus von selbst ein
## durchgehender Strich, und der Ring schliesst sich.
##
## Das Ergebnis wird geteilt und darf nicht veraendert werden: es gibt nur
## eine Handvoll Radien, und sie jedes Bild neu zu rechnen waere Arbeit fuer
## nichts.
static var _formen: Dictionary = {}
static func ring_form(rx: int, ry: int) -> Array:
	var schluessel := rx * 64 + ry
	if _formen.has(schluessel):
		return _formen[schluessel]
	var laeufe: Array = []
	# ry + 0.5: sonst faellt die aeusserste Zeile auf die Breite null zusammen
	# und der Ring haette keinen Deckel.
	var nenner := float(ry) + 0.5
	for dy in range(-ry, ry + 1):
		var aussen := _halbbreite(rx, absi(dy), nenner)
		var innen := _halbbreite(rx, absi(dy) + 1, nenner)
		if innen <= 0:
			laeufe.append([-aussen, dy, aussen * 2 + 1])
		else:
			laeufe.append([innen, dy, aussen - innen + 1])
			laeufe.append([-aussen, dy, aussen - innen + 1])
	_formen[schluessel] = laeufe
	return laeufe

static func _halbbreite(rx: int, dy: int, nenner: float) -> int:
	var q := 1.0 - pow(float(dy) / nenner, 2.0)
	if q <= 0.0:
		return 0
	return int(round(float(rx) * sqrt(q)))

func _ringe(laeufe: Array) -> void:
	var c := _krone
	for eintrag in ring_rechtecke(laeufe):
		c.a = eintrag[1]
		draw_rect(eintrag[0], c)

## Die Rechtecke aller Ringe mit ihrer Deckung, getrennt vom Zeichnen. Der
## Regen macht es genauso (Rain.strich): nur so laesst sich nachrechnen, dass
## kein Ring ueber der Welle liegt -- am fertigen Bild ginge das nicht.
func ring_rechtecke(laeufe: Array) -> Array:
	var stapel: Array = []
	if not regnet or laeufe.is_empty():
		return stapel
	for i in RINGE:
		var z := ring_zustand(i, _zeit)
		var x := snappedf(float(z[0]) * _breite, PIXEL)
		var rx := ring_radius(z[1], z[2])
		var ry := int(round(float(rx) * RING_FLACH))
		# Nicht die Kante unter der Mitte, sondern die TIEFSTE unter der ganzen
		# Breite des Rings: in einem Wellental gemessen, ragte seine Flanke
		# sonst durch den Kamm daneben.
		var oben := _oberflaeche_hoechste(laeufe, x, float(rx) * PIXEL)
		if oben == INF:
			continue
		# Der Ring liegt AUF dem Wasser: nie ueber der Welle -- da waere er in
		# der Luft -- und nie halb unter dem Bildrand.
		var hoch := oben + PIXEL * float(KRONE + ry)
		var tief := _unterkante - PIXEL * float(ry + 1)
		if tief <= hoch:
			continue
		var y := clampf(snappedf(oben + float(z[1]) * (_unterkante - oben), PIXEL),
			hoch, tief)
		var deckung := ring_deckung(z[2])
		for lauf in ring_form(rx, ry):
			stapel.append([Rect2(x + float(lauf[0]) * PIXEL,
				y + float(lauf[1]) * PIXEL, float(lauf[2]) * PIXEL, PIXEL),
				deckung])
	return stapel
