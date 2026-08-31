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

## 64 statt 32 seit 2026-08-31: dieselbe Figur auf doppelt so vielen
## Bildpunkten, dafür halbe Vergrößerung in der Welt (PIXEL_SCALE 4 → 2).
const FRAME_SIZE: int = 64
## Zehn Bilder: sechs für den Ruhelauf (sie steht nie ganz still), vier für
## den Wurf. Beide Reihen sind gezeichnet, nicht gerechnet.
const FRAMES: int = 10
## Wo der Ruhelauf endet und der Wurf beginnt.
const IDLE_FRAMES: int = 6

## Der Griff je Pose — an der Hand der gezeichneten Figur gemessen. Im
## Ruhelauf wandert er ein paar Pixel, dadurch atmet die Rute mit.
const ROD_ANCHOR: Array[Vector2i] = [
	Vector2i(38, 35), Vector2i(38, 33), Vector2i(38, 34),
	Vector2i(38, 32), Vector2i(37, 35), Vector2i(37, 37),
	Vector2i(33, 24), Vector2i(30, 24), Vector2i(41, 40), Vector2i(38, 42),
]
## Die Spitze, relativ zum Griff. Die Rute schwingt zurück und wieder vor.
const ROD_TIP_OFF: Array[Vector2i] = [
	Vector2i(21, -21), Vector2i(21, -21), Vector2i(21, -21),
	Vector2i(21, -21), Vector2i(21, -21), Vector2i(21, -21),
	Vector2i(-5, -19), Vector2i(-19, -13), Vector2i(19, -9), Vector2i(21, 1),
]
## Wie weit sich die Rute quer zur Achse biegt. Eine gerade Rute sieht aus
## wie ein Stock; die Biegung macht aus dem Wurf eine Bewegung.
const ROD_BEND: Array[float] = [1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 3.0, 4.0, -3.5, -2.0]

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
