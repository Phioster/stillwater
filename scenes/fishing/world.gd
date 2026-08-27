## Die Spielwelt links im Querformat. Zeigt Hintergrund, Angler und Bobber
## und stellt die Fläche bereit, über der die Orbs erscheinen dürfen.
extends Control

@onready var orb_area: Control = $OrbArea
@onready var _bobber: Sprite2D = $Bobber
@onready var _background: TextureRect = $Background

var _bob_time: float = 0.0
var _bobber_home: Vector2

func _ready() -> void:
	_background.texture = _load_texture("res://assets/art/bg_lake.png")
	_bobber.texture = _load_texture("res://assets/art/bobber.png")
	_bobber_home = _bobber.position
	Game.bite.connect(_on_bite)

## Läuft ohne Import-Schritt: die Editor-Ressourcenimportierer stürzen in
## dieser Umgebung ab, daher werden Sprites als Image statt als Texture2D-
## Ressource geladen (siehe tests/test_sprite_assets.gd).
func _load_texture(path: String) -> Texture2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	_bob_time += delta
	var visible_states := [FishingSim.State.WAITING, FishingSim.State.FIGHT]
	_bobber.visible = Game.sim.state in visible_states
	var amplitude := 10.0 if Game.sim.state == FishingSim.State.FIGHT else 3.0
	_bobber.position.y = _bobber_home.y + sin(_bob_time * 3.0) * amplitude

func _on_bite(_fish: FishData) -> void:
	_bob_time = 0.0
