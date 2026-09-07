## ERZEUGT von tools/teile_bauen.py -- nicht von Hand aendern.
##
## Die Geometrie der Teileblaetter. Jedes Teil ist auf seinen eigenen
## Rahmen zugeschnitten -- das ist der Sinn des Umbaus, und es heisst,
## dass niemand die Masse raten kann. Sie werden am Bild gemessen und
## hier abgelegt, weil Godot das Bauwerkzeug nicht aufrufen kann.
class_name AnglerParts
extends RefCounted

const FRAME: int = 128

## Zeichenreihenfolge der Teile. Der Kopf liegt ueber dem Rumpf: lag
## es umgekehrt, frass sein Schulterumriss beim Absenken die
## Kinnzeile. Der Hals gehoert dahinter, sonst schiebt er sich beim
## Neigen ueber den Kragen.
const ORDER: Array[StringName] = [&"zopf", &"beine", &"hals", &"rumpf", &"kopf", &"auge", &"armfern", &"arm"]

## Diese Teile haengen am Kopf und gehen mit seinem Versatz mit.
const AT_HEAD: Array[StringName] = [&"zopf", &"kopf", &"hals", &"auge"]

## Rahmen und Anker im 128er Feld, je Teil.
const BOX := {
	&"zopf": Rect2i(34, 5, 21, 33),
	&"beine": Rect2i(64, 87, 37, 36),
	&"hals": Rect2i(54, 28, 6, 4),
	&"rumpf": Rect2i(44, 30, 45, 59),
	&"kopf": Rect2i(47, 5, 25, 28),
	&"auge": Rect2i(63, 20, 4, 3),
	&"armfern": Rect2i(67, 51, 7, 19),
	&"arm": Rect2i(45, 36, 38, 42),
}

## Wieviele Bilder ein Blatt traegt.
const STATES := {
	&"zopf": 28,
	&"beine": 13,
	&"hals": 1,
	&"rumpf": 1,
	&"kopf": 1,
	&"auge": 3,
	&"armfern": 1,
	&"arm": 11,
}

## Welche Kosmetikebenen in diesem Teil ueberhaupt vorkommen. Eine
## Ebene ohne Pixel bekommt kein Blatt und braucht kein Sprite.
const LAYERS := {
	&"zopf": [&"hair", &"base"],
	&"beine": [&"skin", &"boots", &"base"],
	&"hals": [&"skin", &"base"],
	&"rumpf": [&"skin", &"shirt", &"pants", &"base"],
	&"kopf": [&"skin", &"hair", &"base"],
	&"auge": [&"skin", &"hair", &"base"],
	&"armfern": [&"skin", &"shirt", &"base"],
	&"arm": [&"skin", &"shirt", &"base"],
}

## Der Zustand des Zopfs ist das Tripel aus Atem, Zopfweite und
## Kopfversatz: seine Naht zum Kopf liegt je nach allen dreien
## woanders und ist ins Blatt gebacken.
const ZOPF_INDEX := {
	Vector3i(0, -1, 0): 0,
	Vector3i(0, 0, -1): 1,
	Vector3i(0, 0, 0): 2,
	Vector3i(0, 1, -1): 3,
	Vector3i(0, 1, 0): 4,
	Vector3i(0, 2, -2): 5,
	Vector3i(0, 2, -1): 6,
	Vector3i(0, 2, 0): 7,
	Vector3i(0, 3, -2): 8,
	Vector3i(0, 3, -1): 9,
	Vector3i(0, 3, 0): 10,
	Vector3i(0, 4, -2): 11,
	Vector3i(0, 4, -1): 12,
	Vector3i(0, 5, -2): 13,
	Vector3i(1, -2, 0): 14,
	Vector3i(1, -1, -1): 15,
	Vector3i(1, -1, 0): 16,
	Vector3i(1, 0, -1): 17,
	Vector3i(1, 0, 0): 18,
	Vector3i(1, 1, -2): 19,
	Vector3i(1, 1, -1): 20,
	Vector3i(1, 1, 0): 21,
	Vector3i(1, 2, -2): 22,
	Vector3i(1, 2, -1): 23,
	Vector3i(1, 2, 0): 24,
	Vector3i(1, 3, -2): 25,
	Vector3i(1, 3, -1): 26,
	Vector3i(1, 4, -2): 27,
}

const LEG_SPREADS: Array[int] = [-6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6]
const EYES: Array[StringName] = [&"open", &"half", &"closed"]

## --- Vergleichsreihen fuer den Bewegungstest ---------------------
##
## Die Formeln stehen zweimal: in Python fuer die Vorschau, in
## GDScript fuers Spiel. Das ist bewusst in Kauf genommen -- es sind
## fuenf Zeilen Arithmetik ohne Pixelzugriff. Damit sie nicht
## auseinanderlaufen, liegen die Zahlen der Vorschau hier, und
## tests/test_angler_motion.gd rechnet sie nach.
const BREATH_STEPS: int = 32
const LEG_STEPS: int = 24
## (Atem, Zopfweite) je Schritt des Atemzugs.
const BREATH_REF: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, -1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 1), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 2), Vector2i(0, 2), Vector2i(0, 2), Vector2i(0, 2), Vector2i(0, 2), Vector2i(0, 2), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(1, -1), Vector2i(1, -1), Vector2i(1, -2), Vector2i(1, -2), Vector2i(1, -2), Vector2i(1, -2), Vector2i(1, -2), Vector2i(1, -2), Vector2i(1, -2)]
## Der Beinschwung bei Weite 4, je Schritt -- die Weite selbst wird
## im Umkehrpunkt neu gezogen und ist deshalb nicht vergleichbar.
const LEG_REF: Array[int] = [0, 1, 2, 3, 3, 4, 4, 4, 3, 3, 2, 1, 0, -1, -2, -3, -3, -4, -4, -4, -3, -3, -2, -1]
## Was der Wurf je Bild an Zopf, Kopf und Beinen setzt.
const CAST_ZOPF: Array[int] = [0, 1, 2, 2, 3, 2, 1, 0, 0, 0]
const CAST_HEAD: Array[int] = [0, 0, -1, -1, -2, -1, -1, 0, 0, 0]
const CAST_LEGS: Array[int] = [0, 2, 4, 5, 6, 3, -1, -4, -3, -1]

static func zopf_index(atem: int, weite: int, seit: int) -> int:
	return int(ZOPF_INDEX.get(Vector3i(atem, weite, seit), -1))

static func leg_index(spread: int) -> int:
	return LEG_SPREADS.find(clampi(spread, LEG_SPREADS[0],
		LEG_SPREADS[LEG_SPREADS.size() - 1]))

static func eye_index(name: StringName) -> int:
	return maxi(0, EYES.find(name))
