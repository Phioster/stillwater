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
| **C** — je Teil ein zugeschnittenes Blatt | **41 047** | **0,16 MB** |

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
| Zopf | 19×33 | 5 | Scherung −2…+2 am Haargummi |
| Kopf | 25×28 | 2 | Atem: 0 oder 1 Pixel tiefer |
| Rumpf | 45×59 | 1 | steht still |
| Beine | 39×36 | 13 | Scherung −6…+6 am Knie |
| Arm nah | 32×36 | 11 | Ruhe + zehn Wurfbilder |
| Arm fern | 7×19 | 1 | steht still |

Der Atemzug hat 32 Schritte, aber nur **acht verschiedene** Atem/Zopf-Zustände
— Atem und Zopf hängen an derselben Phase. Die dreizehn Beinausschläge decken
auch den Wurf ab (`BEIN_WURF` bringt keinen neuen Wert).

Das **Auge** ist kein eigener Zustand des Kopfes, sondern eine Auflage von neun
bzw. sieben Pixeln (`figure_parts.AUGE_HALB`, `AUGE_ZU`). Es liegt seit
`56dc360` in der Grundebene und wird nie umgefärbt, braucht also keine
Varianten: **ein** Blatt mit drei Bildern, das mit dem Kopfversatz mitgeht.

## Was sich stapelt und was nicht

Die Vorschau setzt heute nicht einfach übereinander, sie füllt zweimal Lücken.
Nachgemessen über alle acht Atem/Zopf-Zustände:

**Der Zopf braucht keine Unterlage.** 73 Stellen gibt er frei, an denen er frei
hängt — dort ist Hintergrund, und die Lücke ist richtig. Die übrigen 17 füllt
die Vorschau mit dem Ton des Kopfhaars; von ihnen liegen aber **16 gar nicht
auf Kopfpixeln**, der Kopf schließt nur rechts an. Die Füllung erfindet dort
Haar und macht den Hinterkopf breiter, als er gezeichnet ist. Die eine Ausnahme
(47/16) übermalt der Kopf ohnehin.

→ Die Füllung entfällt. Der Zopf stapelt sich sauber.

**Der Hals braucht vier Unterlagepixel.** Über alle Kopfversätze (−2…+2, mehr
macht `kopf_im_wurf` nicht) bleiben genau drei Stellen, die ringsum zugedeckt
sind und trotzdem frei würden: **49/23**, **55/30**, **57/31**, alle bei Kopf
+1 / Atem 0. Dazu die schon bekannte **60/32**.

→ `figure_parts.RUMPF_UNTERLAGE` wächst von einem auf vier Einträge.
→ `preview_parts._luecken_schliessen()` entfällt — ein Suchlauf über 16 000
Pixel je Bild wird zu vier benannten Konstanten.

**Folge für die Optik:** ohne die Zopffüllung wird der Hinterkopf an dieser
Kante um bis zu vier Pixel schmaler. Vorher/Nachher wird vorgelegt; gefällt es
nicht, ist die Füllung eine Zeile.

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
(`SKIN_TONES`, `SHIRT_TONES`, `PANTS_TONES`) wandern aus dem Bauwerkzeug in die
Palette, wo die Haartöne schon liegen.

## Die Blätter

Ein Blatt je **Teil und Kosmetikebene**, Bildgröße gleich dem Rahmen des Teils:

```
char_zopf_hair.png     19x33,  5 Bilder
char_zopf_base.png     19x33,  5
char_kopf_skin.png     25x28,  2
char_kopf_hair.png     25x28,  2
char_kopf_base.png     25x28,  2
char_rumpf_skin.png    45x59,  1
char_rumpf_shirt.png   45x59,  1
char_rumpf_pants.png   45x59,  1
char_rumpf_base.png    45x59,  1
char_beine_skin.png    39x36, 13
char_beine_pants.png   39x36, 13    (Stiefel liegen in der Hosenebene)
char_beine_base.png    39x36, 13
char_arm_skin.png      32x36, 11
char_arm_shirt.png     32x36, 11
char_arm_base.png      32x36, 11
char_armfern_*.png      7x19,  1
char_auge_base.png      4x3,   3    (offen, halb, zu)
```

Jedes Blatt trägt seinen **Ankerpunkt** im Figurenfeld — die Stelle, an der es
im 128er Raster sitzt. Die Anker gehören zu `AnglerPose`, gemessen vom
Bauwerkzeug, nicht getippt.

## Die Szene

`scenes/fishing/angler.tscn` bekommt eine Ebene mehr Struktur: statt sechs
Sprites für sechs Kosmetikebenen gibt es je Teil eine Gruppe, in ihr je Ebene
ein Sprite. Zeichenreihenfolge, aus `preview_parts.zusammensetzen` übernommen:

```
Zopf, Beine, Hals, Rumpf, Kopf, Auge, Arm fern, Arm nah, Hut, Rute
```

Der Kopf liegt **oben**: lag der Rumpf oben, fraß sein Schulterumriss beim
Absenken die Kinnzeile. Ausgenommen ist der Hals, der hinter den Kragen gehört.

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

## Offene Punkte

- **Die Rute im Ruhelauf** hängt heute an einem festen Winkel für alle achtzehn
  Ruheposen. Ob sie mit der Hand mitatmen soll, ist nicht entschieden.
- **Der Hut** ist weiter ein gemalter Klotz aus `gen_sprites.gd` auf einer
  gezeichneten Figur. Der Umbau ändert nur, woran er hängt, nicht wie er
  aussieht.
- **Die fünf Frisuren sind dieselbe Zeichnung.** Solange das so ist, genügt ein
  Zopf- und ein Kopfhaarblatt.

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
