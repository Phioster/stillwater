"""Die vier Sitzposen auf ein gemeinsames 256er-Feld bringen.

Ausgerichtet wird an zwei gemessenen Groessen: der Stiefelsohle und dem
Sitzpunkt (hinterste Stelle der Huefte auf der Sitzlinie). Die Sitzlinie
selbst liegt in allen vier rund 278 Pixel ueber der Sohle -- gemessen, nicht
gewaehlt.
"""
import numpy as np
from PIL import Image

SRC = ('/data/data/com.termux/files/home/.claude/uploads/'
       '11b834f3-c33b-4d10-b5a2-6954415539d5/a08c5e07-image.png')
FRAME = 256
BODY = 200      # Scheitel bis Sohle im fertigen Feld
SOLE = 236      # auf welcher Zeile die Sohle landet
SEAT_X = 128    # auf welcher Spalte die Stiefel stehen

a = np.array(Image.open(SRC).convert('RGBA'))
lab = np.load('c_lab.npy'); bx = np.load('c_box.npy')

# Sitzlinie relativ zur Sohle -- der Mittelwert der vier Messungen.
SEAT_UP = 278

frames = []
for i, (c, x0, x1, y0, y1) in enumerate(bx):
    m = lab == c
    rows = np.flatnonzero(m.any(1)); cols = np.flatnonzero(m.any(0))
    crown, sole = rows[0], rows[-1]
    seat_row = sole - SEAT_UP
    # Anker ist die Stiefelmitte, nicht die Huefte: der Zopf haengt bis auf
    # Sitzhoehe herunter und wanderte sonst als "hinterste Stelle" durch.
    boot = m[sole - 18:sole + 1]
    bc = np.flatnonzero(boot.any(0))
    seat_x = int((bc[0] + bc[-1]) / 2)
    s = BODY / float(sole - crown)
    print('Pose %d  Hoehe %3d -> Faktor %.4f   Stiefelmitte x=%4d, Sitzzeile %3d'
          % (i, sole - crown, s, seat_x, seat_row))
    # zuschneiden, skalieren, einsetzen
    sub = a[y0:y1, x0:x1].copy()
    sub[~m[y0:y1, x0:x1]] = 0
    nw, nh = max(1, round(sub.shape[1] * s)), max(1, round(sub.shape[0] * s))
    im = Image.fromarray(sub, 'RGBA').resize((nw, nh), Image.LANCZOS)
    out = Image.new('RGBA', (FRAME, FRAME), (0, 0, 0, 0))
    ox = SEAT_X - round((seat_x - x0) * s)
    oy = SOLE - round((sole - y0) * s)
    out.paste(im, (ox, oy), im)
    frames.append(out)
    out.save('f_raw_%d.png' % i)
print('geschrieben: f_raw_0..3.png')
