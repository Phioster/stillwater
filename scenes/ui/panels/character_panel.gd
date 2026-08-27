## Charakteranpassung. Rein kosmetisch -- keine Wahl hier ändert einen
## Spielwert, kann aber später eine Fangbedingung erfüllen.
extends PanelBase

const SLOTS := [
	{"key": &"skin", "label": "Hautton"},
	{"key": &"hair", "label": "Frisur"},
	{"key": &"hair_color", "label": "Haarfarbe"},
	{"key": &"shirt", "label": "Oberteil"},
	{"key": &"pants", "label": "Hose"},
	{"key": &"hat", "label": "Hut"},
]

func refresh() -> void:
	clear(self)

	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "Aussehen verändert keine Werte. Manche Fische achten trotzdem darauf."
	add_child(note)

	for slot in SLOTS:
		add_child(_row(slot["key"], slot["label"]))

func _row(category: StringName, label: String) -> Control:
	var current := int(Game.cosmetics.get(String(category), 0))
	var count := _variant_count(category)
	var box := VBoxContainer.new()

	var title := Label.new()
	title.text = "%s  %d / %d" % [label, current + 1, count]
	box.add_child(title)

	var row := HBoxContainer.new()
	for variant in count:
		row.add_child(_variant_button(category, variant, current))
	box.add_child(row)

	return box

func _variant_count(category: StringName) -> int:
	var count := 0
	for id in Database.cosmetics:
		if (Database.cosmetics[id] as CosmeticData).category == category:
			count += 1
	return count

## Preis und Sperrgrund kommen ausschliesslich aus Game.cosmetic_cost() und
## Game.owns_cosmetic() -- das Panel rechnet nicht selbst.
func _variant_button(category: StringName, variant: int, current: int) -> Button:
	var c: CosmeticData = Database.cosmetic_of(category, variant)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var display_name := c.display_name if c != null else str(variant + 1)

	if Game.owns_cosmetic(category, variant):
		b.toggle_mode = true
		b.button_pressed = (variant == current)
		b.text = "%s\n(gekauft)" % display_name
		b.pressed.connect(_wear.bind(category, variant))
		return b

	var cost := Game.cosmetic_cost(category, variant)
	var reason := "nicht verfügbar"
	var affordable := false
	if c != null:
		if Game.ctx.player_level < c.unlock_level:
			reason = "Stufe %d nötig" % c.unlock_level
		elif Game.coins < cost:
			reason = "zu wenig Münzen"
		else:
			reason = "kaufen"
			affordable = true
	b.text = "%s\n%d Münzen – %s" % [display_name, cost, reason]
	b.disabled = not affordable
	b.pressed.connect(_buy.bind(category, variant))
	return b

func _wear(category: StringName, variant: int) -> void:
	if not Game.set_cosmetic(category, variant):
		return
	for angler in get_tree().get_nodes_in_group("angler"):
		angler.set_cosmetics(Game.cosmetics)

func _buy(category: StringName, variant: int) -> void:
	Game.buy_cosmetic(category, variant)
