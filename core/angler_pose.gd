## Die Geometrie der Angler-Bilder — an EINER Stelle.
##
## Sie stand doppelt: der Bilderzeuger zeichnete die Rute, und die Welt hatte
## eine Konstante für deren Spitze. Beim Verschieben der Rute wurde die
## Konstante nicht mitgezogen, und die Schnur begann daneben. Schlimmer noch:
## die Spitze wandert mit dem Bild — beim Wurf liegt sie vier Pixel tiefer als
## im Ruhebild —, und eine Konstante kann das gar nicht abbilden.
class_name AnglerPose
extends RefCounted

const FRAME_SIZE: int = 32
const FRAMES: int = 3

## Wie weit der Arm je Bild gehoben ist: ruhig, ausholen, werfen.
const ARM_OFFSET: Array[int] = [0, -3, 4]

## Die Rute läuft vom Griff diagonal nach oben rechts. ROD_START ist der
## Griff im Ruhebild; sie muss vollständig in den 32 Pixel breiten Rahmen
## passen, sonst blutet sie in den nächsten.
const ROD_START := Vector2i(17, 16)
const ROD_LENGTH: int = 14

static func arm_offset(frame: int) -> int:
	return ARM_OFFSET[clampi(frame, 0, FRAMES - 1)]

## Ein Rutenpixel in Bildkoordinaten. i läuft von 0 (Griff) bis ROD_LENGTH-1.
static func rod_pixel(frame: int, i: int) -> Vector2i:
	return Vector2i(ROD_START.x + i, ROD_START.y + arm_offset(frame) - i)

## Die Spitze für dieses Bild.
static func rod_tip(frame: int) -> Vector2i:
	return rod_pixel(frame, ROD_LENGTH - 1)
