## Die einzige Preisformel des Projekts. Wer anderswo einen Preis rechnet,
## macht einen Fehler.
class_name Economy
extends RefCounted

const SHINY_MULT: float = 4.0

static func sell_price(caught: CaughtFish, fish: FishData, rarity: RarityData, consumable_bonus: float = 1.0) -> int:
	var pct := FishRoll.percentile(fish, caught.weight)
	var price := float(fish.base_value)
	price *= rarity.value_mult
	price *= FishRoll.QUALITY_MULTS[clampi(caught.quality, 0, FishRoll.QUALITY_MULTS.size() - 1)]
	price *= (0.5 + pct)
	if caught.is_shiny:
		price *= SHINY_MULT
	price *= consumable_bonus
	return int(floor(price))
