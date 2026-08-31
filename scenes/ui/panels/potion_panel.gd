## Der Trankbeutel: was man hat und was gerade wirkt.
##
## Er steht bei den Fischen und nicht im Laden, weil er zum Inventar gehört
## und nicht zum Sortiment: gekauft wird hier NICHT. Tränke kommen vom
## Waschbär-Händler und aus dem Paket des Raben — genau wie in der Referenz,
## deren Laden nur Ausbau und Köder führt. Das macht aus einem Trank ein
## Fundstück statt einer Ware aus dem Automaten.
##
## Umgeschaltet wird nach Trankart, mit demselben Knopfraster wie das Journal
## für die Zonen.
extends PanelBase

const ALL: StringName = &"alle"
## Trankgruppe -> Überschrift. Die Gruppe steht schon in den Daten (gleiche
## Gruppe heißt: ersetzt einander), also braucht die Kategorie kein zweites
## Feld, das mit ihr aus dem Tritt geraten könnte.
const GROUP_LABELS := {
	&"schimmer": "Schimmer",
	&"koeder": "Lockstoff",
	&"erfahrung": "Erfahrung",
	&"wert": "Handel",
	&"raritaet": "Seltenheit",
}
## Alles, was keine eigene Leiter hat, landet zusammen unter einem Dach.
const OTHER: String = "Besonderes"

var _category: StringName = ALL

func refresh() -> void:
	clear(self)
	add_child(_active_block())

	var owned := _owned()
	add_child(_switch(owned))

	var header := Label.new()
	header.text = "Beutel"
	header.modulate = Palette.get_color(&"accent")
	add_child(header)

	var shown := 0
	for c in owned:
		if _category != ALL and _key(c) != _category:
			continue
		shown += 1
		add_child(_row(c))
	if shown == 0:
		var empty := Label.new()
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = "Noch nichts da. Tränke bringt der Händler vorbei — oder der Rabe legt eins ab." \
			if owned.is_empty() else "In dieser Kategorie liegt gerade nichts."
		empty.modulate = Palette.get_color(&"reed_light")
		add_child(empty)

func _owned() -> Array[ConsumableData]:
	var out: Array[ConsumableData] = []
	for c in Database.consumables_in_order():
		if Game.consumable_count(c.id) > 0:
			out.append(c)
	return out

func _key(c: ConsumableData) -> StringName:
	return c.group if GROUP_LABELS.has(c.group) else &"besonderes"

func _label(key: StringName) -> String:
	return GROUP_LABELS.get(key, OTHER)

## Nur Kategorien, in denen wirklich etwas liegt. Ein Beutel soll zeigen, was
## drin ist, und nicht sechs leere Fächer.
func _switch(owned: Array[ConsumableData]) -> Control:
	var keys: Array = [ALL]
	var labels: Array = ["Alle"]
	for c in owned:
		var k := _key(c)
		if not keys.has(k):
			keys.append(k)
			labels.append(_label(k))
	if not keys.has(_category):
		_category = ALL
	return CategorySwitch.build(keys, labels, _category, func(k: Variant) -> void:
		_category = k
		refresh())

## Was gerade wirkt, mit Restzeit. Ohne das ist ein Trank Geld, das man
## ausgibt, ohne zu sehen wofür.
func _active_block() -> Control:
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "Wirkt gerade"
	title.modulate = Palette.get_color(&"accent")
	box.add_child(title)
	if Game.buffs.active.is_empty():
		var none := Label.new()
		none.text = "  nichts"
		none.modulate = Palette.get_color(&"reed_light")
		box.add_child(none)
		return box
	for id in Game.buffs.active:
		var c: ConsumableData = Database.consumables.get(id)
		if c == null:
			continue
		var line := Label.new()
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.text = "  %s — noch %s" % [c.display_name, _time_left(Game.buffs.remaining(id))]
		box.add_child(line)
	return box

func _time_left(seconds: float) -> String:
	var s := int(ceil(seconds))
	if s >= 60:
		return "%d:%02d min" % [s / 60, s % 60]
	return "%d s" % s

func _row(c: ConsumableData) -> Control:
	var box := VBoxContainer.new()

	var owned := Game.consumable_count(c.id)
	var title := Label.new()
	var running := "  ← wirkt" if Game.buffs.is_active(c.id) else ""
	title.text = "%s  (%d)%s" % [c.display_name, owned, running]
	box.add_child(title)

	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.text = "  %s · %d min" % [c.description, int(round(c.duration / 60.0))]
	desc.modulate = Palette.get_color(&"reed_light")
	box.add_child(desc)

	var use := TapButton.new()
	use.text = "Trinken"
	use.custom_minimum_size = Vector2(0, 96)
	use.tapped.connect(func() -> void:
		if not Game.use_consumable(c.id):
			use.refuse())
	box.add_child(use)
	return box
