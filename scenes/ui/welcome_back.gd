## Zeigt, was während der Abwesenheit passiert ist. Offline verdient
## niemand Geld — die Fische liegen im Inventar und wollen verkauft werden.
extends PanelContainer

func _ready() -> void:
	$Box/Close.pressed.connect(func() -> void: visible = false)
	if not SaveManager.offline_ready.is_connected(show_summary):
		SaveManager.offline_ready.connect(show_summary)
	if not SaveManager.pending_offline.is_empty():
		show_summary(SaveManager.pending_offline)

func show_summary(summary: Dictionary) -> void:
	var caught := int(summary.get("caught", 0))
	if caught <= 0:
		return
	$Box/Title.text = "Willkommen zurück"
	var lines: Array[String] = []
	lines.append("Du warst %s weg." % _duration(float(summary.get("elapsed", 0.0))))
	lines.append("Gefangen: %d Fische" % caught)
	lines.append("Erhalten: %d XP" % int(summary.get("xp", 0)))
	lines.append("Im Inventar liegen etwa %d Münzen." % int(summary.get("potential_coins", 0)))
	var discovered: Array = summary.get("discovered", [])
	if not discovered.is_empty():
		lines.append("Neu entdeckt: %d Arten" % discovered.size())
	if bool(summary.get("inventory_full", false)):
		lines.append("Die Fischkiste ist voll — das Angeln hat pausiert.")
	if bool(summary.get("was_capped", false)):
		lines.append("Angerechnet wurden höchstens 12 Stunden.")
	$Box/Body.text = "\n".join(lines)
	visible = true

func _duration(seconds: float) -> String:
	var total := int(seconds)
	var h := total / 3600
	var m := (total % 3600) / 60
	if h > 0:
		return "%d h %02d min" % [h, m]
	return "%d min" % m
