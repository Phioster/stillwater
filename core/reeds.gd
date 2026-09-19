## Das Schilf am Ufer und was ein Schnitt einbringt.
##
## Wie die Besucher haengt es an der UHR, nicht an einem Countdown (siehe
## core/visitors.gd): dieselbe Zeitspanne gibt dasselbe Schilf, nichts waechst
## nach, waehrend man zusieht, und wer einen Tag wegbleibt, findet EIN Schilf
## vor, nicht zwoelf. Zustand ist deshalb eine einzige Zahl -- wann zuletzt
## geschnitten wurde.
##
## Der Ertrag sind Koeder, nichts Neues: Koeder werden bei jedem Fang
## verbraucht, es gibt also schon eine Senke dafuer. Ein eigener Rohstoff
## waere eine zweite Waehrung, die niemand braucht.
class_name Reeds
extends RefCounted

## Zwei Stunden -- zwischen Haendler (eine) und Rabe (vier).
const INTERVAL: float = 7200.0
const DAUER: float = 20.0

## Grundwerte der Klinge. Das ist ein Spielanfang, kein Rasenmaeher -- was
## darueber hinausgeht, kommt aus dem Ausbau.
##
## Reichweite ist der Abstand der SPITZE von der Hand, das Messer haengt also
## mit dem Griff nach innen darunter. Sie muss deshalb mindestens so gross
## sein wie das Messer lang ist, sonst raggt der Griff auf der anderen Seite
## wieder heraus. Das Tempo ist das am Geraet
## eingestellte: 3,0 war als Ausgleich fuer die schmalere Klinge gedacht und
## fuehlte sich fuer den Anfang zu hektisch an.
const DREHUNG: float = 2.0
const REICHWEITE: float = 110.0
const SCHNEIDE: float = 1.0
## Das Bild der Klinge. Ihre MASKE ist die Trefferform -- Masse stehen
## deshalb nirgends mehr, sie kommen aus dem Bild (tools/schilfschneiden_bauen.py).
const KLINGE_BILD: String = "res://assets/art/klinge.png"
## Und dasselbe Bild nur mit dem Stahl. NUR die Schneide trifft, der Holzgriff
## faehrt bloss mit -- getrennt schon beim Bauen, weil die Farben nur dort
## exakt sind (tools/schilfschneiden_bauen.py).
const SCHNEIDE_BILD: String = "res://assets/art/klinge_schneide.png"
## Ab welcher Deckung ein Bildpunkt als Klinge zaehlt. Steht hier und nicht in
## der Voreinstellung, weil die Tests dieselbe Grenze brauchen: in der CI wird
## das PNG verlustbehaftet importiert, und mit zwei Grenzen liefen Regel und
## Bild dort um einzelne Randpixel auseinander.
const MASKE_SCHWELLE: float = 0.1

## Zwei Treffer derselben Umdrehung auf denselben Halm zaehlen als einer.
const TREFFER_PAUSE: float = 0.10

const NACHWUCHS: float = 0.5
const START_HALME: int = 24
const SPALTEN: int = 7
const ZEILEN: int = 7

## Das Schilfbild hat drei Halme nebeneinander: voll, angeschnitten, Stummel.
## Ein Halm, der nach jedem Treffer gleich aussieht, gibt keine Rueckmeldung.
const HALM_B: int = 34
const HALM_H: int = 62
const HALM_STUFEN: int = 3
## Wie viele GEZEICHNETE Windstellungen der Horst hat
## (tools/schilfschneiden_bauen.py: WIND). Gezeichnet und nicht verschoben -- ein
## geschertes Bild sah aus wie verrutschte Bildzeilen.
const WIND_BILDER: int = 26

const HALME_JE_KOEDER: int = 6
## Wie wahrscheinlich im Schilf etwas Besonderes liegt. Waechst mit der Ernte,
## aber gedeckelt: ein Fund soll ein Fund bleiben.
const FUND_BASIS: float = 0.06
const FUND_JE_HALM: float = 0.002
const FUND_DECKEL: float = 0.45

var cut_slot: int = -1

static func slot(now: float) -> int:
	return int(floor(now / INTERVAL))

func ready_at(now: float) -> bool:
	return slot(now) != cut_slot

func cut(now: float) -> void:
	cut_slot = slot(now)

## Wie viele Treffer ein Halm braucht: die Zaehigkeit der Zone gegen die
## Schaerfe der Klinge. Mindestens einer -- eine Klinge, der nichts mehr
## entgegensteht, nimmt dem Schneiden den Sinn.
static func treffer_noetig(zaehigkeit: int, schneide: float) -> int:
	return maxi(1, int(ceil(float(zaehigkeit) / maxf(schneide, 0.1))))

## Aus geschnittenen Halmen werden Koeder. Was nicht aufgeht, verfaellt --
## darum ist die Zahl klein, sonst aergert der Rest mehr als der Ertrag freut.
static func koeder_aus(halme: int) -> int:
	return halme / HALME_JE_KOEDER

static func fund_chance(halme: int) -> float:
	return minf(FUND_DECKEL, FUND_BASIS + FUND_JE_HALM * float(halme))

## Welche Koeder in diesem Schilf sitzen. Die Zone bestimmt es; steht dort
## nichts, gibt es den Koeder, den jede Zone hat.
func koeder_art(zone: ZoneData, rng: RandomNumberGenerator) -> StringName:
	if zone == null or zone.reed_baits.is_empty():
		return &"pond_grub"
	return zone.reed_baits[rng.randi_range(0, zone.reed_baits.size() - 1)]

## Was im Schilf lag -- leer, wenn nichts lag. Billiges liegt oft, Teures
## selten, dieselbe Gewichtung wie beim Paket der Raben.
func fund(halme: int, rng: RandomNumberGenerator) -> StringName:
	if rng.randf() > fund_chance(halme):
		return &""
	var pool := Database.consumables_in_order()
	if pool.is_empty():
		return &""
	var gesamt := 0.0
	for c in pool:
		gesamt += 1000.0 / maxf(float(c.cost), 1.0)
	var wurf := rng.randf() * gesamt
	var summe := 0.0
	for c in pool:
		summe += 1000.0 / maxf(float(c.cost), 1.0)
		if wurf < summe:
			return c.id
	return pool[pool.size() - 1].id

## Die Trefferform IST das Bild der Klinge: ihre Maske, in ihre eigenen
## Koordinaten gedreht.
##
## Vier Anlaeufe davor rechneten die Form nach, und drei davon rechneten eine
## ANDERE als die gezeichnete -- am Bild sah man es jedes Mal sofort, an
## Zahlen nie. Eine Form, zwei Rechnungen, geht nicht; also gibt es nur noch
## eine, und die Zeichnung ist es.
static var _maske: BitMap = null
static var _maske_groesse: Vector2i = Vector2i.ZERO

static func maske() -> BitMap:
	if _maske != null:
		return _maske
	var bild := TextureLoader.load_texture(SCHNEIDE_BILD).get_image()
	# In der CI wird das PNG komprimiert importiert, auf diesem Geraet nicht.
	if bild.is_compressed():
		bild.decompress()
	if bild.get_format() != Image.FORMAT_RGBA8:
		bild.convert(Image.FORMAT_RGBA8)
	_maske_groesse = Vector2i(bild.get_width(), bild.get_height())
	_maske = BitMap.new()
	_maske.create_from_image_alpha(bild, MASKE_SCHWELLE)
	return _maske

## Die Masse des Klingenbildes. Schneide- und Messerbild sind gleich gross --
## nur so zeigen beide auf dieselben Bildpunkte.
static func klinge_groesse() -> Vector2i:
	maske()
	return _maske_groesse

## Von wo bis wo der Stahl im Bild sitzt, in Bildpunkten. Daran haengt der
## Schweif: er soll hinter der Schneide herlaufen, nicht hinter dem Griff.
static var _bereich: Vector2 = Vector2.ZERO

static func schneide_bereich() -> Vector2:
	if _bereich != Vector2.ZERO:
		return _bereich
	var g := klinge_groesse()
	var von := g.x
	var bis := 0
	for x in g.x:
		for y in g.y:
			if maske().get_bit(x, y):
				von = mini(von, x)
				bis = maxi(bis, x + 1)
				break
	_bereich = Vector2(float(von), float(bis))
	return _bereich

## Wie weit die Mitte des Klingenbildes von der Hand weg sitzt: so weit, dass
## ihre SPITZE genau auf der Reichweite liegt. Der Ausbau bewegt also ihre
## Bahn, nicht ihre Groesse -- skaliert waere ein Klingenpixel voll ausgebaut
## dreimal so grob wie alles daneben.
static func klinge_bahn(reichweite: float, skala: float) -> float:
	return reichweite - float(klinge_groesse().x) * 0.5 * skala

## Trifft die Klinge diesen Halm? Getrennt vom Zeichnen, damit die Tests
## nachrechnen koennen -- am fertigen Bild ginge das nicht.
static func trifft(halm: Vector2, hand: Vector2, winkel: float,
		reichweite: float, skala: float) -> bool:
	var g := klinge_groesse()
	# In die Koordinaten des Bildes drehen: x ab dem Griffende nach aussen,
	# y ab seiner Oberkante nach unten.
	var d := (halm - hand).rotated(-winkel)
	var bx := (d.x - (reichweite - float(g.x) * skala)) / skala
	var by := d.y / skala + float(g.y) * 0.5
	if bx < 0.0 or by < 0.0:
		return false
	var ix := int(bx)
	var iy := int(by)
	if ix >= g.x or iy >= g.y:
		return false
	return maske().get_bit(ix, iy)

## Trifft die Klinge den Halm IRGENDWO auf ihrem Weg von "von" nach "bis"?
##
## Der Punkttest allein reichte nicht. Die Klinge ist quer nur rund sieben
## Grad breit, dreht sich bei vollem Tempo aber um sechsunddreissig Grad je
## Bild -- sie sprang also ueber Halme hinweg, ohne sie zu beruehren, und umso
## oefter, je schneller sie war. Gemessen war schnelles Kreisen deshalb
## SCHLECHTER als langsames, also genau andersherum als der Ausbau verspricht.
##
## Geprueft wird an dem Winkel des Fensters, der dem Halm am naechsten liegt:
## trifft sie dort nicht, trifft sie ihn auf dem ganzen Weg nicht.
static func trifft_im_schwung(halm: Vector2, hand: Vector2, von: float,
		bis: float, reichweite: float, skala: float) -> bool:
	var d := halm - hand
	if d.is_zero_approx():
		return trifft(halm, hand, bis, reichweite, skala)
	var theta := d.angle()
	# In das durchfahrene Fenster schieben, dann auf dessen Raender begrenzen.
	theta += TAU * roundf(((von + bis) * 0.5 - theta) / TAU)
	var winkel := clampf(theta, minf(von, bis), maxf(von, bis))
	return trifft(halm, hand, winkel, reichweite, skala)

func to_dict() -> Dictionary:
	return {"cut_slot": cut_slot}

func load_dict(d: Dictionary) -> void:
	cut_slot = int(d.get("cut_slot", -1))
