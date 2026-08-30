## Alles, was FishingSim zum Rechnen braucht. Bewusst ein einfacher
## Datenhalter ohne Node-Bezug, damit Tests ihn in drei Zeilen bauen können.
class_name SimContext
extends RefCounted

var zone: ZoneData
var bait: BaitData
var fallback_bait: BaitData
var bait_counts: Dictionary = {}

var rod_power: float = 4.0
var orb_power: float = 6.0
var consumable_bonus: float = 1.0
var shiny_bonus: float = 1.0

var player_level: int = 1
var player_xp: int = 0
var cosmetics: Dictionary = {}

var rarities: Dictionary = {}
var inventory: Inventory
var journal: Journal

## Um wie viele Standardabweichungen der aktive Koeder die Groesse anhebt.
## Der Koeder steuert damit den RANG (wie gross das Exemplar ist), nicht die
## Raritaet (welche Art anbeisst) -- zwei getrennte Achsen.
func bait_rank_shift() -> float:
	return bait.rank_shift if bait != null else 0.0

func rarity_of(fish: FishData) -> RarityData:
	var r: RarityData = rarities.get(fish.rarity_id)
	if r == null:
		r = RarityData.new()
		r.id = fish.rarity_id
	return r

## Der Zustand, gegen den Fangbedingungen prüfen.
## Stunde der echten Uhr. Als Feld statt als direkter Uhrenzugriff, damit die
## Simulation deterministisch bleibt und Tests jede Stunde stellen koennen.
var hour_of_day: int = 12

func condition_state() -> Dictionary:
	return {
		"bait_id": bait.id if bait != null else &"",
		"player_level": player_level,
		"cosmetics": cosmetics,
		"zone_id": zone.id if zone != null else &"",
		"hour_of_day": hour_of_day,
		"journal_species": journal.entries.size() if journal != null else 0,
	}

## Verbraucht einen Köder; läuft ein gekaufter Köder leer, schaltet
## automatisch auf den Grundköder zurück, damit Idle-Sessions nie hängen.
func consume_bait() -> void:
	if bait == null or bait.unlimited:
		return
	var left := int(bait_counts.get(bait.id, 0)) - 1
	bait_counts[bait.id] = maxi(left, 0)
	if left <= 0 and fallback_bait != null:
		bait = fallback_bait
