## Die laufenden Traenke: Bild, Restzeit, leerlaufender Balken. Links unter der
## Kopfzeile, weil das Menue rechts haengt und sie dort nie zudeckt.
class_name BuffBar
extends HBoxContainer

signal tapped

const ICON: int = 64
const EINTRAG_BREITE: float = 64.0

var _takt: float = 0.0
var _gebaut: Array = []
## id -> [Restzeit-Label, Balken]
var _teile: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	if not Game.state_changed.is_connected(refresh):
		Game.state_changed.connect(refresh)
	refresh()

## Einmal je Sekunde reicht: die Anzeige hat Sekunden als kleinste Einheit.
func _process(delta: float) -> void:
	_takt += delta
	if _takt >= 1.0:
		_takt = 0.0
		refresh()

func ids() -> Array:
	return Game.buffs.active.keys()

static func zeit(sekunden: float) -> String:
	var s := int(ceil(sekunden))
	return "%d:%02d" % [s / 60, s % 60]

## Neu gebaut wird nur, wenn sich die Traenke aendern. Sonst wuerde jede
## Sekunde der Knopf unter dem Finger weggeworfen und der Tipp ginge verloren.
func refresh() -> void:
	visible = not Game.buffs.active.is_empty()
	var jetzt := ids()
	if jetzt != _gebaut:
		for k in get_children():
			k.queue_free()
		_teile.clear()
		for id in jetzt:
			var c: ConsumableData = Database.consumables.get(id)
			if c != null:
				add_child(_eintrag(c))
		_gebaut = jetzt
	for id in _teile:
		var rest := Game.buffs.remaining(id)
		(_teile[id][0] as Label).text = zeit(rest)
		(_teile[id][1] as ProgressBar).value = rest

## Ein TapButton je Eintrag: er faengt den Doppel-Tipp der Maus-Emulation ab.
func _eintrag(c: ConsumableData) -> Control:
	var knopf := TapButton.new()
	knopf.flat = true
	knopf.custom_minimum_size = Vector2(EINTRAG_BREITE, 0)
	knopf.tapped.connect(func() -> void: tapped.emit())
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	knopf.add_child(box)
	var bild := TextureRect.new()
	bild.texture = TextureLoader.load_texture("res://assets/art/potion_%s.png" % c.id)
	bild.custom_minimum_size = Vector2(ICON, ICON)
	bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bild.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bild.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bild)
	var rest := Game.buffs.remaining(c.id)
	var text := Label.new()
	text.text = zeit(rest)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(text)
	var balken := ProgressBar.new()
	balken.show_percentage = false
	balken.custom_minimum_size = Vector2(ICON, 4)
	balken.max_value = maxf(c.duration, 1.0)
	balken.value = rest
	balken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(balken)
	_teile[c.id] = [text, balken]
	knopf.custom_minimum_size.y = box.get_combined_minimum_size().y
	return knopf
