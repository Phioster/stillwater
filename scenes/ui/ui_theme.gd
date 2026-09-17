## Schrift, Umriss und Rahmen für die ganze Oberfläche an EINER Stelle.
##
## Die Referenz hat dafür eigene Varianten jedes Standardelements. Ein Theme
## erreicht dasselbe, ohne dass jede neue Zeile daran denken muss — und
## Vergessen ist die wahrscheinlichste Fehlerquelle bei so etwas. main.gd
## setzt es einmal auf den Wurzel-Control, alles darunter erbt es.
##
## Die Oberfläche lief vorher in Godots Standardschrift mit runden Ecken und
## weichen Schatten — daneben sah die gemalte Welt aus wie aus einem anderen
## Spiel. Jetzt: Pixelschrift, harte Kanten, und als Panelrahmen der Steg
## selbst (tools/rahmen_bauen.py schneidet ihn aus assets/art/dock.png).
class_name UiTheme
extends RefCounted

const SCHRIFT := "res://assets/fonts/Silkscreen.ttf"
const SCHRIFT_FETT := "res://assets/fonts/Silkscreen-Bold.ttf"
## Die dreizehn Zeichen, die Silkscreen nicht hat (tools/zeichen_bauen.py) --
## Regenschirm, Sterne, Kästchen, Pfeile. Sie hängen als ERSATZSCHRIFT hinten
## dran: Godot greift pro Zeichen von selbst darauf zurück, und deshalb muss
## keine der zwölf Dateien angefasst werden, die solche Zeichen benutzen.
const ZEICHEN := "res://assets/fonts/StillwaterZeichen.ttf"
const RAHMEN := "res://assets/art/panel_rahmen.png"

## Silkscreen ist auf acht Pixel gezeichnet, 16 sind genau das Doppelte. Bei
## einem krummen Vielfachen bekommt ein Teil der Buchstaben ein Pixel mehr als
## der andere, und die Zeile wirkt zittrig.
##
## 24 waren zu groß: Silkscreen ist deutlich breiter je Zeichen als Godots
## Standardschrift, und die Reiterleiste ist auf 96 Punkte festgenagelt --
## "Optionen" lief dort rechts aus dem Bild. 16 hält die Zeilen so lang wie
## vorher, die Leiste wird trotzdem breiter (tab_rail.tscn).
const SCHRIFT_GROESSE: int = 16
## Bei doppelter Vergrößerung ist 2 genau EIN gezeichnetes Pixel Umriss.
## Vorher standen hier 6 -- das war für eine Schrift ohne eigene Kontur
## gedacht und sähe an einer Pixelschrift aus wie mit dem Filzstift nachgezogen.
const OUTLINE: int = 2
## Die Grundfarbe der Beschriftungen. Sie ist ein MULTIPLIKATOR und keine
## Farbe: die Oberfläche färbt an zwanzig Stellen per `modulate` ein
## (Seltenheit, Akzent, Warnung), und `modulate` multipliziert. Eine helle
## Grundfarbe ließ jede dieser Farben hell auf hellem Sand landen —
## nachgemessen kam KEINE über einen Kontrast von 1,9, lesbar wird es ab 4,5.
## Abgesenkt bleiben die Farbtöne erhalten und landen bei 5 bis 7.
##
## Wer hier heller dreht, macht die Seltenheitsfarben unlesbar; wer dunkler
## dreht, macht sie alle schwarz und wirft die Farbkodierung weg.
const TINTE_AUF_SAND := Color(0.36, 0.35, 0.33)
## Wieviel Luft ein Knopf um seine Aufschrift lässt.
const KNOPF_RAND: int = 4
## Die 9-Slice-Ränder des Rahmenbildes, in Bildpunkten. Sie stehen so auch in
## tools/rahmen_bauen.py; tests/test_ui_theme.gd hält beide zusammen.
const RAHMEN_SEITE: int = 14
const RAHMEN_OBEN: int = 16

static func build() -> Theme:
	var t := Theme.new()
	var ink := Palette.get_color(&"outline")

	var schrift := _schrift(SCHRIFT)
	if schrift != null:
		t.default_font = schrift
	t.default_font_size = SCHRIFT_GROESSE

	# Der Umriss trägt den Text über seinem Untergrund, wo eine Schriftfarbe
	# allein nicht reicht. Seine Farbe haengt deshalb davon ab, WORAUF der
	# Text sitzt, und nicht am Geschmack:
	#
	# Beschriftungen stehen auf dem hellen Sandpanel und tragen ihre
	# Seltenheits- oder Akzentfarbe (fish_row.gd, zwanzig weitere Stellen).
	# Die sind alle dunkler als Sand. Mit dunklem Umriss ersaufen sie darin --
	# ausprobiert, alles sah schwarz aus; ein HELLER Umriss holt sie heraus.
	#
	# Knöpfe sind dunkles Holz mit hellem Text, dort gilt das Umgekehrte.
	for type_name in ["Label", "RichTextLabel"]:
		t.set_color("font_outline_color", type_name,
			Palette.get_color(&"sea_foam"))
		t.set_constant("outline_size", type_name, OUTLINE)
		t.set_color("font_color", type_name, TINTE_AUF_SAND)
	for type_name in ["Button", "LineEdit"]:
		t.set_color("font_outline_color", type_name, ink)
		t.set_constant("outline_size", type_name, OUTLINE)

	var rahmen := _rahmen()
	t.set_stylebox("panel", "PanelContainer", rahmen)
	t.set_stylebox("panel", "Panel", rahmen)

	# Knöpfe standen bisher gar nicht im Theme und trugen deshalb Godots
	# graue Standardkapsel mit runden Ecken. Sie bekommen kein Holz -- ein
	# Rahmen um jede Listenzeile wäre eine Wand aus Brettern --, sondern eine
	# flache Fläche mit harter Kante: das Panel ist das Möbel, der Knopf ist
	# die Aufschrift darauf.
	# Holztöne und nicht Wasser: der Knopf sitzt auf dem Sandpanel im
	# Holzrahmen, ein blaugrüner Fleck darin käme von woanders her.
	t.set_stylebox("normal", "Button", _knopf(Palette.get_color(&"sand_dark"), ink))
	t.set_stylebox("hover", "Button", _knopf(Palette.get_color(&"sand"), ink))
	t.set_stylebox("pressed", "Button", _knopf(Palette.get_color(&"wood_dark"), ink))
	t.set_stylebox("focus", "Button", _knopf(Palette.get_color(&"sand_dark"),
		Palette.get_color(&"accent")))
	var stumm := _knopf(Palette.get_color(&"wood_dark"), ink)
	stumm.bg_color.a = 0.55
	t.set_stylebox("disabled", "Button", stumm)

	# Der Erfahrungsbalken war Godots Standard: hell, rund und auf dem
	# Sandpanel praktisch unsichtbar. Dunkle Rinne, goldene Füllung, harte
	# Kante -- damit liest man auf einen Blick, wie weit er ist.
	var rinne := _knopf(Palette.get_color(&"wood_dark"), ink)
	rinne.set_content_margin_all(0)
	t.set_stylebox("background", "ProgressBar", rinne)
	var fuellung := StyleBoxFlat.new()
	fuellung.bg_color = Palette.get_color(&"accent")
	t.set_stylebox("fill", "ProgressBar", fuellung)
	return t

## Silkscreen mit der eigenen Zeichenschrift als Ersatz dahinter.
static func _schrift(pfad: String) -> FontFile:
	var f := FontLoader.load_font(pfad)
	if f == null:
		return null
	var zeichen := FontLoader.load_font(ZEICHEN)
	if zeichen != null:
		f.fallbacks = [zeichen]
	return f

## Der Steg als Panelrahmen. Ohne das Bild bliebe die Oberfläche unbenutzbar,
## deshalb gibt es einen flachen Rückfall statt eines leeren Rahmens.
static func _rahmen() -> StyleBox:
	var bild := TextureLoader.load_texture(RAHMEN)
	if bild == null:
		return _knopf(Palette.get_color(&"water_deep"),
			Palette.get_color(&"outline"))
	var box := StyleBoxTexture.new()
	box.texture = bild
	box.texture_margin_left = RAHMEN_SEITE
	box.texture_margin_right = RAHMEN_SEITE
	box.texture_margin_top = RAHMEN_OBEN
	box.texture_margin_bottom = RAHMEN_OBEN
	# Der Inhalt darf nicht unter dem Holz liegen -- aber auch nicht mehr Luft
	# bekommen als nötig: jeder Punkt hier fehlt der Zeile, und in der schmalen
	# Reiterleiste ist das der Unterschied zwischen "Optionen" und "Option".
	box.content_margin_left = RAHMEN_SEITE + 2
	box.content_margin_right = RAHMEN_SEITE + 2
	box.content_margin_top = RAHMEN_OBEN + 2
	box.content_margin_bottom = RAHMEN_OBEN + 2
	# GEKACHELT und nicht gedehnt: die Maserung hat eine feste Pixelgröße, ein
	# gedehntes Brett hätte gröbere Pixel als das Deck im Bild daneben.
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return box

## Eine flache Fläche mit harter Kante -- keine Rundung, kein Schatten.
static func _knopf(flaeche: Color, kante: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = flaeche
	box.bg_color.a = 0.92
	box.border_color = kante
	box.set_border_width_all(2)
	box.set_content_margin_all(KNOPF_RAND)
	return box
