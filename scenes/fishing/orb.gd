## Ein antippbarer Orb. Verschwindet nach seiner Lebenszeit von allein.
extends Control

signal tapped

const FADE_TIME: float = 0.15

@onready var _visual: TextureRect = $Visual

var _life: float = 2.0
var _age: float = 0.0
var _dead: bool = false

func _ready() -> void:
	_visual.texture = TextureLoader.load_texture("res://assets/art/orb.png")
	$Button.pressed.connect(_on_pressed)
	pivot_offset = size * 0.5
	scale = Vector2.ZERO

func setup(pos: Vector2, lifetime: float) -> void:
	position = pos - size * 0.5
	_life = lifetime

func _process(delta: float) -> void:
	if _dead:
		return
	_age += delta
	# Kurzes Aufploppen, dann ruhiges Pulsieren.
	if _age < FADE_TIME:
		scale = Vector2.ONE * (_age / FADE_TIME)
	else:
		scale = Vector2.ONE * (1.0 + sin(_age * 6.0) * 0.06)
	modulate.a = clampf((_life - _age) / 0.4, 0.0, 1.0)
	if _age >= _life:
		_expire()

func _on_pressed() -> void:
	if _dead:
		return
	_dead = true
	tapped.emit()
	queue_free()

func _expire() -> void:
	_dead = true
	queue_free()
