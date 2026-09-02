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

## 128 ist die Arbeitsgröße des Bildmodells. Bei Vergrößerung 2 steht die
## Figur genauso groß auf dem Schirm wie vorher bei 256 und Vergrößerung 1
## — kostet aber ein Viertel an Textur und beim Erzeugen von Animationen
## ein Viertel an Rechenaufwand.
const FRAME_SIZE: int = 128
## 24 Bilder: neun fuer den Ruhelauf, neun fuers Blinzeln, sechs fuer den
## Wurf (siehe tools/import_character.py).
const FRAMES: int = 24
## Wo der Ruhelauf endet.
const IDLE_FRAMES: int = 9
## Zu JEDEM Ruhebild gehoert ein Blinzelbild: BLINK_START + Ruhebild. Ein
## einziges Blinzelbild liesse den Kopf springen, denn ueber den Atemzug
## wandert der Scheitel acht Pixel.
const BLINK_START: int = 9
## Ab hier laeuft der Wurf.
const CAST_START: int = 18

## Der Ruhelauf ist eine geschlossene Schleife. Gemessen aendert der groesste
## Schritt innerhalb der Reihe 299 Umrisspixel, der Rundschluss vom letzten
## aufs erste Bild nur 258 — der Sprung faellt nicht auf.
const IDLE_ORDER: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8]

## Der Griff je Pose -- an der Hand der Figur gemessen (rod_grip in
## tools/import_character.py, das die Werte beim Bauen ausgibt). Seitlich
## steht die Hand ueber den ganzen Atemzug still, sie hebt und senkt sich
## aber um zwoelf Pixel; die Rute geht mit.
const ROD_ANCHOR: Array[Vector2i] = [
	Vector2i(61, 74), Vector2i(61, 74), Vector2i(61, 74), Vector2i(62, 74),
	Vector2i(62, 74), Vector2i(62, 74), Vector2i(62, 74), Vector2i(62, 75),
	Vector2i(61, 74), Vector2i(61, 74), Vector2i(61, 74), Vector2i(61, 74),
	Vector2i(62, 74), Vector2i(62, 74), Vector2i(62, 74), Vector2i(62, 74),
	Vector2i(62, 75), Vector2i(61, 74), Vector2i(57, 71), Vector2i(67, 61),
	Vector2i(56, 49), Vector2i(11, 24), Vector2i(87, 60), Vector2i(87, 58),
]
## Die Spitze, relativ zum Griff. Die Ruheposen tragen den Versatz der
## gezeichneten Rute (assets/source/rod_45.png, auf 0.7 verkleinert und
## entlang der Achse wieder gestreckt): die Hand liegt in der MITTE des
## Korkgriffs, die Spitze 83 rechts und 82 ueber ihr. Gemessen und nicht
## gewaehlt -- tools/import_rod.py rechnet den Wert aus und schreibt ihn
## beim Bauen auf die Konsole.
const ROD_TIP_OFF: Array[Vector2i] = [
	Vector2i(83, -82), Vector2i(83, -82), Vector2i(83, -82),
	Vector2i(83, -82), Vector2i(83, -82), Vector2i(83, -82),
	Vector2i(83, -82), Vector2i(83, -82), Vector2i(83, -82),
	Vector2i(83, -82), Vector2i(83, -82), Vector2i(83, -82),
	Vector2i(83, -82), Vector2i(83, -82), Vector2i(83, -82),
	Vector2i(83, -82), Vector2i(83, -82), Vector2i(83, -82),
	Vector2i(60, -85), Vector2i(-40, -70), Vector2i(-65, -45),
	Vector2i(65, -70), Vector2i(75, -40), Vector2i(75, -40),
]
## Wie weit sich die Rute quer zur Achse biegt. Eine gerade Rute sieht aus
## wie ein Stock; die Biegung macht aus dem Wurf eine Bewegung.
const ROD_BEND: Array[float] = [
	3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0,
	3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0,
	6.0, 8.0, 8.0, -7.0, -4.0, -4.0]

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
