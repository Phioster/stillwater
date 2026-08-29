# Stillwater — TODO

Nach Nähe geordnet. Was hier nicht steht und auch nicht in
`GAME_DESIGN.md` als bewusste Abweichung genannt ist, wurde schlicht
noch nicht gebaut.

## Als Nächstes

- **Audio** — Wasser, Wurf, Biss, Fang, Verkauf, Upgrade, Level-Up, UI.
  Dafür entsteht dann auch der vierte Autoload `AudioManager` (siehe
  `ARCHITECTURE.md`), der in Slice 1 bewusst fehlt.
- **Echte Hintergrundgrafik für Sunset Coast.** Die Zone nutzt aktuell
  denselben Hintergrund wie Willow Lake (siehe `GAME_DESIGN.md`).
- **Fisch-Level über Mini-Quests.** `fish_level` wird bereits
  gespeichert, angezeigt und fließt in die Shiny-Formel ein, wird in
  Slice 1 aber nie erhöht.

## Danach

- Quest-System mit erneuerbaren Aufgaben.
- Consumables — **über Anzahl Fänge statt Echtzeit** („nächste 50
  Fänge" statt „nächste 15 Minuten"). Ein zeitbasierter Buff auf einem
  Handy verpufft, während der Spieler weg ist.
- Ein einziger Rückkehr-Rhythmus statt mehrerer Echtzeituhren (nicht
  drei parallele Timer wie im Referenzspiel).
- Raritäten Epic und Legendary (in der Spec bereits mit Werten
  hinterlegt, in Slice 1 aber ungenutzt).
- Weitere Zonen.

## Bedingungstypen für Secret-Fische

Slice 1 kennt `BaitCondition` und `LevelCondition`. Vorgesehen und noch
nicht gebaut:

- Aussehen (Cosmetics)
- Tageszeit
- Fänge in dieser Zone
- Journal-Fortschritt
- aktiver Trank

## Inhalte

- Willow Lake auf 12 bis 18 Arten ausbauen (aktuell 5 regulär + 1
  Secret), davon späte Epic- und Legendary-Fische, die erst mit
  späten Ködern anbeißen — sonst wird die Startzone zu totem Inhalt,
  sobald Sunset Coast freigeschaltet ist.

## Technik

- Lokalisierung über Godots eingebaute CSV-Übersetzungen. Anzeigenamen
  sind aktuell fest Deutsch im Code/in den `.tres`.
- Release-Keystore über GitHub-Secrets. `build.yml` erzeugt aktuell nur
  einen Debug-Keystore zur Laufzeit (siehe unten, "Bekannte Punkte").
- Statistiken.
- Einstellungen.

## Bekannte Punkte (geparkt, keine Bugs)

- **`SaveManager._defaults()` dupliziert die Standardwerte aus
  `Game.new_game()`.** Beide Stellen listen z. B. `coins: 0`,
  `unlocked_zones: ["willow_lake"]` und die Upgrade-Startwerte separat.
  Ändert sich ein Startwert, muss er an beiden Stellen gepflegt werden.
  Bekannt, noch nicht zusammengeführt.
- **Der Fisch-Farb-Hash im Sprite-Generator ist über Godot-Versionen
  nicht stabil.** `tools/gen_sprites.gd` leitet die Farbe jeder Art
  deterministisch aus `String(fish.id).hash()` ab — Godots
  `String.hash()` ist keine über Engine-Versionen garantiert stabile
  Funktion. Unkritisch, weil die erzeugten PNGs unter `assets/art/`
  committet sind und zur Laufzeit nie neu erzeugt werden; ein
  `gen_sprites.gd`-Lauf unter einer anderen Godot-Version könnte aber
  andere Fischfarben liefern als die bereits committeten Bilder.

## Balance-Entscheidung: Rare-Fische zu Beginn nicht landbar

Rare-Fische (Stärke 236–394) und der Secret-Fisch sind mit der Startausrüstung
rechnerisch nicht zu landen: im 20-Sekunden-Kampffenster sind mit Rod Power 4/s
und Orb Power 6/Tap maximal rund 218 Schaden möglich.

Das ist **bewusst so** und kein Fehler. Ein Biss auf einen Rare-Fisch endet zu
Beginn garantiert mit Entkommen — der Spieler sieht, dass es dort etwas gibt,
das er noch nicht schafft, und die ersten Upgrades machen es erreichbar.

Der Code folgt der Spec exakt. Die Spec selbst ist an dieser Stelle nicht
widerspruchsfrei (§6.7 gegen §6.3/§6.8/§10); maßgeblich ist diese Entscheidung.
Falls sich das im Spiel schlecht anfühlt, ist der kleinste Eingriff eine
Senkung der `strength`-Werte in `data/fish/*.tres` — eine Datenänderung ohne
Code.

## CI: Debug-Keystore wird bei jedem Lauf neu erzeugt

`.github/workflows/build.yml` erzeugt den Debug-Keystore per `keytool` bei
jedem Lauf frisch. Dadurch hat jede APK eine andere Signatur, und ein Update
über eine bereits installierte Version schlägt fehl:

    INSTALL_FAILED_UPDATE_INCOMPATIBLE: signatures do not match

In der Praxis heißt das: vor jeder Installation muss deinstalliert werden.
Der Spielstand lässt sich dabei aber mitnehmen — die App ist debuggable, also
greift `run-as` ohne Root:

    adb shell "run-as org.phioster.stillwater cat files/save.json" > save.json
    adb uninstall org.phioster.stillwater && adb install stillwater-debug.apk
    adb push save.json /data/local/tmp/sw_save.json
    adb shell "run-as org.phioster.stillwater sh -c \
      'mkdir -p files && cp /data/local/tmp/sw_save.json files/save.json'"

`cp` unter `run-as` legt die Datei gleich der neuen App-UID an; `adb push`
direkt nach `files/` ginge nicht.

Lösung, wenn es stört: einen festen Debug-Keystore einmal lokal erzeugen, ihn
als GitHub-Secret hinterlegen (base64) und im Workflow daraus wiederherstellen.
Der Keystore selbst gehört **nicht** ins Repo.

## Kunstrichtung: hochauflösende Pixelart, weibliche Figur

**Entschieden (2026-08-27):** Die endgültige Grafik soll **hochauflösende
Pixelart** werden — in der Machart von *Dead Cells*, also viele Bildpunkte pro
Figur, weiche Schattierung und flüssige Animation. **Nicht** die grobe
Low-Res-Optik der Platzhalter. Die Spielfigur ist **weiblich**.

Die aktuellen Sprites sind ausdrücklich Platzhalter aus `tools/gen_sprites.gd`
(32×32 je Frame, vierfach vergrößert).

**Was der Code dafür schon mitbringt:**
- Die Figur besteht aus getrennten Ebenen (Haut, Hose, Oberteil, Haare, Hut,
  Rute). Neue Kunst tauscht Texturen, ohne dass Logik sich ändert.
- Der Palettentausch-Shader färbt Haare über einen Farbwert statt über eigene
  Bilder — bei mehr Farbtiefe bleibt das nutzbar.
- Alle Positionen werden aus der Weltgröße und benannten Konstanten gerechnet,
  nicht fest eingetragen.
- Kosmetik liegt als Daten vor: mehr Varianten heißen mehr `.tres`, kein Code.

**Was beim Wechsel angefasst werden muss** (in `scenes/fishing/world.gd`,
sofern die Bildgrößen sich ändern):
- `PIXEL_SCALE` (jetzt 4) — bei hochauflösender Kunst vermutlich 1 oder 2.
- `CHAR_SIZE` (32) und `CHAR_FEET` (30) — die Zeile, auf der die Füße stehen.
- `ROD_TIP` (Frame-Pixel 31, 6) — der Punkt, an dem die Schnur ansetzt.
- `WATERLINE` (84/180) — die Wasserlinie im Hintergrundbild.
- `tools/gen_sprites.gd` wird dann überflüssig oder erzeugt nur noch
  Ersatzbilder für fehlende Kunst.
- `textures/canvas_textures/default_texture_filter` steht auf Nearest; das ist
  für Pixelart weiterhin richtig, auch bei höherer Auflösung.

Die Sprite-Prüfung in `tests/test_sprite_assets.gd` prüft feste Maße — sie
muss beim Wechsel mit angepasst werden, sonst wird sie zur Bremse.
