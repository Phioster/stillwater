"""Pixelbilder drehen, ohne dass sie ausfransen (RotSprite-Verfahren).

Direkt gedreht sucht sich jedes Zielfeld ein Quellfeld -- an schraegen Kanten
faellt das mal so, mal so aus, und der Rand wird kruemelig. Hier wird das Bild
erst achtfach vergroessert, und zwar mit EPX: der Vergroesserer erkennt, ob
eine Kante schraeg laeuft, und zieht sie glatt weiter. Gedreht wird in dieser
Groesse, und beim Verkleinern gewinnt je 8x8-Block die haeufigste Farbe.

Der Rand entsteht so aus 64 Stimmen statt aus einer.
"""
import math

import numpy as np


def _packen(rgba):
    a = rgba.astype(np.uint32)
    return (a[:, :, 0] << 24) | (a[:, :, 1] << 16) | (a[:, :, 2] << 8) | a[:, :, 3]


def _entpacken(w):
    return np.dstack([(w >> 24) & 255, (w >> 16) & 255, (w >> 8) & 255, w & 255]).astype(np.uint8)


def _epx(f):
    """Verdoppeln und dabei schraege Kanten erkennen (Scale2x/EPX)."""
    h, b = f.shape
    r = np.pad(f, 1, mode="edge")
    A, C, B, D = r[:-2, 1:-1], r[1:-1, :-2], r[1:-1, 2:], r[2:, 1:-1]
    e1 = np.where((C == A) & (C != D) & (A != B), A, f)
    e2 = np.where((A == B) & (A != C) & (B != D), B, f)
    e3 = np.where((D == C) & (D != B) & (C != A), C, f)
    e4 = np.where((B == D) & (B != A) & (D != C), D, f)
    out = np.empty((h * 2, b * 2), dtype=f.dtype)
    out[0::2, 0::2], out[0::2, 1::2] = e1, e2
    out[1::2, 0::2], out[1::2, 1::2] = e3, e4
    return out


def vergroessern(feld, stufen=3):
    for _ in range(stufen):
        feld = _epx(feld)
    return feld


def drehen(feld8, winkel, um, versatz=(0.0, 0.0), N=8):
    """Rueckwaerts drehen: fuer jedes Zielfeld das Quellfeld suchen.

    `um` und `versatz` sind in Feldern der Originalgroesse angegeben.
    """
    h, b = feld8.shape
    ux, uy = um[0] * N + (N - 1) / 2.0, um[1] * N + (N - 1) / 2.0
    vx, vy = versatz[0] * N, versatz[1] * N
    yy, xx = np.mgrid[0:h, 0:b]
    dx = xx - ux - vx
    dy = yy - uy - vy
    c, s = math.cos(-winkel), math.sin(-winkel)
    sx = ux + dx * c - dy * s
    sy = uy + dx * s + dy * c
    ix = np.rint(sx).astype(int)
    iy = np.rint(sy).astype(int)
    gut = (ix >= 0) & (ix < b) & (iy >= 0) & (iy < h)
    out = np.zeros_like(feld8)
    out[gut] = feld8[iy[gut], ix[gut]]
    return out


def verkleinern(feld8, N=8):
    """Je Block gewinnt die haeufigste Farbe; bei Gleichstand die aus der Mitte."""
    h, b = feld8.shape[0] // N, feld8.shape[1] // N
    werte, idx = np.unique(feld8, return_inverse=True)
    idx = idx.reshape(feld8.shape).reshape(h, N, b, N).transpose(0, 2, 1, 3).reshape(h, b, N * N)
    zaehl = np.zeros((h, b, len(werte)), dtype=np.float32)
    for k in range(len(werte)):
        zaehl[:, :, k] = (idx == k).sum(2)
    # Stichentscheid fuer die Farbe aus der Blockmitte -- dazuzaehlen, nicht setzen.
    mitte = idx[:, :, (N // 2) * N + N // 2][:, :, None]
    np.put_along_axis(zaehl, mitte, np.take_along_axis(zaehl, mitte, 2) + 0.5, axis=2)
    return werte[zaehl.argmax(2)]


def gedreht(bild_rgba, winkel, um, versatz=(0.0, 0.0), N=8, vorgross=None):
    """Ein RGBA-Array drehen und in Originalgroesse zurueckgeben."""
    gross = vorgross if vorgross is not None else vergroessern(_packen(bild_rgba))
    return _entpacken(verkleinern(drehen(gross, winkel, um, versatz, N), N))


def drehen_kette(feld8, kette, N=8):
    """Mehrere Drehungen hintereinander, rueckwaerts abgetastet.

    `kette` steht in der Reihenfolge, in der gedreht wird -- der Unterarm
    dreht erst um den Ellenbogen und macht dann die Schulter mit.
    """
    h, b = feld8.shape
    yy, xx = np.mgrid[0:h, 0:b].astype(np.float64)
    for winkel, um in reversed(kette):
        ux = um[0] * N + (N - 1) / 2.0
        uy = um[1] * N + (N - 1) / 2.0
        c, s = math.cos(-winkel), math.sin(-winkel)
        dx, dy = xx - ux, yy - uy
        xx, yy = ux + dx * c - dy * s, uy + dx * s + dy * c
    ix = np.rint(xx).astype(int)
    iy = np.rint(yy).astype(int)
    gut = (ix >= 0) & (ix < b) & (iy >= 0) & (iy < h)
    out = np.zeros_like(feld8)
    out[gut] = feld8[iy[gut], ix[gut]]
    return out
