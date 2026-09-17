## Lädt eine Schrift so, dass beide Umgebungen bedient werden -- genau wie
## core/texture_loader.gd das für Bilder tut: im Export lief der Import-Schritt,
## also trägt der reguläre res://-Weg; auf diesem Entwicklungsgerät gibt es
## keinen Import-Cache (der Editor stürzt hier ab), deshalb der Rückfall auf
## FontFile.load_dynamic_font().
##
## Die Pixeleinstellungen werden hier gesetzt und nicht beim Import: über den
## Rückfallweg gibt es gar keine Importeinstellungen, und eine Pixelschrift mit
## Kantenglättung ist verwaschen statt scharf -- das sieht man sofort.
class_name FontLoader
extends RefCounted

static func load_font(path: String) -> FontFile:
	var schrift: FontFile = null
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is FontFile:
			schrift = res
	if schrift == null:
		var full_path := ProjectSettings.globalize_path(path)
		if not FileAccess.file_exists(full_path):
			return null
		schrift = FontFile.new()
		if schrift.load_dynamic_font(full_path) != OK:
			return null
	_scharf(schrift)
	return schrift

## Keine Glättung, kein Hinting, keine Zwischenpositionen: eine Pixelschrift
## soll auf dem Raster sitzen, auf dem sie gezeichnet wurde.
static func _scharf(schrift: FontFile) -> void:
	schrift.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	schrift.hinting = TextServer.HINTING_NONE
	schrift.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	schrift.multichannel_signed_distance_field = false
	schrift.generate_mipmaps = false
