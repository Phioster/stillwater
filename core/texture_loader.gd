## Lädt eine Textur so, dass beide Umgebungen bedient werden: im Export lief
## der Import-Schritt, also trägt der reguläre res://-Weg; auf diesem
## Entwicklungsgerät gibt es keinen Import-Cache (der Editor stürzt hier ab),
## deshalb der Rückfall auf Image.load_from_file().
class_name TextureLoader
extends RefCounted

static func load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			return res
	var full_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(full_path):
		return null
	var img := Image.load_from_file(full_path)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)
