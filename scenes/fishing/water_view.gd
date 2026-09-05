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

var _punkte := PackedVector2Array()
var _breite: float = 0.0
var _unterkante: float = 0.0
var _zeit: float = 0.0
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
