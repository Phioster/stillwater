## Verlangt ein bestimmtes Aussehen. Damit kosten Geheimfische nicht nur
## Zeit, sondern auch die Muenzen, die das Kleidungsstueck gekostet hat.
class_name CosmeticCondition
extends CatchCondition

@export var category: StringName = &"hat"
@export var variant: int = 0

func is_met(state: Dictionary) -> bool:
	var worn: Dictionary = state.get("cosmetics", {})
	return int(worn.get(String(category), -1)) == variant

func describe() -> String:
	return "Verlangt ein bestimmtes Aussehen"
