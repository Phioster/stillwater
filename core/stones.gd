## Steine flitschen: der Zeitvertreib fuer die Wartezeit zwischen zwei Bissen.
##
## Nur die Rechnung, keine Knoten -- damit die Tests nachrechnen koennen, was
## am fertigen Bild nicht zu pruefen waere (siehe core/reeds.gd).
##
## Vier Regeln stehen ueber allen Zahlen hier: kein Ertrag, nichts zu
## verpassen, kein Nachteil, kein verlorener Fisch. Wer eine davon aufweicht,
## macht aus einem Zeitvertreib eine Aufgabe.
class_name Stones
extends RefCounted

## Ein voller Weg der Ladung: hoch und wieder runter. Schnell genug, dass ein
## guter Wurf Treffsicherheit braucht -- gemuetlich war er beliebig oft
## wiederholbar und damit keine Leistung. Bei 0,8 s bleiben fuer die volle
## Punktzahl noch 68 ms je Zyklus.
const ZYKLUS: float = 0.8
## Wie lange das Band fuer EINEN Weg braucht. Deutlich langsamer als die
## Ladung, sonst faengt man es nur zufaellig.
const BAND_WEG: float = 3.0
## Hoehe des Bandes als Anteil der Balkenhoehe.
const BAND_HOEHE: float = 0.12
## Das Band liegt im oberen Drittel (seine Unterkante bei 0,66) und nirgends
## sonst. Nur so passt der Bonus zur Zahl: wer ihn bekommt, hat auch schon
## fast voll geladen -- tief unten waere ein Bandtreffer eine Belohnung fuer
## einen schwachen Wurf gewesen.
const BAND_UNTEN: float = 0.72
const BAND_OBEN: float = 0.94

## Darunter plumpst der Stein nur.
const PLUMPS: float = 0.15
## Was die Ladung allein hoechstens einbringt.
const GRUND_MAX: int = 6
const BAND_BONUS: int = 2

## Wie nah ein Aufsetzer an den rechten Bildrand darf. Weiter draussen
## halbiert clip_contents seinen Ring -- und zwar den des besten Wurfs.
const RAND: float = 0.03
## Von wo bis wohin die Aufsetzer ins Bild wandern, als Anteil der Wasserhoehe.
const TIEFE_VON: float = 0.15
const TIEFE_BIS: float = 0.80

## Dreieckig, nicht sinusfoermig: gleichmaessig hoch, gleichmaessig runter.
## Ein Sinus verweilt an den Enden, und dann haengt der Balken oben fest.
static func ladung(zeit: float) -> float:
	var p := fposmod(zeit / ZYKLUS, 1.0)
	return 1.0 - absf(p * 2.0 - 1.0)

## Die Mitte des goldenen Bandes. Kehrt an den Enden um, statt zurueckzu-
## springen -- ein Sprung sieht aus wie ein Fehler.
static func band_mitte(zeit: float) -> float:
	var p := fposmod(zeit / (BAND_WEG * 2.0), 1.0)
	return lerpf(BAND_UNTEN, BAND_OBEN, 1.0 - absf(p * 2.0 - 1.0))

static func im_band(wert: float, zeit: float) -> bool:
	return absf(wert - band_mitte(zeit)) <= BAND_HOEHE * 0.5

## Was ein Wurf einbringt -- eine Zahl, kein Gegenstand.
static func spruenge(wert: float, getroffen: bool) -> int:
	if wert < PLUMPS:
		return 0
	var anteil := (wert - PLUMPS) / (1.0 - PLUMPS)
	var grund := clampi(1 + int(round(anteil * float(GRUND_MAX - 1))),
		1, GRUND_MAX)
	return grund + (BAND_BONUS if getroffen else 0)

## Wo der nummer-te Aufsetzer liegt: (anteil_x, tiefe). Schrittweite und
## Tiefenschritt kommen aus dem verbleibenden Platz und der Hoechstzahl der
## Spruenge, nicht aus festen Zahlen -- sonst fielen beim besten moeglichen
## Wurf die letzten beiden Aufsetzer am Bildrand aufeinander.
static func aufsetzer_ort(start_x: float, nummer: int) -> Vector2:
	var hoechste := GRUND_MAX + BAND_BONUS
	var von := clampf(start_x, 0.0, 1.0 - RAND)
	var schritt := (1.0 - RAND - von) / float(hoechste)
	var tiefe := TIEFE_VON + (TIEFE_BIS - TIEFE_VON) \
		* float(nummer) / float(hoechste - 1)
	return Vector2(clampf(von + float(nummer + 1) * schritt, 0.0, 1.0 - RAND),
		clampf(tiefe, TIEFE_VON, TIEFE_BIS))

const BALKEN_BILD: String = "res://assets/art/ladebalken.png"
## Ab welcher Deckung ein Bildpunkt zum Balken zaehlt. Steht hier und nicht
## in der Voreinstellung, weil die Tests dieselbe Grenze brauchen: in der CI
## wird das PNG verlustbehaftet importiert.
const MASKE_SCHWELLE: float = 0.1

static var _maske: BitMap = null
static var _groesse: Vector2i = Vector2i.ZERO

static func maske() -> BitMap:
	if _maske != null:
		return _maske
	var bild := TextureLoader.load_texture(BALKEN_BILD).get_image()
	if bild.is_compressed():
		bild.decompress()
	if bild.get_format() != Image.FORMAT_RGBA8:
		bild.convert(Image.FORMAT_RGBA8)
	_groesse = Vector2i(bild.get_width(), bild.get_height())
	_maske = BitMap.new()
	_maske.create_from_image_alpha(bild, MASKE_SCHWELLE)
	return _maske

static func balken_groesse() -> Vector2i:
	maske()
	return _groesse

## Wo diese Bildzeile im Balken liegt, von unten gemessen. Fuellkante und
## goldenes Band lesen dieselbe Zahl -- zwei Rechnungen drifteten lautlos
## auseinander.
static func zeilen_anteil(zeile: int) -> float:
	var g := balken_groesse()
	if g.y <= 0:
		return 1.0
	return 1.0 - (float(zeile) + 0.5) / float(g.y)

## Ob diese Bildzeile bei diesem Ladestand gefuellt ist. Zeile 0 ist oben,
## gefuellt wird von unten.
static func gefuellt(zeile: int, wert: float) -> bool:
	if balken_groesse().y <= 0:
		return false
	return zeilen_anteil(zeile) <= wert
