"""Achse der Rute und ihr Querschnitt -- die Grundlage fuer den Schnitt."""
import numpy as np
from seed import thin

def core(mask, rgb):
    """Sichere Rutenpixel: duenn ODER kuehl. Die Figur ist durchweg warm
    (R-B im Mittel +32), die Rute zu 44 % kuehl -- das trennt zuverlaessig."""
    return (thin(mask, 10) | (mask & (rgb[:, :, 2] >= rgb[:, :, 0])))

def biggest(m):
    """Groesste zusammenhaengende Flaeche -- streut die Maske, bleibt der Schaft."""
    from collections import deque
    h, w = m.shape
    seen = np.zeros_like(m); best = None
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        if seen[y, x]: continue
        q = deque([(y, x)]); seen[y, x] = True; comp = []
        while q:
            cy, cx = q.popleft(); comp.append((cy, cx))
            for dy in (-2, -1, 0, 1, 2):
                for dx in (-2, -1, 0, 1, 2):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True; q.append((ny, nx))
        if best is None or len(comp) > len(best): best = comp
    out = np.zeros_like(m)
    for y, x in best: out[y, x] = True
    return out

def fit(m):
    """Achse durch die Hauptrichtung der Punktwolke: (Mitte, Richtung)."""
    ys, xs = np.nonzero(m)
    p = np.stack([xs, ys], 1).astype(float)
    c = p.mean(0)
    u, s, vt = np.linalg.svd(p - c, full_matrices=False)
    return c, vt[0]

def coords(mask, c, d):
    """t entlang der Achse, s quer dazu -- fuer jedes Pixel der Maske."""
    ys, xs = np.nonzero(mask)
    p = np.stack([xs, ys], 1).astype(float) - c
    n = np.array([-d[1], d[0]])
    return ys, xs, p @ d, p @ n

def span(t, s, tcore, half=20.0, limit=36.0, step=4.0):
    """Der t-Bereich der Rute: die zusammenhaengende Strecke, auf der der
    Querschnitt schmal bleibt. Die Rute misst quer 13-17 Px, an Ringen und
    Rolle bis 33 -- der Koerper sprengt jede dieser Zahlen sofort."""
    near = np.abs(s) < half
    lo, hi = t[near].min(), t[near].max()
    n = int((hi - lo) / step) + 1
    ok = np.zeros(n, bool)
    b = ((t - lo) / step).astype(int)
    for j in range(n):
        sel = near & (b == j)
        ok[j] = sel.any() and np.abs(s[sel]).max() * 2 <= limit
    j0 = int((np.median(tcore) - lo) / step)
    j0 = max(0, min(n - 1, j0))
    if not ok[j0]:                       # Kern liegt auf einem Ring: danebengreifen
        j0 = min((j for j in range(n) if ok[j]), key=lambda j: abs(j - j0))
    a = j0
    while a > 0 and ok[a - 1]: a -= 1
    z = j0
    while z + 1 < n and ok[z + 1]: z += 1
    return lo + a * step, lo + (z + 1) * step
