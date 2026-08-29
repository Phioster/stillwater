## Alle Würfe, die aus einer Fischart ein konkretes Exemplar machen.
## Rein statisch und ohne Zustand, damit jeder Wurf einzeln testbar ist.
class_name FishRoll
extends RefCounted

const QUALITY_NAMES: Array[String] = ["E", "D", "C", "B", "A", "S", "S+"]
const QUALITY_THRESHOLDS: Array[float] = [0.12, 0.30, 0.55, 0.75, 0.89, 0.97]
const QUALITY_MULTS: Array[float] = [0.6, 0.8, 1.0, 1.3, 1.7, 2.4, 3.5]
const WEIGHT_EXPONENT: float = 1.6
const SHINY_BASE: float = 1.0 / 800.0
const QUALITY_SPREAD: float = 0.18

static func roll_weight(fish: FishData, rng: StillRNG) -> float:
	var span := fish.weight_max - fish.weight_min
	return fish.weight_min + span * pow(rng.randf(), WEIGHT_EXPONENT)

static func percentile(fish: FishData, weight: float) -> float:
	var span := fish.weight_max - fish.weight_min
	if span <= 0.0:
		return 0.0
	return clampf((weight - fish.weight_min) / span, 0.0, 1.0)

static func roll_quality(pct: float, rarity: RarityData, rng: StillRNG) -> int:
	var q := clampf(0.5 * pct + rarity.quality_bias + rng.randfn(0.0, QUALITY_SPREAD), 0.0, 1.0)
	for i in QUALITY_THRESHOLDS.size():
		if q < QUALITY_THRESHOLDS[i]:
			return i
	return QUALITY_NAMES.size() - 1

static func roll_shiny(fish_level: int, consumable_bonus: float, rng: StillRNG) -> bool:
	return rng.randf() < SHINY_BASE * (1.0 + 0.05 * float(fish_level)) * consumable_bonus

static func strength_for(fish: FishData, rarity: RarityData, pct: float) -> float:
	return fish.strength * rarity.strength_mult * (0.75 + 0.5 * pct)
