## Charakteranpassung. Rein kosmetisch -- keine Wahl hier ändert einen
## Spielwert, kann aber später eine Fangbedingung erfüllen.
extends PanelBase

const SLOTS := [
	{"key": "skin", "label": "Hautton", "count": 3},
	{"key": "hair", "label": "Frisur", "count": 3},
	{"key": "hair_color", "label": "Haarfarbe", "count": 3},
	{"key": "shirt", "label": "Oberteil", "count": 3},
	{"key": "pants", "label": "Hose", "count": 2},
	{"key": "hat", "label": "Hut", "count": 3},
]

func refresh() -> void:
	clear(self)

	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "Aussehen verändert keine Werte. Manche Fische achten trotzdem darauf."
	add_child(note)

	for slot in SLOTS:
		add_child(_row(slot))

func _row(slot: Dictionary) -> Control:
	var key: String = slot["key"]
	var current := int(Game.cosmetics.get(key, 0))
	var box := VBoxContainer.new()

	var title := Label.new()
	title.text = "%s  %d / %d" % [slot["label"], current + 1, int(slot["count"])]
	box.add_child(title)

	var row := HBoxContainer.new()
	for i in int(slot["count"]):
		var b := Button.new()
		b.text = str(i + 1)
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.button_pressed = (i == current)
		b.pressed.connect(_choose.bind(key, i))
		row.add_child(b)
	box.add_child(row)

	return box

func _choose(key: String, index: int) -> void:
	Game.cosmetics[key] = index
	Game.ctx.cosmetics = Game.cosmetics
	for angler in get_tree().get_nodes_in_group("angler"):
		angler.set_cosmetics(Game.cosmetics)
	Game.state_changed.emit()
