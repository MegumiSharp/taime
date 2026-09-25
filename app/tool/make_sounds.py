"""Synthesises Taime's bundled reminder sounds (no third-party audio).

Run: python tool/make_sounds.py  -> android/app/src/main/res/raw/*.wav
"""
import math
import os
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src', 'main', 'res', 'raw')


def tone(freqs, amps, dur, decay, attack=0.006, start=0.0, total=None, buf=None):
    n = int((total or dur + start) * RATE)
    buf = buf if buf is not None else [0.0] * n
    s0 = int(start * RATE)
    for i in range(int(dur * RATE)):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-t * decay)
        v = sum(a * math.sin(2 * math.pi * f * t) for f, a in zip(freqs, amps))
        if s0 + i < len(buf):
            buf[s0 + i] += v * env
    return buf


def save(name, buf):
    peak = max(abs(x) for x in buf) or 1
    # Short fade-out so nothing clicks.
    fade = int(0.05 * RATE)
    for i in range(fade):
        buf[-1 - i] *= i / fade
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(x / peak * 0.72 * 32767)) for x in buf))


def bell(f):
    return [f, f * 2.76, f * 5.4, f * 8.93], [1, 0.45, 0.2, 0.08]


# Campanella: two soft dings.
b = [0.0] * int(2.4 * RATE)
fr, am = bell(880)
tone(fr, am, 2.0, 3.2, start=0.0, buf=b)
tone(fr, am, 1.9, 3.2, start=0.38, buf=b)
save('campanella', b)

# Marimba: C5 E5 G5, woody and quick.
b = [0.0] * int(1.4 * RATE)
for k, f in enumerate([523.25, 659.25, 783.99]):
    tone([f, f * 4, f * 9.2], [1, 0.3, 0.06], 0.7, 8.5, start=k * 0.22, buf=b)
save('marimba', b)

# Gong morbido: low, slowly beating, long tail.
b = [0.0] * int(3.2 * RATE)
tone([196, 197.3, 298, 412], [1, 0.6, 0.35, 0.15], 3.1, 1.3, attack=0.03, buf=b)
save('gong', b)

# Due note: a gentle falling fifth.
b = [0.0] * int(1.5 * RATE)
tone([880, 1760], [1, 0.12], 0.8, 4.0, attack=0.02, start=0.0, buf=b)
tone([659.25, 1318.5], [1, 0.12], 0.9, 3.5, attack=0.02, start=0.42, buf=b)
save('duenote', b)

# Carillon: music-box arpeggio G5 B5 D6 G6.
b = [0.0] * int(1.9 * RATE)
for k, f in enumerate([783.99, 987.77, 1174.66, 1567.98]):
    tone([f, f * 3, f * 5.1], [1, 0.22, 0.07], 1.2, 4.2, start=k * 0.17, buf=b)
save('carillon', b)

print('ok', sorted(os.listdir(OUT)))
