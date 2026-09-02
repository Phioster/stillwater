# Die Figur kommt aus PixelLab

Stand 2026-09-02. Ersetzt den Weg, auf dem die Anglerin bisher entstand.

## Warum

Die Figur ist keine Pixelart. `assets/source/angler_cast_1.png` ist ein
gemaltes Bild mit 1024x1536 Punkten, 31.929 Farben und durchgehend weichem
Alpha; `prepare()` rechnet es per LANCZOS auf 256 herunter. Aus Distanz wirkt
das Ergebnis wie Pixelart, die Kanten sind aber Mischfarben.

Die Ebenen sind daraus geraten, nicht gemessen. `classify()` ordnet jede
Palettenfarbe dem Koerperteil zu, in dessen Bildzeilen sie mehrheitlich
liegt -- ab 55 Prozent gilt die Farbe als vergeben, die restlichen 45 Prozent
wandern als Dreck mit. Nachgemessen an Bild 0:

    base    98.199 Pixel   <- wird per Definition NIE umgefaerbt
    hair    51.578 Pixel   <- enthaelt Haare UND Rock UND Beine
    shirt   41.867 Pixel   <- Pullover, halber Stiefel, Gesichtsreste
    skin    19.709 Pixel
    pants   12.944 Pixel   <- ein Stiefel und Streupixel, der Rock fehlt

Fast die halbe Figur liegt in der Ebene, die niemand anfassen darf. Das ist
kein Fehler im Code, sondern die Grenze des Verfahrens: aus einem flachen
Bild laesst sich nicht zurueckrechnen, was beim Zeichnen nie getrennt war.

Der Grund dafuer war die ganze Zeit derselbe: PixelLab wurde als
Bildgenerator benutzt und die Pixelart-Arbeit -- freistellen, verkleinern,
quantisieren, zerlegen -- selbst in Python gemacht. Das Charakter-System,
das genau dafuer da ist, hat das Konto noch nie angefasst (0 Charaktere bei
89 verbrauchten Generierungen).

## Der Gegenentwurf

Nicht ein fertiges Bild zerlegen, sondern nie vermischen.

1. EINE Figur als PixelLab-Charakter, in Schluesselfarben.
2. Jedes Outfit ist ein Zustand DIESER Figur -- gleiche Identitaet, gleicher
   Koerperbau, gleiche Palette.
3. Getrennt wird per Farbtabelle, nicht per Mehrheit.
4. Zusammengesetzt wird nur noch, was heute schon sauber laeuft: Frisur, Hut
   und Rute als Anker-Sprites ueber der Figur.

## 1. Die Schluesselfigur

`create_character`, `mode: "v3"`, `view: "side"`, `size: 128`.
Kosten 2-9 Generierungen je Versuch -- billig genug, um den Look mehrfach
neu zu wuerfeln, statt einen schlechten zu behalten.

Die Beschreibung nennt die Farben ausdruecklich. Sie sind so gewaehlt, dass
kein Teil dem anderen nahekommt:

| Teil      | Schluesselfarbe        | warum die                                  |
|-----------|------------------------|--------------------------------------------|
| Haut      | helles Pfirsich        | hell und blass, kollidiert mit nichts Gesaettigtem |
| Haar      | hellblond, fast weiss  | heller als alles andere im Bild            |
| Oberteil  | kraeftiges Blau        | Farbton ~220 Grad                          |
| Hose/Rock | kraeftiges Gruen       | ~120 Grad, genau dazwischen                |
| Stiefel   | kraeftiges Rot         | eigene Ebene -- heute stecken sie in der Hose |
| Umriss    | fast schwarz           | wird nie umgefaerbt, wie bisher            |

Pfirsich und Rot liegen im Farbton nah beieinander; getrennt werden sie
ueber Saettigung und Helligkeit, nicht ueber den Farbton allein.

Die Figur wird abgenommen, bevor irgendetwas darauf aufbaut: sitzen die
sechs Schluesselfarben sauber getrennt im Bild, oder hat das Modell Haut und
Stiefel ineinander geschoben? Erst wenn das stimmt, geht es weiter.

## 2. Trennen ist Nachschlagen

Die Ebenen fallen aus der Farbtabelle: ein Pixel gehoert zur Haut, weil er
eine Hautfarbe traegt. Keine Schwelle, keine Zonen, kein Votum.

Das haelt auch, wenn die Bilder NICHT pixelgenau uebereinander liegen -- und
das ist der Grund fuer die Schluesselfarben. `create_character_state`
verspricht Identitaet und Proportionen, aber keine Pixelgleichheit; nur
`inpaint_image` friert das Aussenherum ein. Eine Differenz zweier Bilder
waere also unsicher. Eine Farbtabelle braucht keine Ausrichtung.

Haut und Haar bleiben dadurch frei einstellbar, auch wenn die Figur schon
ein Outfit traegt.

## 3. Kleidung

Jedes Outfit ist ein `create_character_state` derselben Figur:
`use_color_palette_from_reference` an, damit Haut- und Haarschluessel
durchgereicht werden. ~20-40 Generierungen.

Es kommt als vollstaendige Figur zurueck, nicht als Ebene. Genau das ist der
Gewinn: die Kleidung muss nicht mehr herausgeloest werden, sie ist von
vornherein ein eigenes Blatt.

Aus diesem Blatt werden nur noch Haut und Haar herausgezogen -- per
Farbtabelle, exakt. Uebrig bleibt Kleidung samt Umriss. Drei Ebenen statt
fuenf, und alle drei stammen aus DEMSELBEN Bild, liegen also deckungsgleich
uebereinander. Das Spiel setzt zusammen: Kleidungsblatt (waehlt das Outfit),
Hautebene (waehlt den Hautton), Haarebene (waehlt die Haarfarbe). Ein
Outfit-Blatt mal neun Hauttoene sind neun Faerbungen einer Ebene, nicht neun
Blaetter.

Kombinierbar bleibt, was oben aufsitzt: Frisur, Hut, Rute. Die werden wie
heute an gemessenen Ankern gefuehrt (`ROD_ANCHOR`), und der Kopfversatz
zwischen zwei Bildern wird gemessen, nicht angenommen -- `head_shift()` in
`tools/import_character.py` kann das bereits und wird uebernommen.

## 4. Bewegung

- **Atemzug**: Template `breathing-idle`, 1 Generierung pro Richtung, und
  gebraucht wird nur eine.
- **Wurf**: `mode: "v3"` mit `action_description`, bei 128 Pixeln rund 2
  Generierungen.
- **Blinzeln**: bleibt wie es ist. `blink_series()` verpflanzt nur das
  Augenfenster und kostet null Generierungen.

Faellt der Atemzug aus dem Template auf einer Seitenansicht schlecht aus,
ist der Rueckfallweg v3 mit `custom_start_frame` und `end_frame`: zwei Posen
hinein, die Zwischenbilder gerechnet. Das ist dasselbe Verfahren, aus dem
der jetzige Ruhelauf entstand.

### Die Reihenfolge wird gemessen, nicht uebernommen

Stehende Regel, bisher bei jedem Durchgang noetig gewesen: was der Generator
liefert, ist ein Bilderstapel, keine Abspielreihenfolge. Die Reihenfolge
entsteht hier, aus den Bildern.

Der Ruhelauf laeuft als Pingpong. Eine Template-Animation ist aber meist als
geschlossene Schleife gebaut -- letztes Bild fast gleich erstes. Im Pingpong
stuenden dann an beiden Enden zwei fast gleiche Bilder hintereinander, und
die Figur haette zweimal je Durchlauf eine sichtbare Pause. Also:

1. Umrissunterschied zwischen aufeinanderfolgenden Bildern messen.
2. Ist das letzte Bild nahe am ersten, ist die Schleife geschlossen --
   hinter dem Umkehrpunkt abschneiden.
3. Aus dem Rest die Pingpong-Reihenfolge bauen und als `IDLE_ORDER`
   ausgeben.

Dasselbe Mass hat die jetzige Reihenfolge begruendet: der Sprung von Bild 8
auf 0 aenderte 2486 Umrisspixel, der groesste Schritt innerhalb der
Schwingung 1949.

## Was wegfaellt und was sich aendert

Weg:

- `assets/source/angler_*.png` und `sit_*.png` -- die gemalten Vorlagen
- `classify()`, `prepare()`, `prepare_image()`, `shared_palette()`,
  `apply_palette()`, `tint()` als Weg zur Ebene
- die Ebenenblaetter in ihrer jetzigen Form: `char_skin_*`, `char_shirt_*`,
  `char_pants_*`, `char_base_0`

Bleibt, weil es funktioniert und nichts kostet:

- `blink_series()`, `transplant_blink()`, `head_shift()`
- `rod_grip()` und das Ankerprinzip der Rute
- `import_prop.py` mit Palettenrasten und Umriss

Aendert sich:

| Stelle                          | von   | auf   |
|---------------------------------|-------|-------|
| `AnglerPose.FRAME_SIZE`         | 256   | 128   |
| Vergroesserung in der Welt      | 1     | 2     |
| `AnglerPose.ROD_FRAME_SIZE`     | 320   | 160   |

Auf dem Bildschirm bleibt die Figur damit gleich gross. `IDLE_ORDER`,
`ROD_ANCHOR` und `ROD_TIP_OFF` werden neu gemessen, nicht umgerechnet -- das
Werkzeug gibt sie beim Bauen aus.

Die Kosmetik-Kategorien in `data/cosmetics/` wechseln von "Farbe je Ebene"
auf "Outfit je Blatt", Frisur und Hut bleiben Aufsaetze.

## Budget

1911 Generierungen bis zum 1. Oktober.

    Schluesselfigur      2-9   je Versuch
    Outfit              ~40   Zustand
    Atemzug               1   je Outfit
    Wurf                 ~2   je Outfit
    ------------------------------------
    je Outfit           ~45   -> rund 40 Outfits im Budget

## Reihenfolge der Arbeit

1. Schluesselfigur erzeugen und abnehmen (Farben sauber getrennt?).
2. Farbtabelle und Ebenen-Auszug bauen, an der nackten Figur pruefen.
3. Atemzug und Wurf fuer die Grundfigur, Reihenfolge messen.
4. Blinzeln aus dem bestehenden Verfahren daraufsetzen.
5. Spiel auf 128 umstellen, Rute nachziehen, Figur im Spiel ansehen.
6. Erst dann das erste Outfit als Zustand -- und daran pruefen, ob Haut- und
   Haarschluessel den Zustand ueberlebt haben.

Schritt 6 ist die eigentliche Probe aufs Exempel. Er kommt bewusst spaet:
faellt er durch, ist alles davor trotzdem brauchbar, und der Rueckfallweg
ist `inpaint_image` mit eingefrorenem Aussenherum statt eines Zustands.
