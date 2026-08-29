class_name ZoneData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var fish: Array[FishData] = []
## Bildname ohne Pfad und Endung: assets/art/bg_<id>.png. Als String statt
## Texture2D, weil Texturen hier ueber TextureLoader laufen -- ein Verweis im
## .tres wuerde beim Export wieder in die .remap-Falle laufen.
@export var background_id: StringName = &"lake"
## Palettenschluessel statt Farbwerte: die Palette bleibt die einzige
## Wahrheit ueber Farben, die Zone waehlt nur aus.
@export var shore_key: StringName = &"reed_dark"
@export var foam_key: StringName = &"foam"
@export var music: AudioStream
@export var bite_time_min: float = 25.0
@export var bite_time_max: float = 45.0
@export var fight_window: float = 20.0
## rarity_id -> Gewicht
@export var rarity_weights: Dictionary = {}
@export var unlock_cost: int = 0
@export var unlock_level: int = 1
