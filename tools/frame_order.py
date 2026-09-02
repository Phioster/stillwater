"""Aus einem Bilderstapel eine Abspielreihenfolge machen.

Was der Generator liefert, ist ein Stapel. Eine erzeugte Animation ist meist
schon eine geschlossene Schleife. Die Reihenfolge wird so gewaehlt, dass der
Rundschluss vom letzten aufs erste Bild nicht sichtbar springt.
"""


def silhouette_delta(a, b):
    """Wie viele Pixel in genau einem der beiden Bilder sichtbar sind."""
    pa, pb = a.load(), b.load()
    n = 0
    for y in range(a.size[1]):
        for x in range(a.size[0]):
            if (pa[x, y][3] > 0) != (pb[x, y][3] > 0):
                n += 1
    return n


def turning_point(frames):
    """Das Bild, das am weitesten von Bild 0 entfernt ist."""
    return max(range(len(frames)), key=lambda i: silhouette_delta(frames[0], frames[i]))


def pingpong_order(frames):
    """Hin bis zum Umkehrpunkt und denselben Weg zurueck."""
    k = turning_point(frames)
    return list(range(k + 1)) + list(range(k - 1, 0, -1))
