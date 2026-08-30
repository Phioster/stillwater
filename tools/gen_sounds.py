#!/usr/bin/env python3
"""Erzeugt die Platzhalter-Klaenge als WAV.

Wie bei den Sprites: selbst erzeugt statt beschafft. Das haelt uns von
Lizenzfragen frei und passt zum Rest der Platzhalter. Alles hier ist
absichtlich schlicht -- kurze Huellkurven auf wenigen Sinustoenen.
"""
import math, os, struct, sys

RATE = 22050

def env(i, n, attack=0.01, release=0.6):
    """Huellkurve: schneller Anschlag, weiches Ausklingen."""
    t = i / n
    a = min(t / attack, 1.0) if attack > 0 else 1.0
    r = 1.0 - max(0.0, (t - (1.0 - release)) / release) if release > 0 else 1.0
    return a * max(r, 0.0) ** 1.5

def tone(freq, dur, vol=0.5, sweep=1.0, attack=0.01, release=0.6, harmonics=(1.0,)):
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq * (sweep ** (i / n))
        phase += 2.0 * math.pi * f / RATE
        s = sum(a * math.sin(phase * k) for k, a in enumerate(harmonics, start=1))
        out.append(s * vol * env(i, n, attack, release) / max(sum(harmonics), 1.0))
    return out

def noise(dur, vol=0.4, attack=0.005, release=0.9, seed=1):
    n = int(RATE * dur)
    x = seed
    out = []
    for i in range(n):
        x = (1103515245 * x + 12345) & 0x7fffffff
        out.append(((x / 0x3fffffff) - 1.0) * vol * env(i, n, attack, release))
    return out

def mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, v in enumerate(l):
            out[i] += v
    return out

def write(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = 0.85 / peak if peak > 0.85 else 1.0
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples)
    path = os.path.join(OUT, name + ".wav")
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVEfmt ")
        f.write(struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16))
        f.write(b"data" + struct.pack("<I", len(data)) + data)
    return path

SOUNDS = {
    # Wurf: ein Rauschwisch, der nach oben zieht.
    "cast":       lambda: mix(noise(0.30, 0.35, 0.01, 0.85, seed=7),
                              tone(320, 0.30, 0.18, sweep=2.2, release=0.8)),
    # Biss: zwei kurze, tiefe Plopps.
    "bite":       lambda: mix(tone(180, 0.09, 0.6, sweep=0.6, attack=0.002, release=0.9),
                              [0.0] * int(RATE * 0.11) + tone(150, 0.09, 0.5, sweep=0.6,
                                                              attack=0.002, release=0.9)),
    # Orb: heller, kurzer Klick.
    "orb":        lambda: tone(880, 0.07, 0.5, sweep=1.5, attack=0.001, release=0.9),
    # Rutenschlag: dumpfer Zug.
    "rod":        lambda: mix(tone(220, 0.10, 0.4, sweep=0.75, attack=0.002, release=0.85),
                              noise(0.06, 0.12, 0.002, 0.95, seed=11)),
    # Fang: kleine aufsteigende Terz.
    "catch":      lambda: mix(tone(523, 0.10, 0.35, attack=0.005, release=0.7),
                              [0.0] * int(RATE * 0.09) + tone(659, 0.10, 0.35, attack=0.005, release=0.7),
                              [0.0] * int(RATE * 0.18) + tone(784, 0.22, 0.4, attack=0.005, release=0.75)),
    # Entkommen: absteigend, kurz.
    "escape":     lambda: tone(400, 0.22, 0.4, sweep=0.45, attack=0.004, release=0.8),
    # Muenzen.
    "coin":       lambda: mix(tone(1200, 0.09, 0.30, attack=0.001, release=0.85, harmonics=(1.0, 0.4)),
                              [0.0] * int(RATE * 0.05) + tone(1600, 0.10, 0.25,
                                                              attack=0.001, release=0.85)),
    # Oberflaeche.
    "click":      lambda: tone(660, 0.05, 0.32, sweep=1.2, attack=0.001, release=0.9),
    "error":      lambda: tone(200, 0.16, 0.42, sweep=0.7, attack=0.002, release=0.7,
                               harmonics=(1.0, 0.5)),
    "level_up":   lambda: mix(tone(523, 0.12, 0.30, attack=0.004, release=0.7),
                              [0.0] * int(RATE * 0.10) + tone(784, 0.12, 0.30, attack=0.004, release=0.7),
                              [0.0] * int(RATE * 0.20) + tone(1046, 0.30, 0.38, attack=0.004, release=0.8)),
    # Schimmernder Fang: heller Nachschlag zum Fangklang.
    "shiny":      lambda: mix(tone(1318, 0.16, 0.28, attack=0.003, release=0.85),
                              [0.0] * int(RATE * 0.12) + tone(1760, 0.26, 0.3,
                                                              attack=0.003, release=0.85)),
}

if __name__ == "__main__":
    OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"
    os.makedirs(OUT, exist_ok=True)
    for name, make in sorted(SOUNDS.items()):
        p = write(name, make())
        print("%-10s %6d Bytes" % (name, os.path.getsize(p)))
