## Der Angler. Besteht aus getrennten Ebenen, damit Cosmetics später nur
## Texturen und Farben tauschen statt den Charakter neu zu zeichnen.
extends Node2D

## Reihenfolge = Zeichenreihenfolge. "Base" traegt Umriss und Schatten und
## wird nie umgefaerbt -- deshalb liegt es ueber der Kleidung.
const LAYERS := ["Skin", "Pants", "Shirt", "Hair", "Base", "Hat", "Rod"]
const TEX_PREFIX := {
	"Skin": "char_skin",
	"Pants": "char_pants",
	"Shirt": "char_shirt",
	"Hair": "char_hair",
	"Base": "char_base",
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
	_set_layer("Base", 0)
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

## Der Ruhelauf zaehlt in sich selbst weiter, der Wurf haengt am Zaehler des
## Kerns: eine zweite Uhr fuer den Wurf koennte davon abdriften, und dann
## stuende die Figur noch beim Ausholen, waehrend der Koeder schon im Wasser
## liegt.
const IDLE_FPS: float = 5.0
## Wie lange ein Blinzeln dauert und wie oft es kommt. Nicht im Atemtakt:
## sechs Ruhebilder sind gut eine Sekunde, so oft blinzelt niemand.
const BLINK_TIME: float = 0.12
const BLINK_MIN: float = 2.5
const BLINK_MAX: float = 6.0

var _idle_time: float = 0.0
var _blink_in: float = 3.0
var _blink_left: float = 0.0

func play_state(frame: int) -> void:
	_frame = AnglerPose.frame_of(frame)
	for name in LAYERS:
		(get_node(name) as Sprite2D).frame = _frame

func _process(delta: float) -> void:
	match Game.sim.state:
		FishingSim.State.CASTING:
			var left: float = clampf(Game.sim.timer / FishingSim.CAST_TIME, 0.0, 1.0)
			var span := AnglerPose.FRAMES - AnglerPose.CAST_START
			play_state(AnglerPose.CAST_START + int((1.0 - left) * float(span)))
		FishingSim.State.FIGHT:
			# Arm vorn, Rute unter Zug -- das letzte Wurfbild.
			play_state(AnglerPose.FRAMES - 1)
		_:
			# Stillstehen sieht tot aus: sechs Bilder Atmen im Kreis, und
			# hin und wieder ein Blinzeln dazwischen.
			_idle_time += delta
			if _blink_left > 0.0:
				_blink_left -= delta
				play_state(AnglerPose.BLINK_FRAME)
				return
			_blink_in -= delta
			if _blink_in <= 0.0:
				_blink_left = BLINK_TIME
				_blink_in = randf_range(BLINK_MIN, BLINK_MAX)
			play_state(int(_idle_time * IDLE_FPS) % AnglerPose.IDLE_FRAMES)

func _on_bite(_fish: FishData) -> void:
	play_state(AnglerPose.FRAMES - 1)

func _on_caught(_c: CaughtFish, _f: FishData, _d: bool, _r: bool) -> void:
	play_state(0)

func _on_escaped(_f: FishData) -> void:
	play_state(0)

## Die Rutenspitze in Weltkoordinaten -- fuer das aktuelle Bild. Beim Wurf
## liegt sie tiefer als im Ruhebild; eine Konstante in der Welt konnte das
## nicht abbilden, und die Schnur begann daneben.
func rod_tip() -> Vector2:
	return position + Vector2(AnglerPose.rod_tip(_frame)) * scale
