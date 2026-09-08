# Die Figur aus Teilen — im Spiel bewegt statt gebacken

**Stand 2026-09-07.** Entwurf, noch nicht umgesetzt.

## Warum

Die Blätter, aus denen das Spiel die Anglerin zeichnet
(`assets/art/char_*.png`), stammen aus `idle_*.png` und `cast_*.png` — den
PixelLab-Bildern, die mit `b7f39e5` als Vorlage **verworfen** wurden. Über die
neun erzeugten Ruhebilder gemessen: 22 verschiedene Hauttöne im Gesicht, die
Gesichtsfläche schwankte zwischen 69 und 112 Pixeln, und in fünf von neun war
das Auge zu, ohne dass es verlangt war.

Seither entsteht die Figur anders: **eine** geprüfte Haltung
(`assets/source/figure/parts/`) wird in bewegliche Teile zerlegt und gerechnet
bewegt — Zopf, Kopf, Rumpf, Beine, zwei Arme. Das läuft bisher nur in den
Vorschauwerkzeugen (`tools/preview_parts.py`, `tools/wurf_lauf.py`), nicht im
Spiel.

Seit `56dc360` liegt auch die Farbtabelle auf diesen Teilen. `import_character.py`
liest dagegen weiter die alten Bilder, deren Farben die Tabelle nicht mehr kennt
— ein Lauf würde dort wieder raten.

## Die Entscheidung

Drei Wege standen zur Wahl. Maßstab war die Frage, **was am Ende am besten
läuft**: das Spiel ist nicht fertig, weitere Pixelart kommt dazu.

| | Pixel je Ebene | als RGBA |
|---|---|---|
| heute, 24 volle 128er Bilder | 393 216 | 1,57 MB |
| **A** — alles in GDScript rechnen | 0 | (dafür Rechenzeit je Bild) |
| **B** — Zustände als volle 128er Bilder backen | 671 744 | 2,69 MB |
| **C** — je Teil ein zugeschnittenes Blatt | **46 767** | **0,19 MB** |

**Gewählt: C.** Der Zopf ist 19×33 Pixel groß; ihn als volles 128×128-Bild zu
backen verschenkt das Sechzehnfache. Zur Laufzeit tun B und C beide fast
nichts — Bild und Position setzen, zehnmal die Sekunde. C hat mehr Sprites
(etwa 15 statt 6), was bei 2D nicht ins Gewicht fällt; Texturspeicher schon.

**A ist ausgeschieden**, weil die Pixellogik dann zweimal vorläge: in Python für
die Vorschau, in GDScript fürs Spiel. Genau davor warnt der Kopf von
`core/angler_pose.gd` — dort stand die Rutenspitze doppelt, und beim Verschieben
wurde die Konstante nicht mitgezogen.

## Die Teile und ihre Zustände

| Teil | Rahmen | Zustände | woher |
|---|---|---|---|
| Zopf | 21×33 | 11 | Paare aus Scherung und Kopfversatz, die der Ablauf erreicht |
| Kopf | 25×28 | 2 | Atem: 0 oder 1 Pixel tiefer |
| Hals | 6×4 | 2 | gehört zum Kopf, wird aber hinter dem Kragen gezeichnet |
| Rumpf | 45×59 | 1 | steht still |
| Beine | 37×36 | 13 | Scherung −6…+6 am Knie |
| Arm nah | 38×42 | 11 | Ruhe + zehn Wurfbilder |
| Arm fern | 7×19 | 1 | steht still |
| Auge | 4×3 | 3 | offen, halb, zu |

Die Rahmen sind am 2026-09-07 von `tools/teile_bauen.py` gemessen worden und
weichen von der ersten Schätzung ab. Der Wurfarm greift weiter aus als der
ruhende — geschätzt war nur `sit3_arm_nah` —, der Zopf reicht durch den
Schwung bis +5 weiter nach rechts, und die Beine brauchen weniger Luft als
angenommen. Die Summe steigt dadurch von 42 254 auf 46 767 Pixel je Ebene.

Der Atemzug hat 32 Schritte, aber nur **acht verschiedene** Atem/Zopf-Zustände
— Atem und Zopf hängen an derselben Phase. Die dreizehn Beinausschläge decken
auch den Wurf ab (`BEIN_WURF` bringt keinen neuen Wert).

**Korrektur vom 2026-09-07, beim Umsetzen gemessen:** der Zopf schwingt im
Ruhelauf ±2, im **Wurf aber bis +5** (`wurf_lauf.zopf_im_wurf`). Und er hängt
nicht nur an seiner eigenen Weite, sondern auch am Kopfversatz — siehe den
nächsten Abschnitt. Der Ablauf erreicht davon elf Paare; die sind die
Zustände des Zopfblatts.

Das **Auge** ist kein eigener Zustand des Kopfes, sondern eine Auflage von neun
bzw. sieben Pixeln (`figure_parts.AUGE_HALB`, `AUGE_ZU`). Es liegt seit
`56dc360` in der Grundebene und wird nie umgefärbt, braucht also keine
Varianten: **ein** Blatt mit drei Bildern, das mit dem Kopfversatz mitgeht.

## Was sich stapelt und was nicht

Die Vorschau setzte die Teile nicht einfach übereinander, sie füllte zweimal
Lücken. Beim Umsetzen ist beides gemessen worden, und der Befund fiel anders
aus als hier zuerst angenommen.

**Der Zopf braucht keine Unterlage.** 73 Stellen gibt er frei, an denen er
frei hängt — dort ist Hintergrund, und die Lücke ist richtig. Die übrigen 17
füllte die Vorschau mit dem Ton des Kopfhaars; von ihnen liegen aber **16 gar
nicht auf Kopfpixeln**, der Kopf schließt nur rechts an. Die Füllung erfand
dort Haar und machte den Hinterkopf breiter, als er gezeichnet ist. Sie ist
mit `ef437fb` entfallen.

**Aber die Naht muss zu.** Zwischen Zopf und Kopf bleibt beim Schwenken
stellenweise eine Zeile leer: links der Kopf, rechts der Zopf, dazwischen
nichts. Über die Zustände, die der Ablauf wirklich erreicht, sind das **acht
Stellen**. Auf dem dunklen Vorschaugrund sieht man sie nicht; im Spiel liegt
dort der See, und es blitzt hell durch.

Feste Unterlagepixel lösen das **nicht**: an fünf der acht Stellen liegt im
Ruhezustand gar nichts, ein Unterlagepixel machte die Figur dort im Stand
einen Pixel größer. Und der Zopf allein reißt bei keiner seiner Weiten —
gemessen über alle acht. Es ist eine Naht zwischen zwei Teilen, keine Lücke
in einem.

Deshalb die Unterscheidung (`b775c3b`): **was zum Rand hin offen ist, bleibt
offen; was ringsum zugedeckt ist, wird geschlossen.** Alle acht Stellen
bekommen `#05000a`, den Umrisston — nicht gesetzt, sondern aus ihren vier
Nachbarn gemessen. Die Naht zwischen Zopf und Kopf ist Umriss.

`preview_parts` trennt dafür in `roh_zusammensetzen()` (legt übereinander,
malt nichts dazu), `naht()` (findet die eingeschlossenen Lücken) und
`zusammensetzen()` (beides). Das Bauwerkzeug braucht die Trennung, weil es
die Naht **in die Zopfbilder backen** muss: im Spiel gibt es niemanden, der
sie zur Laufzeit schließt.

**Daraus folgt der Zuschnitt des Zopfblatts.** Weil die Naht vom Kopfversatz
abhängt, ist der Zustand des Zopfs das Paar aus Weite und Versatz. Der Ablauf
erreicht elf davon.

**`RUMPF_UNTERLAGE` bleibt bei einem Eintrag.** Die drei zusätzlichen, die
hier zuerst vorgesehen waren, wurden nie gebraucht — sie waren die Antwort
auf die falsche Frage.

**Folge für die Optik:** ohne die Zopffüllung ist der Hinterkopf an dieser
Kante um bis zu vier Pixel schmaler. Am 2026-09-07 vorgelegt und angenommen.

## Varianten als Tönung statt als Blätter

`assets/art/palette_swap.gdshader` rechnet `tint * (0.55 + 0.9 * luma)`.
`tools/import_character.py::recolor` rechnet `ziel * (0.55 + 0.9 * lum/255)`.
**Dieselbe Formel.** Die neun Haut-, neun Pullover- und sechs Hosenblätter sind
also vorgebackene Kopien derselben Pixel.

→ Je Teil und Ebene entsteht **ein** Blatt; die Variante wird zum
Shader-Parameter, wie die Haarfarbe es heute schon ist. Variante 0 („wie
gezeichnet") ist `strength = 0`.

Das senkt die Zahl der Dateien von rund hundert auf etwa achtzehn und den
Texturspeicher noch einmal um den Faktor der Variantenzahl. Die Farbwerte
(`SKIN_TONES`, `SHIRT_TONES`, `PANTS_TONES`) mussten gar nicht in die Palette
wandern — nachgeschlagen am 2026-09-08 steht **jeder einzelne Ton dort schon
unter einem Namen**: `skin_0..4`, `skin_moss`, `skin_ice`, `skin_ash`,
`skin_white` und die Stoffnamen `cloth_*`, `leather`, `oilskin`, `denim`,
`wood_dark`. Nachgeschlagen statt wiederholt.

## Die Blätter

Ein Blatt je **Teil und Kosmetikebene**, Bildgröße gleich dem Rahmen des Teils:

Sie heißen `teil_<teil>_<ebene>.png` und nicht `char_…`: die `char_*` sind die
alten Bilderreihen im festen 128er Raster, und `tests/test_sprite_assets.gd`
prüft sie als solche. Zwei verschiedene Dinge, zwei Namen.

Gemessen vom Bauwerkzeug, nicht getippt — Rahmen, Anker im Figurenfeld und
Zahl der Zustände:

```
Teil      Rahmen   Anker   Zustände   Ebenen
zopf      21x33    34,5      14       hair base
beine     37x36    64,87     13       skin boots base
hals       6x4     54,28      2       skin base
rumpf     45x59    44,30      1       skin shirt pants base
kopf      25x28    47,5       2       skin hair base
auge       4x3     63,20      3       skin hair base    (offen, halb, zu)
armfern    7x19    67,51      1       skin shirt base
arm       38x42    45,36     11       skin shirt base
```

Die Stiefel liegen in ihrer **eigenen** Ebene `boots`, nicht in der Hose — die
Farbtabelle trennt sie am unteren Bandrand.

Das Bauwerkzeug schreibt diese Tabelle als `assets/art/teile.json` neben die
Blätter. Der Sprite-Test prüft die Bildgrößen gegen sie, und Stufe 3 setzt die
Teile mit `x,y` wieder an ihren Platz im 128er Feld. Damit steht der Anker an
genau einer Stelle statt zweimal abgetippt.

## Kosmetik als Tönung

Haut, Pullover, Hose und Haarfarbe haben kein eigenes Bild je Variante: sie
färben eine Ebene der Teileblätter mit `assets/art/palette_swap.gdshader` ein.
Die Töne stehen als Namen in `core/palette.gd`, die Zuordnung Kategorie → Töne
in `scenes/fishing/angler.gd::TINTS`, die Zuordnung Kategorie → Ebene in
`TINT_LAYER`.

**Variante 0 wird bei Haut, Pullover und Hose nicht getönt** — sie ist die
gezeichnete Farbe. Die Haarfarbe kennt diese Ausnahme nicht: es gibt keine
gezeichnete Haarfarbe, die man behalten wollte.

**Die Stiefel bleiben außen vor.** Sie sind eine eigene Ebene. Im alten
Backweg kopierte `import_character.py` sie ungetönt über die gefärbte Hose;
jetzt ergibt sich dasselbe von selbst.

**Nachgerechnet gegen die gebackenen Blätter** (2026-09-08, gegen `f0cae5e~1`):
der Shader rechnet `Ton · (0,55 + 0,9 · Helligkeit)` — genau die Formel, mit
der die Blätter entstanden sind.

| | Pixel gleich | daneben |
|---|---|---|
| `skin` Variante 3 | 11 315 | 0 |
| `skin` Variante 8 | 11 315 | 0 |
| `shirt` Variante 1 | 20 017 | 0 |
| `pants` Variante 4 | 8 069 | 11 157 (die Stiefel) |

Die Rechnung muss abschneiden, nicht runden; mit `round()` weichen die Werte
um bis zu eins je Kanal ab. Die Grafikkarte rundet — ein 255stel, unsichtbar.

## Die Szene

`scenes/fishing/angler.tscn` bekommt eine Ebene mehr Struktur: statt sechs
Sprites für sechs Kosmetikebenen gibt es je Teil eine Gruppe, in ihr je Ebene
ein Sprite. Zeichenreihenfolge, aus `preview_parts.zusammensetzen` übernommen:

```
Zopf, Beine, Hals, Rumpf, Kopf, Auge, Arm fern, Rute, Arm nah, Hut
```

Der Kopf liegt **oben**: lag der Rumpf oben, fraß sein Schulterumriss beim
Absenken die Kinnzeile. Ausgenommen ist der Hals, der hinter den Kragen gehört.

Die **Rute liegt hinter dem nahen Arm** — die Faust hält sie, also gehört die
Hand davor. Hier stand sie zuerst zuletzt; gemessen gegen `tools/wurf_lauf.py`
wichen dadurch über die zehn Wurfbilder 13 Pixel ab, alle an der Faust
(korrigiert 2026-09-08).

Innerhalb eines Teils bleibt die bisherige Reihenfolge: Haut, Hose, Pullover,
Haar, Grundebene. Die Grundebene liegt über der Kleidung, weil sie Umriss,
Auge und Kragen trägt (`56dc360`).

Der **Hut** hängt an der Kopfgruppe und geht mit dem Atem mit; die gemessenen
Kopfmitten je Bild in `gen_sprites.gd` entfallen.

Die **Rute** bleibt ein eigenes Sprite mit eigenem, größerem Raster. Ihr Griff
sitzt an der Hand, also an der Armgruppe: `ROD_ANCHOR` schrumpft von 24
Einträgen auf 11 (Ruhe plus zehn Wurfbilder).

## Die Bewegung

`angler.gd` besitzt die Uhr schon heute (`IDLE_FPS`, `BLINK_MIN`/`BLINK_MAX`,
Wurf aus `Game.sim.timer`). Neu ist nur, **was** gesetzt wird:

- **Atem und Zopf** aus der Phase des Atemzugs: `atem = sin(2πt) < 0`,
  `zopf = round(2 sin(2π(t − 0.12)))`. Dieselben Formeln wie in
  `preview_parts.ablauf()`.
- **Beine**: `round(weite · sin(2πi / 24 − 0.6))`. Die **Weite wird im
  Umkehrpunkt neu gezogen** aus 2…6 — mittendrin spränge das Bein. Das ist der
  Grund, warum im Spiel gerechnet und nicht gebacken wird.
- **Blinzeln**: halb, zu, halb — 55, 90, 55 ms. Die Auflage wechselt, der Kopf
  bleibt stehen.
- **Wurf**: die zehn Armbilder über `FishingSim.CAST_TIME`, Kopf bis zu zwei
  Pixel zurück (`kopf_im_wurf`), Beine nach `BEIN_WURF`, Halt bei Bild 4.
- **Die Rute atmet mit** (entschieden 2026-09-07). Der Arm hat im Ruhelauf nur
  einen Zustand, die Faust steht also still; die Rute bekommt deshalb einen
  eigenen kleinen Versatz aus derselben Atemphase, nicht aus der Hand. Ein
  Pixel ist der Startwert — bei mehr rutscht sie sichtbar aus der Faust, bei
  weniger sieht man nichts. Der endgültige Wert wird in der Vorschau
  abgenommen, nicht hier festgelegt. Weil die Spitze 63 Pixel entfernt liegt,
  wird aus einem Pixel am Griff eine deutlich sichtbare Bewegung am Ende.

Die Formeln stehen dann an zwei Stellen — Python für die Vorschau, GDScript
fürs Spiel. Das ist bewusst in Kauf genommen: es sind fünf Zeilen Arithmetik
ohne Pixelzugriff, und ein Test vergleicht beide Reihen gegeneinander.

## Was wegfällt

- `tools/import_character.py` in seiner heutigen Form — es liest die
  verworfenen Bilder. Ersetzt durch ein Werkzeug, das die Teileblätter baut.
- `preview_parts._luecken_schliessen()` und die Zopffüllung.
- `char_skin_1..8`, `char_shirt_1..8`, `char_pants_1..5` — Varianten werden
  getönt statt gebacken.
- Die gemessenen Kopfmitten je Bild in `gen_sprites.gd`.

## Prüfungen

- **Kein Loch:** über alle Kombinationen aus Atem, Zopf, Bein, Kopfversatz und
  Augenstellung darf keine ringsum zugedeckte Stelle frei bleiben. Das ist die
  Prüfung, die die vier Unterlagepixel gefunden hat.
- **Kein Pixel doppelt:** die Ebenen eines Teils überschneiden sich nicht
  (`test_character_layers.gd` prüft das heute für die ganze Figur).
- **Vorschau und Spiel stimmen überein:** die Zahlenreihen für Atem, Zopf und
  Bein werden in Python und GDScript gegeneinander gehalten.
- **Anker:** jedes Teilblatt sitzt an der Stelle, an der das Bauwerkzeug es
  gemessen hat; zusammengesetzt ergibt sich Pixel für Pixel dasselbe Bild wie
  in der Vorschau.
- `tests/test_sprite_assets.gd` prüft feste Maße und muss mitwachsen.

## Ausdrücklich später

Entschieden am 2026-09-07: das hier gehört nicht in diesen Umbau.

- **Hüte und Kopfschmuck** bleiben die gemalten Klötze aus `gen_sprites.gd`.
  Der Umbau ändert nur, woran sie hängen — an der Kopfgruppe, damit sie
  mitatmen —, nicht wie sie aussehen.
- **Die fünf Frisuren** bleiben dieselbe Zeichnung. Solange das so ist, genügt
  je ein Zopf- und ein Kopfhaarblatt. Eine zweite Frisur ist eine zweite
  Zeichnung, keine Umfärbung.

## Reihenfolge der Umsetzung

Der Entwurf trägt mehr, als in einem Zug sinnvoll ist. Der Plan zerlegt ihn in
Stufen, jede für sich lauffähig und prüfbar:

1. **Unterlagen und Füllungen** — die vier Pixel in `RUMPF_UNTERLAGE`, die
   Zopffüllung raus, `_luecken_schliessen()` raus, Lochprüfung als Test. Danach
   stapeln sich die Teile, und die Vorschau sieht schon so aus wie das spätere
   Spiel.
2. **Das Bauwerkzeug** — die Teileblätter samt Ankern erzeugen, an Stelle von
   `import_character.py`. Prüfung: zusammengesetzt Pixel für Pixel wie die
   Vorschau.
3. **Szene und Bewegung** — Sprites je Teil, `angler.gd` setzt Bilder und
   Versätze, `angler_pose.gd` schrumpft auf die neuen Anker.
4. **Varianten als Tönung** — erst danach, weil es die Kosmetikdaten berührt
   und ohne die ersten drei Stufen nichts verbessert.

Stufe 4 ist abtrennbar: bricht sie ab, bleiben die Blätter gebacken wie heute,
und alles andere läuft trotzdem.
