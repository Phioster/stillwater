class_name BaitCondition
extends CatchCondition

@export var bait_id: StringName = &""

func is_met(state: Dictionary) -> bool:
	return state.get("bait_id", &"") == bait_id

func describe() -> String:
	return "Verlangt einen bestimmten Köder"
