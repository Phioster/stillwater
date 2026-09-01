## Die Geometrie der Angler-Bilder — an EINER Stelle.
##
## Sie stand doppelt: der Bilderzeuger zeichnete die Rute, und die Welt hatte
## eine Konstante für deren Spitze. Beim Verschieben der Rute wurde die
## Konstante nicht mitgezogen, und die Schnur begann daneben.
##
## Seit die Figur gezeichnet ist (assets/source/angler_frames.png) hat jede
## Pose ihren EIGENEN Griff und ihre eigene Richtung: beim Ausholen zeigt die
## Rute nach hinten, beim Wurf nach vorn. Ein gemeinsamer Startpunkt mit
## einem Höhenversatz konnte das nie abbilden.
class_name AnglerPose
extends RefCounted

## 256 seit 2026-09-01. Das ist die obere Grenze, nicht der Anfang einer
## Reihe: die Vergrößerung in der Welt muss ganzzahlig bleiben, sonst landen
## Pixelkanten zwischen Bildschirmpunkten und alles flimmert. Bei 256 und
## Vergrößerung 1 steht die Figur so groß da wie vorher — mit sechzehnmal so
## vielen Bildpunkten wie beim 64er-Anfang. Bei 512 füllte sie zwei Drittel
## des Bildschirms, und kleiner anzeigen hieße wieder herunterrechnen.
const FRAME_SIZE: int = 256
## Zwoelf Bilder: sechs fuer den Ruhelauf, eins fuers Blinzeln, fuenf fuer
## den Wurf. Der Ruhelauf ist aus dem Ruhebild gerechnet, alles andere ist
## gezeichnet (siehe tools/import_character.py).
const FRAMES: int = 12
## Wo der Ruhelauf endet.
const IDLE_FRAMES: int = 6
## Das Blinzeln steht fuer sich: es blitzt gelegentlich dazwischen, statt im
## Atemtakt mitzulaufen -- sonst blinzelt sie im Sekundentakt.
const BLINK_FRAME: int = 6
## Ab hier laeuft der Wurf.
const CAST_START: int = 7

## Der Griff je Pose -- an der Hand der gezeichneten Figur gemessen.
const ROD_ANCHOR: Array[Vector2i] = [
	Vector2i(156, 128), Vector2i(156, 127), Vector2i(156, 127),
	Vector2i(156, 128), Vector2i(156, 129), Vector2i(156, 128),
	Vector2i(156, 128),
	Vector2i(148, 100), Vector2i(86, 82), Vector2i(79, 69),
	Vector2i(176, 98), Vector2i(174, 130),
]
## Die Spitze, relativ zum Griff. Die Ruheposen tragen den Versatz der
## gezeichneten Rute (assets/source/rod_45.png): Griff (1,97), Spitze (98,1)
## im Bild, also (97,-96). Gemessen, nicht gewaehlt -- dann liegt die Schnur
## wirklich an der gezeichneten Spitze an.
const ROD_TIP_OFF: Array[Vector2i] = [
	Vector2i(97, -96), Vector2i(97, -96), Vector2i(97, -96),
	Vector2i(97, -96), Vector2i(97, -96), Vector2i(97, -96),
	Vector2i(97, -96),
	Vector2i(60, -85), Vector2i(-40, -70), Vector2i(-65, -45),
	Vector2i(65, -70), Vector2i(75, -40),
]
## Wie weit sich die Rute quer zur Achse biegt. Eine gerade Rute sieht aus
## wie ein Stock; die Biegung macht aus dem Wurf eine Bewegung.
const ROD_BEND: Array[float] = [3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0,
	6.0, 8.0, 8.0, -7.0, -4.0]

static func frame_of(frame: int) -> int:
	return clampi(frame, 0, FRAMES - 1)

## Ein Punkt auf der Rute. t läuft von 0 (Griff) bis 1 (Spitze).
static func rod_point(frame: int, t: float) -> Vector2:
	var f := frame_of(frame)
	var a := Vector2(ROD_ANCHOR[f])
	var b := a + Vector2(ROD_TIP_OFF[f])
	# Quadratische Bézierkurve: der Kontrollpunkt liegt quer zur Achse.
	var mid := (a + b) * 0.5
	var control := mid + (b - a).orthogonal().normalized() * ROD_BEND[f]
	var u := 1.0 - t
	return a * (u * u) + control * (2.0 * u * t) + b * (t * t)

## Die Spitze für dieses Bild — dort setzt die Schnur an.
static func rod_tip(frame: int) -> Vector2i:
	var f := frame_of(frame)
	return ROD_ANCHOR[f] + ROD_TIP_OFF[f]

## Der Griff für dieses Bild.
static func rod_grip(frame: int) -> Vector2i:
	return ROD_ANCHOR[frame_of(frame)]
