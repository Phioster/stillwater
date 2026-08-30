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
## Gewicht ist normalverteilt, nicht gleichverteilt: seltene Ausreisser
## entstehen dann von selbst, und ein Rekord hat ein natuerliches Mass.
@export var weight_mean: float = 0.5
@export var weight_dev: float = 0.15
## Multiplikator auf Lebenspunkte und Kampfzeit dieser Art.
@export var difficulty: float = 1.0

## Gewicht eines Exemplars, das `dev` Standardabweichungen vom Mittel liegt.
func weight_at(dev: float) -> float:
	return maxf(weight_mean + dev * weight_dev, weight_mean * 0.05)

## Lesbares Gewicht mit Dezimalkomma. Unter einem Kilo in Gramm -- "840 g"
## sagt mehr als "0,84 kg", und die Kleinfische sind die haeufigen.
func weight_str(dev: float) -> String:
	var kg := weight_at(dev)
	if kg < 1.0:
		return "%d g" % int(round(kg * 1000.0))
	return ("%.2f kg" % kg).replace(".", ",")

## Name mit Groessenwort: "Laternenschleie (riesig)". Nachgestellt und
## eingeklammert, weil ein vorangestelltes Adjektiv im Deutschen nach dem
## Geschlecht gebeugt werden muesste -- der Hecht, die Schleie, das Rotauge.
## Die mittlere Groesse ist stumm und faellt ganz weg.
func full_name(dev: float) -> String:
	var size := FishRoll.size_name(dev)
	return display_name if size == "" else "%s (%s)" % [display_name, size]

@export_group("Secret")
@export var is_secret: bool = false
@export var secret_chance: float = 0.0
@export var secret_hint: String = ""
@export var conditions: Array[CatchCondition] = []
