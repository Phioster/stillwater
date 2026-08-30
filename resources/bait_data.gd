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
## Um wie viele Standardabweichungen dieser Köder die Größe anhebt. Damit
## steuert der Köder den Rang des Exemplars, nicht die Art.
@export var rank_shift: float = 0.0
## zone_id -> Faktor. Fehlende Einträge = 1.0
@export var zone_bonus: Dictionary = {}
@export var unlocks_fish: Array[StringName] = []
