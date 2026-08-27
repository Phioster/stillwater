# Stillwater — Game Design (Slice 1)

Fasst zusammen, welche Systeme Slice 1 tatsächlich enthält und wie sie
zusammenspielen. Die vollständige Herleitung, alle Formeln und alle
Zahlen stehen in der Spezifikation:
`docs/superpowers/specs/2026-08-26-stillwater-design.md`. Jeder
Abschnitt hier verweist auf den entsprechenden Spec-Abschnitt.

## Fang-Loop

```
angeln → Biss → automatischer oder manueller Fang → Inventar
       → verkaufen → Coins → Upgrades → bessere Fische
       → neue Zonen → neue Köder → Journal
```

Zustandsautomat: `IDLE → CASTING → WAITING → BITE → FIGHT → CAUGHT`
(zurück zu `CASTING`) oder `→ ESCAPED` (zurück zu `CASTING`). Ist das
Inventar voll, pausiert der Automat sichtbar in `INVENTORY_FULL` — die
natürliche Bremse für Offline-Fortschritt. Implementiert in
`core/fishing_sim.gd`. Spec §5.1.

## Auto- gegen Manualfang und die Entkommen-Regel

Jeder Kampf hat ein Zeitfenster (`zone.fight_window`, Standard 20 s).
Auto-Fang zieht `rod_power` pro Sekunde von der Fischstärke ab, jeder
Tap auf einen Orb zieht `orb_power` ab. Läuft das Fenster ab, entkommt
der Fisch statt die Angel für immer zu blockieren. Das macht
Rod-Upgrades spürbar und gibt manuellem Tippen einen echten Zweck: man
rettet genau die Fische, die der Auto-Fang noch nicht packt. Spec §5.3.

## Raritäten und Qualitäten

Fünf Raritätsstufen sind in der Spec definiert; Slice 1 nutzt Common,
Uncommon und Rare (`data/rarities/*.tres`). Gewicht wird mit Exponent
1.6 gewürfelt (schwere Exemplare sind seltener), daraus ein Perzentil,
daraus die Qualität in sieben Stufen (E/D/C/B/A/S/S+) mit den
Schwellen 0.12/0.30/0.55/0.75/0.89/0.97 und den Multiplikatoren
0.6/0.8/1.0/1.3/1.7/2.4/3.5. Art und Qualität sind zwei unabhängige
Sammelachsen. Implementiert in `core/fish_roll.gd`. Spec §6.2, §6.8.

## Secret-Fische mit Bedingungssystem

Ein Secret-Fisch ist normale `FishData` mit `is_secret = true` und
einer Liste von `CatchCondition`-Resources. Er erscheint nie in der
normalen Raritätstabelle, wird von keinem Köder-Raritätsbonus
beeinflusst und zählt nicht zur Journal-Prozentvollendung. Slice 1
kennt zwei Bedingungstypen: `BaitCondition` und `LevelCondition`
(`resources/bait_condition.gd`, `resources/level_condition.gd`). Genau
ein Secret-Fisch (Hohlflosse, Willow Lake) beweist, dass das System
trägt. Spec §7.

## Journal und Fisch-Level

Pro Zone eine Liste, pro Fisch: Anzahl gefangen, schwerstes und
leichtestes Exemplar, höchste Qualität, ob ein Shiny gefunden wurde,
und `fish_level`. `fish_level` fließt bereits in die Shiny-Formel ein
(`1.0 + 0.05 * fish_level`), ist in Slice 1 aber immer 0: gespeichert
und angezeigt (`core/journal.gd`), aber noch nicht durch Mini-Quests
erhöht — dieser Ausbau ist in `TODO.md` als „Als Nächstes" vorgemerkt.
Spec §9.

## Ökonomie — eine Preisformel

Verkaufspreise werden ausschließlich in `Economy.sell_price()`
berechnet (`core/economy.gd`): Grundwert × Raritäts-Multiplikator ×
Qualitäts-Multiplikator × (0.5 + Perzentil) × Shiny-Multiplikator (4.0,
falls zutreffend) × Consumable-Bonus. Nirgendwo sonst im Projekt wird
ein Preis gerechnet. Upgrade-Kosten sind eine eigene Formel in
`UpgradeData.cost_at()` (`resources/upgrade_data.gd`), Köderpreise
laufen über `Game.bait_cost()` (`autoload/Game.gd`). Spec §6.5, §6.7.

## Fortschritt

XP pro Fang: `floor(fish.xp * rarity.xp_mult * (0.75 + 0.5 * quality_index / 6.0))`.
Levelkurve: `xp_needed(n) = round(80 * n^1.55)`, bewusst flach, damit
ein Idle-Spiel regelmäßig kleine statt seltener großer Fortschritte
zeigt. Implementiert in `core/progression.gd`. Vier Upgrades (Rod
Power, Orb Power, Fish Inventory, Bait Capacity) mit
`cost(level) = floor(base_cost * cost_growth^level)`. Spec §6.6, §6.7.

## Köder

Der Grundköder (Teichmade) ist gratis und unbegrenzt — bewusste
Abweichung vom Referenzspiel, siehe unten. Bessere Köder
(Eintagsfliegen-Nymphe) sind endlich, erhöhen Raritäts- und
Fischgewichte und werden beim Biss verbraucht, auch wenn der Fisch
entkommt. Spec §5.4.

## Zonen

Willow Lake (Startzone, 5 reguläre Fische + 1 Secret) und Sunset Coast
(5 Fische, ab Level 6 für 1500 Coins freischaltbar). Sunset Coast
nutzt in Slice 1 denselben Hintergrund wie Willow Lake — ein
vollständiger Datensatz beweist, dass das Zonensystem datengetrieben
trägt, ohne dass eine eigene Hintergrundgrafik nötig war. Spec §10.

## Offline-Verhalten

Der Offline-Fortschritt ist kein zweites System, sondern derselbe
`FishingSim.tick()`, mit einem großen Delta gefüttert
(`core/offline_sim.gd`, gedeckelt bei 12 h). Der Nachweis dafür ist ein
Gleichheitstest: `tests/test_offline_sim.gd::test_offline_equals_online`
vergleicht dieselbe Zeitspanne einmal als ein großes `tick()` und
einmal als viele kleine `tick(0.1)` — Fänge, Entkommen, XP und
Coins müssen identisch sein. Das ist der wichtigste Test des Projekts,
weil genau diese Drift Idle-Spiele üblicherweise zerstört. Spec §11.2,
§14.1.

## Cosmetics

Der Charakter besteht aus getrennten Sprite-Ebenen (Haut, Haar,
Oberteil, Hose, Hut, Angel), Farbwahl über einen Paletten-Shader
(`assets/art/palette_swap.gdshader`). Cosmetics sind rein kosmetisch
und verändern keine Werte in Slice 1. Spec §8.

## Bewusste Abweichungen vom Referenzspiel

Drei Entscheidungen weichen absichtlich von der Referenz ab. Wer
später „aufräumt", sollte sie stehen lassen:

1. **Fische können entkommen.** Ein reiner Stärkeabbau ohne
   Zeitlimit blockiert das Idle-Spiel: beißt ein Fisch, den die Angel
   nicht schafft, hängt die Angel für immer an ihm. Das Zeitfenster
   löst das, siehe „Auto- gegen Manualfang" oben. Spec §5.3.
2. **Der Grundköder ist unbegrenzt.** Ohne diese Regel stoppt jede
   längere Idle-Session, sobald der Köder leer ist — genau der
   Kritikpunkt, den Spielerbewertungen am Referenzspiel nennen. Spec §5.4.
3. **Shiny ist 1 zu 800, nicht 1 zu 3000.** Bei Stillwaters Takt von
   rund 40 s pro Fisch wären 1 zu 3000 rund 33 Stunden Angeln pro
   Shiny — auch das ein häufiger Kritikpunkt am Referenzspiel. 1 zu
   800 bleibt selten, ist aber innerhalb einer Spielerlaufbahn
   erreichbar. Spec §6.4.
