class_name LevelCondition
extends CatchCondition

@export var min_level: int = 1

func is_met(state: Dictionary) -> bool:
	return int(state.get("player_level", 1)) >= min_level

func describe() -> String:
	return "Ab Level %d" % min_level
