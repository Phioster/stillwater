## Reine Rueckmeldung zu vorhandenen Game-Signalen: Platschen, Funkeln,
## aufsteigende Zahlen, kurzes Wackeln. Entscheidet nichts, rechnet keinen
## Wert selbst -- alles kommt fertig aus Game/FishRoll/Palette. Ein Knoten in
## World statt ein Autoload, weil alle vier Rueckmeldungen an Orten in der
## Weltszene erscheinen (Schwimmer, CatchToast) und so einfach lokale
## Koordinaten der Geschwisterknoten nutzen koennen.
extends Control

const POP_TEXT_SCENE := preload("res://scenes/effects/pop_text.tscn")
const BURST_SCENE := preload("res://scenes/effects/burst.tscn")

## Deckelt Reaktionen pro Frame -- ein grosser Tick (z.B. ueber time_scale)
## kann dutzende caught-Ereignisse in einem einzigen _process()-Aufruf
## feuern. Das darf den Baum nicht ungebremst fuellen.
const MAX_REACTIONS_PER_FRAME: int = 3
const WIGGLE_STEP: float = 0.09
const WIGGLE_ANGLE: float = 0.10

@onready var _bobber: Node2D = get_node("../Bobber")
@onready var _catch_toast: Control = get_node("../CatchToast")

var _last_state: int = -1
var _last_coins: int = 0
var _reaction_frame: int = -1
var _reactions_this_frame: int = 0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_last_state = Game.sim.state
	_last_coins = Game.coins
	if not Game.caught.is_connected(_on_caught):
		Game.caught.connect(_on_caught)
	if not Game.coins_changed.is_connected(_on_coins_changed):
		Game.coins_changed.connect(_on_coins_changed)

## Kein eigenes Signal fuer "Schwimmer landet auf dem Wasser" -- der
## Zustandswechsel nach WAITING wird wie in world.gd per Polling erkannt.
func _process(_delta: float) -> void:
	var state: int = Game.sim.state
	var landed := state == FishingSim.State.WAITING and _last_state != FishingSim.State.WAITING
	_last_state = state
	if landed and _try_react():
		_spawn_burst(_bobber.position, false)

func _on_caught(c: CaughtFish, _fish: FishData, discovered: bool, record: bool) -> void:
	if not _try_react():
		return
	_spawn_burst(_bobber.position, false)
	if c.is_shiny:
		_spawn_burst(_bobber.position, true)
	var quality := FishRoll.QUALITY_NAMES[clampi(c.quality, 0, FishRoll.QUALITY_NAMES.size() - 1)]
	_spawn_text(quality, _bobber.position, Palette.get_color(&"accent"))
	if discovered or record:
		_wiggle(_catch_toast)

## coins_changed feuert auch beim Ausgeben (Upgrade, Koeder, Zone) -- nur ein
## Anstieg ist ein Verkauf, deshalb wird die eigentliche Differenz verglichen.
func _on_coins_changed(value: int) -> void:
	var delta := value - _last_coins
	_last_coins = value
	if delta <= 0 or not _try_react():
		return
	_spawn_text("+%d Münzen" % delta, Vector2(size.x * 0.5, 96.0), Palette.get_color(&"accent"))

## true nur, wenn die Szene sichtbar ist und das Budget fuer diesen Frame
## noch nicht ausgeschoepft ist. Zaehlt beim Erlauben gleich mit.
func _try_react() -> bool:
	if not is_visible_in_tree():
		return false
	var frame := Engine.get_process_frames()
	if frame != _reaction_frame:
		_reaction_frame = frame
		_reactions_this_frame = 0
	if _reactions_this_frame >= MAX_REACTIONS_PER_FRAME:
		return false
	_reactions_this_frame += 1
	return true

func _spawn_burst(pos: Vector2, shiny: bool) -> void:
	var burst: Node2D = BURST_SCENE.instantiate()
	add_child(burst)
	if shiny:
		burst.setup_sparkle(pos)
	else:
		burst.setup_splash(pos)

func _spawn_text(txt: String, pos: Vector2, color: Color) -> void:
	var pop: Control = POP_TEXT_SCENE.instantiate()
	add_child(pop)
	pop.setup(txt, pos, color)

## Sehr kurz und schwach, damit es auffaellt statt zu stoeren.
func _wiggle(node: Control) -> void:
	if node == null:
		return
	node.pivot_offset = node.size * 0.5
	var tween := create_tween()
	tween.tween_property(node, "rotation", WIGGLE_ANGLE, WIGGLE_STEP)
	tween.tween_property(node, "rotation", -WIGGLE_ANGLE, WIGGLE_STEP * 2.0)
	tween.tween_property(node, "rotation", 0.0, WIGGLE_STEP)
