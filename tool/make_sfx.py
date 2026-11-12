"""Synthesises every sound in Keeper of the Cove from scratch: no samples, no
third-party audio, no licences. Run from the project root:

    python tool/make_sfx.py

Writes assets/audio/*.ogg (needs numpy and ffmpeg with libvorbis on PATH).
Everything is soft: bells, buoy rings, a far-off foghorn, the sea itself.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(ROOT, 'assets', 'audio')
rng = np.random.default_rng(1852)  # fixed seed: the same sounds every run


def t_axis(dur):
    return np.arange(int(RATE * dur)) / RATE


def bell(freq, dur, decay=4.0, partials=((1, 1.0), (2.0, 0.4), (3.01, 0.18), (4.2, 0.07)),
         attack=0.006):
    """A struck bell: inharmonic partials, each fading at its own rate."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for k, (mult, amp) in enumerate(partials):
        out += amp * np.sin(2 * np.pi * freq * mult * t) * np.exp(-decay * (1 + 0.6 * k) * t)
    return out * np.minimum(1, t / attack)


def tone(freq, dur, attack=0.05, release=0.3, vibrato=0.0):
    t = t_axis(dur)
    phase = 2 * np.pi * freq * t + vibrato * np.sin(2 * np.pi * 5 * t)
    env = np.minimum(1, t / attack) * np.minimum(1, (dur - t) / release)
    return np.sin(phase) * np.clip(env, 0, 1)


def noise(dur, smooth=0.995):
    """Brown-ish noise: the sound of water and wind."""
    white = rng.standard_normal(int(RATE * dur))
    out = np.empty_like(white)
    acc = 0.0
    a = 1 - smooth
    for i, w in enumerate(white):
        acc = smooth * acc + a * w
        out[i] = acc
    return out / (np.max(np.abs(out)) + 1e-9)


def lowpass(x, cutoff):
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def mix(*parts):
    """parts: (offset_seconds, samples, gain)."""
    n = max(int(o * RATE) + len(s) for o, s, _ in parts)
    out = np.zeros(n)
    for o, s, g in parts:
        k = int(o * RATE)
        out[k:k + len(s)] += s * g
    return out


def fade(x, fin=0.005, fout=0.05):
    n = len(x)
    env = np.ones(n)
    a, b = int(RATE * fin), int(RATE * fout)
    if a:
        env[:a] = np.linspace(0, 1, a)
    if b:
        env[n - b:] = np.linspace(1, 0, b)
    return x * env


def reverb(x, room=0.32, taps=((0.031, 0.5), (0.047, 0.42), (0.071, 0.33), (0.113, 0.24), (0.167, 0.16))):
    """A small stone-room reverb: the lamp room at the top of the tower."""
    tail = int(RATE * 0.6)
    out = np.concatenate([x, np.zeros(tail)])
    for delay, gain in taps:
        d = int(RATE * delay)
        out[d:d + len(x)] += x * gain * room * 3
    return out


def write(name, samples, peak=0.7):
    os.makedirs(OUT, exist_ok=True)
    samples = samples / (np.max(np.abs(samples)) + 1e-9) * peak
    pcm = (np.clip(samples, -1, 1) * 32767).astype('<i2')
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        path = tmp.name
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    dest = os.path.join(OUT, name + '.ogg')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', path, '-c:a', 'libvorbis',
                    '-q:a', '4', dest], check=True)
    os.remove(path)
    print(f'{name:12s} {len(samples) / RATE:5.2f}s {os.path.getsize(dest) // 1024:4d} KB')


# --- Interface -------------------------------------------------------------
# A brass latch: short, warm click for buttons and hotspots.
write('tap', fade(reverb(bell(740, 0.16, decay=26, partials=((1, 1), (2.7, 0.3))))), 0.5)
# A page of the logbook turning.
page = lowpass(noise(0.35, smooth=0.9), 2400) * np.exp(-9 * t_axis(0.35))
write('page', fade(page, 0.01, 0.1), 0.45)

# --- Night -----------------------------------------------------------------
# The ring starts filling: a tiny glass tick.
write('chart', fade(bell(1568, 0.25, decay=16, partials=((1, 1), (2.4, 0.2)))), 0.35)
# Charted: the boat turns for home, two rising notes.
write('charted', reverb(mix((0, bell(659, 0.9, 4.5), 1), (0.11, bell(988, 1.1, 4), 0.9))), 0.55)
# A soul is home: the harbour bell, low and round.
write('home', reverb(mix((0, bell(392, 2.2, 1.8), 1), (0, bell(784, 1.4, 3), 0.25))), 0.6)
# Lost: a muffled foghorn far away. Sad, never frightening.
horn = tone(98, 1.6, attack=0.25, release=0.8, vibrato=0.02) * 0.7 + tone(147, 1.6, attack=0.3, release=0.8) * 0.3
write('lost', fade(lowpass(horn, 500), 0.02, 0.4), 0.45)
# An ember gutters out: a soft breath of air.
breath = lowpass(noise(0.7, smooth=0.97), 900) * np.sin(np.pi * t_axis(0.7) / 0.7) ** 2
write('ember', fade(breath, 0.01, 0.2), 0.4)
# A bell buoy kindled: two strokes of a buoy bell, rocking.
write('kindle', reverb(mix((0, bell(523, 1.6, 2.4), 1), (0.38, bell(523, 1.4, 2.6), 0.7))), 0.6)
# A buoy's halo goes dark.
write('buoy_out', fade(bell(330, 0.8, 5, partials=((1, 1), (2.0, 0.2)))), 0.3)

# --- Results and rewards --------------------------------------------------
# Dawn: a slow major arpeggio, like light arriving.
dawn = mix(*[(i * 0.22, bell(f, 2.6, 1.6), 1 - i * 0.12) for i, f in enumerate((392, 494, 587, 784))])
write('dawn', reverb(dawn), 0.6)
# One lantern lit on the result card.
write('lantern', fade(bell(1175, 0.6, 7, partials=((1, 1), (2.76, 0.22)))), 0.45)
# The dark watch: a low chord that fades, calm and final.
dark = mix((0, tone(147, 2.4, 0.4, 1.4), 0.6), (0, tone(220, 2.4, 0.5, 1.4), 0.4), (0, tone(175, 2.4, 0.6, 1.4), 0.3))
write('dark', fade(lowpass(dark, 900), 0.05, 0.6), 0.45)
# Unlock / achievement: a bright two-note sparkle.
write('unlock', reverb(mix((0, bell(880, 0.8, 5), 1), (0.12, bell(1319, 1.0, 4.5), 0.8), (0.24, bell(1760, 0.9, 6), 0.4))), 0.55)
# Purchase: lamp oil poured, then a soft bell.
pour = lowpass(noise(0.45, smooth=0.6), 3200) * np.exp(-5 * t_axis(0.45))
write('purchase', mix((0, pour, 0.5), (0.3, bell(698, 1.0, 4), 1)), 0.5)

# --- Ambience --------------------------------------------------------------
# The sea at night: slow swells of surf, a breath of wind, and a far bell
# buoy now and then. 32 s, crossfaded so it loops without a seam.
DUR = 32.0
t = t_axis(DUR + 2)
surf = lowpass(noise(DUR + 2, smooth=0.996), 420)
swell = 0.45 + 0.55 * np.sin(2 * np.pi * t / 8.0) ** 4
wind = lowpass(noise(DUR + 2, smooth=0.9993), 260) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 16.0 + 1.3))
sea = surf * swell * 0.9 + wind * 0.5
for at in (5.0, 21.0):
    b = bell(523, 4.0, 1.1) * 0.05
    k = int(at * RATE)
    sea[k:k + len(b)] += b
n = int(DUR * RATE)
x = int(2 * RATE)
loop = sea[:n].copy()
loop[:x] = loop[:x] * np.linspace(0, 1, x) + sea[n:n + x] * np.linspace(1, 0, x)
write('sea_loop', loop, 0.5)

# A quiet keeper's tune for the hub: a few slow notes over the sea (48 s).
DUR = 48.0
melody = [(0, 392), (3, 440), (6, 494), (9, 587), (15, 523), (18, 494), (21, 440), (27, 392),
          (30, 330), (33, 392), (36, 440), (42, 392)]
parts = [(at, bell(f, 5.0, 0.9, partials=((1, 1), (2.0, 0.25), (3.0, 0.08))), 0.32) for at, f in melody]
pad = sum(tone(f, DUR, attack=6, release=6) for f in (196, 247, 294)) * 0.06
music = mix((0, pad, 1), *parts)[:int(DUR * RATE)]
x = int(3 * RATE)
music[:x] *= np.linspace(0, 1, x)
music[-x:] *= np.linspace(1, 0, x)
write('keeper_tune', reverb(music)[:int(DUR * RATE)], 0.45)
