class_name UpgradeData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var max_level: int = 50
@export var base_cost: int = 50
@export var cost_growth: float = 1.6
@export var value_base: float = 0.0
@export var value_per_level: float = 1.0

func cost_at(level: int) -> int:
	return int(floor(float(base_cost) * pow(cost_growth, float(level))))

func value_at(level: int) -> float:
	return value_base + value_per_level * float(level)
