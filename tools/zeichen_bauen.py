"""Die Zeichen bauen, die Silkscreen nicht hat.

    python3 -m tools.zeichen_bauen [ziel.ttf]

Die Oberflaeche benutzt 14 Sonderzeichen (Regenschirm, Sterne, Haken,
Pfeile ...), die in keiner Pixelschrift vorkommen. Ohne sie stuende dort ein
leeres Kaestchen. Sie werden hier als Schrift gebaut und in ui_theme.gd als
ERSATZSCHRIFT hinter Silkscreen gehaengt: Godot greift pro Zeichen von selbst
darauf zurueck. Dadurch bleibt "  ☂" im Quelltext stehen, und keine der
zwoelf Dateien, die solche Zeichen benutzen, muss angefasst werden.

Es ist bewusst eine TTF mit Pixelkonturen und keine Bitmap-Schrift: eine
Bitmap-Schrift haengt an einer festen Groesse, diese hier skaliert mit
Silkscreen mit.

Das Raster ist an Silkscreen ABGEMESSEN (tools/tests/test_zeichen.py rechnet
es nach): ein Pixel sind 125 Einheiten, ein Grossbuchstabe ist 4x5 Pixel und
traegt links und rechts ein Pixel Luft.

Nicht alle Zeichen sind gleich gross, und das ist Absicht. Auf Buchstabenhoehe
(5 Pixel) geht nur, was GEOMETRISCH ist: Haken, Pfeile, Kaestchen, Raute. Was
ein BILD sein will -- Schirm, Schloss, Muenze, Stern --, zerfaellt dort zu
einem Klumpen, den man nur erkennt, wenn man ihn schon kennt. Die stehen
deshalb auf 7 bis 8 Pixeln und ragen ueber die Zeile hinaus, wie Symbole das
duerfen.
"""
import os
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

W = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLATT = os.path.join(W, "assets", "fonts", "StillwaterZeichen.ttf")

## Silkscreens Raster, abgemessen: Grossbuchstabe 500x625 Einheiten ab x=125.
PIXEL = 125
LUFT = 1          # Pixel Seitenabstand, wie bei Silkscreen
UPEM = 1000
ASCENT, DESCENT = 1030, -250

## Jedes Zeichen 5x5, oberste Zeile zuerst. Die Grundlinie liegt unter der
## untersten Zeile -- genau wie bei einem Grossbuchstaben.
ZEICHEN = {
    0x2602: ("umbrella", [     # Regenschirm mit Griff
        "....#....",
        "..#####..",
        ".#######.",
        "#########",
        "....#....",
        "....#....",
        "..#.#....",
        "..###....",
    ]),
    0x2605: ("starfilled", [   # gefuellter Stern
        "...#...",
        "..###..",
        "#######",
        ".#####.",
        "..###..",
        "..#.#..",
        ".#...#.",
    ]),
    0x2606: ("starhollow", [   # leerer Stern
        "...#...",
        "..#.#..",
        "###.###",
        ".#...#.",
        "..#.#..",
        "..#.#..",
        ".#...#.",
    ]),
    0x2610: ("ballotbox", [    # leeres Kaestchen
        "#####",
        "#...#",
        "#...#",
        "#...#",
        "#####",
    ]),
    0x2611: ("ballotcheck", [  # angekreuztes Kaestchen
        "#####",
        "#...#",
        "#.#.#",
        "##.##",
        "#####",
    ]),
    0x2713: ("checkmark", [    # Haken
        "....#",
        "...#.",
        "..#..",
        "#.#..",
        ".#...",
    ]),
    0x2726: ("sparkle", [      # Glitzern
        "..#..",
        ".###.",
        "#####",
        ".###.",
        "..#..",
    ]),
    0x2A00: ("circleddot", [   # Muenze
        "..###..",
        ".#...#.",
        "#.....#",
        "#..#..#",
        "#.....#",
        ".#...#.",
        "..###..",
    ]),
    0x1F512: ("lock", [        # Vorhaengeschloss mit Schluesselloch
        "..###..",
        ".#...#.",
        ".#...#.",
        "#######",
        "###.###",
        "###.###",
        "#######",
    ]),
    0x2190: ("arrowleft", [
        "..#..",
        ".#...",
        "#####",
        ".#...",
        "..#..",
    ]),
    0x2192: ("arrowright", [
        "..#..",
        "...#.",
        "#####",
        "...#.",
        "..#..",
    ]),
    0x25B2: ("triangleup", [
        ".....",
        "..#..",
        ".###.",
        "#####",
        ".....",
    ]),
    0x2212: ("minussign", [
        ".....",
        ".....",
        "#####",
        ".....",
        ".....",
    ]),
}


## Zeichen, die NICHT auf der Grundlinie stehen sollen, in Pixeln nach unten.
##
## Ein Buchstabe ist 5 Pixel hoch, die Muenze 7. Auf derselben Grundlinie sitzt
## ihre Mitte damit 1 Pixel ueber der Buchstabenmitte -- neben einer Zahl sieht
## das aus, als schwebe sie. Ein runder Umriss will optisch mittig sitzen und
## nicht aufsitzen; bei Stern und Schirm ist Aufsitzen dagegen richtig.
VERSATZ = {
    0x2A00: -1,   # Muenze
}


def laeufe(zeile):
    """Die zusammenhaengenden Strecken einer Zeile als (von, bis)."""
    out, start = [], None
    for i, c in enumerate(zeile):
        if c == "#" and start is None:
            start = i
        elif c != "#" and start is not None:
            out.append((start, i)); start = None
    if start is not None:
        out.append((start, len(zeile)))
    return out


def zeichne(muster, versatz=0):
    """Ein Muster als Kontur. Waagerechte Strecken werden zusammengefasst --
    ein Rechteck je Strecke statt eines je Pixel haelt die Schrift klein."""
    stift = TTGlyphPen(None)
    hoch = len(muster)
    for y, zeile in enumerate(muster):
        # Oberste Musterzeile liegt am hoechsten: y zaehlt nach unten, die
        # Schrift rechnet nach oben.
        unten = (hoch - 1 - y + versatz) * PIXEL
        for von, bis in laeufe(zeile):
            x0 = (LUFT + von) * PIXEL
            x1 = (LUFT + bis) * PIXEL
            # Im Uhrzeigersinn -- TrueType fuellt sonst nichts.
            stift.moveTo((x0, unten))
            stift.lineTo((x0, unten + PIXEL))
            stift.lineTo((x1, unten + PIXEL))
            stift.lineTo((x1, unten))
            stift.closePath()
    return stift.glyph()


def bauen():
    namen = [".notdef"] + [n for n, _ in ZEICHEN.values()]
    fb = FontBuilder(UPEM, isTTF=True)
    fb.setupGlyphOrder(namen)
    fb.setupCharacterMap({cp: n for cp, (n, _) in ZEICHEN.items()})
    glyphen = {".notdef": TTGlyphPen(None).glyph()}
    breiten = {".notdef": (PIXEL * 6, 0)}
    for cp, (name, muster) in ZEICHEN.items():
        glyphen[name] = zeichne(muster, VERSATZ.get(cp, 0))
        breite = (len(muster[0]) + 2 * LUFT) * PIXEL
        breiten[name] = (breite, LUFT * PIXEL)
    fb.setupGlyf(glyphen)
    fb.setupHorizontalMetrics(breiten)
    fb.setupHorizontalHeader(ascent=ASCENT, descent=DESCENT)
    fb.setupNameTable({
        "familyName": "Stillwater Zeichen",
        "styleName": "Regular",
        "uniqueFontIdentifier": "StillwaterZeichen-Regular",
        "fullName": "Stillwater Zeichen",
        "psName": "StillwaterZeichen-Regular",
        "version": "Version 1.0",
    })
    fb.setupOS2(sTypoAscender=ASCENT, sTypoDescender=DESCENT, sCapHeight=700,
                usWinAscent=ASCENT, usWinDescent=-DESCENT)
    fb.setupPost()
    return fb


def main(ziel=BLATT):
    bauen().save(ziel)
    print("Zeichenschrift geschrieben: %s (%d Zeichen)" % (ziel, len(ZEICHEN)))


if __name__ == "__main__":
    main(*sys.argv[1:])
