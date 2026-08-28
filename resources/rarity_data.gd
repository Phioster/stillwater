class_name RarityData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var color: Color = Color.WHITE
@export var value_mult: float = 1.0
@export var xp_mult: float = 1.0
@export var strength_mult: float = 1.0
@export var quality_bias: float = 0.0

## Ab welcher Spielerstufe diese Rarität überhaupt beißt.
@export var unlock_level: int = 1
## Über wie viele Stufen sie danach auf ihr volles Gewicht anläuft. 1 heißt
## sofort voll. So ist der Anfang gewöhnlich, ohne dass später etwas fehlt.
@export var ramp_levels: int = 1

## Anteil des Zonengewichts, der auf dieser Stufe wirklich zählt: 0 vor der
## Freischaltung, dann linear bis 1.
func availability(level: int) -> float:
	if level < unlock_level:
		return 0.0
	if ramp_levels <= 1:
		return 1.0
	return clampf(float(level - unlock_level + 1) / float(ramp_levels), 0.0, 1.0)
