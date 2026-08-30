## Die einzige Preisformel des Projekts. Wer anderswo einen Preis rechnet,
## macht einen Fehler.
class_name Economy
extends RefCounted

const SHINY_MULT: float = 4.0

static func sell_price(caught: CaughtFish, fish: FishData, rarity: RarityData, consumable_bonus: float = 1.0) -> int:
	var price := float(fish.base_value)
	price *= rarity.value_mult
	# Der Rang traegt den Preis, die Abweichung darin feint ihn nach: sonst
	# waeren zwei Fische desselben Rangs exakt gleich viel wert.
	price *= FishRoll.RANK_VALUE_MULTS[clampi(caught.rank, 0, FishRoll.RANK_VALUE_MULTS.size() - 1)]
	price *= 1.0 + 0.08 * caught.weight_dev
	if caught.is_shiny:
		price *= SHINY_MULT
	price *= consumable_bonus
	return int(floor(price))
