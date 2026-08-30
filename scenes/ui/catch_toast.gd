## Zeigt nach einem Fang kurz an, was gefangen wurde, und blendet sich selbst
## wieder aus. Rechnet nichts: Preis kommt aus Economy, Qualitaet aus FishRoll.
extends PanelContainer

const SHOW_SECONDS: float = 3.0

@onready var _line1: Label = $Box/Line1
@onready var _line2: Label = $Box/Line2
@onready var _timer: Timer = $Timer

func _ready() -> void:
	# Siehe catch_view.gd: Anker der Szenenwurzel ueberleben den Export nicht.
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -220.0
	offset_right = 220.0
	offset_top = 110.0
	offset_bottom = 180.0
	visible = false
	_timer.wait_time = SHOW_SECONDS
	_timer.one_shot = true
	if not _timer.timeout.is_connected(_hide):
		_timer.timeout.connect(_hide)
	if not Game.caught.is_connected(_on_caught):
		Game.caught.connect(_on_caught)

func _on_caught(c: CaughtFish, fish: FishData, discovered: bool, record: bool) -> void:
	show_catch(c, fish, discovered, record)

## Ein neuer Fang ersetzt die stehende Karte und startet die Zeit neu, statt
## sich anzustellen -- bei schneller Angelei waere eine Warteschlange nur Stau.
func show_catch(c: CaughtFish, fish: FishData, discovered: bool, record: bool) -> void:
	if fish == null or c == null:
		return
	var quality: String = FishRoll.RANK_NAMES[clampi(c.rank, 0, FishRoll.RANK_NAMES.size() - 1)]
	var value := Economy.sell_price(c, fish, Game.ctx.rarity_of(fish), Game.ctx.consumable_bonus)
	var kg := fish.weight_str(c.weight_dev)
	_line1.text = "%s · %s · %s" % [fish.full_name(c.weight_dev), kg, quality]
	var second := "%d Münzen" % value
	if c.is_shiny:
		second += "  ✦ schimmernd"
	if discovered:
		second += "  ★ neue Art"
	elif record:
		second += "  ▲ neuer Rekord"
	_line2.text = second
	visible = true
	_timer.start()

func _hide() -> void:
	visible = false
