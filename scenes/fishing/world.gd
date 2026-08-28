## Die Spielwelt links im Querformat. Zeigt Hintergrund, Angler und Bobber
## und stellt die Fläche bereit, über der die Orbs erscheinen dürfen.
extends Control

@onready var orb_area: Control = $CatchView.spawn_area
@onready var _bobber: Sprite2D = $Bobber
@onready var _background: TextureRect = $Background
@onready var _dock: Sprite2D = $Dock
@onready var _angler: Node2D = $Angler
@onready var _line: Line2D = $Line
@onready var _water_line: Line2D = $WaterLine
@onready var _water_body: Polygon2D = $WaterBody

## Der Hintergrund ist 320x180: Himmel bis Zeile 77, Ufer 78-83, Wasser ab 84.
## Alles andere richtet sich danach, damit es bei jedem Seitenverhaeltnis passt.
const WATERLINE := 84.0 / 180.0
const PIXEL_SCALE := 4.0
## Die Angler-Ebenen haben centered = false: ihr Ursprung ist die obere linke
## Ecke, nicht die Mitte. Alle Offsets zaehlen deshalb von dort.
const CHAR_SIZE := 32.0
## Die Schuhe enden im 32er-Frame bei Zeile 30 (Generator: _pants zeichnet sie
## bei 27..29). Die letzten zwei Reihen sind leer -- wer die Sprite-Unterkante
## aufs Deck setzt, laesst die Figur um 8 Pixel schweben.
const CHAR_FEET := 30.0
## Rutenspitze im 32x32-Frame bei (31, 6).
const ROD_TIP := Vector2(31.0, 6.0) * PIXEL_SCALE

## Stuetzpunkte der Wasserlinie -- sparsam gewaehlt, siehe Bericht fuer die
## gemessenen Kosten pro Frame.
const WATER_POINTS := 28
## Wellen-Einheiten (core/water_surface.gd) -> Bildschirmpixel. Bewusst klein:
## die Grundbewegung soll man suchen muessen, nicht ertragen (GAME_DESIGN.md,
## "Auffaellig nur, was selten ist").
const WAVE_SCALE := 7.0
## Die Welle schwingt komplett UNTERHALB der Uferlinie. Sonst lief sie ins Gras
## und die kerzengerade Kante des Hintergrundbilds blieb daneben sichtbar.
const WAVE_BIAS := 9.5
## Kleiner, laufender Antrieb durchs Wippen des Schwimmers -- daraus entsteht
## die Stoerung, die von seiner Position nach aussen laeuft.
const BOBBER_DRIVE := 0.05
const BITE_KICK := 12.0
const CATCH_KICK := 20.0

var _bob_time: float = 0.0
var _bobber_home: Vector2
var _water := WaterSurface.new(WATER_POINTS)
## Laeuft immer weiter, anders als _bob_time (das bei jedem Biss auf 0
## zurueckspringt) -- die Grundbewegung des Wassers darf davon nicht mitreissen.
var _water_time: float = 0.0

func _ready() -> void:
	_background.texture = TextureLoader.load_texture("res://assets/art/bg_lake.png")
	_bobber.texture = TextureLoader.load_texture("res://assets/art/bobber.png")
	_dock.texture = TextureLoader.load_texture("res://assets/art/dock.png")
	_dock.scale = Vector2(PIXEL_SCALE, PIXEL_SCALE)
	_angler.scale = Vector2(PIXEL_SCALE, PIXEL_SCALE)
	_bobber.scale = Vector2(PIXEL_SCALE, PIXEL_SCALE)
	_water_line.width = 4.0
	var crest := Palette.get_color(&"foam")
	crest.a = 0.85
	_water_line.default_color = crest
	# Die Flaeche zwischen gerader Uferlinie und Welle wird in der FARBE DES
	# UFERS gefuellt. Dadurch verschiebt sich die sichtbare Grenze auf die
	# Welle, und es gibt keine zweite, gerade Kante mehr.
	_water_body.color = Palette.get_color(&"reed_dark")
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
	if not Game.caught.is_connected(_on_caught):
		Game.caught.connect(_on_caught)


## Steg ans Ufer, Figur darauf, Schwimmer aufs Wasser -- aus der Weltgroesse
## gerechnet statt fest eingetragen.
func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var water_y := size.y * WATERLINE
	var dock_h := 24.0 * PIXEL_SCALE
	# Der Steg liegt mit seiner Oberkante knapp ueber der Wasserlinie, die
	# Pfosten ragen ins Wasser.
	# Buendig mit dem linken Rand: ein Steg, der frei im Wasser beginnt, sieht
	# abgeschnitten aus statt am Ufer angebaut.
	_dock.position = Vector2(0.0, water_y - 6.0 * PIXEL_SCALE)
	var deck_y := _dock.position.y
	# Die Figur ist 32x32 und mittig verankert: Fuesse auf das Deck setzen.
	# Fuesse auf die Deckoberkante: der Sprite haengt an seiner oberen linken
	# Ecke, also ist die Unterkante position.y + 32 * scale.
	_angler.position = Vector2(_dock.position.x + 25.0 * PIXEL_SCALE, deck_y - CHAR_FEET * PIXEL_SCALE)
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
	_water_time += delta
	_water.step(delta)
	if _bobber.visible:
		# Ableitung der Bob-Sinuskurve: das Wippen selbst stoesst das Wasser an,
		# nicht ein fester Takt -- schneller im Kampf, ruhiger beim Warten.
		var bob_velocity := amplitude * 3.0 * cos(_bob_time * 3.0)
		_water.disturb_at(_bobber_fraction(), bob_velocity * BOBBER_DRIVE * delta)
	_update_water_line()

func _update_water_line() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var water_y := size.y * WATERLINE
	var pts := PackedVector2Array()
	pts.resize(WATER_POINTS)
	for i in WATER_POINTS:
		var fraction := float(i) / float(WATER_POINTS - 1)
		var wave := WaterSurface.ambient_offset(fraction, _water_time) + _water.heights[i]
		pts[i] = Vector2(size.x * fraction, water_y + WAVE_BIAS + wave * WAVE_SCALE)
	_water_line.points = pts
	# Ufer bis zur Welle herunterziehen: hin entlang der Welle, zurueck entlang
	# der geraden Uferlinie.
	var poly := PackedVector2Array()
	poly.resize(WATER_POINTS * 2)
	for i in WATER_POINTS:
		poly[i] = pts[i]
		poly[WATER_POINTS * 2 - 1 - i] = Vector2(pts[i].x, water_y - 1.0)
	_water_body.polygon = poly

func _bobber_fraction() -> float:
	if size.x <= 0.0:
		return 0.5
	return clampf(_bobber.position.x / size.x, 0.0, 1.0)

func _on_bite(_fish: FishData) -> void:
	_bob_time = 0.0
	_water.disturb_at(_bobber_fraction(), BITE_KICK)

## Keine Spiellogik hier -- nur die Stoerung, die das Aufspritzen zeigt. Die
## eigentliche Reaktion (Text, Partikel) macht effects.gd auf dasselbe Signal.
func _on_caught(_c: CaughtFish, _fish: FishData, _discovered: bool, _record: bool) -> void:
	_water.disturb_at(_bobber_fraction(), CATCH_KICK)
