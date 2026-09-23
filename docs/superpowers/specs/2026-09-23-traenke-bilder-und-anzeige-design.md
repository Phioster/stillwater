# Tränke: Bilder und Anzeige

**Stand 2026-09-23.** Mit dem Nutzer abgestimmt, noch nicht umgesetzt.
Erstes von drei Pixelart-Teilprojekten (danach Fische, dann Accessoires).

## Warum

- Die 18 Tränke haben **kein Bild**. Im Beutel stehen sie als Textzeilen.
- Was gerade wirkt und wie lange noch, steht **nur** unter Fische →
  „Tränke“ (`potion_panel.gd::_active_block`). Wer angelt, sieht es nicht.
- Die Fanganzeige (`catch_toast.gd`) und die Kampfleiste (`catch_view.tscn`,
  Knoten `Panel`) stehen links unter der Kopfzeile, bei `x=16, y=132`. Diese
  Spalte braucht jetzt die Trankreihe.

## 1. Bilder

**Weg: Mischung.** PixelLab erzeugt nur die Grundformen, ein Skript färbt
sie. So passen alle Bilder zusammen, und ein neuer Trank kostet keine
Generation.

### Die sieben Grundbilder

Das System: **Flaschenform = Stufe, Flüssigkeitsfarbe = Wirkung.**

| Grundbild | Für | Flüssigkeit |
|---|---|---|
| Phiole (schmal, klein) | `*_phiole` | ja |
| Trank (bauchig) | `*_trank` | ja |
| Elixier (verziert) | `*_elixier` der vier Wirkungen | ja |
| Kristallflasche (Stern am Stöpsel) | `selten_`, `episch_`, `legendaer_elixier` | ja |
| Mondglas | `mondglas` | nein |
| Sparhaken | `sparhaken` | nein |
| Senkblei | `tiefenlot` | nein |

Die Kristallflasche ist gegenüber dem Chat-Entwurf dazugekommen: das
Handel-Elixier (gold) und das Legenden-Elixier (gold) wären sonst dasselbe
Bild gewesen.

### Erzeugung

- `create_image_pixflux`, **32×32** (kleiner lässt PixelLab nicht zu:
  Mindestfläche 1024 Pixel), `no_background`, `side`-Ansicht, einheitliche
  Stilangaben für alle sieben. Die Flüssigkeit wird **rot** verlangt, damit
  das Skript sie findet.
- Alle sieben zusammen durch `reduce_colors` — eine gemeinsame Palette.
- Rohbilder nach `assets/source/potions/<grundbild>.png`.
- Geschätzt 7 bis 14 Generationen plus 0,1 für die Palette.

### `tools/traenke_bauen.py`

- Schneidet jedes Grundbild auf **24×24** um seinen Inhalt zu (passt der
  Inhalt nicht hinein, bricht das Skript mit Meldung ab statt zu skalieren).
- Färbt die Flüssigkeit um: Pixel mit rotem Farbton und Sättigung über
  0,35 bekommen Farbton und Sättigung der Wirkung, die **Helligkeit bleibt**
  — dieselbe Regel wie `palette_swap.gdshader`.
- Schreibt `assets/art/potion_<id>.png`, eine Zeile je Trank.

| Wirkung | Farbe |
|---|---|
| Schimmer | Perlflieder `#d8c8f0` |
| Lockstoff | Moosgrün `#6fae4f` |
| Erfahrung | Türkis `#4fb8c8` |
| Handel | Gold `accent` `#f0c05a` |
| Selten / Episch / Legendär | Farbe aus `data/rarities/<id>.tres` |

Anzeige im Spiel doppelt groß (48 Punkte), im 2er-Raster der Schrift.
Geladen wird nach Namensregel wie bei den Fischen
(`res://assets/art/potion_%s.png`), kein neues Feld in `ConsumableData`.

## 2. Anordnung und Anzeige

### Fanganzeige und Kampfleiste: oben in die Mitte

- Beide ziehen **oben mittig in die freie Fläche** (Himmel). Frei ist bei
  geschlossenem Menü `0..1280 - RAIL_WIDTH` = `0..1140`, Mitte `x≈570`.
  Eine 360 breite Karte liegt also bei `390..750` — die Kopfzeile endet bei
  `x≈372`, die Reiterleiste beginnt bei 1140.
- **Menü offen: beide unsichtbar.** Der Kampf läuft weiter, die Orbs am
  Schwimmer bleiben antippbar. Wird das Menü während des Kampfes oder in den
  3 Sekunden der Fanganzeige geschlossen, erscheinen sie wieder.
- Mechanik: `main.gd::show_tab` setzt eine Eigenschaft `menu_offen` an
  `CatchToast` und an der `CatchView` (über `world.gd`). Beide verknüpfen sie
  mit ihrem eigenen Sichtbarkeitszustand, statt ihn zu überschreiben.
- Die Masse stehen wie bisher im **Code** (`catch_toast.gd::RECT` bzw. ein
  entsprechendes Mass in `catch_view.gd`), weil Anker einer Szenenwurzel den
  Export nicht überleben.

### Trankreihe: `scenes/ui/buff_bar.gd`

- Sitzt links unter der Kopfzeile, wo bisher die Fanganzeige stand. Bleibt
  auch bei offenem Menü sichtbar (das Menü hängt rechts).
- Je laufendem Trank ein Eintrag: Bild (48 Punkte), darunter die Restzeit
  `m:ss`, darunter ein dünner Balken, der von voll nach leer läuft
  (`remaining / duration`).
- Reihenfolge: die Reihenfolge in `Game.buffs.active`, also nach dem
  Trinken. Einträge springen nicht umher.
- Keine Tränke aktiv: die Reihe ist unsichtbar.
- Ein Tipp auf die Reihe öffnet Fische → Tränke (dort liegt `PotionPanel`, Unterreiter 2) (Signal an `main.gd`, wie
  `_open_trader`). Antippbar über `TapButton`-Muster, wegen der
  Doppel-Tipp-Falle (Maus-Emulation) mit Sperre.
- Aktualisierung einmal je Sekunde plus bei `Game.state_changed`, nicht in
  jedem Bild.
- Die Liste im Tränke-Reiter (`potion_panel.gd`) bekommt dieselben Bilder.

## 3. Tests

- Jeder Trank in `Database` hat `assets/art/potion_<id>.png`, 24×24, nicht
  leer (Silhouette prüfen, nicht Farben — Farbwerte unterscheiden sich
  zwischen CI-Import und Gerät).
- Trankreihe: zeigt genau die aktiven Tränke in Trinkreihenfolge, Restzeit
  richtig formatiert, verschwindet ohne Trank.
- Fanganzeige und Kampfleiste: liegen mittig in `0..1140`, berühren weder
  Kopfzeile noch Reiterleiste; mit `menu_offen` unsichtbar, danach wieder
  sichtbar, wenn sie es vorher waren. Ersetzt
  `test_the_catch_panel_never_hides_behind_the_hud` und
  `test_the_catch_toast_stays_in_the_free_column`.
- Trankreihe: liegt unter der Kopfzeile und endet links vom offenen Menü
  (`1280 - RAIL_WIDTH - PANEL_WIDTH`), auch mit allen acht Gruppen aktiv
  (je Gruppe höchstens ein Trank, `group` ersetzt statt zu stapeln).
- Je ein Test hält Code-Mass und Szene zusammen.

## Nicht Teil davon

- Fische und Accessoires (eigene Teilprojekte).
- Neue Tränke oder geänderte Wirkungen.
- Ton für die Trankreihe.
