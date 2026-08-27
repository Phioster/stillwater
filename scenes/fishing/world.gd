## Die Spielwelt links im Querformat. Zeigt Hintergrund, Angler und Bobber
## und stellt die Fläche bereit, über der die Orbs erscheinen dürfen.
extends Control

@onready var orb_area: Control = $CatchView.spawn_area
@onready var _bobber: Sprite2D = $Bobber
@onready var _background: TextureRect = $Background
@onready var _dock: Sprite2D = $Dock
@onready var _angler: Node2D = $Angler
@onready var _line: Line2D = $Line

## Der Hintergrund ist 320x180: Himmel bis Zeile 77, Ufer 78-83, Wasser ab 84.
## Alles andere richtet sich danach, damit es bei jedem Seitenverhaeltnis passt.
const WATERLINE := 84.0 / 180.0
const PIXEL_SCALE := 4.0
## Die Angler-Ebenen haben centered = false: ihr Ursprung ist die obere linke
## Ecke, nicht die Mitte. Alle Offsets zaehlen deshalb von dort.
const CHAR_SIZE := 32.0
## Rutenspitze im 32x32-Frame bei (31, 6).
const ROD_TIP := Vector2(31.0, 6.0) * PIXEL_SCALE

var _bob_time: float = 0.0
var _bobber_home: Vector2

func _ready() -> void:
	_background.texture = TextureLoader.load_texture("res://assets/art/bg_lake.png")
	_bobber.texture = TextureLoader.load_texture("res://assets/art/bobber.png")
	_dock.texture = TextureLoader.load_texture("res://assets/art/dock.png")
	_dock.scale = Vector2(PIXEL_SCALE, PIXEL_SCALE)
	_angler.scale = Vector2(PIXEL_SCALE, PIXEL_SCALE)
	_bobber.scale = Vector2(PIXEL_SCALE, PIXEL_SCALE)
	_layout()
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	# Die Wurzel einer instanzierten Szene kommt im Android-Export mit
	# Standardankern an (auf dem Geraet gemessen: 0/0/0/0 statt 0/0/1/1).
	# Deshalb hier setzen statt sich auf die Szenendatei zu verlassen.
	$CatchView.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Gleiche Falle wie oben: die Karte haengt mittig oben, das muss hier
	# gesetzt werden, weil die Szenenwurzel ihre Anker im Export verliert.
	var toast: Control = $CatchToast
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.offset_left = -220.0
	toast.offset_right = 220.0
	toast.offset_top = 110.0
	toast.offset_bottom = 180.0
	if not Game.bite.is_connected(_on_bite):
		Game.bite.connect(_on_bite)


## Steg ans Ufer, Figur darauf, Schwimmer aufs Wasser -- aus der Weltgroesse
## gerechnet statt fest eingetragen.
func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var water_y := size.y * WATERLINE
	var dock_h := 24.0 * PIXEL_SCALE
	# Der Steg liegt mit seiner Oberkante knapp ueber der Wasserlinie, die
	# Pfosten ragen ins Wasser.
	_dock.position = Vector2(size.x * 0.03, water_y - 6.0 * PIXEL_SCALE)
	var deck_y := _dock.position.y
	# Die Figur ist 32x32 und mittig verankert: Fuesse auf das Deck setzen.
	# Fuesse auf die Deckoberkante: der Sprite haengt an seiner oberen linken
	# Ecke, also ist die Unterkante position.y + 32 * scale.
	_angler.position = Vector2(_dock.position.x + 15.0 * PIXEL_SCALE, deck_y - CHAR_SIZE * PIXEL_SCALE)
	_bobber_home = Vector2(size.x * 0.42, water_y + size.y * 0.14)
	_bobber.position = _bobber_home

func _process(delta: float) -> void:
	_bob_time += delta
	var visible_states := [FishingSim.State.WAITING, FishingSim.State.FIGHT]
	_bobber.visible = Game.sim.state in visible_states
	var amplitude := 10.0 if Game.sim.state == FishingSim.State.FIGHT else 3.0
	_bobber.position.y = _bobber_home.y + sin(_bob_time * 3.0) * amplitude
	# Schnur von der Rutenspitze zum Schwimmer -- folgt dadurch von selbst
	# dem Auf und Ab und dem Zappeln im Kampf.
	_line.visible = _bobber.visible
	if _line.visible:
		_line.points = PackedVector2Array([_angler.position + ROD_TIP, _bobber.position])
	# Die Orbs erscheinen rund um den Schwimmer, nicht ueber dem ganzen Bild.
	$CatchView.focus_point = _bobber.position

func _on_bite(_fish: FishData) -> void:
	_bob_time = 0.0
