## Die Zahlen eines Spielstands. Reines Mitzählen — nichts hier beeinflusst
## das Spiel, es erinnert sich nur.
##
## Bewusst getrennt vom Journal: das Journal ist die Sammlung, das hier ist
## die Bilanz. Beides in einem Topf hätte bedeutet, dass ein neuer Zähler
## die Sammlung anfasst.
class_name Records
extends RefCounted

var started_unix: int = int(Time.get_unix_time_from_system())
var playtime: float = 0.0
var fish_caught: int = 0
var shiny_caught: int = 0
var fish_escaped: int = 0
var fish_sold: int = 0
var coins_earned: int = 0
var coins_spent: int = 0
var orbs_tapped: int = 0
var potions_drunk: int = 0
var quests_done: int = 0
var casts: int = 0

const FIELDS := ["started_unix", "playtime", "fish_caught", "shiny_caught",
	"fish_escaped", "fish_sold", "coins_earned", "coins_spent", "orbs_tapped",
	"potions_drunk", "quests_done", "casts"]

func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for f in FIELDS:
		out[f] = get(f)
	return out

func load_dict(d: Dictionary) -> void:
	for f in FIELDS:
		if not d.has(f):
			continue
		var v = d[f]
		if v is float or v is int:
			set(f, v if f == "playtime" else int(v))

## Wie lange schon gespielt wird, als "3 h 12 min".
func playtime_text() -> String:
	var total := int(playtime)
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	if hours > 0:
		return "%d h %d min" % [hours, minutes]
	return "%d min" % minutes

## Tage seit dem ersten Wurf.
func days_since_start() -> int:
	var seconds := int(Time.get_unix_time_from_system()) - started_unix
	return maxi(seconds / 86400, 0)
