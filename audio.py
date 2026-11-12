"""Procedural soundtrack: mood-based music beds plus sound effects, no samples."""
import random
import wave

import numpy as np

SR = 44100


def _t(d):
    return np.arange(int(SR * d)) / SR


def midi(n):
    return 440 * 2 ** ((n - 69) / 12)


def tone(f, d, kind='pluck'):
    t = _t(d)
    if kind == 'pluck':
        w = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(4 * np.pi * f * t) + 0.25 * np.sin(6 * np.pi * f * t)) * np.exp(-t * 9)
    elif kind == 'bass':
        w = (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t)) * np.exp(-t * 6)
    elif kind == 'bell':
        w = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 5)
             + 0.25 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 9)) * np.exp(-t * 3.2)
    else:
        w = np.sin(2 * np.pi * f * t)
    a = min(len(w), 220)
    w[:a] *= np.linspace(0, 1, a)
    return w


def noise(d, smooth=1, seed=1):
    w = np.random.RandomState(seed).uniform(-1, 1, int(SR * d))
    if smooth > 1:
        w = np.convolve(w, np.ones(smooth) / smooth, 'same')
    return w


def add(buf, t0, w, g=1.0):
    i = int(t0 * SR)
    if i >= len(buf) or i < 0:
        return
    j = min(len(buf), i + len(w))
    buf[i:j] += w[:j - i] * g


def music(mood, dur, seed):
    buf = np.zeros(int(SR * dur) + SR)
    rnd = random.Random(seed)
    if mood == 'comedy':
        beat = 0.5
        chords = [(48, (60, 64, 67)), (45, (57, 60, 64)), (41, (57, 60, 65)), (43, (59, 62, 67))]
        scale = [72, 74, 76, 79, 81, 84]
        hat = noise(0.03, 1, 3) * np.exp(-_t(0.03) * 120)
        bar, t = 0, 0.0
        while t < dur:
            root, tri = chords[bar % 4]
            add(buf, t, tone(midi(root), 0.5, 'bass'), 0.5)
            add(buf, t + 2 * beat, tone(midi(root + 7), 0.5, 'bass'), 0.42)
            for k in (1, 3):
                for n in tri:
                    add(buf, t + k * beat, tone(midi(n), 0.22), 0.1)
            for e in range(8):
                add(buf, t + e * beat / 2, hat, 0.05 if e % 2 else 0.025)
                if rnd.random() < 0.5:
                    add(buf, t + e * beat / 2, tone(midi(rnd.choice(scale)), 0.3), 0.13)
            t += 4 * beat
            bar += 1
    elif mood == 'spooky':
        t = _t(dur + 1)
        buf += (np.sin(2 * np.pi * 55 * t) + 0.6 * np.sin(2 * np.pi * 82.6 * t)
                + 0.4 * np.sin(2 * np.pi * 110.7 * t)) * 0.16 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.3 * t))
        notes = [69, 72, 76, 75, 68, 72, 64, 63]
        tt, i = 0.4, 0
        while tt < dur:
            add(buf, tt, tone(midi(notes[i % len(notes)] + (12 if rnd.random() < 0.3 else 0)), 2.2, 'bell'), 0.16)
            add(buf, tt, tone(46, 0.4, 'bass'), 0.45)
            add(buf, tt + 0.28, tone(44, 0.3, 'bass'), 0.3)
            tt += 1.6
            i += 1
    elif mood == 'warm':
        beat = 0.3
        chords = [(41, (65, 69, 72, 77)), (48, (64, 67, 72, 76)), (50, (65, 69, 74, 77)), (46, (65, 70, 74, 77))]
        bar, t = 0, 0.0
        while t < dur:
            root, arp = chords[bar % 4]
            add(buf, t, tone(midi(root), 1.4, 'bass'), 0.4)
            for e in range(8):
                add(buf, t + e * beat, tone(midi(arp[(e * 3) % 4]), 0.9, 'bell'), 0.11)
            t += 8 * beat
            bar += 1
    return buf[:int(SR * dur)]


def sfx(name):
    if name == 'pop':
        t = _t(0.09)
        return np.sin(2 * np.pi * (380 + 5200 * t) * t) * np.exp(-t * 40) * 0.6
    if name == 'tick':
        t = _t(0.05)
        return np.sin(2 * np.pi * 1250 * t) * np.exp(-t * 90) * 0.5
    if name == 'ding':
        return (tone(1318, 0.9, 'bell') + tone(1976, 0.9, 'bell') * 0.5) * 0.5
    if name == 'msg':
        w = np.zeros(int(SR * 0.4))
        add(w, 0, tone(880, 0.16, 'bell'), 0.6)
        add(w, 0.1, tone(1175, 0.28, 'bell'), 0.6)
        return w
    if name == 'knock':
        w = np.zeros(int(SR * 0.9))
        t = _t(0.16)
        k = (np.sin(2 * np.pi * (120 - 250 * t) * t) + noise(0.16, 6, 2) * 0.6) * np.exp(-t * 34)
        for i in range(3):
            add(w, i * 0.23, k, 1.3)
        return w
    if name == 'whoosh':
        t = _t(0.38)
        return noise(0.38, 14, 5) * np.sin(np.pi * t / 0.38) ** 2 * 1.6
    if name == 'boom':
        t = _t(0.9)
        return (np.sin(2 * np.pi * (70 - 30 * t) * t) * np.exp(-t * 5) + noise(0.9, 30, 6) * np.exp(-t * 14) * 2) * 0.9
    if name == 'click':
        t = _t(0.06)
        return (noise(0.06, 2, 7) * np.exp(-t * 160) + np.sin(2 * np.pi * 2100 * t) * np.exp(-t * 110) * 0.5) * 1.2
    if name == 'sting':
        t = _t(1.3)
        w = sum(np.sign(np.sin(2 * np.pi * f * t)) * 0.3 + np.sin(2 * np.pi * f * t) for f in (220, 233.1, 311.1, 110))
        w = np.convolve(w, np.ones(12) / 12, 'same') * np.exp(-t * 3) * 0.3
        add(w, 0, sfx('boom'), 0.8)
        return w
    if name == 'fail':
        w = np.zeros(int(SR * 1.5))
        for i, n in enumerate((63, 62, 61, 60)):
            d = 0.28 if i < 3 else 0.6
            t = _t(d)
            f = midi(n) * (1 + (0.02 * np.sin(2 * np.pi * 6 * t) if i == 3 else 0))
            ph = 2 * np.pi * np.cumsum(f * np.ones(len(t))) / SR
            s = (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.33 * np.sin(3 * ph)) * np.minimum(1, t * 30) * np.exp(-t * (2 if i < 3 else 3))
            add(w, i * 0.28, s, 0.45)
        return w
    if name == 'meow':
        t = _t(0.6)
        f = 520 + 420 * np.sin(np.pi * t / 0.6) ** 0.6
        ph = 2 * np.pi * np.cumsum(f) / SR
        return (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph)) * np.sin(np.pi * t / 0.6) * 0.5
    if name == 'snore':
        t = _t(1.3)
        return noise(1.3, 40, 9) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 28 * t))) * np.sin(np.pi * t / 1.3) * 6
    if name == 'riser':
        t = _t(0.8)
        return np.sin(2 * np.pi * (200 + 900 * t) * t) * (t / 0.8) ** 2 * 0.4
    raise KeyError(name)


def build(tl, path, seed=1):
    n = int(SR * tl.total)
    out = np.zeros(n)
    moods = sorted({m for _, _, m in tl.moods if m != 'silent'})
    for m in moods:
        env = np.zeros(n)
        for s0, s1, mm in tl.moods:
            if mm == m:
                env[int(s0 * SR):int(s1 * SR)] = 1
        k = int(SR * 0.35)
        env = np.convolve(env, np.ones(k) / k, 'same')
        out += music(m, tl.total, seed) * env * 0.55
    cache = {}
    for t, name, g in tl.events:
        if name not in cache:
            cache[name] = sfx(name)
        add(out, t, cache[name], g * 0.6)
    fade = int(SR * 0.4)
    out[-fade:] *= np.linspace(1, 0, fade)
    out = np.tanh(out * 1.3)
    out = out / max(1e-6, np.abs(out).max()) * 0.86
    pcm = (np.repeat(out[:, None], 2, 1) * 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
