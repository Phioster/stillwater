## Charakteranpassung. Rein kosmetisch -- keine Wahl hier ändert einen
## Spielwert, kann aber später eine Fangbedingung erfüllen.
extends PanelBase

const SLOTS := [
	{"key": &"skin", "label": "Hautton"},
	{"key": &"hair", "label": "Frisur"},
	{"key": &"hair_color", "label": "Haarfarbe"},
	{"key": &"shirt", "label": "Oberteil"},
	{"key": &"pants", "label": "Hose"},
	{"key": &"hat", "label": "Kopf"},
	{"key": &"rod", "label": "Rute"},
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

	# Ein Raster statt einer Reihe: elf Kopfteile nebeneinander waeren je 38
	# Pixel breit gewesen. Dieselbe Spaltenzahl wie die anderen Umschalter.
	var grid := GridContainer.new()
	grid.columns = CategorySwitch.COLUMNS
	for variant in count:
		grid.add_child(_variant_button(category, variant, current))
	box.add_child(grid)

	return box

func _variant_count(category: StringName) -> int:
	var count := 0
	for id in Database.cosmetics:
		if (Database.cosmetics[id] as CosmeticData).category == category:
			count += 1
	return count

## Preis und Sperrgrund kommen ausschliesslich aus Game.cosmetic_state() --
## das Panel rechnet die Freischaltregel nicht selbst nach.
func _variant_button(category: StringName, variant: int, current: int) -> Button:
	var c: CosmeticData = Database.cosmetic_of(category, variant)
	var b := TapButton.new()
	b.custom_minimum_size = Vector2(0, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Ohne das waechst die Mindestbreite mit dem Text: drei Knoepfe nebeneinander
	# brauchten 550 statt der 420, die das Seitenpanel breit ist.
	b.clip_text = true
	var display_name := c.display_name if c != null else str(variant + 1)
	var cost := Game.cosmetic_cost(category, variant)

	match Game.cosmetic_state(category, variant):
		Game.CosmeticState.OWNED:
			b.toggle_mode = true
			b.button_pressed = (variant == current)
			b.text = "%s\n✓" % display_name
			b.tapped.connect(_wear.bind(category, variant))
		Game.CosmeticState.LOCKED_LEVEL:
			b.text = "%s\n%d ⨀ · Stufe %d" % [display_name, cost, c.unlock_level]
			b.disabled = true
			b.tapped.connect(_buy.bind(category, variant))
		Game.CosmeticState.LOCKED_COINS:
			b.text = "%s\n%d ⨀" % [display_name, cost]
			b.disabled = true
			b.tapped.connect(_buy.bind(category, variant))
		Game.CosmeticState.BUYABLE:
			b.text = "%s\n%d Münzen – kaufen" % [display_name, cost]
			b.tapped.connect(_buy.bind(category, variant))
		_:
			b.text = "%s\nnicht verfügbar" % display_name
			b.disabled = true
	return b

func _wear(category: StringName, variant: int) -> void:
	if not Game.set_cosmetic(category, variant):
		return
	for angler in get_tree().get_nodes_in_group("angler"):
		angler.set_cosmetics(Game.cosmetics)

func _buy(category: StringName, variant: int) -> void:
	Game.buy_cosmetic(category, variant)
