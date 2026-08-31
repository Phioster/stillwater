## Verlangt einen wirkenden Trank aus einer bestimmten Gruppe. Über die
## Gruppe und nicht über eine einzelne Kennung: sonst hinge der Fisch an
## genau einer Stufe, und die teurere Variante desselben Tranks würde ihn
## nicht mehr locken.
class_name PotionCondition
extends CatchCondition

@export var potion_group: StringName = &""

func is_met(state: Dictionary) -> bool:
	return potion_group in state.get("potion_groups", [])

func describe() -> String:
	return "Verlangt einen wirkenden Trank"
