class_name BaitData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var cost: int = 0
@export var max_stack: int = 99
@export var unlimited: bool = false
@export var unlock_level: int = 1
## rarity_id -> Faktor auf das Raritätsgewicht der Zone. Fehlende Einträge = 1.0
@export var rarity_weight_bonus: Dictionary = {}
## Faktor auf die Bisszeit der Zone. Kleiner = es beißt schneller. Damit hat
## der Köder zwei Achsen: er sagt, WAS anbeißt (rank_probabilities) und WIE
## SCHNELL. Ohne die zweite wäre ein teurer Köder nur größer, nicht besser.
@export var bite_time_mult: float = 1.0

## Rang (0 = E bis 6 = S+) -> Gewicht. Der Köder bestimmt damit direkt, welche
## Größenklasse anbeißt — anders als eine verschobene Verteilung lässt sich das
## auf dem Köder auch versprechen: "am besten für B/A".
@export var rank_probabilities: Dictionary = {}

## Die Ränge, die dieser Köder nennenswert oft bringt, aufsteigend.
func main_ranks(threshold: float = 0.15) -> Array[int]:
	var total := 0.0
	for r in rank_probabilities:
		total += maxf(float(rank_probabilities[r]), 0.0)
	var out: Array[int] = []
	if total <= 0.0:
		return out
	for r in rank_probabilities:
		if float(rank_probabilities[r]) / total >= threshold:
			out.append(int(r))
	out.sort()
	return out
## zone_id -> Faktor. Fehlende Einträge = 1.0
@export var zone_bonus: Dictionary = {}
@export var unlocks_fish: Array[StringName] = []
