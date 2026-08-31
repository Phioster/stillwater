## Die Spielwelt links im Querformat. Zeigt Hintergrund, Angler und Bobber
## und stellt die Fläche bereit, über der die Orbs erscheinen dürfen.
extends Control

## Meldet, dass jemand den Haendler angetippt hat -- main.gd oeffnet dann
## seinen Reiter. Die Welt kennt das Menue nicht und soll es nicht kennen.
signal visitor_tapped

@onready var orb_area: Control = $CatchView.spawn_area
@onready var _bobber: Sprite2D = $Bobber
@onready var _background: TextureRect = $Background
@onready var _dock: Sprite2D = $Dock
@onready var _angler: Node2D = $Angler
@onready var _line: Line2D = $Line
@onready var _water_line: Line2D = $WaterLine
@onready var _water_body: Polygon2D = $WaterBody
@onready var _raven: TextureButton = $Visitors/Raven
@onready var _trader: TextureButton = $Visitors/Trader
var _rain: Rain = null

## Der Hintergrund ist 320x180: Himmel bis Zeile 77, Ufer 78-83, Wasser ab 84.
## Alles andere richtet sich danach, damit es bei jedem Seitenverhaeltnis passt.
const WATERLINE := 84.0 / 180.0
## Ganzzahlig halten! Bei 1,5 landen Pixelkanten zwischen Bildschirmpunkten
## und das ganze Bild flimmert. Bei 256er Rahmen ist 1 die richtige Wahl:
## die Figur steht so gross da wie vorher, hat aber viermal so viele
## Bildpunkte (siehe core/angler_pose.gd).
const PIXEL_SCALE := 1.0
## Die Angler-Ebenen haben centered = false: ihr Ursprung ist die obere linke
## Ecke, nicht die Mitte. Alle Offsets zaehlen deshalb von dort.
const CHAR_SIZE := 256.0
## Die Stiefel enden im 256er-Frame bei Zeile 247. Die letzten Reihen sind
## leer -- wer die Sprite-Unterkante aufs Deck setzt, laesst die Figur
## schweben.
const CHAR_FEET := 248.0

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
## Wie weit die Uferfarbe ins Gras hinaufreicht. Die Farbkante des skalierten
## Hintergrundbilds liegt nicht exakt auf 84/180 -- ohne Reserve blitzte dort
## ein zwei Pixel duenner Streifen Wasser durch (am Screenshot ausgemessen).
const SHORE_OVERLAP := 10.0
## Kleiner, laufender Antrieb durchs Wippen des Schwimmers -- daraus entsteht
## die Stoerung, die von seiner Position nach aussen laeuft.
const BOBBER_DRIVE := 0.05
const BITE_KICK := 12.0
const CATCH_KICK := 20.0
## Der Spritzer beim Aufsetzen. Kleiner als ein Biss -- der Wurf soll das
## Wasser anstossen, nicht aufschrecken.
const SPLASH_KICK := 7.0
## Wie hoch der Wurf ueber die Verbindungslinie hinausgeht.
const CAST_ARC := 200.0
const POP_TEXT_SCENE := preload("res://scenes/effects/pop_text.tscn")

var _bob_time: float = 0.0
var _bobber_home: Vector2
var _water := WaterSurface.new(WATER_POINTS)
## Laeuft immer weiter, anders als _bob_time (das bei jedem Biss auf 0
## zurueckspringt) -- die Grundbewegung des Wassers darf davon nicht mitreissen.
var _water_time: float = 0.0
## Verhindert, dass jedes state_changed Textur und Farben neu setzt.
var _applied_zone: StringName = &""

func _ready() -> void:
	_bobber.texture = TextureLoader.load_texture("res://assets/art/bobber.png")
	_dock.texture = TextureLoader.load_texture("res://assets/art/dock.png")
	_dock.scale = Vector2(PIXEL_SCALE, PIXEL_SCALE)
	_angler.scale = Vector2(PIXEL_SCALE, PIXEL_SCALE)
	_bobber.scale = Vector2(PIXEL_SCALE, PIXEL_SCALE)
	_setup_visitors()
	_rain = Rain.new()
	add_child(_rain)
	_rain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rain.visible = false
	_water_line.width = 4.0
	_apply_zone()
	_layout()
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	if not Game.state_changed.is_connected(_apply_zone):
		Game.state_changed.connect(_apply_zone)
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
	var dock_h := 192.0 * PIXEL_SCALE
	# Der Steg liegt mit seiner Oberkante knapp ueber der Wasserlinie, die
	# Pfosten ragen ins Wasser.
	# Buendig mit dem linken Rand: ein Steg, der frei im Wasser beginnt, sieht
	# abgeschnitten aus statt am Ufer angebaut.
	_dock.position = Vector2(0.0, water_y - 48.0 * PIXEL_SCALE)
	var deck_y := _dock.position.y
	# Fuesse auf die Deckoberkante: der Sprite haengt an seiner oberen linken
	# Ecke, also zaehlt CHAR_FEET von dort.
	_angler.position = Vector2(_dock.position.x + 200.0 * PIXEL_SCALE, deck_y - CHAR_FEET * PIXEL_SCALE)
	_bobber_home = Vector2(size.x * 0.42, water_y + size.y * 0.14)
	_bobber.position = _bobber_home

## Der Wurfklang haengt am Zustandswechsel, nicht an einem Ereignis: die
## Simulation schickt fuer den Wurf keins, und im Offline-Nachlauf duerfte
## sie es auch gar nicht.
var _last_state: int = -1

func _process(delta: float) -> void:
	if Game.sim.state != _last_state:
		if Game.sim.state == FishingSim.State.CASTING and _last_state != -1:
			Audio.play(&"cast", 0.3)
		# Aufsetzen: ein Spritzer da, wo der Schwimmer landet.
		if Game.sim.state == FishingSim.State.WAITING and _last_state == FishingSim.State.CASTING:
			_water.disturb_at(_bobber_fraction(), SPLASH_KICK)
		_last_state = Game.sim.state

	_bob_time += delta
	var casting := Game.sim.state == FishingSim.State.CASTING
	var visible_states := [FishingSim.State.CASTING, FishingSim.State.WAITING, FishingSim.State.FIGHT]
	_bobber.visible = Game.sim.state in visible_states
	var amplitude := 10.0 if Game.sim.state == FishingSim.State.FIGHT else 3.0
	if casting:
		# Der Schwimmer war waehrend des Wurfs unsichtbar und tauchte am Ende
		# an seiner Endstelle auf -- er teleportierte. Jetzt fliegt er einen
		# Bogen, und die Schnur folgt ihm von selbst.
		_bobber.position = _cast_position()
	else:
		_bobber.position = Vector2(_bobber_home.x,
			_bobber_home.y + sin(_bob_time * 3.0) * amplitude)
	# Schnur von der Rutenspitze zum Schwimmer -- folgt dadurch von selbst
	# dem Auf und Ab und dem Zappeln im Kampf.
	_line.visible = _bobber.visible
	if _line.visible:
		_line.points = PackedVector2Array([_angler.rod_tip(), _bobber.position])
	# Die Orbs erscheinen rund um den Schwimmer, nicht ueber dem ganzen Bild.
	$CatchView.focus_point = _bobber.position
	_update_visitors()
	if _rain != null:
		_rain.visible = Game.ctx.raining
	_water_time += delta
	_water.step(delta)
	if _bobber.visible and not casting:
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
		poly[WATER_POINTS * 2 - 1 - i] = Vector2(pts[i].x, water_y - SHORE_OVERLAP)
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

## Hintergrund und Wasserfarben kommen aus der Zone. Die Flaeche zwischen
## gerader Uferlinie und Welle wird in der FARBE DES UFERS gefuellt: dadurch
## liegt die sichtbare Grenze auf der Welle und nicht auf einer zweiten,
## geraden Kante.
func _apply_zone() -> void:
	var zone: ZoneData = Game.ctx.zone
	if zone == null or zone.id == _applied_zone:
		return
	_applied_zone = zone.id
	_background.texture = TextureLoader.load_texture(
		"res://assets/art/bg_%s.png" % zone.background_id)
	var crest := Palette.get_color(zone.foam_key)
	crest.a = 0.85
	_water_line.default_color = crest
	_water_body.color = Palette.get_color(zone.shore_key)

## Der Schwimmer auf seinem Flug: eine quadratische Bezierkurve von der
## Rutenspitze zur Ruhelage, mit einem Scheitel darueber. Der Fortschritt
## kommt aus der Simulationsuhr, damit Flug und Wurfdauer nicht auseinander
## laufen koennen.
func _cast_position() -> Vector2:
	var t := 1.0 - clampf(Game.sim.timer / FishingSim.CAST_TIME, 0.0, 1.0)
	var from: Vector2 = _angler.rod_tip()
	var to := _bobber_home
	var peak: Vector2 = (from + to) * 0.5 - Vector2(0.0, CAST_ARC)
	var inv := 1.0 - t
	return inv * inv * from + 2.0 * inv * t * peak + t * t * to

## Besucher stehen am Steg und wollen angetippt werden. Sichtbar nur, wenn
## es wirklich etwas zu holen gibt -- ein Knopf, der nichts tut, ist Ballast.
func _setup_visitors() -> void:
	_raven.texture_normal = TextureLoader.load_texture("res://assets/art/raven.png")
	_trader.texture_normal = TextureLoader.load_texture("res://assets/art/trader.png")
	for b in [_raven, _trader]:
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(96, 96)
		b.size = Vector2(96, 96)
	if not _raven.pressed.is_connected(_on_raven_pressed):
		_raven.pressed.connect(_on_raven_pressed)
	if not _trader.pressed.is_connected(_on_trader_pressed):
		_trader.pressed.connect(_on_trader_pressed)

func _update_visitors() -> void:
	_raven.visible = Game.raven_waiting()
	_trader.visible = Game.trader_present() and not Game.trader_offer().is_empty()
	var deck_y := _dock.position.y
	_raven.position = Vector2(_dock.position.x + 8.0, deck_y - 104.0)
	_trader.position = Vector2(_dock.position.x + 116.0, deck_y - 96.0)

func _on_raven_pressed() -> void:
	var gift := Game.collect_raven()
	if gift == &"":
		return
	var c: ConsumableData = Database.consumables.get(gift)
	var name := c.display_name if c != null else String(gift)
	var pop := POP_TEXT_SCENE.instantiate()
	$Visitors.add_child(pop)
	pop.setup(name, _raven.position + Vector2(48.0, 0.0), Palette.get_color(&"accent"))

func _on_trader_pressed() -> void:
	Audio.click()
	visitor_tapped.emit()
