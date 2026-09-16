## Ein Besucher am Steg -- der Rabe oder der Waschbaer.
##
## Vorher schalteten beide hart auf sichtbar und wieder weg. Jetzt kommen sie
## an und gehen wieder, und der Zustandsablauf dafuer liegt HIER statt in
## world.gd: die Welt sagt nur noch, ob der Besucher da sein soll.
##
## Vier Zustaende. Entscheidend ist der WECHSEL und nicht der Istwert: wer nur
## auf "soll da sein" schaut, laesst den Raben bei jedem Bild neu landen.
class_name Visitor
extends RefCounted

enum Zustand { ABWESEND, ANKUNFT, DA, ABGANG }

## Wie lange Ankunft und Abgang dauern.
const DAUER := 1.6
## Bilder je Sekunde in der Laufreihe.
const TAKT := 10.0
## Wie weit ueber den oberen Bildrand hinaus der Rabe verschwindet, in
## seinen eigenen Kantenlaengen -- und wie weit dabei zur Seite.
const FLUG_HOCH := 1.0
const FLUG_SEITE := 1.6
## Wie weit ausserhalb des Bildes die Reise beginnt und endet.
const WEITE := 1.6
## Kantenlaenge eines Besucherbildes in Bildpixeln.
const BILD_PX := 48.0

var _knopf: TextureButton
var _ruhe: Texture2D
var _bilder: Array[AtlasTexture] = []
## Der Rabe fliegt (steigt beim Kommen und Gehen), der Waschbaer laeuft.
var _fliegt: bool
## Der Waschbaer geht nach links und dreht sich dabei um; der Rabe zieht nach
## rechts uebers Wasser weiter und bleibt, wie er ist.
var _geht_links: bool
## Takt des Wippens im Stand. Verschiedene Werte je Besucher, sonst huepfen
## beide im Gleichschritt wie ein Uhrwerk.
var _wippt: float

var _zustand: int = Zustand.ABWESEND
## Fortschritt in Ankunft oder Abgang, 0 bis 1.
var _fort: float = 0.0
var _takt: float = 0.0
## Erst ab dem zweiten Bild darf animiert werden: beim Programmstart ist ein
## wartender Besucher einfach da und landet nicht erst.
var _erster_lauf := true

var _fuss: float = 0.0
var _ziel_x: float = 0.0
var _kante: float = 0.0
var _breite_welt: float = 0.0

func _init(knopf: TextureButton, ruhe: Texture2D, blatt: Texture2D,
		bilder: int, fliegt: bool, geht_links: bool, wippt: float) -> void:
	_knopf = knopf
	_ruhe = ruhe
	_fliegt = fliegt
	_geht_links = geht_links
	_wippt = wippt
	# Ein Blatt, viele Ausschnitte: der Knopf kann keine Bildnummer, also
	# bekommt er je Bild eine eigene Atlastextur statt eines Bildindex.
	if blatt != null:
		var h := blatt.get_height()
		var b := blatt.get_width() / maxi(bilder, 1)
		for i in bilder:
			var teil := AtlasTexture.new()
			teil.atlas = blatt
			teil.region = Rect2(i * b, 0, b, h)
			_bilder.append(teil)

## Wo der Besucher steht, wie gross er ist und wie breit die Welt ist.
func setze(fuss: float, ziel_x: float, kante: float, breite: float) -> void:
	_fuss = fuss
	_ziel_x = ziel_x
	_kante = kante
	_breite_welt = breite

## Ein Bild weiter. `da` ist, was die Spielregeln sagen.
func tick(delta: float, da: bool) -> void:
	if _erster_lauf:
		_erster_lauf = false
		_zustand = Zustand.DA if da else Zustand.ABWESEND
	match _zustand:
		Zustand.ABWESEND:
			if da:
				_starte(Zustand.ANKUNFT)
		Zustand.DA:
			if not da:
				_starte(Zustand.ABGANG)
		Zustand.ANKUNFT:
			# Kehrt der Besucher mitten im Kommen zurueck ins Nichts, laeuft
			# er den Weg nicht rueckwaerts -- er geht regulaer wieder.
			_fort += delta / DAUER
			if _fort >= 1.0:
				_zustand = Zustand.DA
			elif not da:
				_starte(Zustand.ABGANG)
		Zustand.ABGANG:
			_fort += delta / DAUER
			if _fort >= 1.0:
				_zustand = Zustand.ABWESEND
			elif da:
				_starte(Zustand.ANKUNFT)
	_takt += delta
	_zeichne()

func _starte(zustand: int) -> void:
	_zustand = zustand
	_fort = 0.0

func _zeichne() -> void:
	_knopf.visible = _zustand != Zustand.ABWESEND
	# Antippen nur, wenn er wirklich dasteht: einen landenden Raben zu
	# pfluecken waere ein Treffer auf etwas, das noch gar nicht da ist.
	_knopf.disabled = _zustand != Zustand.DA
	if not _knopf.visible:
		return
	var unterwegs := _zustand == Zustand.ANKUNFT or _zustand == Zustand.ABGANG
	_knopf.texture_normal = _bild() if unterwegs and not _bilder.is_empty() \
		else _ruhe
	var ort := _ort()
	# Gespiegelt wird ueber die Skalierung; sie dreht um die linke Kante,
	# deshalb muss die Stelle um eine Breite zurueck.
	var links := _zustand == Zustand.ABGANG and _geht_links
	_knopf.scale = Vector2(-1.0 if links else 1.0, 1.0)
	_knopf.position = Vector2(ort.x + (_kante if links else 0.0), ort.y)

func _bild() -> Texture2D:
	return _bilder[int(_takt * TAKT) % _bilder.size()]

## Wo der Besucher gerade ist. Ausserhalb liegt der Anfang der Ankunft und
## das Ende des Abgangs.
func _ort() -> Vector2:
	# Im Stand wippt er einen Bildpixel auf und ab -- auf ganze Pixel
	# gerundet, sonst wandert die Kante durchs Raster statt zu springen.
	var pixel := _kante / BILD_PX
	var steht := Vector2(_ziel_x,
		_fuss - roundf(sin(_takt * _wippt) * 0.5 + 0.5) * pixel)
	if _zustand == Zustand.DA or _zustand == Zustand.ABWESEND:
		return steht
	var fern := _fern()
	var t: float = clampf(_fort, 0.0, 1.0)
	if _zustand == Zustand.ANKUNFT:
		# Weich abbremsen: ein Landeanflug mit gleichbleibendem Tempo sieht
		# aus wie ein Schienenfahrzeug.
		return fern.lerp(steht, 1.0 - pow(1.0 - t, 2.0))
	return steht.lerp(fern, t * t)

func _fern() -> Vector2:
	if _fliegt:
		# Schraeg ueber dem Platz aus dem Bild, nicht quer hindurch: ein
		# Vogel steigt auf und ist weg. Die ganze Bildbreite abzufliegen
		# machte aus dem Abflug eine Reise.
		var seite := -FLUG_SEITE if _zustand == Zustand.ANKUNFT else FLUG_SEITE
		return Vector2(_ziel_x + _kante * seite, -_kante * FLUG_HOCH)
	var weit := _kante * WEITE
	var nach_links := _zustand == Zustand.ANKUNFT or _geht_links
	var x := -weit if nach_links else _breite_welt + weit
	return Vector2(x, _fuss)
