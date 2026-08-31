# Stillwater — TODO

Nach Nähe geordnet. Was hier nicht steht und auch nicht in
`GAME_DESIGN.md` als bewusste Abweichung genannt ist, wurde schlicht
noch nicht gebaut.

## Als Nächstes

- ~~**Audio**~~ — erledigt 2026-08-30: `autoload/Audio.gd` mit Abspieler-Pool,
  Tonhöhenstreuung ±5 %, Abklingzeit je Ereignis und eigener Lautstärke für
  die Oberfläche. Elf Klänge, selbst erzeugt via `tools/gen_sounds.py`.
  Offen: Lautstärkeregler in einem Einstellungen-Menü (es gibt noch keins).
- ~~Alt:~~ **Audio** — Wasser, Wurf, Biss, Fang, Verkauf, Upgrade, Level-Up, UI.
  Dafür entsteht dann auch der vierte Autoload `AudioManager` (siehe
  `ARCHITECTURE.md`), der in Slice 1 bewusst fehlt. **Bewusst zuletzt**
  (2026-08-29): Ton ist überwiegend Materialbeschaffung mit Lizenzpflege,
  und er folgt dem Bild — vor der endgültigen Pixelart gemacht hieße ihn
  zweimal machen.
- **Hochauflösende Pixelart** (siehe unten, "Kunstrichtung"). Die
  Zonenhintergründe sind seit 2026-08-29 pro Zone austauschbar, die
  Platzhalter kommen weiter aus `tools/gen_sprites.gd`.

## Menü und Oberfläche (aus dem Cornerpond-Dossier, Abschnitt 10)

Noch nicht angefasst, aber der Grund, warum das Referenzspiel „fertig"
wirkt und unseres noch nicht. Die Mechanik steht — das hier ist die
Schicht darüber:

- ~~**Sortierung des Inventars**~~ — erledigt 2026-08-31: sechs Modi
  (Fang, Rang, Gewicht, Wert, Art, Selten) in `core/fish_sort.gd`, gemerkt
  in den Einstellungen, Kiste und Vitrine teilen sie sich.
- **Rückmeldung auf jeden Griff.** Knöpfe federn, Panels wackeln bei
  Fehlschlägen, Zahlen hüpfen. Wir haben `pop_text` und `burst`, aber
  nur im Kampf.
- **Schatten unter Text und Flächen.** Das Referenzspiel hat dafür
  eigene Varianten aller Standardelemente; ein Theme mit
  Umriss/Schatten täte dasselbe an einer Stelle.
- ~~Panels mit Titelzeile~~ — seit 2026-08-31 tragen Gruppen mit mehreren
  Unterreitern deren Leiste oben; ein Schließen-Knopf fehlt weiter (die
  Reiterleiste klappt zu, wenn man denselben Reiter noch einmal tippt).
- **Tooltips** an Zahlen, die sonst unerklärt bleiben.

## Danach

- ~~Quest-System mit erneuerbaren Aufgaben~~ — gebaut 2026-08-31
  (`core/quests.gd`, aus der Uhr abgeleitet, über den Ausbau
  „Auftragsbuch" von 3 auf 6 erweiterbar).
- ~~Consumables~~ — gebaut 2026-08-31. **Entschieden gegen die alte Idee
  „über Anzahl Fänge statt Echtzeit":** die Wirkdauer läuft in Echtzeit,
  tickt aber NUR bei offenem Spiel (`core/buffs.gd`). Damit verpufft
  nichts, während man weg ist, und die Zahl auf der Flasche bleibt
  verständlich.
- ~~Ein einziger Rückkehr-Rhythmus~~ — alles Wiederkehrende hängt an
  derselben Uhrableitung `floor(jetzt / dauer)`: Händler (1 h), Rabe
  (4 h), Aufträge (3 h), Regen (Block aus 6 h). Keine laufenden Timer.
- ~~Raritäten Epic und Legendary~~ — über die Stufenrampe erreichbar.
- ~~Weitere Zonen~~ — sieben Zonen, 105 Arten.

## Bedingungstypen für Secret-Fische

Gebaut: `LevelCondition`, `BaitCondition`, `CosmeticCondition`,
`TimeOfDayCondition`, `JournalCondition` — jeder Typ wird von mindestens
einem Geheimfisch verlangt, sonst wäre er selbst ein totes Ende
(`test_every_condition_type_is_used_by_a_secret_fish`).

Noch offen, jeweils mit Grund:

- **Fänge in dieser Zone** — braucht einen neuen, gespeicherten Zähler pro
  Zone. Machbar, aber es vergrößert die Speicherfläche; erst bauen, wenn
  ein Fisch ihn wirklich verlangt.
- ~~**Aktiver Trank**~~ — gebaut 2026-08-31 als `PotionCondition`. Sie fragt
  nach der Trank-GRUPPE, nicht nach der einzelnen Flasche, sonst lockte nur
  genau eine Stufe. Die Glasflut in der Tiefen Zisterne verlangt sie.

Nicht maschinell prüfbar: ob ein `secret_hint` das richtige Kleidungsstück
oder Zeitfenster benennt. Bei neuen Hinweisen von Hand gegenlesen.

## Kosmetik (Stand 2026-08-31)

50 Varianten in sieben Kategorien. Zwei Regeln, die nicht verhandelbar sind:

- **Echte Hauttöne kosten nichts** und sind ab Stufe 1 da — niemand zahlt
  für sein Aussehen. Bezahlt wird nur Fantasie (Moosgrün, Eisblau,
  Aschgrau) und Kleidung.
- **Der Kopfplatz trägt Hüte UND Kopfschmuck** (Hörner, Heiligenschein,
  Kopfhörer). Ein zweiter Platz hätte bei jeder Kombination eine neue
  Überdeckungsfrage aufgeworfen.

Seltene Varianten sind Fangbedingungen: der **Tanggeist** (Sunset Coast)
kommt nur zu moosgrüner Haut, der **Nimbusbarsch** (Wolkensee) nur zu
jemandem mit Heiligenschein.

## Inhalte

- ~~Willow Lake auf 12 bis 18 Arten ausbauen~~ — erledigt 2026-08-29:
  16 Arten (13 regulär + 3 Secret), darunter Wels (Epic) und
  Mondkarpfen (Legendary). Sie kommen nicht über späte Köder, sondern
  über die Stufenrampe der Rarität (`unlock_level`/`ramp_levels`): Epic
  ab Stufe 10, Legendary ab 18, volles Gewicht bei 32. Späte Köder
  wären ein zweiter Hebel für dieselbe Wirkung.
- Sunset Coast hat 8 Arten (7 regulär + 1 Secret) und darf mitwachsen.

## Technik

- Lokalisierung über Godots eingebaute CSV-Übersetzungen. Anzeigenamen
  sind aktuell fest Deutsch im Code/in den `.tres`.
- ~~Statistiken~~ — erledigt 2026-08-31: `core/records.gd` und die Seite
  „Bilanz" im Journal.
- ~~Einstellungen~~ — erledigt (Ton, Lautstärken, Köder-Rückfall).
- Release-Keystore, Paketname und Store-Eintrag fürs Veröffentlichen.

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

## Signaturschlüssel (gelöst 2026-08-30)

Die CI erzeugte den Schlüssel bei jedem Lauf neu, also hatte jede APK eine
andere Signatur und musste vor der Installation deinstalliert werden.

**Der echte Schlüssel liegt ausschließlich auf dem Gerät**, in
`~/.stillwater-release/` — nicht im Repo und **nicht bei GitHub**. Die CI
signiert nur mit einem Wegwerf-Schlüssel; nachsigniert wird lokal:

    bash tools/sign.sh build/stillwater-debug.apk --install

Das ersetzt die Signatur (v1, v2 und v3 — v1 allein reicht Android 11+ nicht)
und installiert mit `adb install -r`. Kein Deinstallieren, kein
Spielstandverlust.

Nötig dafür: `pkg install apksigner`.

**Geht `~/.stillwater-release/` verloren, lässt sich keine bestehende
Installation mehr aktualisieren** — dann hilft nur Deinstallieren. Also
mitsichern, wenn das Gerät gewechselt wird.


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
