## Die Geometrie der Rute — an EINER Stelle.
##
## Sie stand doppelt: der Bilderzeuger zeichnete die Rute, und die Welt hatte
## eine Konstante für deren Spitze. Beim Verschieben der Rute wurde die
## Konstante nicht mitgezogen, und die Schnur begann daneben.
##
## Die Rute ist GEZEICHNET (assets/source/figure/parts/rute_mit_griff.png) und
## von tools/rute_anheften.py in die zehn Wurfwinkel gedreht. Jeder Zustand hat
## seinen eigenen Griff und seine eigene Richtung: beim Ausholen zeigt sie nach
## hinten, beim Wurf nach vorn.
##
## Bis 2026-09-07 zeigte das Spiel eine ANDERE Rute -- aus assets/source/
## rod_45.png gerechnet, grauer Schaft, grosse Rolle, doppelt so lang. Die
## Vorschau zeigte die gezeichnete. Dieselbe Sorte Abweichung wie pose_raw
## gegen sit3_rumpf, nur bei der Rute.
class_name AnglerPose
extends RefCounted

## 128 ist die Arbeitsgröße des Figurenfelds. Bei Vergrößerung 2.16 steht die
## Figur genauso groß auf dem Schirm wie vorher bei 256 und Vergrößerung 1.08
## — kostet aber ein Viertel an Textur.
const FRAME_SIZE: int = 128

## Elf Zustaende: Ruhe plus zehn Wurfbilder. Die Rute folgt dem ARM, denn dort
## ist die Faust. Zustand 0 teilt sich Bild und Griff mit Wurfbild 0 --
## sit3_arm_nah.png und wurf_arm_0.png sind byteweise dasselbe Bild.
const ROD_STATES: int = 11

## Wo der Griff im 128er Figurenfeld liegt, je Zustand. Gemessen an
## assets/source/figure/wurf_anker.json, nicht getippt.
const ROD_ANCHOR: Array[Vector2i] = [
	Vector2i(70, 68), Vector2i(70, 68), Vector2i(74, 63), Vector2i(76, 54),
	Vector2i(76, 47), Vector2i(75, 42), Vector2i(77, 48), Vector2i(76, 57),
	Vector2i(72, 66), Vector2i(67, 71), Vector2i(68, 70)]

## Die Spitze, relativ zum Griff -- am gezeichneten Rutenbild abgenommen.
## Alle elf Zustaende tragen dieselbe Laenge: 76 Pixel, gut zwei Drittel der
## sitzenden Figurenhoehe von 118.
const ROD_TIP_OFF: Array[Vector2i] = [
	Vector2i(43, -63), Vector2i(43, -63), Vector2i(24, -72),
	Vector2i(-12, -75), Vector2i(-40, -65), Vector2i(-47, -60),
	Vector2i(-34, -68), Vector2i(14, -75), Vector2i(40, -65),
	Vector2i(56, -51), Vector2i(45, -61)]

## --- Die Rute hat ihr EIGENES Bildraster ------------------------------------
##
## Beim Ausholen sitzt die Faust neben dem Kopf, und die Rute zeigt von dort
## nach hinten oben. Im 128er Feld der Figur ist an dieser Stelle wenig Platz;
## das Rasterfeld ist deshalb eigen, und die Rute wird als eigenes Sprite an
## den Griff geschoben statt in jedes Figurenbild gezeichnet.
##
## Vom Griff aus reicht sie hoechstens 75 Pixel nach oben, 58 nach rechts, 47
## nach links und 15 nach unten -- 160 fasst das mit Rand. Frueher standen
## hier 320, gerechnet fuer eine doppelt so lange Rute.
const ROD_FRAME_SIZE: int = 160
## Wo der Griff INNERHALB eines Rutenbildes liegt: in der Mitte, damit die
## Rute in jede Richtung gleich weit reicht.
const ROD_GRIP: Vector2i = Vector2i(80, 80)
## Zehn gezeichnete Winkel; Ruhe und Wurfbild 0 teilen sich einen.
const ROD_FRAMES: int = 10
const ROD_FRAME: Array[int] = [0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

static func frame_of(frame: int) -> int:
	return clampi(frame, 0, ROD_STATES - 1)

## Die Spitze für diesen Zustand — dort setzt die Schnur an.
static func rod_tip(frame: int) -> Vector2i:
	var f := frame_of(frame)
	return ROD_ANCHOR[f] + ROD_TIP_OFF[f]

## Der Griff für diesen Zustand.
static func rod_grip(frame: int) -> Vector2i:
	return ROD_ANCHOR[frame_of(frame)]

## Wohin das Rutensprite muss, damit sein Griff auf dem Anker dieses Zustands
## liegt. Das Sprite ist größer als das Figurenfeld und hängt deshalb an einer
## eigenen Position, nicht am gemeinsamen Bildindex.
static func rod_offset(frame: int) -> Vector2i:
	return ROD_ANCHOR[frame_of(frame)] - ROD_GRIP
