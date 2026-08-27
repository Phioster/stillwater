## Die verbindliche Farbpalette von Stillwater. Handgemalte Sprites müssen
## sich daran halten, sonst fällt der Stil auseinander.
class_name Palette
extends RefCounted

const COLORS := {
	&"sky_high":    Color("2f4858"),
	&"sky_low":     Color("6a8ba0"),
	&"water_deep":  Color("1f3b47"),
	&"water_mid":   Color("2e5f6b"),
	&"water_light": Color("478a8f"),
	&"foam":        Color("bcd9d2"),
	&"reed_dark":   Color("2f4a34"),
	&"reed":        Color("4d7a4a"),
	&"reed_light":  Color("7ba85f"),
	&"wood_dark":   Color("4a3626"),
	&"wood":        Color("7a5a3c"),
	&"wood_light":  Color("a5825a"),
	&"skin_1":      Color("e8be9a"),
	&"skin_2":      Color("c68c63"),
	&"skin_3":      Color("8d5a3c"),
	&"cloth_red":   Color("b4523f"),
	&"cloth_blue":  Color("3f6fb4"),
	&"cloth_green": Color("4a9455"),
	&"cloth_grey":  Color("6f7a75"),
	&"hair_dark":   Color("2c2320"),
	&"hair_warm":   Color("8a5a2c"),
	&"hair_pale":   Color("d8c48a"),
	&"accent":      Color("f0c05a"),
	&"outline":     Color("1a2320"),
	&"shadow":      Color("141c1a"),
}

static func get_color(name: StringName) -> Color:
	return COLORS.get(name, Color.MAGENTA)
