## Die Bilanz. Reines Nachschauen — hier lässt sich nichts drücken.
##
## Getrennt vom Journal: das Journal ist die Sammlung, das hier sind die
## Zahlen drumherum.
extends PanelBase

func refresh() -> void:
	clear(self)
	var r := Game.records
	var j := Game.ctx.journal

	var all: Array[FishData] = []
	for zone_id in Database.zones:
		all.append_array(Database.fish_of_zone(zone_id))

	add_child(_title("Sammlung"))
	add_child(_line("Arten entdeckt", "%d von %d" % [_countable(j, all), _total(all)]))
	add_child(_line("Ränge gesammelt", "%d %%" % int(round(j.rank_completion(all) * 100.0))))
	add_child(_line("Schimmernde Fänge", str(r.shiny_caught)))

	add_child(_title("Angeln"))
	add_child(_line("Würfe", str(r.casts)))
	add_child(_line("Fänge", str(r.fish_caught)))
	add_child(_line("Entkommen", str(r.fish_escaped)))
	add_child(_line("Fangpunkte getroffen", str(r.orbs_tapped)))
	add_child(_line("Aufträge erfüllt", str(r.quests_done)))
	add_child(_line("Tränke getrunken", str(r.potions_drunk)))

	add_child(_title("Münzen"))
	add_child(_line("Eingenommen", _grouped(r.coins_earned)))
	add_child(_line("Ausgegeben", _grouped(r.coins_spent)))
	add_child(_line("Fische verkauft", str(r.fish_sold)))

	add_child(_title("Zeit"))
	add_child(_line("Gespielt", r.playtime_text()))
	add_child(_line("Dabei seit", "%d Tagen" % r.days_since_start()))

func _countable(j: Journal, all: Array[FishData]) -> int:
	var n := 0
	for f in all:
		if not f.is_secret and j.is_discovered(f.id):
			n += 1
	return n

func _total(all: Array[FishData]) -> int:
	var n := 0
	for f in all:
		if not f.is_secret:
			n += 1
	return n

func _title(text: String) -> Control:
	var l := Label.new()
	l.text = text
	l.modulate = Palette.get_color(&"accent")
	l.custom_minimum_size = Vector2(0, 56)
	return l

func _line(name: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 44)
	var left := Label.new()
	left.text = "  " + name
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var right := Label.new()
	right.text = value
	row.add_child(right)
	return row

func _grouped(value: int) -> String:
	var s := str(absi(value))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if value < 0 else "") + out
