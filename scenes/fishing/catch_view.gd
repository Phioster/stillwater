## Die Fanganzeige während eines Kampfes: Fischstärke, Leinenspannung und
## die antippbaren Orbs.
extends Control

const ORB_SCENE := preload("res://scenes/fishing/orb.tscn")
const ORB_INTERVAL: float = 0.9
const ORB_LIFETIME: float = 2.2
const ORB_MARGIN: float = 80.0
## Die Orbs erscheinen rund um den Schwimmer statt ueber dem ganzen Bild.
const ORB_RADIUS: float = 190.0

## Mittelpunkt des Fangbereichs, von der Welt jeden Frame auf den Schwimmer
## gesetzt. Ohne Welt bleibt es die Mitte der Flaeche, damit CatchView
## eigenstaendig laedt.
var focus_point: Vector2 = Vector2.ZERO

@onready var _panel: PanelContainer = $Panel
@onready var _name: Label = $Panel/Box/FishName
@onready var _strength: ProgressBar = $Panel/Box/Strength
@onready var _line: ProgressBar = $Panel/Box/Line
## Fläche für die Orbs; deckungsgleich mit World.orb_area, aber lokal in
## dieser Szene, damit CatchView ohne Weltreferenz eigenständig lädt.
@onready var spawn_area: Control = $Orbs

var _spawn_timer: float = 0.0

func _ready() -> void:
	_panel.visible = false
	if not Game.bite.is_connected(_on_bite):
		Game.bite.connect(_on_bite)
	if not Game.caught.is_connected(_on_caught):
		Game.caught.connect(_on_caught)
	if not Game.escaped.is_connected(_on_escaped):
		Game.escaped.connect(_on_escaped)

func _process(delta: float) -> void:
	var fighting := Game.sim.state == FishingSim.State.FIGHT
	_panel.visible = fighting
	if not fighting:
		_clear_orbs()
		return
	_strength.max_value = Game.sim.hooked_max_strength
	_strength.value = maxf(Game.sim.hooked_strength, 0.0)
	_line.max_value = Game.ctx.zone.fight_window
	_line.value = maxf(Game.sim.timer, 0.0)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = ORB_INTERVAL
		_spawn_orb()

func _on_bite(fish: FishData) -> void:
	_name.text = fish.display_name
	_spawn_timer = 0.25

func _on_caught(_c: CaughtFish, _f: FishData, _d: bool, _r: bool) -> void:
	_clear_orbs()

func _on_escaped(_f: FishData) -> void:
	_clear_orbs()

func _clear_orbs() -> void:
	for child in spawn_area.get_children():
		child.queue_free()

func _spawn_orb() -> void:
	var orb := ORB_SCENE.instantiate()
	spawn_area.add_child(orb)
	orb.setup(_orb_position(), ORB_LIFETIME)
	orb.tapped.connect(Game.tap)

## Ein Punkt im Kreis um den Schwimmer, aber immer so weit vom Rand entfernt,
## dass der Orb vollstaendig im Bild bleibt -- sonst waere er am Ufer halb ab.
func _orb_position() -> Vector2:
	var area := spawn_area.size
	var center := focus_point if focus_point != Vector2.ZERO else area * 0.5
	var angle := randf() * TAU
	var distance := sqrt(randf()) * ORB_RADIUS
	var pos := center + Vector2(cos(angle), sin(angle)) * distance
	return Vector2(
		clampf(pos.x, ORB_MARGIN, maxf(area.x - ORB_MARGIN, ORB_MARGIN + 1.0)),
		clampf(pos.y, ORB_MARGIN, maxf(area.y - ORB_MARGIN, ORB_MARGIN + 1.0))
	)

