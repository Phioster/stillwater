# Stillwater

Ein ruhiges 2D-Pixel-Art-Angel-Idle-Spiel für Android, gebaut mit Godot
4.7.2. Der Spieler angelt automatisch an einem See, verkauft Fische,
kauft Ausrüstung und schaltet damit Zonen, Köder und seltenere Fische
frei.

Alle Inhalte sind eigenständig. Reale Fischarten (Bluegill, Rotauge,
Flussbarsch, Spiegelkarpfen, Makrele, Hornhecht, Meerbarbe, Wolfsbarsch
...) werden frei verwendet, weil es reale Tiere sind. Erfundene Namen,
Grafiken, Texte und UI-Entwürfe stammen nicht aus einem Referenzspiel.

## Voraussetzungen

- Godot 4.7.2 stable
- Für den Android-Export zusätzlich JDK 17 und das Android SDK — beide
  werden nur in der CI gebraucht, nicht für Tests oder lokale Entwicklung.

## Starten

```
godot res://scenes/main.tscn
```

Auf dem Entwicklungsgerät (Termux/Android) stürzt der Godot-Editor ab
(siehe [ARCHITECTURE.md](ARCHITECTURE.md)); dort läuft alles headless
über den Wrapper, zum Beispiel zur Startprüfung:

```
PROJECT=$HOME/stillwater bash tools/godot.sh --quit-after 60 res://scenes/main.tscn
```

## Tests

```
PROJECT=$HOME/stillwater bash ./tools/godot.sh --script res://tests/run_tests.gd
```

Ein `SceneTree`-Skript ohne externes Test-Framework, siehe
`tests/run_tests.gd`. Stand: 125 Tests, 0 fehlgeschlagen.

## Inhalte neu erzeugen

```
PROJECT=$HOME/stillwater bash tools/godot.sh --script res://tools/build_data.gd
PROJECT=$HOME/stillwater bash tools/godot.sh --script res://tools/gen_sprites.gd
```

`build_data.gd` erzeugt die `.tres`-Ressourcen (Fische, Köder, Zonen,
Upgrades, Raritäten) unter `data/`. `gen_sprites.gd` erzeugt die
Platzhalter-Sprites unter `assets/art/`.

## Android bauen

```
gh workflow run build.yml
gh run watch
gh run download -n stillwater-debug-apk -D ~/stillwater-apk
adb install -r ~/stillwater-apk/stillwater-debug.apk
```

`test.yml` läuft bei jedem Push und ist das Test-Gate. `build.yml`
läuft nur auf Anforderung und legt `stillwater-debug.apk` als Artefakt
ab.

## Projektstruktur

| Pfad | Inhalt |
|---|---|
| `project.godot` | Godot-Projektdatei: Autoloads, Anzeige (1280×720, Landscape), Rendering |
| `autoload/` | Die drei Autoloads: `Database.gd`, `Game.gd`, `SaveManager.gd` |
| `core/` | Simulationskern, reines GDScript ohne Node-Bezug: `fishing_sim.gd`, `offline_sim.gd`, `economy.gd`, `progression.gd`, `fish_roll.gd`, `inventory.gd`, `journal.gd`, `sim_context.gd`, `still_rng.gd`, `caught_fish.gd`, `palette.gd` (Farbpalette — Laufzeitcode, deshalb hier und nicht unter `tools/`) |
| `resources/` | `Resource`-Basisklassen der Daten: `fish_data.gd`, `bait_data.gd`, `zone_data.gd`, `upgrade_data.gd`, `rarity_data.gd`, `catch_condition.gd`, `bait_condition.gd`, `level_condition.gd` |
| `data/` | Die eigentlichen Spieldaten als `.tres`: `fish/`, `bait/`, `zones/`, `upgrades/`, `rarities/` |
| `scenes/` | Szenen und ihre Skripte: `main.tscn`, `fishing/` (Welt, Angler, Fangansicht, Orbs), `ui/` (HUD, Tab-Leiste, sechs Panels, Rückkehr-Fenster) |
| `assets/art/` | Platzhalter-PNGs und der Paletten-Shader |
| `tools/` | `godot.sh` (Wrapper), `gen_class_cache.py` (Script-Class-Cache), `build_data.gd` (Dateninhalte), `gen_sprites.gd` (Sprites, nutzt `Palette` aus `core/`) — bewusst vom Export ausgeschlossen |
| `tests/` | `run_tests.gd` (Runner) und 18 `test_*.gd`-Suiten |
| `docs/` | Spezifikation und Implementierungsplan |

## Lizenz / Herkunft

Kein externer Code, keine externen Assets. Details zur Namensregel und
zu den Abweichungen vom Referenzspiel stehen in
[GAME_DESIGN.md](GAME_DESIGN.md).
