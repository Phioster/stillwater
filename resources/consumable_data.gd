## Ein Trank. Alle Wirkungen sind reine Faktoren auf Zahlen, die es schon
## gibt — kein Trank führt ein eigenes System ein. Das ist die wichtigste
## Regel aus der Referenzauswertung: sonst wächst mit jedem Trank die Anzahl
## der Sonderfälle im Kern.
class_name ConsumableData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cost: int = 0
@export var unlock_level: int = 1
## Wirkdauer in Sekunden.
@export var duration: float = 900.0
## Tränke derselben Gruppe ersetzen einander, statt sich zu stapeln. Sonst
## könnte man drei Stufen desselben Effekts übereinanderlegen.
@export var group: StringName = &""

@export_group("Wirkung")
@export var shiny_mult: float = 1.0
@export var value_mult: float = 1.0
@export var xp_mult: float = 1.0
## Kleiner = es beißt schneller.
@export var bite_time_mult: float = 1.0
## Größer = mehr Zeit im Kampf.
@export var fight_time_mult: float = 1.0
## rarity_id -> Faktor auf das Zonengewicht.
@export var rarity_weight_bonus: Dictionary = {}
## Hebt den Rang um so viele Stufen — das gibt es in der Referenz nicht,
## weil dort der Rang allein vom Köder kommt.
@export var rank_shift: int = 0
## Der Köder wird nicht verbraucht.
@export var free_bait: bool = false
## Tageszeit-Bedingungen gelten als erfüllt.
@export var ignore_time_of_day: bool = false
