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
## 23 Bilder: neun fuer den Ruhelauf, neun fuers Blinzeln, fuenf fuer den
## Wurf (siehe tools/import_character.py).
const FRAMES: int = 23
## Wo der Ruhelauf endet.
const IDLE_FRAMES: int = 9
## Zu JEDEM Ruhebild gehoert ein Blinzelbild: BLINK_START + Ruhebild. Ein
## einziges Blinzelbild liesse den Kopf springen, denn ueber den Atemzug
## wandert der Scheitel acht Pixel.
const BLINK_START: int = 9
## Ab hier laeuft der Wurf.
const CAST_START: int = 18

## Der Ruhelauf laeuft hin und zurueck, nicht im Kreis. Bild 8 ist der
## Umkehrpunkt des Atemzugs: von dort direkt auf Bild 0 zu springen aendert
## 2486 Umrisspixel, der groesste Schritt innerhalb der Schwingung dagegen
## 1949 -- der Zopf wuerde sichtbar zurueckgerissen.
const IDLE_ORDER: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1]

## Der Griff je Pose -- an der Hand der Figur gemessen (rod_grip in
## tools/import_character.py, das die Werte beim Bauen ausgibt). Seitlich
## steht die Hand ueber den ganzen Atemzug still, sie hebt und senkt sich
## aber um zwoelf Pixel; die Rute geht mit.
const ROD_ANCHOR: Array[Vector2i] = [
	Vector2i(150, 127), Vector2i(150, 122), Vector2i(151, 118),
	Vector2i(151, 116), Vector2i(151, 118), Vector2i(151, 120),
	Vector2i(151, 123), Vector2i(151, 129), Vector2i(150, 127),
	Vector2i(150, 127), Vector2i(150, 122), Vector2i(151, 118),
	Vector2i(151, 116), Vector2i(151, 118), Vector2i(151, 120),
	Vector2i(151, 123), Vector2i(151, 129), Vector2i(150, 127),
	Vector2i(142, 100), Vector2i(80, 82), Vector2i(73, 69),
	Vector2i(170, 98), Vector2i(168, 130),
]
## Die Spitze, relativ zum Griff -- Richtung UND Laenge in einer Zahl.
## Alle sechs tragen dieselbe Laenge (140 Pixel, siebzig Prozent der
## Koerperhoehe): es ist EINE Rute, nur anders gehalten. Vorher hatte jede
## Wurfpose ihre eigene Laenge zwischen 79 und 104 Pixeln, und die Rute wurde
## waehrend des Wurfs sichtbar laenger und wieder kuerzer.
## Der Ruhelauf zeigt auf 1 Uhr 30, so wie die Figur gezeichnet ist.
const ROD_TIP_OFF: Array[Vector2i] = [
	Vector2i(99, -99), Vector2i(99, -99), Vector2i(99, -99),
	Vector2i(99, -99), Vector2i(99, -99), Vector2i(99, -99),
	Vector2i(99, -99), Vector2i(99, -99), Vector2i(99, -99),
	Vector2i(99, -99), Vector2i(99, -99), Vector2i(99, -99),
	Vector2i(99, -99), Vector2i(99, -99), Vector2i(99, -99),
	Vector2i(99, -99), Vector2i(99, -99), Vector2i(99, -99),
	Vector2i(81, -114), Vector2i(-69, -122), Vector2i(-115, -80),
	Vector2i(95, -103), Vector2i(123, -66),
]
## --- Die Rute hat ihr EIGENES Bildraster ------------------------------------
##
## Beim Ausholen sitzt die Faust neben dem Kopf, und die Rute zeigt von dort
## nach hinten oben. Im 256er-Feld der Figur sind an dieser Stelle nur 61
## Pixel Platz; gebraucht werden 140 (siebzig Prozent der Koerperhoehe).
## Das Feld fuer ALLE sieben Ebenen zu vergroessern kostete das Vierfache an
## Textur, obwohl sechs davon den Rand nie brauchen -- also bekommt nur die
## Rute ein groesseres, und sie wird als eigenes Sprite an den Griff der Pose
## geschoben statt in jedes Figurenbild einzeln gezeichnet.
const ROD_FRAME_SIZE: int = 320
## Wo der Griff INNERHALB eines Rutenbildes liegt: in der Mitte, damit die
## Rute in jede Richtung gleich weit reicht.
const ROD_GRIP: Vector2i = Vector2i(160, 160)
## Der Ruhelauf und das Blinzeln halten die Rute im selben Winkel -- es
## wandert nur die Hand, und die traegt jetzt das Sprite. Achtzehn Posen
## teilen sich deshalb EIN Rutenbild, und eine neue Rute kostet sechs
## Zeichnungen statt dreiundzwanzig.
const ROD_FRAMES: int = 6
const ROD_FRAME: Array[int] = [
	0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0,
	1, 2, 3, 4, 5,
]

## Wie weit sich die Rute quer zur Achse biegt. Eine gerade Rute sieht aus
## wie ein Stock; die Biegung macht aus dem Wurf eine Bewegung.
const ROD_BEND: Array[float] = [
	3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0,
	3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0,
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

## Wohin das Rutensprite muss, damit sein Griff auf dem Anker dieser Pose
## liegt. Das Sprite ist groesser als das Figurenfeld und haengt deshalb an
## einer eigenen Position, nicht am gemeinsamen Bildindex.
static func rod_offset(frame: int) -> Vector2i:
	return ROD_ANCHOR[frame_of(frame)] - ROD_GRIP
