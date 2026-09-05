"""Rute und Figur endgueltig trennen.

Zwei Regeln, weil eine nicht reicht: wo die Rute frei steht, verraet sie ihr
schmaler Querschnitt; wo sie vor dem Koerper liegt, hilft nur noch die Farbe
-- die Figur ist durchweg warm, die Rute zu knapp der Haelfte kuehl.
"""
import numpy as np
from axis import core, biggest, fit, coords

HALF = 20.0      # Suchband quer zur Achse
LIMIT = 36.0     # breiter heisst: hier steht die Figur, nicht die Rute
STEP = 8.0       # Streifenbreite entlang der Achse
PROBE = 60.0     # so weit schaut der Streifen zur Seite, um Koerper zu finden
BODY = 210       # gemessen: freie Rutenstreifen haben 72-180 Pixel, Streifen
                 # mit Koerper 230-960. Dazwischen ist viel Luft.
DARK = 130       # Helligkeitsgrenze in der 32er-Palette: Schaft, Rolle und
                 # Ringe liegen darunter, Haut und Pullover ab 170 darueber.

def rod_mask(mask, rgb, qrgb):
    """Maske der Rute. Liefert zusaetzlich Achse und Griff-/Spitzenparameter."""
    k = biggest(core(mask, rgb))
    c, d = fit(k)
    if d[0] < 0: d = -d
    ys, xs, t, s = coords(mask, c, d)
    _, _, tc, sc = coords(k, c, d)
    near = np.abs(s) < HALF
    lo, hi = t[near].min(), t[near].max()
    n = int((hi - lo) / STEP) + 1
    b = np.clip(((t - lo) / STEP).astype(int), 0, n - 1)

    # Wie weit reicht die Rute? Bis dahin, wo der Querschnitt schmal bleibt.
    narrow = np.zeros(n, bool)
    for j in range(n):
        sel = near & (b == j)
        narrow[j] = sel.any() and np.abs(s[sel]).max() * 2 <= LIMIT
    j0, j1 = int((tc.min() - lo) / STEP), int((tc.max() - lo) / STEP)
    j0, j1 = max(0, min(n - 1, j0)), max(0, min(n - 1, j1))
    while j1 + 1 < n and narrow[j1 + 1]: j1 += 1
    while j0 > 0 and narrow[j0 - 1]: j0 -= 1
    # (Der Griff hinter der Faust kommt weiter unten dazu.)

    # Das Schaftfenster kommt aus der Dichte des Kerns, nicht aus seinen
    # Raendern: dicht besetzt ist nur der Schaft (s etwa -8 bis +5), der
    # duenne Ausläufer darunter sind Ringe und Rolle. Die haengen frei und
    # brauchen das Fenster nicht -- vor dem Koerper haette es sonst die
    # Finger unter dem Schaft mitgenommen.
    R, G, B = qrgb[:, :, 0], qrgb[:, :, 1], qrgb[:, :, 2]
    lum = (R[ys, xs] * 299 + G[ys, xs] * 587 + B[ys, xs] * 114) // 1000
    cool = B[ys, xs] >= R[ys, xs] - 4
    probe = np.abs(s) < PROBE
    hist, edges = np.histogram(sc, bins=np.arange(-HALF, HALF + 1))
    dense = np.flatnonzero(hist >= hist.max() * 0.25)
    s_lo, s_hi = edges[dense[0]], edges[dense[-1] + 1]
    inside = (s >= s_lo - 1) & (s <= s_hi + 1)

    # Gemessen wird auf der quantisierten Fassung: dort gibt es keine
    # Zwischentoene mehr, an denen sich ein relativer Schwellwert verhakt.
    # Hinter der Faust hoert der schmale Querschnitt auf, die Rute aber
    # nicht: dort steckt der Korkgriff. Solange auf der Achse Rutenmaterial
    # liegt -- kuehl oder dunkler als 130 --, laeuft der Bereich weiter.
    while j0 > 0:
        prev = near & (b == j0 - 1) & inside
        if (prev & (cool | (lum < DARK))).sum() < 8: break
        j0 -= 1

    take = np.zeros(len(t), bool)
    wide_take = np.zeros(len(t), bool)
    for j in range(j0, j1 + 1):
        binj = near & (b == j)
        if not binj.any(): continue
        if (probe & (b == j)).sum() <= BODY:
            take |= binj; wide_take |= binj
            continue
        # Das Schaftfenster begrenzt nur die HELLEN Pixel (Finger unter dem
        # Schaft). Dunkles Messing darf ueberall im Band durch, sonst fehlt
        # der Ring, der hier gerade vor dem Koerper haengt.
        take |= binj & (cool | (lum < DARK)) & (inside | (lum < DARK))
        wide_take |= binj & (cool | (lum < DARK + 30)) & (inside | (lum < DARK))
    # Was hell ist und neben dem Schaft liegt, gehoert der Figur -- der Kork
    # sitzt auf der Achse und bleibt davon unberuehrt.
    fringe = (lum > 150) & ~inside
    take &= ~fringe; wide_take &= ~fringe
    out = np.zeros(mask.shape, bool); out[ys[take], xs[take]] = True
    ok = np.zeros(mask.shape, bool); ok[ys[wide_take], xs[wide_take]] = True
    return out, ok, c, d, lo + j0 * STEP, lo + (j1 + 1) * STEP

def _shift(m, dy, dx):
    o = np.zeros_like(m)
    ys = slice(max(dy, 0), m.shape[0] + min(dy, 0))
    xs = slice(max(dx, 0), m.shape[1] + min(dx, 0))
    yt = slice(max(-dy, 0), m.shape[0] + min(-dy, 0))
    xt = slice(max(-dx, 0), m.shape[1] + min(-dx, 0))
    o[ys, xs] = m[yt, xt]
    return o

def grow(m, n=1):
    for _ in range(n):
        m = m | _shift(m, 1, 0) | _shift(m, -1, 0) | _shift(m, 0, 1) | _shift(m, 0, -1)
    return m

def keep_main(m, bridge=2, floor=40):
    """Nur die zusammenhaengende Rute. Der Farbtest greift auch mal einen
    Sprenkel Haut oder Pullover ab -- der haengt an nichts und faellt hier weg."""
    from collections import deque
    h, w = m.shape
    seen = np.zeros_like(m); best = []
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        if seen[y, x]: continue
        q = deque([(y, x)]); seen[y, x] = True; comp = []
        while q:
            cy, cx = q.popleft(); comp.append((cy, cx))
            for dy in range(-bridge, bridge + 1):
                for dx in range(-bridge, bridge + 1):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True; q.append((ny, nx))
        if len(comp) > len(best): best = comp
    out = np.zeros_like(m)
    if len(best) >= floor:
        for y, x in best: out[y, x] = True
    return out

def fill(idx, mask, hole):
    """Loecher, die die Rute im Koerper hinterlaesst, mit der naechsten
    Koerperfarbe schliessen -- sonst klafft im Bein ein Spalt."""
    have = mask & ~hole
    out = idx.copy()
    todo = hole.copy()
    while todo.any():
        ring = grow(have, 1) & todo
        if not ring.any(): break
        left = ring.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            t = left & _shift(have, dy, dx)
            # aus out lesen, nicht aus idx: sonst reicht der zweite Ring
            # den Wert 0 weiter statt der eben gesetzten Koerperfarbe.
            out[t] = _shift(out * have, dy, dx)[t]
            left = left & ~t
        have = have | ring; todo = todo & ~ring
    return out
