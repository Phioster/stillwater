## Die Spielwelt links im Querformat. Zeigt Hintergrund, Angler und Bobber
## und stellt die Fläche bereit, über der die Orbs erscheinen dürfen.
extends Control

@onready var orb_area: Control = $CatchView.spawn_area
@onready var _bobber: Sprite2D = $Bobber
@onready var _background: TextureRect = $Background

var _bob_time: float = 0.0
var _bobber_home: Vector2

func _ready() -> void:
	_background.texture = TextureLoader.load_texture("res://assets/art/bg_lake.png")
	_bobber.texture = TextureLoader.load_texture("res://assets/art/bobber.png")
	_bobber_home = _bobber.position
	# Die Wurzel einer instanzierten Szene kommt im Android-Export mit
	# Standardankern an (auf dem Geraet gemessen: 0/0/0/0 statt 0/0/1/1).
	# Deshalb hier setzen statt sich auf die Szenendatei zu verlassen.
	$CatchView.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not Game.bite.is_connected(_on_bite):
		Game.bite.connect(_on_bite)

func _process(delta: float) -> void:
	_bob_time += delta
	var visible_states := [FishingSim.State.WAITING, FishingSim.State.FIGHT]
	_bobber.visible = Game.sim.state in visible_states
	var amplitude := 10.0 if Game.sim.state == FishingSim.State.FIGHT else 3.0
	_bobber.position.y = _bobber_home.y + sin(_bob_time * 3.0) * amplitude

func _on_bite(_fish: FishData) -> void:
	_bob_time = 0.0
