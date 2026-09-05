"""Die duenne Saat: was eine morphologische Oeffnung wegnimmt, ist die Rute."""
import numpy as np

INF = 1 << 20

def dist(mask):
    """Chamfer-3-4-Abstand jedes gesetzten Pixels zum naechsten leeren."""
    h, w = mask.shape
    d = np.where(mask, INF, 0).astype(np.int32)
    for y in range(h):
        r = d[y]
        if y:
            u = d[y - 1]
            np.minimum(r, u + 3, out=r)
            np.minimum(r[1:], u[:-1] + 4, out=r[1:])
            np.minimum(r[:-1], u[1:] + 4, out=r[:-1])
        for x in range(1, w):          # links-nach-rechts muss laufen
            if r[x] > r[x - 1] + 3: r[x] = r[x - 1] + 3
    for y in range(h - 1, -1, -1):
        r = d[y]
        if y + 1 < h:
            u = d[y + 1]
            np.minimum(r, u + 3, out=r)
            np.minimum(r[1:], u[:-1] + 4, out=r[1:])
            np.minimum(r[:-1], u[1:] + 4, out=r[:-1])
        for x in range(w - 2, -1, -1):
            if r[x] > r[x + 1] + 3: r[x] = r[x + 1] + 3
    return d

def thin(mask, radius):
    """Maske der duennen Teile: alles, was eine Oeffnung mit radius wegnimmt."""
    r3 = radius * 3
    core = dist(mask) >= r3
    return mask & (dist(~core) > r3)
