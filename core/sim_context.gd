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

## Zieht den Rang aus der Tabelle des aktiven Koeders. Ohne Tabelle bleibt es
## bei E -- ein Koeder ohne Angabe verspricht nichts und liefert das Kleinste.
func pull_rank(rng: StillRNG) -> int:
	if bait == null or bait.rank_probabilities.is_empty():
		return 0
	var weights := PackedFloat64Array()
	weights.resize(FishRoll.RANK_NAMES.size())
	for r in bait.rank_probabilities:
		var i := int(r)
		if i >= 0 and i < weights.size():
			weights[i] = maxf(float(bait.rank_probabilities[r]), 0.0)
	var picked := rng.weighted_pick(weights)
	return picked if picked >= 0 else 0

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
