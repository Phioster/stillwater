"""Farben, die an zwei getrennten Stellen im Bild vorkommen."""

from collections import defaultdict

from tools.character_keys import assign


def zweigeteilt(zeilen, mindestluecke=20):
    """Die Zeile, an der eine Farbe in zwei Haufen zerfaellt -- oder None.

    Gemessen an der groessten Luecke zwischen zwei belegten Zeilen: liegen
    zwischen dem obersten und dem untersten Vorkommen einer Farbe zwanzig
    leere Zeilen, sind es zwei Stellen und nicht eine.
    """
    if not zeilen:
        return None

    sorted_zeilen = sorted(set(zeilen))

    if len(sorted_zeilen) < 2:
        return None

    max_gap = 0
    max_gap_start = None

    for i in range(len(sorted_zeilen) - 1):
        gap = sorted_zeilen[i + 1] - sorted_zeilen[i]
        if gap > max_gap:
            max_gap = gap
            max_gap_start = sorted_zeilen[i]

    if max_gap < mindestluecke:
        return None

    grenze = max_gap_start + max_gap // 2
    return grenze


def finde_mehrdeutige(img, mindestluecke=20, mindestpixel=4):
    """Farben, die an zwei getrennten Stellen im Bild vorkommen.

    Liefert je Farbe einen fertigen geteilten Eintrag. Welches Teil oben
    und welches unten gilt, wird NICHT aus der Zeile geraten, sondern
    daran gemessen, wovon die Pixel umgeben sind.
    """
    px = img.load()
    w, h = img.size

    color_pixels = defaultdict(list)
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 128:
                color_pixels[(r, g, b)].append((x, y))

    result = {}

    for color, pixels in color_pixels.items():
        if len(pixels) < mindestpixel:
            continue

        # Umriss selbst kann nicht mehrdeutig sein — es umrandet alles.
        if assign(color) == "base":
            continue

        zeilen = [y for x, y in pixels]

        grenze = zweigeteilt(zeilen, mindestluecke)
        if grenze is None:
            continue

        oben = [(x, y) for x, y in pixels if y < grenze]
        unten = [(x, y) for x, y in pixels if y >= grenze]

        def find_surrounding_part(haufen):
            """Das haeufigste Teil, das diese Pixel umgibt.

            Umriss-Nachbarn werden gefiltert — sie umranden jeden Teil
            gleichermaßen und sagen nichts über die Zugehoerigkeit aus.
            """
            part_counts = defaultdict(int)

            for x, y in haufen:
                neighbors = [
                    (x - 1, y - 1), (x, y - 1), (x + 1, y - 1),
                    (x - 1, y),                 (x + 1, y),
                    (x - 1, y + 1), (x, y + 1), (x + 1, y + 1),
                ]

                for nx, ny in neighbors:
                    if nx < 0 or nx >= w or ny < 0 or ny >= h:
                        continue

                    nr, ng, nb, na = px[nx, ny]

                    if na <= 128:
                        continue

                    if (nr, ng, nb) == color:
                        continue

                    part = assign((nr, ng, nb))

                    # Umriss-Nachbarn nicht zählen — sie sind neutral.
                    if part == "base":
                        continue

                    part_counts[part] += 1

            if part_counts:
                return max(part_counts, key=part_counts.get)
            return None

        part_oben = find_surrounding_part(oben)
        part_unten = find_surrounding_part(unten)

        # Nur mehrdeutig, wenn oben und unten verschiedene Teile sind.
        if part_oben is not None and part_unten is not None and part_oben != part_unten:
            result[color] = {
                "grenze": grenze,
                "oben": part_oben,
                "unten": part_unten,
            }

    return result
