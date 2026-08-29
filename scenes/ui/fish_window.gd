## Grosse Fischansicht in einem eigenen Fenster -- ersetzt das Aufklappen im
## Journal. Rechnet nichts selbst: Preis kommt aus Economy, Qualitaetsname
## aus FishRoll, Raritaet aus SimContext.rarity_of().
extends Control

## Ganzzahliger Faktor, damit die 32x16-Sprites scharf bleiben.
const ICON_SCALE := 8.0

@onready var _scrim: ColorRect = $Scrim
@onready var _panel: PanelContainer = $Panel
@onready var _icon: TextureRect = $Panel/Box/Icon
@onready var _name_label: Label = $Panel/Box/NameLabel
@onready var _zone_label: Label = $Panel/Box/ZoneLabel
@onready var _stats_label: Label = $Panel/Box/StatsLabel
@onready var _close: Button = $Panel/Box/Close

func _ready() -> void:
	visible = false
	# Die Wurzel einer instanzierten Szene verliert im Android-Export ihre
	# Anker (auf dem Geraet gemessen, siehe world.gd) -- deshalb hier gesetzt
	# statt sich auf die .tscn-Werte zu verlassen.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -280.0
	_panel.offset_right = 280.0
	_panel.offset_top = -260.0
	_panel.offset_bottom = 260.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if not _scrim.gui_input.is_connected(_on_scrim_input):
		_scrim.gui_input.connect(_on_scrim_input)
	if not _close.pressed.is_connected(close):
		_close.pressed.connect(close)

## Tipp per Maus (Desktop) oder Finger (Android) auf den Bereich neben dem
## Fenster schliesst es -- dieselbe Erkennung wie im Journal.
func _on_scrim_input(event: InputEvent) -> void:
	var mouse_tap: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var touch_tap: bool = event is InputEventScreenTouch and event.pressed
	if mouse_tap or touch_tap:
		close()

func close() -> void:
	visible = false

## Baut den Inhalt fuer eine Art neu auf und zeigt das Fenster. Wird nur beim
## Antippen einer Journalzeile gerufen -- nie bei Game.state_changed, sonst
## spraenge das offene Fenster dem Spieler bei jedem Fang unter den Fingern weg.
func open(id: StringName) -> void:
	var f: FishData = Database.fish.get(id)
	if f == null:
		return
	var known := Game.ctx.journal.is_discovered(id)
	var suffix := "" if known else "_silhouette"
	_icon.texture = TextureLoader.load_texture("res://assets/art/fish_%s%s.png" % [id, suffix])
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_icon.custom_minimum_size = Vector2(32.0, 16.0) * ICON_SCALE

	if not known:
		_name_label.text = "???"
		_name_label.modulate = Palette.get_color(&"shadow")
		_zone_label.text = ""
		if f.is_secret:
			_stats_label.text = "🔒 %s" % f.secret_hint
			_stats_label.modulate = Palette.get_color(&"accent")
		else:
			_stats_label.text = "Noch nicht gefangen."
			_stats_label.modulate = Palette.get_color(&"shadow")
		visible = true
		return

	var rarity := Game.ctx.rarity_of(f)
	var zone: ZoneData = Database.zones.get(f.zone_id)
	var e := Game.ctx.journal.entry(id)
	var record := CaughtFish.make(id, float(e["best_weight"]), int(e["best_quality"]), bool(e["shiny_found"]))
	var value := Economy.sell_price(record, f, rarity)

	_name_label.text = f.display_name
	_name_label.modulate = rarity.color
	_zone_label.text = zone.display_name if zone != null else ""

	var worst := ("%.2f" % float(e["worst_weight"])).replace(".", ",")
	var best := ("%.2f" % float(e["best_weight"])).replace(".", ",")
	var span_lo := ("%.2f" % f.weight_min).replace(".", ",")
	var span_hi := ("%.2f" % f.weight_max).replace(".", ",")
	_stats_label.text = "Rarität: %s\nFänge: %d\nRekordgewicht: %s kg\nKleinstes Gewicht: %s kg\nGewichtsspanne: %s–%s kg\nBeste Qualität: %s\nSchimmernd: %s\nFischlevel: %d\nWert des Rekordfangs: %d Münzen\nGrundwert: %d\nXP: %d" % [
		rarity.display_name, int(e["caught_count"]), best, worst, span_lo, span_hi,
		FishRoll.QUALITY_NAMES[int(e["best_quality"])],
		"ja" if bool(e["shiny_found"]) else "nein",
		int(e["fish_level"]), value, f.base_value, f.xp,
	]
	_stats_label.modulate = rarity.color
	visible = true
