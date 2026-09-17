## Kopfzeile oben links: Geld, Level, XP-Fortschritt, aktuelle Zone.
##
## ZWEI Zeilen, nicht eine. Nebeneinander war sie mit echten Zahlen
## ("13.883.961 Münzen  Lvl 63  [Balken]  Willow Lake") 640 Punkte breit --
## über ein Drittel des Bildes, und die Fanganzeige in der Bildmitte
## verschwand dahinter. Übereinander sind es 356, und dahinter kann nichts
## mehr geraten.
extends PanelContainer

@onready var _coins: Label = $Box/Top/Coins
@onready var _level: Label = $Box/Top/Level
@onready var _xp: ProgressBar = $Box/Bottom/Xp
@onready var _zone: Label = $Box/Bottom/Zone

func _ready() -> void:
	if not Game.state_changed.is_connected(refresh):
		Game.state_changed.connect(refresh)
	if not Game.coins_changed.is_connected(_on_coins_changed):
		Game.coins_changed.connect(_on_coins_changed)
	refresh()

func _on_coins_changed(_v: int) -> void:
	refresh()

func refresh() -> void:
	# Das Münzzeichen statt des Wortes: dieselbe Aussage in sieben Zeichen
	# weniger, und im Charakterfenster steht es ohnehin schon für Preise.
	_coins.text = "%s ⨀" % _grouped(Game.coins)
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
