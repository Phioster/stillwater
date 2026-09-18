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
const DAUER: float = 18.0

## Grundwerte der Sichel, am Geraet an den Reglern der Probe eingestellt
## (2026-09-18): langsam, klein und zaeh. Das ist ein Spielanfang, kein
## Rasenmaeher -- was darueber hinausgeht, kommt aus dem Ausbau.
const DREHUNG: float = 2.0
const REICHWEITE: float = 50.0
const SCHNEIDE: float = 1.0
## Wie breit die Schneide trifft, im Bogenmass. Ein voller Kreis waere ein
## Rasenmaeher; der Reiz ist, dass die Klinge vorbeikommen MUSS.
const SEKTOR: float = 1.40
## Zwei Treffer derselben Umdrehung auf denselben Halm zaehlen als einer.
const TREFFER_PAUSE: float = 0.10

const NACHWUCHS: float = 0.5
const START_HALME: int = 24
const SPALTEN: int = 7
const ZEILEN: int = 7

## Das Schilfbild hat drei Halme nebeneinander: voll, angeschnitten, Stummel.
## Ein Halm, der nach jedem Treffer gleich aussieht, gibt keine Rueckmeldung.
const HALM_B: int = 34
const HALM_STUFEN: int = 3
## Wie viele GEZEICHNETE Windstellungen der Horst am Ufer hat
## (tools/sichel_bauen.py: WIND). Gezeichnet und nicht verschoben -- ein
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
## Schaerfe der Sichel. Mindestens einer -- eine Sichel, der nichts mehr
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

## Trifft die Sichel diesen Halm? Getrennt vom Zeichnen, damit die Tests
## nachrechnen koennen -- am fertigen Bild ginge das nicht.
static func trifft(halm: Vector2, klinge: Vector2, winkel: float,
		reichweite: float) -> bool:
	var d := halm - klinge
	if d.length() > reichweite:
		return false
	return absf(wrapf(d.angle() - winkel, -PI, PI)) <= SEKTOR * 0.5

func to_dict() -> Dictionary:
	return {"cut_slot": cut_slot}

func load_dict(d: Dictionary) -> void:
	cut_slot = int(d.get("cut_slot", -1))
