## Das Schilfschneiden: die kurze, aktive Sache zwischen zwei Bissen.
##
## Ein kreisendes Messer folgt dem Finger ueber ein Schilfbeet. Es dreht sich
## von selbst -- es gibt keinen Schlagknopf und keine laufende Figur, der
## Finger IST die Hand. Getroffen wird nur, wo die Klinge WIRKLICH ist, sie
## muss also erst vorbeikommen; ein voller Kreis waere ein Rasenmaeher.
##
## Die Zahlen stehen nicht hier, sondern in core/reeds.gd und im Ausbau.
extends Control

signal beendet

## Zeigt, wo die Klinge wirklich trifft. Sie ist ihre eigene Trefferform, das
## Bild hier ist also der Umriss DERSELBEN Bitmap, nach der geschnitten wird
## -- es kann gar nicht auseinanderlaufen. Eigener Knoten, weil er UEBER
## Halmen und Klinge liegen muss; _draw der Wurzel malt hinter ihre Kinder.
class Trefferzone extends Node2D:
	var hand := Vector2.ZERO
	var winkel := 0.0
	var reichweite := 0.0
	var skala := 1.0

	var _umriss: Array[PackedVector2Array] = []

	func _draw() -> void:
		if reichweite <= 0.0:
			return
		var rot := Color(1.0, 0.33, 0.28, 0.9)
		# Blass die Bahn der Spitze: daran ist der Reichweiten-Ausbau zu sehen.
		draw_arc(hand, reichweite, 0.0, TAU, 64, Color(1.0, 0.33, 0.28, 0.22),
			1.0)
		var g := Reeds.klinge_groesse()
		if _umriss.is_empty():
			_umriss = Reeds.maske().opaque_to_polygons(
				Rect2i(Vector2i.ZERO, g), 0.5)
		var fuss := reichweite - float(g.x) * skala
		for teil in _umriss:
			var welt := PackedVector2Array()
			for punkt in teil:
				welt.append(hand + Vector2(fuss + punkt.x * skala,
					(punkt.y - float(g.y) * 0.5) * skala).rotated(winkel))
			if welt.size() > 1:
				welt.append(welt[0])
				draw_polyline(welt, rot, 2.0, false)


## Die Spur, die die Klinge hinter sich laesst.
##
## Sie ist der Grund, warum man ueberhaupt sieht, dass sich da etwas dreht:
## ein kurzes Messer allein blitzt nur. Im Vorbild ist genau DAS das grosse
## weisse Sicheldings, das wie eine Klinge aussieht -- nachgemessen ist das
## Werkzeug dort ein Balken von vierzehn Pixeln, der Rest ist Schweif.
##
## Und weil die Spur mit dem Tempo laenger wird, ist auch dieser Ausbau zu
## sehen, statt sich nur in einer Zahl abzuspielen.
class Schweif extends Node2D:
	## Wie lange sie nachleuchtet.
	const NACHLEUCHTEN := 0.13
	const DECKUNG := 0.40
	var innen := 0.0
	var aussen := 0.0

	var _hand := PackedVector2Array()
	var _dreh := PackedFloat32Array()
	var _zeit := PackedFloat32Array()

	func melde(stelle: Vector2, winkel: float, jetzt: float) -> void:
		_hand.append(stelle)
		_dreh.append(winkel)
		_zeit.append(jetzt)
		while _zeit.size() > 0 and jetzt - _zeit[0] > NACHLEUCHTEN:
			_hand.remove_at(0)
			_dreh.remove_at(0)
			_zeit.remove_at(0)
		queue_redraw()

	func leere() -> void:
		_hand.clear()
		_dreh.clear()
		_zeit.clear()

	func _draw() -> void:
		if _zeit.size() < 2 or aussen <= innen:
			return
		var jetzt := _zeit[_zeit.size() - 1]
		var c := Palette.get_color(&"rod_shine")
		var mitte := (innen + aussen) * 0.5
		var halb := (aussen - innen) * 0.5
		for i in _zeit.size() - 1:
			var t0 := clampf((jetzt - _zeit[i]) / NACHLEUCHTEN, 0.0, 1.0)
			var t1 := clampf((jetzt - _zeit[i + 1]) / NACHLEUCHTEN, 0.0, 1.0)
			# Nach hinten duenner UND blasser: ein gleich breites Band sieht
			# aus wie ein Reifen, nicht wie eine Spur.
			var h0 := halb * (1.0 - t0 * 0.8)
			var h1 := halb * (1.0 - t1 * 0.8)
			var ecken := PackedVector2Array([
				_hand[i] + Vector2(mitte + h0, 0.0).rotated(_dreh[i]),
				_hand[i + 1] + Vector2(mitte + h1, 0.0).rotated(_dreh[i + 1]),
				_hand[i + 1] + Vector2(mitte - h1, 0.0).rotated(_dreh[i + 1]),
				_hand[i] + Vector2(mitte - h0, 0.0).rotated(_dreh[i])])
			var f0 := Color(c.r, c.g, c.b, DECKUNG * (1.0 - t0))
			var f1 := Color(c.r, c.g, c.b, DECKUNG * (1.0 - t1))
			draw_polygon(ecken, PackedColorArray([f0, f1, f1, f0]))


## Der Zellabstand. Gross genug, dass die Halme sich nicht gegenseitig
## verdecken -- sie sind so hoch wie die am Ufer, und das sind ueber hundert
## Punkte auf dem Schirm.
const HALB_B := 62.0
const HALB_H := 34.0
## Wie Steg, Figur und Schwimmer -- ein Pixel ist ein Pixel.
const SKALA := 2.16
var _schilf: Texture2D
var _klinge_bild: Texture2D

var _halme_ebene: Node2D
var _klinge: Sprite2D
var _zone: Trefferzone
var _schweif: Schweif
var _zaehler: Label
var _warnung: Label
var _uhr: ProgressBar
var _karte: PanelContainer
var _karte_text: RichTextLabel

var _halme: Dictionary = {}
var _winkel := 0.0
var _ziel := Vector2.ZERO
## Wo die Hand steht -- die Klinge kreist darum.
var _hand := Vector2.ZERO
var _zeit := 0.0
var _zeit_gesamt := 0.0
var _seit_nachwuchs := 0.0
var _wind := 0.0
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
	_klinge_bild = TextureLoader.load_texture(Reeds.KLINGE_BILD)
	_rng.randomize()

	_halme_ebene = Node2D.new()
	_halme_ebene.y_sort_enabled = true
	add_child(_halme_ebene)
	_schweif = Schweif.new()
	add_child(_schweif)
	_klinge = Sprite2D.new()
	_klinge.texture = _klinge_bild
	add_child(_klinge)
	_zone = Trefferzone.new()
	_zone.visible = false
	add_child(_zone)
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
	_zeit_gesamt = 0.0
	_geschnitten = 0
	_laeuft = true
	_karte.visible = false
	# Bei voller Tasche bringt das Schneiden nur noch Funde. Das gehoert VOR
	# die Runde, nicht auf die Abrechnung danach -- sonst maeht man achtzehn
	# Sekunden fuer nichts und erfaehrt es erst am Ende.
	_warnung.visible = Game.bait_used() >= Game.bait_capacity()
	_ziel = _beet_mitte()
	_hand = _ziel
	_winkel = 0.0
	_schweif.leere()
	_klinge.position = _ziel
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
		s.region_rect = Rect2(0.0, 0.0, float(Reeds.HALM_B), float(Reeds.HALM_H))
		s.scale = Vector2(SKALA, SKALA)
		# Der Fuss des Halms sitzt auf der Zelle, nicht seine Mitte.
		s.offset = Vector2(0.0, -float(Reeds.HALM_H) * 0.5)
		s.position = _zelle_pos(z.x, z.y)
		s.set_meta(&"leben", _noetig)
		s.set_meta(&"pause", 0.0)
		s.set_meta(&"stufe", 0)
		# Jeder Halm bringt seine eigene Zeit mit, sonst wiegt sich das ganze
		# Beet im Gleichschritt -- und das sieht aus wie eine Tapete.
		s.set_meta(&"wind", _rng.randf() * 100.0)
		s.set_meta(&"stellung", -1)
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
	# Nicht gewickelt: der Schweif haengt an aufeinanderfolgenden Winkeln,
	# und ein Sprung von PI auf -PI zoege ihn einmal ums ganze Bild.
	var vorher := _winkel
	_winkel += Game.scythe_speed() * TAU * delta
	var reichweite := Game.scythe_reach()
	# Die Hand zieht dem Finger NACH, statt an ihm zu kleben: ohne das springt
	# sie bei jedem Antippen quer durchs Bild.
	_hand = _hand.lerp(_ziel, clampf(delta * 18.0, 0.0, 1.0))
	# Das Messer haengt mit dem Griff nach innen an der Hand, seine Spitze
	# genau auf der Reichweite.
	_klinge.position = _hand + Vector2(Reeds.klinge_bahn(reichweite, SKALA),
		0.0).rotated(_winkel)
	_klinge.rotation = _winkel
	_klinge.scale = Vector2(SKALA, SKALA)
	# Der Schweif laeuft hinter der SCHNEIDE her, nicht hinter dem Griff.
	var g := Reeds.klinge_groesse()
	var stahl := Reeds.schneide_bereich()
	_schweif.innen = reichweite - (float(g.x) - stahl.x) * SKALA
	_schweif.aussen = reichweite - (float(g.x) - stahl.y) * SKALA
	_schweif.melde(_hand, _winkel, _zeit_gesamt)
	_zeit_gesamt += delta
	_zone.visible = Game.dev_scythe_box
	if _zone.visible:
		_zone.hand = _hand
		_zone.winkel = _winkel
		_zone.reichweite = reichweite
		_zone.skala = SKALA
		_zone.queue_redraw()
	if not _laeuft:
		queue_redraw()
		return
	_wind += delta
	_zeit = maxf(0.0, _zeit - delta)
	_seit_nachwuchs += delta
	while _seit_nachwuchs >= Reeds.NACHWUCHS:
		_seit_nachwuchs -= Reeds.NACHWUCHS
		_saee()
	_schneide(delta, reichweite, vorher)
	_wiege()
	_zaehler.text = "%d" % _geschnitten
	_uhr.value = _zeit / Reeds.DAUER * 100.0
	if _zeit <= 0.0:
		_beende()
	queue_redraw()

## Wer unter der Klinge steht, bekommt einen Treffer -- unter der Klinge
## selbst, nicht unter irgendeinem Kreis um sie herum.
func _schneide(delta: float, reichweite: float, vorher: float) -> void:
	for z in _halme.keys():
		var s: Sprite2D = _halme[z]
		var pause: float = s.get_meta(&"pause")
		if pause > 0.0:
			s.set_meta(&"pause", pause - delta)
			continue
		# Ueber den ganzen Bogen dieses Bildes, nicht nur an seinem Ende --
		# sonst springt die Klinge bei hohem Tempo ueber Halme hinweg.
		if not Reeds.trifft_im_schwung(s.position, _hand, vorher, _winkel,
				reichweite, SKALA):
			continue
		var leben: int = int(s.get_meta(&"leben")) - 1
		s.set_meta(&"leben", leben)
		s.set_meta(&"pause", Reeds.TREFFER_PAUSE)
		if leben > 0:
			# Der Halm wird kuerzer, statt nur zu blinken: sonst weiss man
			# nicht, ob man ihn schon hat.
			s.set_meta(&"stufe", clampi(int(floor(float(_noetig - leben)
				/ float(_noetig) * float(Reeds.HALM_STUFEN))),
				0, Reeds.HALM_STUFEN - 1))
			s.set_meta(&"stellung", -1)
			continue
		_geschnitten += 1
		Audio.play(&"rod", 0.04)
		_halme.erase(z)
		s.queue_free()

## Jeder Halm im Beet wiegt sich wie der am Ufer -- aber jeder zu seiner
## eigenen Zeit. Neu gesetzt wird nur, wenn sich die Stellung wirklich
## aendert; dazwischen steht das Bild still, und das soll es auch.
func _wiege() -> void:
	for s in _halme.values():
		var neu := ReedPatch.stellung(_wind + float(s.get_meta(&"wind")),
			Reeds.WIND_BILDER)
		if neu == int(s.get_meta(&"stellung")):
			continue
		s.set_meta(&"stellung", neu)
		s.region_rect.position = Vector2(float(neu * Reeds.HALM_B),
			float(int(s.get_meta(&"stufe")) * Reeds.HALM_H))

func _beende() -> void:
	_laeuft = false
	var e := Game.finish_reed_cut(_geschnitten)
	var zeilen: Array[String] = ["[b]%d Halme[/b]" % int(e["halme"])]
	var b: BaitData = Database.baits.get(e["bait"])
	var name: String = b.display_name if b != null else String(e["bait"])
	# Erst was es gab, dann warum es nicht mehr war. Vorher standen
	# "Zu wenig für einen Köder" und "Die Ködertasche ist voll" zusammen da --
	# das zweite war der Grund, das erste damit schlicht falsch.
	if int(e["got"]) > 0:
		zeilen.append("%d × %s" % [int(e["got"]), name])
	if int(e["got"]) < int(e["wanted"]):
		zeilen.append("Die Ködertasche ist voll")
	elif int(e["got"]) == 0:
		zeilen.append("Zu wenig für einen Köder")
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
## Schrift, die UEBER der Welt steht und nicht auf dem Sandpanel: weiss mit
## DUNKLEM Umriss. Das Theme macht es genau andersherum -- dunkle Tinte, heller
## Umriss --, weil es fuer die Panels gemacht ist; ueber dem Nachtwasser war
## "HALME" dadurch kaum zu lesen. Dieselbe Behandlung wie
## scenes/effects/pop_text.gd, das als einziges sonst ueber der Welt steht.
func _ueber_der_welt(l: Label, groesse: int) -> Label:
	l.add_theme_font_size_override(&"font_size", groesse)
	l.add_theme_color_override(&"font_color", Color.WHITE)
	l.add_theme_color_override(&"font_outline_color",
		Palette.get_color(&"shadow"))
	l.add_theme_constant_override(&"outline_size",
		maxi(4, groesse / UiTheme.SCHRIFT_GROESSE * UiTheme.OUTLINE * 2))
	return l

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
	_zaehler = _ueber_der_welt(Label.new(), UiTheme.SCHRIFT_GROESSE * 3)
	_zaehler.text = "0"
	kopf.add_child(_zaehler)
	var unterschrift := _ueber_der_welt(Label.new(), UiTheme.SCHRIFT_GROESSE)
	unterschrift.text = "HALME"
	kopf.add_child(unterschrift)
	_warnung = _ueber_der_welt(Label.new(), UiTheme.SCHRIFT_GROESSE)
	_warnung.text = "KÖDERTASCHE VOLL"
	_warnung.add_theme_color_override(&"font_color",
		Palette.get_color(&"accent"))
	_warnung.visible = false
	kopf.add_child(_warnung)

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
