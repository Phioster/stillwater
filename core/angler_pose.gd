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
## Die Spitze, relativ zum Griff. Die Rute hat ihr EIGENES Bildraster und
## sitzt deshalb in ROD_GRIP, nicht im Figurengriff. Alle Posen tragen die
## gleiche Laenge: 63 Pixel (65 Prozent der sitzenden Figurenhoehe, 97 Pixel).
## Der Ruhelauf zeigt auf 1 Uhr 30, wie die Figur gezeichnet ist.
const ROD_TIP_OFF: Array[Vector2i] = [
	Vector2i(45, -44), Vector2i(45, -44), Vector2i(45, -44),
	Vector2i(45, -44), Vector2i(45, -44), Vector2i(45, -44),
	Vector2i(45, -44), Vector2i(45, -44), Vector2i(45, -44),
	Vector2i(45, -44), Vector2i(45, -44), Vector2i(45, -44),
	Vector2i(45, -44), Vector2i(45, -44), Vector2i(45, -44),
	Vector2i(45, -44), Vector2i(45, -44), Vector2i(45, -44),
	Vector2i(36, -51), Vector2i(-31, -55), Vector2i(-52, -36),
	Vector2i(43, -46), Vector2i(56, -30), Vector2i(54, 32),
]
## Wie weit sich die Rute quer zur Achse biegt. Eine gerade Rute sieht aus
## wie ein Stock; die Biegung macht aus dem Wurf eine Bewegung.
const ROD_BEND: Array[float] = [
	3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0,
	3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0,
	6.0, 8.0, 8.0, -7.0, -4.0, -4.0, -4.0]

## --- Die Rute hat ihr EIGENES Bildraster ------------------------------------
##
## Beim Ausholen sitzt die Faust neben dem Kopf, und die Rute zeigt von dort
## nach hinten oben. Im 128er-Feld der Figur sind an dieser Stelle nur wenig
## Platz; das Rasterfeld wird groesser, damit die Rute nicht abgeschnitten wird.
## Die Rute wird als eigenes Sprite an den Griff der Pose geschoben statt
## in jedes Figurenbild einzeln gezeichnet.
const ROD_FRAME_SIZE: int = 320
## Wo der Griff INNERHALB eines Rutenbildes liegt: in der Mitte, damit die
## Rute in jede Richtung gleich weit reicht.
const ROD_GRIP: Vector2i = Vector2i(160, 160)
## Der Ruhelauf und das Blinzeln halten die Rute im selben Winkel -- es
## wandert nur die Hand, und die traegt jetzt das Sprite. Achtzehn Posen
## teilen sich deshalb EIN Rutenbild, und eine neue Rute kostet sieben
## Zeichnungen statt vierundzwanzig.
const ROD_FRAMES: int = 7
const ROD_FRAME: Array[int] = [
	0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0,
	1, 2, 3, 4, 5, 6,
]

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

## Wohin das Rutensprite muss, damit sein Griff auf dem Anker dieser Pose
## liegt. Das Sprite ist groesser als das Figurenfeld und haengt deshalb an
## einer eigenen Position, nicht am gemeinsamen Bildindex.
static func rod_offset(frame: int) -> Vector2i:
	return ROD_ANCHOR[frame_of(frame)] - ROD_GRIP
