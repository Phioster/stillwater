# Stillwater — Architektur

## Der Grundsatz: Simulationskern plus dünne Ansicht

Die Spiellogik in `core/` besteht aus reinen GDScript-Klassen ohne
Nodes, ohne Szenenbezug und ohne Grafikkenntnis. Szenen und UI zeigen
diesen Zustand nur an und leiten Eingaben weiter.

Der entscheidende Grund: der **Offline-Fortschritt ist kein zweites
System**, sondern derselbe `FishingSim.tick()`, im Schnelldurchlauf mit
einem großen Delta gefüttert (`core/offline_sim.gd`). Genau hier
sterben Idle-Spiele sonst — online und offline rechnen
unterschiedlich, und der Fehler ist nicht auffindbar. Weil der
Simulationskern keinen Node-Bezug hat, ist er außerdem in Sekunden
statt in CI-Minuten headless testbar.

## Die Regel für `core/`

Kein `extends Node`, kein `get_node`, kein `await get_tree()`. Wer dort
Zeit braucht, bekommt sie als Parameter (`tick(delta, ctx, rng)`). Das
gilt strikt für `core/` und `resources/`; Autoloads und Szenen dürfen
Nodes sein, weil sie die dünne Ansicht sind, nicht der Kern.

## Warum `tick()` deltaunabhängig ist

`FishingSim.tick()` rechnet nicht in festen Zeitschritten, sondern
segmentweise geschlossen: eine `while remaining > 0.0`-Schleife
springt bei jedem Automatenzustand direkt zum nächsten Ereignis (Ende
der Wartezeit, Ende des Kampfes) statt in kleinen Schritten zu
simulieren. Dadurch liefert ein einziger `tick(43200.0)` (12 Stunden)
dasselbe Ergebnis wie 432 000 Aufrufe von `tick(0.1)` — genau das
braucht der Offline-Fortschritt, der 12 Stunden in Millisekunden
rechnen muss. Ein `MAX_SEGMENTS`-Schutz verhindert eine Endlosschleife,
falls ein Zustand fälschlich nie Zeit verbraucht.

Der Nachweis ist `tests/test_offline_sim.gd::test_offline_equals_online`:
derselbe Zeitraum einmal als ein großes `tick()`, einmal als 18 000
kleine `tick(0.1)`-Aufrufe, verglichen auf Fänge, Entkommen, XP und
Coins.

## Die vier Autoloads

| Autoload | Zweck |
|---|---|
| `Database` | Lädt alle `.tres`-Daten beim Start, liefert sie per ID aus, prüft sie in `validate()` |
| `Game` | Hält den Spielzustand, tickt `FishingSim` per `_process()`, übersetzt Ereignisse in Signale |
| `SaveManager` | Serialisieren, Laden, Migration, Autosave, stößt `OfflineSim` beim Laden an |

Die Spezifikation sieht einen vierten Autoload `AudioManager` vor. Er
existiert in Slice 1 bewusst nicht — es gibt noch keine Audio-Assets
und keinen Code, der sie abspielen würde, ein leerer Autoload wäre nur
Ballast. Er entsteht mit dem Audio-Ausbau (siehe `TODO.md`).

## Datenfluss

```
Database (lädt .tres) → Game.new_game() baut den SimContext
    → Game._process() ruft FishingSim.tick(delta, ctx, rng)
    → tick() gibt eine Liste von Ereignis-Dictionaries zurück
    → Game._dispatch() übersetzt sie in Signale (bite, caught, escaped, level_up, ...)
    → Panels und Szenen hören auf diese Signale und zeichnen sich neu
```

`SimContext` (`core/sim_context.gd`) bündelt alles, was `FishingSim`
zum Rechnen braucht — Zone, Köder, Inventar, Journal, Spielerstand —
in einem einfachen Datenhalter ohne Node-Bezug, damit Tests ihn in
wenigen Zeilen aufbauen können.

## Warum Resources statt JSON

Alle Spieldaten (Fische, Köder, Zonen, Upgrades, Raritäten) sind
typisierte Godot-`Resource`-Klassen unter `resources/`, gespeichert als
`.tres` unter `data/`. Das ist Godots eigene Antwort auf
datengetriebenes Design: Typprüfung durch die Engine, kein
selbstgeschriebener Loader, kein JSON-Schema zum Pflegen. `Database`
lädt jeden Ordner generisch über `DirAccess` und indiziert die
Ressourcen über ihr `id`-Feld — ein neuer Fisch braucht nur eine neue
`.tres`-Datei, keinen Codeeintrag.

## Wo Zufall herkommt

Zwei getrennte Zufallsquellen, bewusst nicht vermischt:

- **`Game.rng`** (`core/still_rng.gd`, ein `StillRNG` mit
  speicherbarem Zustand über `get_state()`/`set_state()`) für jede
  Spielentscheidung: Bisszeit, Fischauswahl, Gewicht, Qualität, Shiny,
  Secret-Würfe. Der Zustand wird mit dem Spielstand gesichert, damit
  Offline-Ergebnisse reproduzierbar bleiben und sich nicht durch
  wiederholtes Laden neu würfeln lassen.
- **`randf_range()`** direkt in Szenenskripten (z. B.
  `scenes/fishing/catch_view.gd` für Orb-Positionen) für reine
  Darstellung, die kein Spielergebnis beeinflusst.

Die Trennung ist nötig, weil nur `Game.rng` deterministisch
reproduzierbar sein muss — würde eine Orb-Position denselben
Zustand verbrauchen, wäre Online- und Offline-Ergebnis bei
identischem Save nicht mehr identisch nachvollziehbar, sobald irgendwo
Darstellungscode mitgezählt hätte.

## Testaufbau

Ein `SceneTree`-Skript ohne externes Plugin
(`tests/run_tests.gd`, gestartet mit
`godot --headless --script res://tests/run_tests.gd`), lädt 16
`test_*.gd`-Suiten, die jeweils von `TestCase` (`tests/test_case.gd`)
erben. Ein Parse-Fehler in einer Testdatei zählt als Fehlschlag statt
den Prozess hängen zu lassen (`script.can_instantiate()`-Prüfung). Der
Runner beendet sich mit `quit(1 if failed > 0 else 0)` — das ist der
Exit-Code, an dem auch die CI einen roten Lauf erkennt.

Der wichtigste Test ist `test_offline_sim.gd::test_offline_equals_online`
(siehe oben) — läuft er grün, ist die Fehlerklasse ausgeschlossen, an
der Idle-Spiele üblicherweise sterben.

## Entwicklungsgerät-Besonderheit

Auf dem Entwicklungsgerät (Termux/Android, proot-Debian, Godot
4.7.2-ARM64) stürzt jeder Editor-Modus deterministisch ab — sowohl
`--editor` als auch `--headless --import` enden mit Signal 11. Das
betrifft zwei Dinge:

1. **Script-Class-Cache.** Normalerweise schreibt der Editor
   `.godot/global_script_class_cache.cfg`, ohne die kein `class_name`
   auflöst. `tools/gen_class_cache.py` erzeugt diese Datei stattdessen
   aus dem Quellcode; `tools/godot.sh` ruft es vor jedem Godot-Start
   automatisch auf. In der CI (x86_64-Container) stürzt `--headless
   --import` nicht ab, dort erzeugt Godot den Cache also ganz normal
   selbst — beide Wege laufen daher nie gegeneinander, sie sind für
   zwei verschiedene Umgebungen gebaut.
2. **PNG-Einbindung.** `[ext_resource type="Texture2D"]` und
   `load("res://assets/art/x.png")` brauchen einen `.import`-Cache,
   den nur der Editor erzeugt. Szenenskripte laden PNGs deshalb selbst
   zur Laufzeit: `Image.load_from_file(pfad)` und daraus
   `ImageTexture.create_from_image(img)` — so in
   `scenes/fishing/angler.gd`, `scenes/fishing/orb.gd`,
   `scenes/fishing/world.gd`, `scenes/ui/panels/journal_panel.gd` und
   `tests/test_sprite_assets.gd`. `.tscn`-Dateien nutzen `ext_resource`
   nur für Scripts und `PackedScene`s, nie für Texturen.
