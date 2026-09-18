## Das Schilfschneiden: die kurze, aktive Sache zwischen zwei Bissen.
##
## Eine kreisende Sichel folgt dem Finger ueber ein Schilfbeet. Sie dreht sich
## von selbst -- es gibt keinen Schlagknopf und keine laufende Figur, der
## Finger IST die Klinge. Getroffen wird, was im Kreisausschnitt vor ihrer
## Schneide steht, also muss die Klinge erst vorbeikommen; ein voller Kreis
## waere ein Rasenmaeher.
##
## Die Zahlen stehen nicht hier, sondern in core/reeds.gd und im Ausbau: was
## sich am Geraet gut angefuehlt hat, ist der GRUNDwert, alles darueber kommt
## aus Sichelschaerfe, -reichweite und -tempo.
extends Control

signal beendet

## Der Zellabstand. Gross genug, dass die Halme sich nicht gegenseitig
## verdecken -- sie sind so hoch wie die am Ufer, und das sind ueber hundert
## Punkte auf dem Schirm.
const HALB_B := 62.0
const HALB_H := 34.0
## Wie Steg, Figur und Schwimmer -- ein Pixel ist ein Pixel.
const SKALA := 2.16
## Der aeussere Radius der gezeichneten Sichel in ihren eigenen Pixeln. Die
## Klinge wird darueber auf die Reichweite skaliert, damit man SIEHT, was der
## Ausbau gebracht hat.
const SICHEL_RADIUS := 21.0

var _schilf: Texture2D
var _sichel_bild: Texture2D

var _halme_ebene: Node2D
var _sichel: Sprite2D
var _zaehler: Label
var _uhr: ProgressBar
var _karte: PanelContainer
var _karte_text: RichTextLabel

var _halme: Dictionary = {}
var _winkel := 0.0
var _ziel := Vector2.ZERO
var _zeit := 0.0
var _seit_nachwuchs := 0.0
var _geschnitten := 0
var _laeuft := false
var _noetig := 5
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	# Anker der Szenenwurzel ueberleben den Export nicht -- deshalb hier.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_schilf = TextureLoader.load_texture("res://assets/art/schilf_horst.png")
	_sichel_bild = TextureLoader.load_texture("res://assets/art/sichel.png")
	_rng.randomize()

	_halme_ebene = Node2D.new()
	_halme_ebene.y_sort_enabled = true
	add_child(_halme_ebene)
	_sichel = Sprite2D.new()
	_sichel.texture = _sichel_bild
	add_child(_sichel)
	_baue_hud()

## Beginnt eine Runde. Die Zaehigkeit kommt aus der Zone, die Schaerfe aus
## dem Ausbau -- beides wird EINMAL hier gelesen, damit sich mitten in der
## Runde nichts unter den Fuessen aendert.
func starte() -> void:
	var zaeh: int = Game.ctx.zone.reed_toughness if Game.ctx.zone != null else 5
	_noetig = Reeds.treffer_noetig(zaeh, Game.scythe_edge())
	for h in _halme.values():
		h.queue_free()
	_halme.clear()
	for i in Reeds.START_HALME:
		_saee()
	_zeit = Reeds.DAUER
	_geschnitten = 0
	_laeuft = true
	_karte.visible = false
	_ziel = _beet_mitte()
	_sichel.position = _ziel
	visible = true
	Audio.play(&"cast")

func _beet_mitte() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.54)

func _zelle_pos(c: int, r: int) -> Vector2:
	var x := float(c - r) * HALB_B
	var y := (float(c + r) - float(Reeds.SPALTEN + Reeds.ZEILEN - 2) * 0.5) * HALB_H
	return _beet_mitte() + Vector2(x, y)

## Ein neuer Halm auf eine freie Zelle. Sind alle belegt, passiert nichts --
## ein volles Beet ist ein gutes Problem.
func _saee() -> void:
	for versuch in 24:
		var z := Vector2i(_rng.randi_range(0, Reeds.SPALTEN - 1),
			_rng.randi_range(0, Reeds.ZEILEN - 1))
		if _halme.has(z):
			continue
		var s := Sprite2D.new()
		s.texture = _schilf
		s.region_enabled = true
		s.region_rect = Rect2(0.0, 0.0, float(Reeds.HALM_B), float(_schilf.get_height()))
		s.scale = Vector2(SKALA, SKALA)
		# Der Fuss des Halms sitzt auf der Zelle, nicht seine Mitte.
		s.offset = Vector2(0.0, -float(_schilf.get_height()) * 0.5)
		s.position = _zelle_pos(z.x, z.y)
		s.set_meta(&"leben", _noetig)
		s.set_meta(&"pause", 0.0)
		_halme_ebene.add_child(s)
		_halme[z] = s
		return

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_ziel = (event as InputEventScreenDrag).position
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_ziel = (event as InputEventScreenTouch).position
	elif event is InputEventMouseMotion:
		_ziel = (event as InputEventMouseMotion).position

func _process(delta: float) -> void:
	if not visible:
		return
	_winkel = wrapf(_winkel + Game.scythe_speed() * TAU * delta, -PI, PI)
	var reichweite := Game.scythe_reach()
	# Die Klinge zieht dem Finger NACH, statt an ihm zu kleben: ohne das
	# springt sie bei jedem Antippen quer durchs Bild.
	_sichel.position = _sichel.position.lerp(_ziel, clampf(delta * 18.0, 0.0, 1.0))
	_sichel.rotation = _winkel
	_sichel.scale = Vector2.ONE * (reichweite / SICHEL_RADIUS)
	if not _laeuft:
		queue_redraw()
		return
	_zeit = maxf(0.0, _zeit - delta)
	_seit_nachwuchs += delta
	while _seit_nachwuchs >= Reeds.NACHWUCHS:
		_seit_nachwuchs -= Reeds.NACHWUCHS
		_saee()
	_schneide(delta, reichweite)
	_zaehler.text = "%d" % _geschnitten
	_uhr.value = _zeit / Reeds.DAUER * 100.0
	if _zeit <= 0.0:
		_beende()
	queue_redraw()

## Wer im Kreisausschnitt vor der Schneide steht, bekommt einen Treffer.
func _schneide(delta: float, reichweite: float) -> void:
	for z in _halme.keys():
		var s: Sprite2D = _halme[z]
		var pause: float = s.get_meta(&"pause")
		if pause > 0.0:
			s.set_meta(&"pause", pause - delta)
			continue
		if not Reeds.trifft(s.position, _sichel.position, _winkel, reichweite):
			continue
		var leben: int = int(s.get_meta(&"leben")) - 1
		s.set_meta(&"leben", leben)
		s.set_meta(&"pause", Reeds.TREFFER_PAUSE)
		if leben > 0:
			# Der Halm wird kuerzer, statt nur zu blinken: sonst weiss man
			# nicht, ob man ihn schon hat.
			var stufe := clampi(int(floor(float(_noetig - leben)
				/ float(_noetig) * float(Reeds.HALM_STUFEN))), 0, Reeds.HALM_STUFEN - 1)
			s.region_rect.position.x = float(stufe * Reeds.HALM_B)
			continue
		_geschnitten += 1
		Audio.play(&"rod", 0.04)
		_halme.erase(z)
		s.queue_free()

func _beende() -> void:
	_laeuft = false
	var e := Game.finish_reed_cut(_geschnitten)
	var zeilen: Array[String] = ["[b]%d Halme[/b]" % int(e["halme"])]
	var b: BaitData = Database.baits.get(e["bait"])
	var name: String = b.display_name if b != null else String(e["bait"])
	if int(e["got"]) > 0:
		zeilen.append("%d × %s" % [int(e["got"]), name])
	else:
		zeilen.append("Zu wenig für einen Köder")
	if int(e["got"]) < int(e["wanted"]):
		zeilen.append("Die Ködertasche ist voll")
	if String(e["find"]) != "":
		var c: ConsumableData = Database.consumables.get(e["find"])
		zeilen.append("Im Schilf lag: %s" % (c.display_name if c != null
			else String(e["find"])))
	_karte_text.text = "\n".join(zeilen)
	_karte.visible = true

func _draw() -> void:
	if not visible:
		return
	# Ein Schleier ueber der Szene dahinter: das Beet soll das Bild sein,
	# nicht der See darunter.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.06, 0.72))
	var ecken := PackedVector2Array([
		_zelle_pos(0, 0) + Vector2(0.0, -HALB_H),
		_zelle_pos(Reeds.SPALTEN - 1, 0) + Vector2(HALB_B, 0.0),
		_zelle_pos(Reeds.SPALTEN - 1, Reeds.ZEILEN - 1) + Vector2(0.0, HALB_H),
		_zelle_pos(0, Reeds.ZEILEN - 1) + Vector2(-HALB_B, 0.0)])
	draw_colored_polygon(ecken, Palette.get_color(&"peat"))
	draw_polyline(ecken + PackedVector2Array([ecken[0]]),
		Palette.get_color(&"peat_dark"), 3.0)

## Anzeige. Alles per Anker gesetzt und nichts aus size gerechnet: in _ready()
## ist die noch (0,0), die erste Groesse kommt mit dem Layout-Durchlauf.
func _baue_hud() -> void:
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	# Die Zahl ist das Ergebnis der Runde -- sie darf gross sein. Ein Vielfaches
	# der Theme-Groesse, damit Silkscreen auf ihrem Achterraster bleibt.
	var kopf := VBoxContainer.new()
	kopf.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	kopf.offset_left = 32.0
	kopf.offset_top = 18.0
	kopf.add_theme_constant_override(&"separation", 0)
	hud.add_child(kopf)
	_zaehler = Label.new()
	_zaehler.text = "0"
	_zaehler.add_theme_font_size_override(&"font_size", UiTheme.SCHRIFT_GROESSE * 3)
	_zaehler.add_theme_constant_override(&"outline_size", UiTheme.OUTLINE * 3)
	kopf.add_child(_zaehler)
	var unterschrift := Label.new()
	unterschrift.text = "HALME"
	unterschrift.modulate = Palette.get_color(&"reed_light")
	kopf.add_child(unterschrift)

	_uhr = ProgressBar.new()
	_uhr.show_percentage = false
	_uhr.max_value = 100.0
	_uhr.value = 100.0
	_uhr.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_uhr.offset_left = 320.0
	_uhr.offset_right = -320.0
	_uhr.offset_top = 26.0
	_uhr.offset_bottom = 62.0
	hud.add_child(_uhr)

	# Die Karte legt sich mittig hin und wird nur so gross wie ihr Inhalt --
	# fest gesetzte Masse gaben eine halbleere Tafel ueber dem ganzen Beet.
	var mitte := CenterContainer.new()
	mitte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mitte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(mitte)
	_karte = PanelContainer.new()
	_karte.custom_minimum_size = Vector2(560.0, 0.0)
	_karte.visible = false
	mitte.add_child(_karte)
	var kasten := VBoxContainer.new()
	kasten.add_theme_constant_override(&"separation", 18)
	_karte.add_child(kasten)
	_karte_text = RichTextLabel.new()
	_karte_text.bbcode_enabled = true
	_karte_text.fit_content = true
	_karte_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kasten.add_child(_karte_text)
	var fertig := Button.new()
	fertig.text = "FERTIG"
	fertig.custom_minimum_size = Vector2(0.0, 76.0)
	fertig.pressed.connect(_schliesse)
	kasten.add_child(fertig)

func _schliesse() -> void:
	visible = false
	Audio.play(&"click", 0.05, true)
	beendet.emit()
