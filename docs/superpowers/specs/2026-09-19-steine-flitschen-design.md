# Steine flitschen — ein Zeitvertreib für die Wartezeit am Wasser

**Stand 2026-09-19.** Entwurf, noch nicht umgesetzt.

## Warum

Zwischen zwei Bissen stehst du **30 bis 60 Sekunden** da und tust nichts
(`bite_time_min`/`bite_time_max` in den Zonendaten, gedeckelt durch
`FishingSim.MIN_BITE_TIME`/`MAX_BITE_TIME`). Während dieser Zeit passiert im
Spiel nichts, womit man sich beschäftigen könnte: der Schwimmer liegt, Wolken
ziehen, sonst nichts.

Der Stundentakt ist dagegen gut gefüllt — im Schnitt passiert alle halbe
Stunde etwas:

| Was | Takt |
|---|---|
| Wetterwechsel (`Weather.INTERVAL`) | 1 Stunde |
| Händler (`Visitors.TRADER_INTERVAL`) | 1 Stunde |
| Schilf (`Reeds.INTERVAL`) | 2 Stunden |
| Aufträge (`Quests.INTERVAL`) | 3 Stunden |
| Rabe (`Visitors.RAVEN_INTERVAL`) | 4 Stunden |

Die Lücke ist also **nicht** der Stundentakt, sondern die Minute am Wasser.
Den Schilftakt zu verdichten hilft dagegen nicht: auch alle zehn Minuten Schilf
würde eine 45-Sekunden-Lücke nicht füllen, es wäre nur öfter derselbe
Unterbrecher.

## Die Vorgabe

Wörtlich vom Nutzer: *„irgendwas kleines unauffälliges was man machen kann aber
nicht muss, so ein kleines Extra was Zeitvertreib ist."*

Daraus folgen vier Regeln, und sie sind wichtiger als jedes Detail unten:

1. **Kein Ertrag.** Keine Münzen, keine Köder, kein Fund, keine Erfahrung.
   Sobald es etwas gibt, wird aus „kann" ein „sollte".
2. **Nichts zu verpassen.** Nichts läuft ab, nichts sammelt sich an, es gibt
   keinen Takt, den man verpasst.
3. **Kein Nachteil.** Die Steine verscheuchen keine Fische. Das wäre
   realistisch, würde die Spielerei aber bestrafen.
4. **Nichts, was den Fang kostet.** Werfen geht nur beim Warten; beißt es,
   verschwindet die Anzeige von selbst.

Verworfen wurden: *Vorzupfer am Schwimmer* (macht das Angeln aktiver, statt
etwas danebenzustellen — der Nutzer wollte ausdrücklich das Zweite),
*Treibgut zum Einsammeln* (verstößt gegen Regel 1 und 2) und *kürzere
Bisszeiten* (macht die Lücke kleiner statt besser).

## Der Ablauf

1. Am Ufer liegt ein **Kieselhaufen**, antippbar, sonst stumm — genau wie der
   Schilfhorst (`scenes/fishing/reed_patch.gd`, angebunden in `world.gd` über
   `SCHILF_KNOPF_X` und ein `tapped`-Signal).
2. Antippen: du nimmst einen Stein, der **Ladebalken** erscheint.
3. Der Balken füllt sich von unten. Oben angekommen sinkt die Ladung wieder,
   dann steigt sie erneut — ein langsamer Zyklus, kein einmaliges Aufladen.
   Wer zu spät loslässt, verpasst also nichts, sondern bekommt den nächsten
   Anlauf.
4. Ein **goldenes Band** liegt quer über dem Balken und wandert langsam auf und
   ab. Es sitzt nie lange an derselben Stelle, man kann es nicht auswendig
   lernen.
5. Nochmal tippen: Wurf. Der Stein fliegt **seitlich am Schwimmer vorbei**,
   springt übers Wasser — je Aufsetzer ein Ring — und sinkt. Flugbahn und
   Ringe dürfen den Schwimmer nie überdecken.
6. Nach dem letzten Ring verschwindet der Balken. Der Kieselhaufen bleibt.

## Der Ladebalken

**Form.** Eine Sichel: Kreis minus versetzter Kreis, oben gerade gekappt. Breit
und gerade am oberen Rand, nach unten auslaufend in eine Spitze, beide Kanten
gebogen. **Gespiegelt, Spitze nach links unten** (Variante B der vorgelegten
Formen).

Erzeugt aus drei Zahlen, wie schon `assets/art/klinge.png`:

| | Wert |
|---|---|
| Außenkreis `R` | 35,96 (58 × 0,62) |
| Versatz `V` | 16,12 (26 × 0,62) |
| Ausschnittkreis `RS` | 38,44 (62 × 0,62) |
| Schnitt (Anteil der oberen Hälfte, der wegfällt) | 0,55 |

Ergibt **38 × 56 Bildpunkte**, am Schirm 82 × 120 Punkte (Weltmaßstab 2,16).

**Füllung.** Der gefüllte Teil wächst von der Spitze nach oben. Gefüllt in
`torch`, ungefüllt in `peat_dark`, das Band in `rod_brass` — alles aus
`core/palette.gd`.

Gezeichnet wird wie bei der Klinge: `ladebalken.png` hält **nur den Umriss**,
daraus entsteht einmal eine `BitMap` (wie `Reeds.maske()`), und Füllung und
Band werden zur Laufzeit durch diese Maske gemalt. Damit gibt es die Form
genau einmal — kein zweites Bild je Füllstand, und kein Weg, auf dem
Zeichnung und Rechnung auseinanderlaufen könnten.

**Ladung.** Ein Wert zwischen 0 und 1, der auf und ab schwingt —
**dreieckig, nicht sinusförmig**: gleichmäßiges Steigen, gleichmäßiges Fallen,
keine Verlangsamung an den Enden. Sonst hängt der Balken oben fest und das
Zielen wird zäh. Vollständiger Zyklus (hoch und wieder runter): **1,8
Sekunden**.

**Goldenes Band.** Höhe **0,12** der Balkenhöhe. Seine Mitte wandert zwischen
0,25 und 0,85 der Höhe und **kehrt an den Enden um** (es springt nicht
zurück). Ein voller Weg dauert **5,5 Sekunden** — also deutlich langsamer als
die Ladung, damit es sich anfühlt wie Zielen und nicht wie Glück.

## Was ein Wurf einbringt

Reine Zahl, kein Gegenstand:

| Ladung beim Loslassen | Sprünge |
|---|---|
| unter 0,15 | 0 — ein Plumps, ein einzelner Ring |
| 0,15 bis 1,0 | 1 bis 6, linear |
| im goldenen Band | zusätzlich +2, also bis 8 |

Der Stein blitzt kurz auf, wenn das Band getroffen wurde. Ist er versunken,
steigt an seiner letzten Stelle **die Zahl der Sprünge** auf und verblasst —
über `scenes/effects/pop_text.gd`, denselben Weg, den auch der Fang nimmt. Der
Text ist schon für Schrift über dem Wasser eingestellt (heller Fond, dunkler
Umriss) und räumt sich nach 1,1 Sekunden selbst weg.

Das ist die einzige Zahl, und sie ist flüchtig: kein Zähler, keine Bestenliste
am Bildrand, nichts, was stehenbleibt. Ohne sie weiß man nicht, ob der Wurf gut
war — mit einer bleibenden wäre es eine Aufgabe.

Der **beste Wurf** wird still mitgezählt: ein Eintrag in `Records.FIELDS`
(`best_skips`). `Records.load_dict` überspringt fehlende Felder, alte
Spielstände laufen also unverändert weiter. Die Zahl taucht nur in der
Rekordeansicht auf, nirgends im Spielgeschehen.

## Die Ringe

Jeder Aufsetzer erzeugt **einen** Ring auf dem Wasser.

`scenes/fishing/water_view.gd` hat die Ringmechanik bereits, aber
regenspezifisch: `ring_zustand(i, zeit)` leitet Ort und Alter aus Index und Uhr
ab, `ring_rechtecke()` baut daraus die Zeichenliste. Wiederverwendbar sind
`ring_radius()`, `ring_deckung()`, `ring_form()`, `_halbbreite()` und das
Abschneiden an `_oberflaeche_hoechste()`.

**Erweiterung:** eine kurze Liste ausdrücklich gesetzter Ringe (Ort und
Geburtszeit) neben den Regenringen, die durch denselben Zeichenweg läuft.
Regen und Steine dürfen sich nicht gegenseitig verdrängen.

## Wann es geht und wann nicht

| Zustand | Kieselhaufen | Balken |
|---|---|---|
| `IDLE`, `CASTING`, `WAITING` | antippbar | erscheint |
| `FIGHT` | stumm | verschwindet sofort |
| `INVENTORY_FULL` | antippbar | erscheint |

Beißt ein Fisch, während der Balken läuft, verschwindet der Balken ohne Wurf —
der Stein bleibt in der Hand, es ist nichts verloren. Ein **bereits fliegender**
Stein fliegt zu Ende; der Kampf trägt sich ohnehin von allein ab
(`rod_power` in `core/fishing_sim.gd`), es geht also kein Fisch verloren.

## Dateien

| Datei | Was |
|---|---|
| `core/stones.gd` (neu) | Die Regel: Ladung → Sprünge, goldenes Band, Schwingung. Ohne Nodes, damit sie testbar ist wie `core/reeds.gd`. |
| `scenes/fishing/pebble_pile.gd` (neu) | Der antippbare Kieselhaufen, nach dem Vorbild von `reed_patch.gd`. |
| `scenes/fishing/stone_throw.gd` (neu) | Balken und Flugbahn. |
| `scenes/fishing/water_view.gd` | Einzelne Ringe auf Zuruf. |
| `scenes/fishing/world.gd` | Kieselhaufen setzen und anbinden. |
| `core/records.gd` | Ein Eintrag in `FIELDS`. |
| `tools/kiesel_bauen.py` (neu) | Erzeugt `assets/art/ladebalken.png` (die Sichelform) aus den Zahlen oben und beschneidet den Kieselhaufen aus `assets/source/steine/kiesel.png` auf `assets/art/kiesel.png`. |

Der Kieselhaufen kommt wie das Messer von PixelLab und liegt roh unter
`assets/source/steine/kiesel.png` — 39 × 14 Bildpunkte, am Schirm 84 × 30.
Das genauere Modell nimmt keine Zwangspalette, die Farben werden deshalb beim
Bauen auf die vier neutralen Grautöne eingerastet.

## Was geprüft wird

- Die Sprungzahl folgt der Tabelle, an jeder Grenze.
- Das goldene Band gibt genau dann den Bonus, wenn die Ladung darin liegt.
- Die Ladung schwingt, statt oben stehenzubleiben: nach einem vollen Zyklus
  ist sie wieder unten.
- Das Band wandert langsamer als die Ladung schwingt.
- Der gezeichnete Balken und die gefüllte Höhe stimmen überein — dieselbe
  Lehre wie bei der Klinge: **die Form, die man sieht, ist die Form, mit der
  gerechnet wird** (siehe `core/reeds.gd`).
- Ein Wurf ändert weder Münzen, Köder, Erfahrung noch Inventar.
- Die Sprungzahl wird angezeigt und räumt sich selbst wieder weg — nach ihrer
  Lebenszeit hängt kein Knoten mehr im Baum.
- Beim Anbiss verschwindet der Balken, ohne zu werfen.
- Ein alter Spielstand ohne `best_skips` lädt.
- Die Ringe des Steins verdrängen die Regenringe nicht.

## Offene Zahlen

Alles, was sich nur am Gerät beurteilen lässt, und was der Nutzer entscheidet:
Zyklusdauer der Ladung (1,8 s), Wanderdauer des Bands (5,5 s), Bandhöhe (0,12),
Höchstzahl der Sprünge (8), und wo am Ufer der Kieselhaufen liegt.
