## Der Angler. Besteht aus getrennten Ebenen, damit Cosmetics später nur
## Texturen und Farben tauschen statt den Charakter neu zu zeichnen.
extends Node2D

const LAYERS := ["Skin", "Pants", "Shirt", "Hair", "Hat", "Rod"]
const TEX_PREFIX := {
	"Skin": "char_skin",
	"Pants": "char_pants",
	"Shirt": "char_shirt",
	"Hair": "char_hair",
	"Hat": "char_hat",
	"Rod": "char_rod",
}
## Die Reihenfolge ist die Variantennummer der Kategorie hair_color -- ein
## Ton mehr hier verlangt eine .tres mehr, sonst zeigt die Auswahl weniger
## Farben als es gibt (dagegen steht test_every_hair_colour_has_a_tint).
const HAIR_TINTS := [&"hair_dark", &"hair_warm", &"hair_pale", &"hair_moss",
	&"hair_snow", &"hair_teal", &"hair_violet", &"hair_pink"]

var _frame: int = 0

func _ready() -> void:
	set_cosmetics(Game.cosmetics)
	if not Game.bite.is_connected(_on_bite):
		Game.bite.connect(_on_bite)
	if not Game.caught.is_connected(_on_caught):
		Game.caught.connect(_on_caught)
	if not Game.escaped.is_connected(_on_escaped):
		Game.escaped.connect(_on_escaped)
	add_to_group("angler")

func set_cosmetics(c: Dictionary) -> void:
	_set_layer("Skin", int(c.get("skin", 0)))
	_set_layer("Pants", int(c.get("pants", 0)))
	_set_layer("Shirt", int(c.get("shirt", 0)))
	_set_layer("Hair", int(c.get("hair", 0)))
	_set_layer("Hat", int(c.get("hat", 0)))
	_set_layer("Rod", int(c.get("rod", 0)))
	_tint_hair(int(c.get("hair_color", 0)))

func _set_layer(name: String, index: int) -> void:
	var sprite: Sprite2D = get_node(name)
	var path := "res://assets/art/%s_%d.png" % [TEX_PREFIX[name], index]
	var tex := TextureLoader.load_texture(path)
	if tex != null:
		sprite.texture = tex
	sprite.frame = _frame

func _tint_hair(color_index: int) -> void:
	var sprite: Sprite2D = $Hair
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/art/palette_swap.gdshader")
	mat.set_shader_parameter("tint", Palette.get_color(HAIR_TINTS[clampi(color_index, 0, HAIR_TINTS.size() - 1)]))
	mat.set_shader_parameter("strength", 1.0)
	sprite.material = mat

## 0 ruhig, 1 Ausholen, 2 Wurf
func play_state(state: int) -> void:
	_frame = clampi(state, 0, 2)
	for name in LAYERS:
		(get_node(name) as Sprite2D).frame = _frame

func _process(_delta: float) -> void:
	match Game.sim.state:
		FishingSim.State.CASTING:
			play_state(2)
		FishingSim.State.FIGHT:
			play_state(1)
		_:
			play_state(0)

func _on_bite(_fish: FishData) -> void:
	play_state(1)

func _on_caught(_c: CaughtFish, _f: FishData, _d: bool, _r: bool) -> void:
	play_state(0)

func _on_escaped(_f: FishData) -> void:
	play_state(0)

## Die Rutenspitze in Weltkoordinaten -- fuer das aktuelle Bild. Beim Wurf
## liegt sie tiefer als im Ruhebild; eine Konstante in der Welt konnte das
## nicht abbilden, und die Schnur begann daneben.
func rod_tip() -> Vector2:
	return position + Vector2(AnglerPose.rod_tip(_frame)) * scale
