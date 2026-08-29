class_name ZoneData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var fish: Array[FishData] = []
@export var background: Texture2D
@export var music: AudioStream
@export var bite_time_min: float = 25.0
@export var bite_time_max: float = 45.0
@export var fight_window: float = 20.0
## rarity_id -> Gewicht
@export var rarity_weights: Dictionary = {}
@export var unlock_cost: int = 0
@export var unlock_level: int = 1
