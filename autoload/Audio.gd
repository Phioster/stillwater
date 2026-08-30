## Die Tonausgabe. Der vierte Autoload, den die Spec von Anfang an vorsah.
##
## Vier Dinge, die aus der Referenzauswertung stammen und ohne die Ton nervt:
## ein POOL von Abspielern statt Neuanlage pro Klang, eine ZUFÄLLIGE TONHÖHE
## (±5 %), damit derselbe Klang nie zweimal gleich klingt, eine ABKLINGZEIT je
## Ereignis, damit ein Klang sich nicht selbst übersteuert, und getrennte
## Lautstärken für Spiel und Oberfläche.
extends Node

const VOICES: int = 12
const PITCH_SPREAD: float = 0.05
## Zwei Rutenschläge im selben Bild sollen nicht doppelt so laut sein.
const DEFAULT_COOLDOWN: float = 0.04

var enabled: bool = true
var volume: float = 1.0
var ui_volume: float = 0.8

var _voices: Array[AudioStreamPlayer] = []
var _next: int = 0
var _streams: Dictionary = {}
var _cooldowns: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)

func _process(delta: float) -> void:
	for key in _cooldowns.keys():
		var left: float = float(_cooldowns[key]) - delta
		if left <= 0.0:
			_cooldowns.erase(key)
		else:
			_cooldowns[key] = left

## Klänge werden beim ersten Gebrauch geladen, nicht beim Start: ein fehlender
## Klang darf das Spiel nicht aufhalten, er schweigt einfach.
func stream_for(id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var stream: AudioStream = null
	var path := "res://assets/audio/%s.wav" % id
	if ResourceLoader.exists(path):
		stream = ResourceLoader.load(path) as AudioStream
	if stream == null:
		stream = _load_wav(path)
	_streams[id] = stream
	return stream

## Ohne Godot-Editor gibt es keine Import-Dateien, und ResourceLoader findet
## nichts. Dieselbe Falle wie bei den Bildern (siehe TextureLoader), also
## derselbe Ausweg: die RIFF-Datei selbst lesen.
func _load_wav(path: String) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 44:
		return null
	var raw := f.get_buffer(f.get_length())
	if raw.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var rate := raw.decode_u32(24)
	var channels := raw.decode_u16(22)
	var bits := raw.decode_u16(34)
	if bits != 16:
		return null
	# Den data-Abschnitt suchen statt ihn bei 44 zu vermuten: manche Schreiber
	# setzen weitere Abschnitte davor.
	var pos := 12
	while pos + 8 <= raw.size():
		var tag := raw.slice(pos, pos + 4).get_string_from_ascii()
		var size := raw.decode_u32(pos + 4)
		if tag == "data":
			var w := AudioStreamWAV.new()
			w.format = AudioStreamWAV.FORMAT_16_BITS
			w.mix_rate = int(rate)
			w.stereo = channels == 2
			w.data = raw.slice(pos + 8, mini(pos + 8 + size, raw.size()))
			return w
		pos += 8 + size + (size & 1)
	return null

func play(id: StringName, cooldown: float = DEFAULT_COOLDOWN, ui: bool = false) -> bool:
	if not enabled or _cooldowns.has(id):
		return false
	var stream := stream_for(id)
	if stream == null or _voices.is_empty():
		return false
	var voice := _voices[_next]
	_next = (_next + 1) % _voices.size()
	voice.stream = stream
	voice.pitch_scale = randf_range(1.0 - PITCH_SPREAD, 1.0 + PITCH_SPREAD)
	voice.volume_db = linear_to_db(maxf((ui_volume if ui else volume), 0.0001))
	voice.play()
	if cooldown > 0.0:
		_cooldowns[id] = cooldown
	return true

## Für die Oberfläche: eigene Lautstärke, kürzere Sperre.
func click(id: StringName = &"click") -> void:
	play(id, 0.02, true)
