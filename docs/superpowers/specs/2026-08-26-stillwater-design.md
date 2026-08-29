# Stillwater — Design-Spezifikation

Stand: 2026-08-26 · Godot 4.7.2 · GDScript · Android (Landscape)

## 1. Was Stillwater ist

Ein ruhiges 2D-Pixel-Art-Angel-Idle-Spiel für Android. Der Spieler
angelt automatisch an einem See, verkauft Fische, kauft Ausrüstung und
schaltet damit Zonen, Köder und seltenere Fische frei. Das langfristige
Ziel ist ein vollständiges Fisch-Journal.

Der Kernkreislauf:

```
angeln → Biss → automatischer oder manueller Fang → Inventar
       → verkaufen → Coins → Upgrades → bessere Fische
       → neue Zonen → neue Köder → Journal
```

Er muss sich in fünf Minuten gut anfühlen und über Stunden Idle-Zeit
tragen.

### 1.1 Eigenständigkeit

Cornerpond ist die erklärte Referenz. Die ursprüngliche Fassung dieser
Regel verbot pauschal jede Anlehnung; das ging weiter, als es musste,
und hat dem Spiel geschadet. Es gilt jetzt eine Grenze, die dort
verläuft, wo sie tatsächlich verläuft:

**Frei — darf studiert, verglichen und nachempfunden werden:**

- Spielmechaniken und Formeln: wie Seltenheit an die Stufe koppelt, wie
  Fangpunkte getaktet sind, wie Offline-Fortschritt abgerechnet wird.
- Systemzuschnitt und Fortschrittskurve: welche Systeme es gibt
  (Kosmetik, Ausrüstung, Verbrauchsgüter, Orte) und wann sie aufgehen.
- Bedienung und Aufbau: dass Fanginfos in einem eigenen Fenster stehen,
  wie ein Journal gegliedert ist, wo Knöpfe erwartet werden.
- Anmutung und Tempo: Ruhe, Lesbarkeit, wie lang eine Rückmeldung steht.

Mechaniken, Systeme und Bedienabläufe sind Ideen. Ideen sind frei, und
ein Genre lebt davon, dass sie weitergereicht werden.

**Nie — kommt unter keinen Umständen ins Repository:**

- Dateien: Sprites, Illustrationen, Sounds, Musik, Schriften, Paletten
  als Datei. Nichts wird aus dem PCK entpackt und eingebaut.
- Quelltext wörtlich oder abgeschrieben. Ein System verstehen und selbst
  bauen ist erlaubt; Zeilen übertragen ist es nicht.
- Wörtliche Texte, Beschreibungen, Tooltips.
- Erfundene Eigennamen: Fischarten, Orte, Gegenstände, Figuren.

Der Grund ist nicht Ängstlichkeit, sondern Nutzen: Stillwater soll
veröffentlichbar bleiben. Ideen kosten das nichts, fremde Dateien schon.

Verbindliche Namensregel:

- **Reale Fischarten sind frei.** Bluegill, Rotauge, Flussbarsch,
  Spiegelkarpfen, Makrele und so weiter sind reale Tiere. Überschneidung
  mit anderen Angelspielen ist unvermeidlich und unproblematisch.
- **Erfundene Fische, Köder, Zonen, Tränke und Figuren sind unsere
  eigenen.** Jeder Fantasiename wird vor dem Anlegen geprüft, dass er
  nicht bereits in einem anderen Spiel existiert.
- Anzeigenamen sind zunächst deutsch, IDs immer englisch und
  snake_case. Lokalisierung später über Godots eingebaute
  CSV-Übersetzungen (siehe TODO.md).

## 2. Technische Grundlage

- Godot 4.7.2 stable, GDScript, reines 2D
- Zielplattform Android, Touch als primäre Eingabe
- **Landscape**, Basisauflösung 1280 × 720
- Keine externen Plugins. Vor jeder technischen Entscheidung gilt:
  erst prüfen, ob Godot selbst bereits eine Lösung mitbringt.

Entwicklungsumgebung: Entwickelt wird in Termux auf Android. Godot läuft
dort headless in einem proot-Debian für Tests und Syntaxprüfung. Die
spielbare APK entsteht über GitHub Actions und wird per adb installiert.

## 3. Architektur

### 3.1 Grundsatz: Simulationskern plus dünne Ansicht

Die Spiellogik besteht aus reinen GDScript-Klassen ohne Nodes, ohne
Szenenbezug und ohne Grafikkenntnis. Szenen und UI zeigen diesen Zustand
nur an und leiten Eingaben weiter.

Zwei Gründe, beide entscheidend:

1. **Der Offline-Fortschritt ist kein zweites System**, sondern
   derselbe `FishingSim`, im Schnelldurchlauf gefüttert. Genau hier
   sterben Idle-Spiele sonst: online und offline rechnen unterschiedlich,
   und der Fehler ist nicht auffindbar.
2. **Alles ist headless testbar**, in Sekunden statt in CI-Minuten.

Harte Regel: in `core/` gibt es kein `extends Node`, kein `get_node`,
kein `await get_tree()`. Wer dort Zeit braucht, bekommt sie als
Parameter.

### 3.2 Ordnerstruktur

```
stillwater/
  project.godot
  autoload/     Game.gd  Database.gd  SaveManager.gd  AudioManager.gd
  core/         fishing_sim.gd  inventory.gd  economy.gd
                progression.gd  offline_sim.gd  rng.gd
                catch_conditions.gd  journal.gd
  resources/    fish_data.gd  bait_data.gd  zone_data.gd
                upgrade_data.gd  rarity_data.gd  condition.gd
  data/         fish/*.tres  bait/*.tres  zones/*.tres
                upgrades/*.tres  rarities/*.tres
  scenes/       main.tscn  fishing/  ui/
  assets/       art/  audio/
  tools/        gen_sprites.py  palette.gpl
  tests/        run_tests.gd  test_*.gd
  docs/
```

### 3.3 Autoloads

Nur vier, und jeder mit einem klaren Zweck. Es gibt bewusst **keinen**
Sammelbecken-`GameManager`.

| Autoload | Zweck |
|---|---|
| `Database` | Lädt alle `.tres`-Daten beim Start, liefert sie per ID aus |
| `Game` | Hält den Spielzustand, tickt `FishingSim`, sendet Signale |
| `SaveManager` | Serialisieren, Laden, Migration, Autosave |
| `AudioManager` | Musik- und SFX-Busse, Zonenwechsel |

Dateien bleiben unter etwa 400 Zeilen. Wird eine größer, ist das ein
Signal, dass sie zu viel tut.

## 4. Datenmodell

Alle Spieldaten sind typisierte Godot-`Resource`-Klassen, gespeichert
als `.tres`. Das ist Godots eigene Antwort auf datengetriebenes Design:
Typprüfung, Editor-Unterstützung, kein selbstgeschriebener Loader, kein
JSON-Schema.

### 4.1 Drei Ebenen

Ein Fisch existiert im Spiel auf drei streng getrennten Ebenen:

| Ebene | Was es ist | Wo es lebt |
|---|---|---|
| **Art** (`FishData`) | Die Fischart, unveränderlich | `data/fish/*.tres` |
| **Fang** (`CaughtFish`) | Ein konkret gefangenes Exemplar | Inventar, Save |
| **Journal-Eintrag** | Was der Spieler über die Art weiß | Journal, Save |

Der Journal-Eintrag **überlebt das Verkaufen**. Sonst verliert der
Spieler beim Verkauf seine Sammlung, und das Journal wäre wertlos.

### 4.2 Resource-Klassen

**FishData** — `id`, `display_name`, `zone_id`, `rarity_id`,
`base_value`, `strength`, `xp`, `sprite`, `spawn_weight`,
`preferred_baits`, `weight_min`, `weight_max`, `is_secret`,
`conditions`

**BaitData** — `id`, `display_name`, `cost`, `max_stack`, `unlimited`,
`rarity_weight_bonus` (Dictionary rarity_id → Faktor), `zone_bonus`,
`unlocks_fish`, `unlock_level`

**ZoneData** — `id`, `display_name`, `fish`, `background`, `music`,
`bite_time_min`, `bite_time_max`, `fight_window`, `rarity_weights`,
`unlock_cost`, `unlock_level`

**UpgradeData** — `id`, `display_name`, `description`, `max_level`,
`base_cost`, `cost_growth`, `value_base`, `value_per_level`

**RarityData** — `id`, `display_name`, `color`, `value_mult`, `xp_mult`,
`strength_mult`, `quality_bias`

**Condition** — Basisklasse mit `is_met(state) -> bool`. Slice 1 kennt
`BaitCondition` und `LevelCondition`; vorgesehen sind
`CosmeticCondition`, `TimeOfDayCondition`, `ZoneCatchCountCondition`,
`JournalProgressCondition`, `ActiveConsumableCondition`.

**CaughtFish** (kein Resource, leichte `RefCounted`-Instanz) —
`fish_id`, `weight`, `quality`, `is_shiny`, `is_favorite`

**Journal-Eintrag** — `caught_count`, `best_weight`, `worst_weight`,
`best_quality`, `shiny_found`, `fish_level`

## 5. Der Fang-Loop

### 5.1 Zustandsautomat

```
IDLE → CASTING → WAITING → BITE → FIGHT → CAUGHT   ⟶ CASTING
                                        ↘ ESCAPED  ⟶ CASTING
```

- **WAITING** — zufällige Bisszeit aus `zone.bite_time_min/max`
- **BITE** — die Simulation würfelt den Fisch, der Köder wird verbraucht
- **FIGHT** — Kampffenster läuft, Stärke wird abgebaut
- **CAUGHT** — Fisch ins Inventar, Journal aktualisieren, XP gutschreiben
- **ESCAPED** — Zeitfenster abgelaufen, kurze Abklingzeit, Angel frei

Ist das Inventar voll, pausiert der Automat sichtbar im Zustand
`INVENTORY_FULL`. Das ist die natürliche Bremse für Offline-Fortschritt.

### 5.2 Fischauswahl beim Biss

In dieser Reihenfolge:

1. **Secret-Durchgang.** Welche Secret-Fische dieser Zone erfüllen
   gerade *alle* Bedingungen? Von denen wird mit ihrer jeweiligen,
   sehr kleinen Chance einer gezogen. Trifft einer, ist die Auswahl
   beendet.
2. **Rarität** aus `zone.rarity_weights`, multipliziert mit dem
   `rarity_weight_bonus` des aktiven Köders.
3. **Fisch** gewichtet aus den Fischen dieser Zone und Rarität nach
   `spawn_weight`, erhöht bei passendem Köder (`preferred_baits`).
4. **Gewicht**, **Qualität**, **Shiny** würfeln (Formeln in Abschnitt 6).

Secret-Fische erscheinen **niemals** in der normalen Raritätstabelle.
Sonst verwässern sie die Wahrscheinlichkeiten aller anderen Fische.
Tränke und Köder erhöhen ihre Chance nicht.

### 5.3 Kampf: warum Fische entkommen können

Ein reiner Stärkeabbau ohne Zeitlimit blockiert das Idle-Spiel: beißt
ein Fisch, den die Angel nicht schafft, hängt die Angel für immer an
ihm. Zwei Stunden abwesend, ein Fisch gefangen.

Deshalb hat jeder Kampf ein **Zeitfenster** (`zone.fight_window`,
Standard 20 s):

- Auto-Fang zieht `rod_power` pro Sekunde von der Fischstärke ab.
- Jeder Tap auf einen Orb zieht `orb_power` ab.
- Stärke ≤ 0 → gefangen.
- Fenster abgelaufen → der Fisch entkommt, kurze Abklingzeit.

Das löst drei Dinge gleichzeitig: kein Deadlock, Rod-Upgrades werden
spürbar statt nur rechnerisch, und manuelles Tippen bekommt einen
echten Zweck — man rettet genau die Fische, die der Auto-Fang noch
nicht packt.

### 5.4 Köder

Der Köder wird **beim Biss** verbraucht, auch wenn der Fisch entkommt.
Der Fisch hat ihn mitgenommen.

Der Grundköder ist gratis und unbegrenzt. Ohne diese Regel stoppt jede
längere Idle-Session, sobald der Köder leer ist — genau der Fehler, für
den das Referenzspiel in Rezensionen kritisiert wird. Bessere Köder
sind endlich und sind das Hauptziel früher Ausgaben.

## 6. Zahlen und Formeln

Alle Werte liegen in `.tres`-Dateien, nicht im Code. Die Formeln stehen
jeweils an genau einer Stelle.

### 6.1 Pacing

| Größe | Wert |
|---|---|
| Bisszeit Willow Lake | 25–45 s |
| Bisszeit Sunset Coast | 35–60 s |
| Kampffenster | 20 s |
| Takt pro Fisch | ~40 s |
| Offline-Obergrenze | 12 h |

Diese Zahlen stammen aus einer Pacing-Recherche: das Referenzspiel hob
seine Grundfangzeit im Laufe der Updates von 5 s auf 25 s an, und aus
Spielerangaben lässt sich ein Takt von rund 48 s pro Fisch ableiten.
Ein Takt im Sekundenbereich fühlt sich für dieses Genre falsch an.

`Game.time_scale` beschleunigt die Simulation für Tests und
Entwicklung. Im Release steht der Faktor auf 1.

Daraus folgende Erwartung für Slice 1, bei durchschnittlich rund 12 XP
pro Fisch: Level 5 und damit der Secret-Fisch nach etwa 120 Fischen
(~80 Minuten), Level 6 und damit Sunset Coast nach etwa 200 Fischen
(~2 Stunden). Das ist für ein Idle-Spiel richtig, für einen Testlauf zu
lang — deshalb existiert `time_scale`.

### 6.2 Gewicht und Qualität

```gdscript
w = weight_min + (weight_max - weight_min) * pow(randf(), 1.6)
percentile = (w - weight_min) / (weight_max - weight_min)
```

Der Exponent 1.6 macht schwere Exemplare seltener als leichte.

```gdscript
q = clamp(0.5 * percentile + rarity.quality_bias + randfn(0.0, 0.18), 0.0, 1.0)
```

Schwellen → Stufe: `<0.12` E · `<0.30` D · `<0.55` C · `<0.75` B ·
`<0.89` A · `<0.97` S · sonst S+

Ein schwerer Common kann damit A erreichen, seltene Fische liegen im
Mittel höher. Art und Qualität sind zwei echte Sammelachsen.

Qualitätsmultiplikatoren: E 0.6 · D 0.8 · C 1.0 · B 1.3 · A 1.7 ·
S 2.4 · S+ 3.5

### 6.3 Fischstärke

```gdscript
strength = fish.strength * rarity.strength_mult * (0.75 + 0.5 * percentile)
```

Schwerere Exemplare kämpfen härter.

### 6.4 Shiny

```gdscript
shiny_chance = (1.0 / 800.0) * (1.0 + 0.05 * fish_level) * consumable_bonus
```

In Slice 1 ist `fish_level` immer 0 und `consumable_bonus` immer 1.0,
weil Mini-Quests und Tränke noch nicht existieren. Die Formel steht
trotzdem vollständig, damit später nur Daten dazukommen.

Bewusste Abweichung von der Referenz, die 1 zu 3000 verwendet: bei
unserem Takt von ~40 s wären das rund 33 Stunden Angeln pro Shiny. Die
Foren des Referenzspiels beschweren sich genau darüber. 1 zu 800 bleibt
selten, ist aber innerhalb einer Spielerlaufbahn erreichbar.

Shiny-Fische haben einen eigenen Journal-Vermerk und den Multiplikator
4.0 auf den Verkaufspreis.

### 6.5 Verkaufspreis — genau eine Funktion

```gdscript
Economy.sell_price(caught) -> int:
    floor(base_value
          * rarity.value_mult
          * quality_mult
          * (0.5 + percentile)
          * (is_shiny ? 4.0 : 1.0)
          * consumable_bonus)
```

Nirgendwo sonst wird ein Preis berechnet. `consumable_bonus` ist in
Slice 1 konstant 1.0.

### 6.6 XP und Level

```gdscript
xp_gain = floor(fish.xp * rarity.xp_mult * (0.75 + 0.5 * quality_index / 6.0))
xp_needed(level) = round(80 * pow(level, 1.55))
```

Bewusst flach. Ein Idle-Spiel soll regelmäßig kleine Fortschritte
zeigen, nicht wenige große.

### 6.7 Upgrades

```gdscript
cost(level)  = floor(base_cost * pow(cost_growth, level))
value(level) = value_base + value_per_level * level
```

Slice 1 kennt vier:

| Upgrade | Startwert | pro Stufe | Basiskosten | Wachstum |
|---|---|---|---|---|
| Rod Power | 4 / s | +2 | 50 | 1.6 |
| Orb Power | 6 / Tap | +3 | 40 | 1.6 |
| Fish Inventory | 20 | +15 | 80 | 1.6 |
| Bait Capacity | 30 | +20 | 60 | 1.6 |

Mit Rod Power 4 und 20 s Fenster ergibt sich von allein: Common in
3–5 s gelandet, Uncommon in 7–12 s, Rare in 15–23 s. Rare liegt damit
haarscharf an der Grenze — genau der Punkt, an dem der Spieler selbst
tippen will.

Fish Inventory muss über die Stufen deutlich greifen (20 → mehrere
hundert). Sonst wächst die mögliche Idle-Zeit nicht in Stunden, und das
Spiel bestraft genau das Verhalten, für das es gebaut ist.

### 6.8 Raritäten

Fünf Stufen (§10 der Anforderungen), plus **Secret** als eigene
Kategorie außerhalb der Leiter.

| Rarität | value | xp | strength | quality_bias |
|---|---|---|---|---|
| Common | 1.0 | 1.0 | 1.0 | 0.00 |
| Uncommon | 2.5 | 2.0 | 2.2 | 0.10 |
| Rare | 7.0 | 4.5 | 4.5 | 0.20 |
| Epic | 20.0 | 10.0 | 8.0 | 0.30 |
| Legendary | 60.0 | 25.0 | 14.0 | 0.40 |

Slice 1 verwendet Common, Uncommon und Rare.

Zonenverteilung Willow Lake: Common 70 · Uncommon 25 · Rare 5
Sunset Coast: Common 50 · Uncommon 32 · Rare 18

## 7. Secret-Fische

Ein Secret-Fisch ist kein Sonderfall im Code, sondern normale
`FishData` mit `is_secret = true` und einer Liste von Bedingungen.

Regeln:

- Nie in der normalen Raritätstabelle (siehe 5.2)
- Von keinem Trank und keinem Köder-Raritätsbonus beeinflussbar
- Zählen **nicht** zur Journal-Prozentvollendung — sie sind Kür, nicht
  Pflicht, damit 100 % erreichbar bleibt
- Die Journal-Kategorie „Secret" erscheint erst nach dem ersten Fang
- Vorher zeigt das Journal einen verschlossenen Platz mit einem
  Hinweistext statt einer Silhouette

Bedingungstypen in Slice 1: **Köder** und **Mindestlevel**.
Später: Aussehen, Tageszeit, Fänge in dieser Zone, Journal-Fortschritt,
aktiver Trank.

Bewusst *nicht* übernommen wird das Muster „Buff alle 15 Minuten
nachlegen", das die Referenz für einen ihrer Secret-Fische verwendet.
Das bestraft Idle-Spiel. Aussehensbedingungen sind die bessere Form
derselben Idee: einmal einstellen, bleibt erfüllt.

Slice 1 enthält genau einen Secret-Fisch als Beweis, dass das System
trägt.

## 8. Charakter und Cosmetics

Der Charakter besteht von Anfang an aus getrennten Sprite-Ebenen:

```
Haut · Haar · Oberteil · Hose · Hut · Angel · Bobber · Accessoire
```

Diese Struktur jetzt zu bauen ist billig; sie nachträglich einzuziehen
hieße, Charakter und Animationen komplett neu zu zeichnen.

Farbwahl für Haut, Haar und Kleidung läuft über Palettenaustausch per
Shader, nicht über getrennte Sprites pro Farbe.

Cosmetics sind **rein kosmetisch** und verändern keine Werte. Sie können
aber Fangbedingungen erfüllen (`CosmeticCondition`) — etwa ein
Secret-Fisch, der nur anbeißt, wenn der Spieler vollständig grün
gekleidet ist. Das macht Aussehen bedeutsam, ohne Pay-to-Win zu
erzeugen: es schaltet Entdeckungen frei, keine Stärke.

## 9. Journal

Pro Zone eine Liste. Pro Fisch:

- Silhouette, solange unentdeckt; Bild nach dem ersten Fang
- Rarität, Anzahl gefangen
- schwerstes **und leichtestes** Exemplar
- höchste erreichte Qualität
- Shiny entdeckt: ja/nein
- Fisch-Level

**Fisch-Level** ist langfristig das wichtigste Journal-Feature: jede
Fischart hat eigene Mini-Quests, deren Erfüllung das Level dieser Art
hebt, was Shiny-Chance und Verkaufswert steigert. Das verwandelt das
Journal von einer Abhakliste in etwas, an dem man aktiv arbeitet, und
gibt dem zwanzigsten Fang derselben Art wieder einen Sinn.

In Slice 1 wird `fish_level` gespeichert und angezeigt, aber noch nicht
durch Quests erhöht.

## 10. Fortschritt und Zonen

Level schalten frei: Köder, Zonen, Upgrades, Shop-Angebote, Fischarten.

**Willow Lake** — Startzone, ruhig, kleine Fische, ab Level 1

| Fisch | Rarität | Wert | Stärke | XP | Gewicht |
|---|---|---|---|---|---|
| Bluegill | Common | 8 | 12 | 4 | 0.05–0.35 kg |
| Rotauge | Common | 10 | 15 | 5 | 0.10–0.80 kg |
| Flussbarsch | Uncommon | 22 | 32 | 12 | 0.15–1.20 kg |
| Spiegelkarpfen | Uncommon | 30 | 40 | 16 | 1.00–6.50 kg |
| Laternenschleie | Rare | 85 | 70 | 40 | 0.80–3.50 kg |
| Hohlflosse | Secret | 400 | 95 | 200 | 0.50–2.00 kg |

Laternenschleie und Hohlflosse sind eigene Erfindungen, der Rest sind
reale Arten. Die Hohlflosse verlangt Eintagsfliegen-Nymphe und
Level 5, Chance 2 % pro Biss.

**Sunset Coast** — zweite Zone, größere und wertvollere Fische,
freischaltbar ab Level 6 für 1500 Coins.

| Fisch | Rarität | Wert | Stärke | XP | Gewicht |
|---|---|---|---|---|---|
| Makrele | Common | 18 | 20 | 8 | 0.30–1.00 kg |
| Hornhecht | Common | 24 | 26 | 10 | 0.40–1.60 kg |
| Meerbarbe | Uncommon | 55 | 44 | 26 | 0.25–1.40 kg |
| Wolfsbarsch | Uncommon | 70 | 52 | 32 | 1.00–7.00 kg |
| Glutrochen | Rare | 180 | 88 | 75 | 2.00–12.00 kg |

Glutrochen ist eine eigene Erfindung, der Rest sind reale Arten.

In Slice 1 existiert sie als
vollständiger Datensatz mit eigener Fischtabelle, nutzt aber vorerst
denselben Hintergrund. Damit ist bewiesen, dass das Zonensystem
datengetrieben trägt, ohne Art-Aufwand zu verursachen.

Köder in Slice 1:

| Köder | Kosten | Effekt |
|---|---|---|
| Teichmade | 0, unbegrenzt | keiner |
| Eintagsfliegen-Nymphe | 15 | Uncommon ×1.4, Rare ×2.2 |

## 11. Speichern und Offline

### 11.1 Save

JSON nach `user://save.json` — auf Android app-privater Speicher, kein
Berechtigungsthema.

- Feld `save_version`, Migrationskette `_migrate_1_to_2` und so weiter.
  Ein alter Spielstand darf nie verloren gehen.
- Geschrieben wird in eine Temp-Datei und dann umbenannt. Ein Absturz
  mitten im Schreiben darf den Spielstand nicht zerlegen.
- Autosave nach Verkauf, Upgrade und Zonenwechsel, alle 60 s, und bei
  `NOTIFICATION_APPLICATION_PAUSED`.

Gespeichert wird: `save_version`, `player_level`, `xp`, `coins`,
`current_zone`, `unlocked_zones`, `upgrade_levels`, `bait_inventory`,
`active_bait`, `fish_inventory`, `journal`, `cosmetics`,
`active_consumables`, `settings`, `statistics`, `last_seen_unix`,
`rng_state`.

### 11.2 Offline

Beim Laden: `elapsed = now - last_seen_unix`, gedeckelt bei 12 h.

`OfflineSim` springt **von Biss zu Biss** statt in Sekundenschritten —
12 Stunden sind damit in Millisekunden gerechnet. Sie ruft dabei
denselben `FishingSim` wie das laufende Spiel auf. Sie endet, sobald
das Inventar voll ist oder die Zeit aufgebraucht ist.

Der Zufallsgenerator wird aus dem gespeicherten `rng_state` abgeleitet,
damit sich Offline-Ergebnisse nicht durch wiederholtes Laden neu
würfeln lassen.

Ergebnis ist ein Rückkehr-Panel: Abwesenheitsdauer, gefangene Fische,
verdiente Coins, erhaltene XP.

## 12. UI

**Landscape**, Basisauflösung 1280 × 720,
`stretch_mode = canvas_items`, `stretch_aspect = expand`. Damit passt
sich das Layout an jedes Handyformat an, statt Balken zu zeigen.

```
┌──────────────────────────────────────────────┬────┐
│ Coins · Level · XP                           │ 🐟 │
│                                              │ 📖 │
│              WELT                            │ 🛒 │
│       Charakter · Steg · Wasser              │ ⚙  │
│              Orbs                            │ 🗺  │
│                                              │ 👤 │
└──────────────────────────────────────────────┴────┘
        ~60 % Welt          ~40 % Panel      Tab-Leiste
```

- Links die Welt, immer sichtbar
- Rechts ein einschiebbares Panel mit dem aktiven Tab
- Ganz rechts eine schmale senkrechte Icon-Leiste — im Querformat
  liegt dort der rechte Daumen

Der entscheidende Punkt: **das Panel unterbricht das Spiel nicht.** Die
Welt bleibt sichtbar und tippbar, ein Fisch kann mitten im Shop
gedrillt werden. Deshalb Landscape statt Portrait.

Tabs: Fish · Journal · Shop · Upgrades · World · Character

Alle Tap-Flächen mindestens 96 px in Basisauflösung (≈ 48 dp). Orbs
bekommen bewusst größere Trefferflächen als Sichtflächen — auf dem
Handy tippt man ungenau. Sicherer Bereich über
`DisplayServer.get_display_safe_area()`, damit unter Notch und
Gestenleiste nichts klemmt.

## 13. Art-Pipeline

Der Prototyp verwendet selbst erzeugte Platzhalter-Sprites. `tools/`
enthält Generatoren, die aus einer kleinen Konfiguration See, Steg,
Charakterebenen, Angel, Bobber und Fischsilhouetten als PNG erzeugen.

Diese Generatoren bleiben als Werkzeug im Repo: ein neuer Fisch braucht
einen Eintrag und einen Skriptlauf, keine Handarbeit und keine externe
Hilfe.

Für spätere Handarbeit, alles kostenlos und auf dem Handy nutzbar:
Pixel Studio (Android), dotpict (Android), Piskel (Browser),
LibreSprite (Desktop). Farben kommen aus einer festen Palette in
`tools/palette.gpl`, damit generierte und handgemalte Sprites
zusammenpassen.

Stil: ruhige Farben, klare Silhouetten, kleine Animationen, gemütlich,
nicht überladen.

## 14. Tests und CI

### 14.1 Tests

Ein `SceneTree`-Skript, gestartet mit
`godot --headless --script tests/run_tests.gd`. Kein Test-Plugin —
Godot kann das selbst.

Abgedeckt:

- Fischauswahl-Verteilung über viele Durchläufe
- Köder-Raritätsbonus wirkt wie erwartet
- Secret-Fische erscheinen nur bei erfüllten Bedingungen und nie in der
  normalen Tabelle
- Preisformel, Qualitätsverteilung, XP-Formel, Upgrade-Kosten
- Kampfrechnung inklusive Entkommen
- Inventar-Obergrenze pausiert den Automaten
- **Offline gleich Online**: dieselbe Zeitspanne, beide Wege gerechnet,
  identisches Ergebnis
- Save-Roundtrip und Migration

Der Offline-gleich-Online-Test ist der wichtigste des Projekts. Läuft
er grün, ist die Fehlerklasse ausgeschlossen, an der Idle-Spiele
üblicherweise sterben.

### 14.2 CI

Zwei Workflows, beide holen Godot 4.7.2 und die Export-Templates selbst,
damit nichts an einem fremden Container hängt.

- `test.yml` — headless-Tests bei jedem Push. Test-Gate.
- `build.yml` — baut die Android-APK auf Anforderung.

Repo `Phioster/stillwater`, öffentlich, damit Actions-Minuten nicht
limitiert sind. Package `org.phioster.stillwater`.

Keine Secrets oder Tokens im Repo.

## 15. Umfang von Slice 1

Verbindliche Liste. Was hier nicht steht, kommt später.

**Welt** — Willow Lake voll ausgebaut; Sunset Coast als vollständiger
Datensatz mit geteiltem Hintergrund

**Inhalte** — 5 reguläre Fische plus 1 Secret-Fisch in Willow Lake,
5 Fische in Sunset Coast, 2 Köder, 3 Raritäten, 7 Qualitätsstufen

**Gameplay** — Auto-Angeln, Biss, automatischer Fang, manueller
Orb-Fang, Entkommen, Fisch-Inventar, Verkauf, Coins, XP, Level,
Zonenwechsel, Bedingungssystem mit Köder- und Level-Bedingung

**Charakter** — Ebenen-Charakter mit Angelanimation, Anpassungsbildschirm
mit Farbwahl und je zwei bis drei Kleidungsteilen

**Upgrades** — Rod Power, Orb Power, Fish Inventory, Bait Capacity

**UI** — Landscape-Layout, Fishing-Screen, Inventar, Shop/Upgrades,
Journal, World, Character

**Save** — lokal speichern, laden, Autosave, Versionierung,
Offline-Fortschritt mit Rückkehr-Panel

**Android** — Touchsteuerung, Landscape, APK-Testbuild über CI

## 16. Bewusst später

Aus der Recherche übernommenswert, aber nicht in Slice 1:

- **Fisch-Level über Mini-Quests** — die stärkste Idee der Referenz
- Quest-System mit erneuerbaren Aufgaben
- Consumables — und zwar **über Anzahl Fänge statt Echtzeit**
  („nächste 50 Fänge" statt „nächste 15 Minuten"). Ein zeitbasierter
  Buff auf einem Handy verpufft, während der Spieler weg ist. Das ist
  der Punkt, an dem wir das Vorbild schlagen können.
- **Ein** Rückkehr-Rhythmus, nicht drei. Die Referenz hat Quests alle
  3 h, einen Händler stündlich und ein Geschenk alle 4 h — drei
  Echtzeituhren, die den Spieler an die Leine legen. Rezensionen
  kritisieren genau das. Wir bauen einen.
- Weitere Zonen, Köder, Raritäten Epic und Legendary
- Weitere Bedingungstypen für Secret-Fische
- Audio, Cosmetics-Shop, Statistiken, Lokalisierung

## 17. Designprinzipien

Bei jedem System gilt die Frage: **macht es das Angeln, Sammeln oder
Fortschreiten interessanter?** Wenn nein, brauchen wir es nicht.

Das Spiel soll entspannend sein, ohne Energie-Systeme, ohne Lootboxen,
ohne Pay-to-Win, ohne aggressive Monetarisierung. Es muss ohne ständige
Aufmerksamkeit funktionieren und trotzdem bei aktiver Teilnahme
interessante Entscheidungen bieten.

Zu vermeiden: unnötige Abstraktionen, riesige Monolithen,
Copy-Paste-Code, hartcodierte Fischdaten, hartcodierte Preise,
hartcodierte Drop-Chancen, unstrukturierte globale Variablen.
