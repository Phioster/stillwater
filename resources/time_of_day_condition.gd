## Beisst nur in einem Zeitfenster der echten Uhr. Ueber Mitternacht hinweg
## gueltig, wenn from_hour groesser als to_hour ist (z. B. 21 bis 4).
class_name TimeOfDayCondition
extends CatchCondition

@export_range(0, 23) var from_hour: int = 0
@export_range(0, 23) var to_hour: int = 23
@export var window_name: String = ""

func is_met(state: Dictionary) -> bool:
	# Das Mondglas hebt die Zeitbedingung auf. Hier statt beim Wurf, damit
	# jede Prüfung -- auch die im Journal -- dieselbe Antwort gibt.
	if bool(state.get("ignore_time_of_day", false)):
		return true
	var h := int(state.get("hour_of_day", 12))
	if from_hour <= to_hour:
		return h >= from_hour and h <= to_hour
	return h >= from_hour or h <= to_hour

func describe() -> String:
	return "Nur %s" % window_name if window_name != "" else "Nur zu bestimmten Stunden"
