"""Farbreduktion und Rute/Figur-Trennung fuer die gezeichneten Sitzposen.

Das gelieferte Bild ist glatt gemalt, nicht gerastert -- 60 000 Farben, und
die Rute versteckt sich zwischen den Zwischentoenen. Erst die Farben auf eine
kleine Palette zwingen, dann laesst sich die Rute als eigene Farbfamilie
herausziehen.
"""
import sys
import numpy as np
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else 'assets/source/sit_poses_raw.png'

def load():
    # int32, nicht int16: die Helligkeit rechnet R*299 + G*587 + B*114, und
    # das laeuft in 16 Bit still ueber -- die Dunkelheitstests bekamen Muell.
    return np.array(Image.open(SRC).convert('RGBA'), dtype=np.int32)

def poses(a):
    """Die vier Posen als Ausschnitte -- an den Luecken in der Alphaspalte."""
    col = (a[:, :, 3] > 128).any(axis=0)
    runs, s = [], None
    for x, v in enumerate(col):
        if v and s is None: s = x
        if not v and s is not None:
            if x - s > 40: runs.append((s, x))
            s = None
    if s is not None: runs.append((s, len(col)))
    out = []
    for x0, x1 in runs:
        row = (a[:, x0:x1, 3] > 128).any(axis=1)
        ys = np.flatnonzero(row)
        out.append((x0, x1, int(ys[0]), int(ys[-1]) + 1))
    return out

def kmeans(px, k, iters=24, seed=0):
    """k-Means in RGB. px ist (n,3) float."""
    rng = np.random.default_rng(seed)
    c = px[rng.choice(len(px), k, replace=False)].astype(np.float64)
    for _ in range(iters):
        d = ((px[:, None, :] - c[None, :, :]) ** 2).sum(2)
        lab = d.argmin(1)
        for j in range(k):
            m = lab == j
            if m.any(): c[j] = px[m].mean(0)
    return c

def assign(px, c):
    """Nachstgelegene Palettenfarbe, blockweise damit der Speicher reicht."""
    out = np.empty(len(px), dtype=np.int32)
    for i in range(0, len(px), 20000):
        b = px[i:i + 20000]
        out[i:i + 20000] = ((b[:, None, :] - c[None, :, :]) ** 2).sum(2).argmin(1)
    return out
