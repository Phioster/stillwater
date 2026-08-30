# Reihenfolge

Aus dem Cornerpond-Dossier abgeleitet, nach **Abhängigkeit** sortiert:
jeder Schritt setzt nur auf Fertiges auf. Abgehakt wird hier.

## A — Der Kampf soll sich anfühlen (Grundlage für alles Weitere)

- [ ] **A1 Schattenbalken.** Zwei übereinanderliegende Leisten mit
      richtungsabhängigem Verhalten: fällt der Wert, springt die vordere
      sofort und die hintere zieht nach — man sieht den abgezogenen
      Streifen. Steigt er, umgekehrt. Danach beide per Lerp mit
      Einrast-Schwelle aufs Ziel.
      *Zuerst, weil A2 und A3 diese Leiste benutzen.*
- [ ] **A2 Rutenschaden in Schüben.** Statt stiller Dauerabzug alle
      `pull_cooldown` Sekunden ein sichtbarer Treffer mit eigener Zahl.
      **Muss die Delta-Unabhängigkeit erhalten** — der Offline-Fortschritt
      hängt daran.
- [ ] **A3 Die Idle-Grenze ansagen.** Vor dem Kampf ausrechnen, ob die
      Rute allein reicht. Wenn nicht: sichtbar sagen. Braucht A2, weil
      die Rechnung dieselbe Taktung benutzt.
- [ ] **A4 Schadenszahlen an eine feste Stelle**, nicht an den Orb; die
      letzte Nachrück-Pause raus.

## B — Rang und Größe trennen (Datenmodell)

- [ ] **B1 Köder bestimmt den Rang** über eigene Wahrscheinlichkeiten,
      statt die Größenverteilung zu verschieben. Damit kann auf dem Köder
      stehen, was er tut. Die Abweichung bleibt als reine
      Größenstreuung *innerhalb* des Rangs.
      *Nach A, weil A dieselbe Kampfstelle anfasst — sonst zweimal.*
- [ ] **B2 Köderbeschreibung** aus den Wahrscheinlichkeiten erzeugen.

## C — Rückmeldung überall (Menü)

- [ ] **C1 Federn und Wackler** als eigene kleine Bausteine
      (gedämpfter Schwinger, Verwalter, Erschütterung mit vorab
      gezogenem Rauschen). Lehrbuchphysik, ~100 Zeilen.
- [ ] **C2 Anwenden**: Knöpfe federn beim Drücken, abgelehnte Aktionen
      wackeln, Reiterwechsel gibt Rückmeldung.
- [ ] **C3 Umriss und Schatten** für Text und Flächen über ein Theme
      statt pro Element.

## D — Ton (zuletzt, wie besprochen)

- [ ] **D1 Tonverwaltung**: Abspieler-Pool, zufällige Tonhöhe ±5 %,
      Abklingzeit je Ton, mehrere Varianten je Ereignis, getrennte Busse.
- [ ] **D2 Die Klänge selbst.** **Offene Entscheidung:** woher? Freie
      Quellen mit Lizenzpflege, oder selbst erzeugt. Cornerponds Töne
      fallen aus.

## Später, mit eigenem Anlass

- Wiederkehrende Inhalte aus der Uhr **ableiten** statt herunterzählen
  (`index = floor(zeit / dauer)`, Zufall mit `hash(index)`) — sobald es
  Quests oder einen Händler gibt.
- Rotierende Spielstand-Sicherungen.
- Nachschwingendes Scrollen.
