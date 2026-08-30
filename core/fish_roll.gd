## Alle Würfe, die aus einer Fischart ein konkretes Exemplar machen.
## Rein statisch und ohne Zustand, damit jeder Wurf einzeln testbar ist.
class_name FishRoll
extends RefCounted

## Der Rang sagt, wie gross DIESES Exemplar ist -- unabhaengig davon, wie
## selten seine Art ist. Ein gewoehnlicher Fisch in S+ ist ein Ereignis,
## ein legendaerer in E eine Enttaeuschung mit Sammelwert.
const RANK_NAMES: Array[String] = ["E", "D", "C", "B", "A", "S", "S+"]
## Untergrenzen in Standardabweichungen. Ein Durchschnittsfisch (0.0) ist C.
const RANK_THRESHOLDS: Array[float] = [-1.5, -0.5, 0.5, 1.5, 2.25, 3.0]
const RANK_VALUE_MULTS: Array[float] = [0.6, 0.8, 1.0, 1.3, 1.7, 2.4, 3.5]
## Lebenspunkte je Rang. Verdoppeln sich, damit ein Rang spuerbar ist.
const RANK_HEALTH: Array[float] = [7.0, 14.0, 28.0, 54.0, 108.0, 216.0, 432.0]
## Groessenwoerter. Die Mitte ist absichtlich stumm: ein durchschnittlicher
## Fisch bekommt kein Adjektiv, sonst nutzt sich das Lob ab.
const SIZE_NAMES: Array[String] = ["winzig", "klein", "", "groß", "riesig"]
const SIZE_THRESHOLDS: Array[float] = [-1.5, -0.5, 0.5, 1.5]
## So weit darf ein Exemplar vom Mittel abweichen.
const DEV_LIMIT: float = 3.5
const SHINY_BASE: float = 1.0 / 800.0

## Wie viele Standardabweichungen dieses Exemplar vom Mittel liegt. Nur
## dieser Wert wird gespeichert -- das Gewicht folgt daraus jederzeit.
static func roll_deviation(bait_shift: float, rng: StillRNG) -> float:
	return clampf(rng.randfn(bait_shift, 1.0), -DEV_LIMIT, DEV_LIMIT)

static func rank_for_deviation(dev: float) -> int:
	for i in RANK_THRESHOLDS.size():
		if dev < RANK_THRESHOLDS[i]:
			return i
	return RANK_NAMES.size() - 1

static func size_name(dev: float) -> String:
	for i in SIZE_THRESHOLDS.size():
		if dev < SIZE_THRESHOLDS[i]:
			return SIZE_NAMES[i]
	return SIZE_NAMES[SIZE_NAMES.size() - 1]

## Lebenspunkte, die im Kampf abgetragen werden muessen.
static func health_for(fish: FishData, rank: int) -> float:
	return RANK_HEALTH[clampi(rank, 0, RANK_HEALTH.size() - 1)] * fish.difficulty

## Zeit waechst mit dem Rang, aber LANGSAMER als die Lebenspunkte. Dadurch
## holt die Rute allein die kleinen Fische, und die grossen verlangen Tippen.
## Genau daran haengt, dass Idle und aktives Spiel dasselbe System bleiben.
const RANK_TIME_MULTS: Array[float] = [0.7, 0.85, 1.0, 1.2, 1.5, 1.9, 2.4]

## Bewusst OHNE difficulty: skalierte die Zeit mit, kuerzte sich die
## Schwierigkeit vollstaendig weg und waere wirkungslos. Sie liegt allein
## auf den Lebenspunkten.
static func time_for(_fish: FishData, rank: int, base_window: float) -> float:
	return base_window * RANK_TIME_MULTS[clampi(rank, 0, RANK_TIME_MULTS.size() - 1)]

static func roll_shiny(fish_level: int, consumable_bonus: float, rng: StillRNG) -> bool:
	return rng.randf() < SHINY_BASE * (1.0 + 0.05 * float(fish_level)) * consumable_bonus
