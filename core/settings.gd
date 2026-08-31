## Alle Einstellungen an einer Stelle. Bewusst ein reiner Datenhalter mit
## Vorgaben — die Oberfläche liest und schreibt hier, der Spielstand
## serialisiert dasselbe Wörterbuch.
##
## Grundsatz aus der Referenzauswertung: Spielhilfen sind ABSCHALTBAR, keine
## Entscheidung des Entwicklers.
class_name Settings
extends RefCounted

var sound_enabled: bool = true
var volume: float = 0.8
var ui_volume: float = 0.6
## Geht ein Köder aus, schaltet das Spiel auf den Grundköder zurück, statt
## anzuhalten. Wer das nicht will, schaltet es ab.
var auto_fallback_bait: bool = true
## Nach welchem Schluessel die Fischliste sortiert wird. Gemerkt, weil eine
## Sortierung, die man bei jedem Oeffnen neu waehlt, keine ist.
var fish_sort: StringName = &"fang"

func to_dict() -> Dictionary:
	return {
		"sound_enabled": sound_enabled,
		"volume": volume,
		"ui_volume": ui_volume,
		"auto_fallback_bait": auto_fallback_bait,
		"fish_sort": String(fish_sort),
	}

## Tolerant gegen Unsinn im Spielstand: ein falsch typisierter Wert darf das
## Laden nicht sprengen. GDScript kennt kein bool("ja") -- ein direkter
## Aufruf waere hier ein Absturz statt eines Rueckfalls.
func load_dict(d: Dictionary) -> void:
	sound_enabled = _bool(d.get("sound_enabled"), sound_enabled)
	volume = _ratio(d.get("volume"), volume)
	ui_volume = _ratio(d.get("ui_volume"), ui_volume)
	auto_fallback_bait = _bool(d.get("auto_fallback_bait"), auto_fallback_bait)
	var mode := StringName(str(d.get("fish_sort", fish_sort)))
	fish_sort = mode if FishSort.is_mode(mode) else fish_sort

func _bool(v, fallback: bool) -> bool:
	return v if v is bool else fallback

func _ratio(v, fallback: float) -> float:
	if v is float or v is int:
		return clampf(float(v), 0.0, 1.0)
	return fallback
