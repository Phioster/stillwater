## Umriss und Schatten für die ganze Oberfläche an EINER Stelle.
##
## Die Referenz hat dafür eigene Varianten jedes Standardelements. Ein Theme
## erreicht dasselbe, ohne dass jede neue Zeile daran denken muss — und
## Vergessen ist die wahrscheinlichste Fehlerquelle bei so etwas.
class_name UiTheme
extends RefCounted

const OUTLINE: int = 6
const PANEL_RADIUS: int = 10

static func build() -> Theme:
	var t := Theme.new()
	var ink := Palette.get_color(&"outline")

	# Ein dunkler Umriss trägt Text über jedem Hintergrund — auch über
	# bewegtem Wasser, wo eine Schriftfarbe allein nie reicht.
	for type_name in ["Label", "Button", "RichTextLabel", "LineEdit"]:
		t.set_color("font_outline_color", type_name, ink)
		t.set_constant("outline_size", type_name, OUTLINE)
	t.set_color("font_shadow_color", "Label", Color(ink.r, ink.g, ink.b, 0.5))
	t.set_constant("shadow_offset_y", "Label", 2)

	var panel := StyleBoxFlat.new()
	panel.bg_color = Palette.get_color(&"water_deep")
	panel.bg_color.a = 0.92
	panel.corner_radius_top_left = PANEL_RADIUS
	panel.corner_radius_top_right = PANEL_RADIUS
	panel.corner_radius_bottom_left = PANEL_RADIUS
	panel.corner_radius_bottom_right = PANEL_RADIUS
	panel.border_color = ink
	panel.set_border_width_all(2)
	panel.shadow_color = Color(ink.r, ink.g, ink.b, 0.55)
	panel.shadow_size = 6
	panel.shadow_offset = Vector2(0, 3)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	return t
