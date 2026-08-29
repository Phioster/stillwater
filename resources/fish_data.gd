class_name FishData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var zone_id: StringName = &""
@export var rarity_id: StringName = &"common"
@export var base_value: int = 1
@export var strength: float = 10.0
@export var xp: int = 1
@export var sprite: Texture2D
@export var spawn_weight: float = 1.0
@export var preferred_baits: Array[StringName] = []
@export var preferred_bait_mult: float = 2.0
@export var weight_min: float = 0.1
@export var weight_max: float = 1.0

@export_group("Secret")
@export var is_secret: bool = false
@export var secret_chance: float = 0.0
@export var secret_hint: String = ""
@export var conditions: Array[CatchCondition] = []
