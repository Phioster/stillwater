# Fischvarianten: Schimmer, Dunkel, Trophäe, Albino

**Stand 2026-09-26.** Mit dem Nutzer abgestimmt.

## Warum

Nach den legendären Arten fehlt eine Sammelstufe darüber. Heute gibt es nur
den Schimmer (1/800, ×4). Idee aus FishOnMC (Albino/Melanistic/Trophy),
eigene Umsetzung, keine Namen oder Grafiken übernommen.

## Entscheidungen

### Varianten

| Variante | id | Chance je Fang | Wert | Bedingung |
|---|---|---|---|---|
| normal | `&""` | – | ×1 | – |
| Schimmer | `&"shiny"` | 1/800 (wie heute) | ×4 | – |
| Dunkel | `&"dark"` | 1/1500 | ×6 | nur 21:00–5:59 Uhr (echte Uhr, `ctx.hour_of_day` 21…5) |
| Trophäe | `&"trophy"` | 1/3000 | ×10 | – |
| Albino | `&"albino"` | 1/10000 | ×25 | – |

- Ein Fang hat **höchstens eine** Variante.
- Gewürfelt wird von selten nach häufig: Albino, Trophäe, Dunkel, Schimmer;
  der erste Treffer gewinnt.
- Das Fischlevel erhöht **jede** Chance um 5 % je Stufe (wie heute beim
  Schimmer). Schimmer-Tränke (`shiny_mult`) wirken **nur** auf den Schimmer.
- **Offline** (OfflineSim) wird weder eine Variante noch ein Geheimfisch
  gewürfelt – das gilt auch für den bisherigen Schimmer. Besonderes gibt es
  nur beim aktiven Spielen.
- Rangfolge „beste Variante“: Albino > Trophäe > Dunkel > Schimmer > normal.

### Daten und Spielstand

- `CaughtFish.variant: StringName` ersetzt `is_shiny`. `to_dict` schreibt
  `"variant"`; `from_dict` liest `"variant"`, sonst das alte `"is_shiny"`
  (true → `&"shiny"`). Kein neuer `SAVE_VERSION` nötig.
- Journal-Eintrag: `"variants": Array[String]` (gefundene Varianten) ersetzt
  `"shiny_found"`; beim Laden wird `shiny_found = true` zu `["shiny"]`.
- `Economy`: eine Tabelle `VARIANT_MULT` statt `SHINY_MULT`.
- Statistik (`Records`): je Variante ein Zähler; `shiny_caught` bleibt als
  Zähler für den Schimmer erhalten (alte Stände).

### Bilder

- `tools/fische_bauen.py` rechnet je Art vier Bilder
  `fish_<id>_<variant>.png` aus dem fertigen Zonenbild:
  - **Schimmer:** bläulich, heller, leuchtend.
  - **Trophäe:** goldener Glanz.
  - **Albino:** weiß mit grauen Akzenten, **rotes Auge**.
  - **Dunkel:** fast schwarz, **rotes Auge**.
- **Jedes** sichtbare Auge wird rot, auch mehrere (Krug-Mimik hat zwei,
  die Eishydra drei Köpfe). Die Augen werden automatisch gesucht; wo das
  danebenliegt, stehen die Stellen in einer Tabelle `AUGEN` im Werkzeug.
  Nur Bilder ganz ohne Auge bleiben ohne rotes Auge – das zeigt die
  Abnahme.
- Abnahme vor dem Einbau auf der Vorschauseite; unsichere Fälle in
  Fünfergruppen.
- Schimmer und Trophäe funkeln zusätzlich leicht (kleines Funkeln im Spiel)
  im Fischfenster und in der Fangmeldung.

### Anzeige

- **Journal, Liste:** das Fischbild zeigt die **beste gefangene Variante**;
  dahinter kleine Symbole (PixelLab) für jede gefundene Variante.
- **Journal, Detailansicht (Fischfenster):** Zeile
  „Normal · Schimmer · Dunkel · Trophäe · Albino“ zum Antippen, das Bild
  wechselt; nicht gefundene stehen ausgegraut als „???“.
- **Kiste, Fangmeldung, Haken:** zeigen das Variantenbild und den
  Variantennamen.

## Tests

- Würfelreihenfolge und „höchstens eine Variante“; Dunkel nie zwischen
  6 und 20 Uhr; offline weder Variante noch Geheimfisch.
- Preise je Variante; alte Spielstände (`is_shiny`, `shiny_found`) laden.
- Zu jeder Art existieren die vier Variantenbilder in Rohbildgröße.

## Nicht Teil davon

- Tränke für Dunkel/Trophäe/Albino.
- Variantenwahl in Aufträgen oder beim Händler.
