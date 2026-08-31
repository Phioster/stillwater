## Kopfzeile oben links: Geld, Level, XP-Fortschritt, aktuelle Zone.
extends PanelContainer

@onready var _coins: Label = $Box/Coins
@onready var _level: Label = $Box/Level
@onready var _xp: ProgressBar = $Box/Xp
@onready var _zone: Label = $Box/Zone

func _ready() -> void:
	if not Game.state_changed.is_connected(refresh):
		Game.state_changed.connect(refresh)
	if not Game.coins_changed.is_connected(_on_coins_changed):
		Game.coins_changed.connect(_on_coins_changed)
	refresh()

func _on_coins_changed(_v: int) -> void:
	refresh()

func refresh() -> void:
	_coins.text = "%s Münzen" % _grouped(Game.coins)
	_level.text = "Lvl %d" % Game.ctx.player_level
	_xp.max_value = Progression.xp_needed(Game.ctx.player_level)
	_xp.value = Game.ctx.player_xp
	# Regen ist ein Vorteil und gehoert deshalb angesagt -- sonst wundert
	# man sich nur, warum es gerade so gut laeuft.
	_zone.text = "%s%s" % [Game.ctx.zone.display_name, "  ☂" if Game.ctx.raining else ""]

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
