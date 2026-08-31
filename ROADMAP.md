# Reihenfolge

Aus dem Cornerpond-Dossier abgeleitet, nach **Abhängigkeit** sortiert:
jeder Schritt setzt nur auf Fertiges auf. Abgehakt wird hier.

## A — Der Kampf soll sich anfühlen (Grundlage für alles Weitere)

- [x] **A1 Schattenbalken.** Zwei übereinanderliegende Leisten mit
      richtungsabhängigem Verhalten: fällt der Wert, springt die vordere
      sofort und die hintere zieht nach — man sieht den abgezogenen
      Streifen. Steigt er, umgekehrt. Danach beide per Lerp mit
      Einrast-Schwelle aufs Ziel.
      *Zuerst, weil A2 und A3 diese Leiste benutzen.*
- [x] **A2 Rutenschaden in Schüben.** Statt stiller Dauerabzug alle
      `pull_cooldown` Sekunden ein sichtbarer Treffer mit eigener Zahl.
      **Muss die Delta-Unabhängigkeit erhalten** — der Offline-Fortschritt
      hängt daran.
- [x] **A3 Die Idle-Grenze ansagen.** Vor dem Kampf ausrechnen, ob die
      Rute allein reicht. Wenn nicht: sichtbar sagen. Braucht A2, weil
      die Rechnung dieselbe Taktung benutzt.
- [x] **A4 Schadenszahlen an eine feste Stelle**, nicht an den Orb; die
      letzte Nachrück-Pause raus.

## B — Rang und Größe trennen (Datenmodell)

- [x] **B1 Köder bestimmt den Rang** über eigene Wahrscheinlichkeiten,
      statt die Größenverteilung zu verschieben. Damit kann auf dem Köder
      stehen, was er tut. Die Abweichung bleibt als reine
      Größenstreuung *innerhalb* des Rangs.
      *Nach A, weil A dieselbe Kampfstelle anfasst — sonst zweimal.*
- [x] **B2 Köderbeschreibung** aus den Wahrscheinlichkeiten erzeugen.

## C — Rückmeldung überall (Menü)

- [x] **C1 Federn und Wackler** als eigene kleine Bausteine
      (gedämpfter Schwinger, Verwalter, Erschütterung mit vorab
      gezogenem Rauschen). Lehrbuchphysik, ~100 Zeilen.
- [x] **C2 Anwenden**: Knöpfe federn beim Drücken, abgelehnte Aktionen
      wackeln, Reiterwechsel gibt Rückmeldung.
- [x] **C3 Umriss und Schatten** für Text und Flächen über ein Theme
      statt pro Element.

## D — Ton (zuletzt, wie besprochen)

- [x] **D1 Tonverwaltung**: Abspieler-Pool, zufällige Tonhöhe ±5 %,
      Abklingzeit je Ton, mehrere Varianten je Ereignis, getrennte Busse.
- [x] **D2 Die Klänge selbst** — **selbst erzeugt**, wie die Sprites:
      `tools/gen_sounds.py` schreibt elf WAVs aus kurzen Hüllkurven auf
      wenigen Sinustönen. Das hält uns von Lizenzfragen frei und passt zum
      Rest der Platzhalter. Wenn die endgültige Grafik kommt, kommen auch
      echte Klänge — bis dahin trägt das.

## Später, mit eigenem Anlass

- Wiederkehrende Inhalte aus der Uhr **ableiten** statt herunterzählen
  (`index = floor(zeit / dauer)`, Zufall mit `hash(index)`) — sobald es
  Quests oder einen Händler gibt.
- Rotierende Spielstand-Sicherungen.
- Nachschwingendes Scrollen.

## E — Was ohne Absprache fertig wird

- [x] **E1 Einstellungen.** Ton an/aus und zwei Lautstärken. Der Ton hat
      seit D Regler nötig, es gab nur kein Menü dafür. Wird im Spielstand
      gemerkt (`settings` liegt dort schon leer bereit).
- [x] **E2 Spielstand-Sicherungen.** Rotierende Kopien in einem eigenen
      Ordner. Bisher gibt es nur temp+umbenennen — das schützt vor einem
      Absturz beim Schreiben, nicht vor einem kaputten Stand.
- [x] **E3 Nachschwingendes Scrollen.** Die Referenz brauchte dafür ein
      Fremd-Addon; unsere Listen bleiben beim Loslassen abrupt stehen.
- [x] **E4 Sunset Coast auffüllen.** 8 Arten gegen 16 in Willow Lake —
      die zweite Zone ist dünner als die erste.

---

**Stand 2026-08-31: A bis E sind abgearbeitet, dazu Tränke, Besucher,
Aufträge, Wetter, Bilanz und Sortierung.** 432 Tests grün, alles auf dem
Gerät. Offen bleiben nur noch Grafik, Ton und das Veröffentlichen.

**Was jetzt noch offen ist, braucht eine Entscheidung — also gemeinsam:**

- **Hochauflösende Pixelart.** Die Richtung steht (Dead-Cells-Machart,
  weibliche Figur), aber jedes Sprite ist Geschmackssache. Solange die
  Platzhalter stehen, bleiben auch meine Sinustöne stehen.
- ~~Tränke~~ — gebaut 2026-08-31. Zwölf nach dem Vorbild (Schimmer,
  Lockstoff, Erfahrung, Handel × drei Stufen, 600/3.000/15.000, 15 min),
  drei Raritäts-Elixiere, drei eigene: **Tiefenlot** (Rang +1),
  **Sparhaken** (kein Köderverbrauch), **Mondglas** (Nachtfische am Tag).
  Die drei hängen an Systemen, die die Referenz gar nicht hat.
- ~~Weitere Zonen~~ — **sieben Zonen stehen** (2026-08-30): Willow Lake,
  Sunset Coast, Nebelmoor, Frostbucht, Tiefe Zisterne, Wolkensee,
  Sternensee. 104 Arten. Damit sind wir beim Umfang der Referenz.
- ~~Waschbär-Händler und Rabe~~ — gebaut 2026-08-31, beide aus der Uhr
  abgeleitet statt heruntergezählt. Der Händler zieht weiter, sobald man
  bei ihm gekauft und den Laden geschlossen hat.
- ~~Quests~~ — gebaut 2026-08-31, gleicher Uhr-Rhythmus, freischaltbar und
  gegen Geld von 3 auf 6 erweiterbar.
- ~~Wetter~~ — Regen zieht über GENAU EINE Zone und höchstens einmal je
  Sechs-Stunden-Block; die Weltliste zeigt mit „☂", wo.
- ~~Bilanzseite, Beutel im Inventar, Inventarsortierung, Kosmetik auf 33
  Varianten inkl. Ruten~~ — 2026-08-31.
- **Veröffentlichen.** Release-Keystore als GitHub-Secret, Paketname,
  Store-Eintrag.
