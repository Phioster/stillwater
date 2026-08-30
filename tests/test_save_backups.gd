extends TestCase

## temp+umbenennen schützt vor einem Absturz mitten im Schreiben. Es schützt
## NICHT davor, dass ein kaputter Stand sauber gespeichert wird und den guten
## überschreibt. Genau dafür sind die Sicherungen da.

var _original_path: String = ""

func _path() -> String:
	return "user://test_backup.json"

## Der Pfad MUSS am Ende jedes Tests zurückgesetzt werden, sonst speichern
## alle folgenden Tests in die Testdatei dieser Suite und finden dort
## Sicherungen, die sie nicht erwarten.
func _restore() -> void:
	if _original_path != "":
		SaveManager.SAVE_PATH = _original_path

func _clean() -> void:
	if _original_path == "":
		_original_path = SaveManager.SAVE_PATH
	SaveManager.SAVE_PATH = _path()
	for p in [_path(), _path() + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	for i in range(1, SaveManager.BACKUP_COUNT + 1):
		var b := SaveManager.backup_path(i)
		if FileAccess.file_exists(b):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(b))
	SaveManager._saves_since_backup = SaveManager.BACKUP_EVERY

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func test_a_backup_is_kept_before_overwriting() -> void:
	_clean()
	Game.new_game()
	Game.coins = 111
	SaveManager.save()
	assert_false(FileAccess.file_exists(SaveManager.backup_path(1)),
		"beim ersten Speichern gibt es noch nichts zu sichern")

	Game.coins = 222
	SaveManager._saves_since_backup = SaveManager.BACKUP_EVERY
	SaveManager.save()
	var kept = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.backup_path(1)))
	assert_eq(int(kept["coins"]), 111, "die Sicherung muss den VORIGEN Stand enthalten")

## Nicht bei jedem Autospeichern sichern -- sonst sind nach drei Minuten alle
## Kopien so alt wie das Original und damit wertlos.
	_restore()

func test_backups_are_not_taken_on_every_save() -> void:
	_clean()
	Game.new_game()
	Game.coins = 1
	SaveManager.save()
	SaveManager._saves_since_backup = 0
	for i in SaveManager.BACKUP_EVERY - 1:
		Game.coins = 100 + i
		SaveManager.save()
	assert_false(FileAccess.file_exists(SaveManager.backup_path(1)),
		"es wurde zu früh gesichert")
	_restore()

func test_older_backups_move_down_the_line() -> void:
	_clean()
	Game.new_game()
	for value in [10, 20, 30, 40]:
		Game.coins = value
		SaveManager._saves_since_backup = SaveManager.BACKUP_EVERY
		SaveManager.save()
	# Nach vier Ständen: Sicherung 1 = 30, 2 = 20, 3 = 10.
	for pair in [[1, 30], [2, 20], [3, 10]]:
		var d = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.backup_path(pair[0])))
		assert_eq(int(d["coins"]), pair[1], "Sicherung %d" % pair[0])

## Der eigentliche Zweck: ein zerstörter Stand kostet nicht alles.
	_restore()

func test_a_broken_save_falls_back_to_the_newest_backup() -> void:
	_clean()
	Game.new_game()
	Game.coins = 777
	SaveManager.save()
	Game.coins = 888
	SaveManager._saves_since_backup = SaveManager.BACKUP_EVERY
	SaveManager.save()

	_write(_path(), "{ das ist kein JSON")
	Game.new_game()
	assert_true(SaveManager.load_game(), "die Sicherung muss einspringen")
	assert_eq(Game.coins, 777, "der gerettete Stand stimmt nicht")
	_restore()

func test_without_any_usable_backup_it_gives_up_honestly() -> void:
	_clean()
	_write(_path(), "kaputt")
	assert_false(SaveManager.load_game(), "ohne Sicherung darf es nicht so tun als ginge es")
	_restore()

func test_a_backup_from_the_future_is_not_used() -> void:
	_clean()
	_write(_path(), "kaputt")
	_write(SaveManager.backup_path(1), '{"save_version": 9999, "coins": 5}')
	assert_eq(SaveManager.newest_usable_backup(), "",
		"ein Stand aus einer neueren Version ist keine brauchbare Sicherung")
	_restore()
