## Basisklasse aller Fangbedingungen. Erfüllt sich selbst immer.
## Der state-Dictionary enthält: bait_id, player_level, cosmetics, zone_id.
class_name CatchCondition
extends Resource

func is_met(_state: Dictionary) -> bool:
	return true

func describe() -> String:
	return ""
