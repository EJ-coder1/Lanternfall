#!/usr/bin/env python3
"""Generates every sound effect and the music loop for Lanternfall from scratch.

All audio is synthesized by this script (sine/square/triangle/noise), so it is original
and carries the project's own license. Run from the project root:

    python3 tools/generate_audio.py
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT_SFX = "assets/audio/sfx"
OUT_MUSIC = "assets/audio/music"
random.seed(7)


def write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))


def osc(kind, phase):
    f = phase - math.floor(phase)
    if kind == "sine":
        return math.sin(2 * math.pi * f)
    if kind == "square":
        return 1.0 if f < 0.5 else -1.0
    if kind == "tri":
        return 4.0 * abs(f - 0.5) - 1.0
    if kind == "saw":
        return 2.0 * f - 1.0
    return random.uniform(-1, 1)


def sweep(f0, f1, dur, kind="sine", vol=0.5, decay=3.0, attack=0.004):
    n = int(dur * SR)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        freq = f0 + (f1 - f0) * t
        phase += freq / SR
        e = min(1.0, (i / SR) / attack) * math.exp(-decay * t)
        out.append(osc(kind, phase) * vol * e)
    return out


def noise(dur, vol=0.5, decay=6.0, smooth=0.0):
    n = int(dur * SR)
    out, prev = [], 0.0
    for i in range(n):
        t = i / n
        raw = random.uniform(-1, 1)
        prev = prev * smooth + raw * (1.0 - smooth)
        out.append(prev * vol * math.exp(-decay * t))
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


def seq(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def silence(dur):
    return [0.0] * int(dur * SR)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


def note(midi, dur, kind="square", vol=0.3, decay=4.0):
    return sweep(hz(midi), hz(midi), dur, kind, vol, decay)


def make_sfx():
    sfx = {
        "jump": sweep(300, 640, 0.14, "tri", 0.45, 3.5),
        "land": mix(noise(0.09, 0.35, 8.0, 0.8), sweep(95, 60, 0.09, "sine", 0.5, 6.0)),
        "slash": mix(noise(0.16, 0.28, 5.0, 0.35), sweep(1100, 280, 0.16, "sine", 0.3, 4.0)),
        "hit": mix(sweep(170, 70, 0.13, "square", 0.35, 5.0), noise(0.1, 0.3, 8.0, 0.4)),
        "hurt": sweep(420, 110, 0.3, "saw", 0.35, 3.0),
        "die": sweep(330, 55, 0.7, "saw", 0.4, 2.2),
        "flare": mix(sweep(380, 1250, 0.32, "sine", 0.4, 2.5),
                     sweep(1900, 2300, 0.32, "sine", 0.15, 3.0)),
        "pickup": seq(note(81, 0.06, "square", 0.25), note(88, 0.12, "square", 0.25, 5.0)),
        "checkpoint": seq(note(72, 0.1, "tri", 0.4), note(76, 0.1, "tri", 0.4),
                          note(79, 0.1, "tri", 0.4), note(84, 0.35, "tri", 0.4, 3.0)),
        "enemy_windup": sweep(110, 280, 0.55, "saw", 0.22, 0.8, attack=0.05),
        "lunge": mix(noise(0.22, 0.3, 4.0, 0.5), sweep(200, 90, 0.22, "square", 0.2, 4.0)),
        "enemy_die": mix(noise(0.3, 0.3, 5.0, 0.6), sweep(260, 50, 0.38, "square", 0.3, 3.0)),
        "reveal": mix(sweep(900, 1600, 0.45, "sine", 0.28, 2.0, attack=0.05),
                      sweep(1350, 1900, 0.45, "tri", 0.12, 2.5, attack=0.05)),
        "victory": seq(note(72, 0.14, "tri", 0.4), note(76, 0.14, "tri", 0.4),
                       note(79, 0.14, "tri", 0.4), note(84, 0.14, "tri", 0.4),
                       note(88, 0.7, "tri", 0.45, 2.0)),
        "ui_click": sweep(700, 760, 0.06, "square", 0.2, 6.0),
        "deny": sweep(160, 130, 0.14, "square", 0.25, 5.0),
    }
    for name, samples in sfx.items():
        write_wav(f"{OUT_SFX}/{name}.wav", samples)


def make_music():
    """24 second ambient loop: Am - F - C - G, wraps around so it loops without a click."""
    bpm = 80
    beat = 60.0 / bpm
    total_beats = 32
    n = int(total_beats * beat * SR)
    buf = [0.0] * n

    def add(start_s, dur_s, midi, vol, kind, attack, release, decay=0.0):
        f = hz(midi)
        start = int(start_s * SR)
        count = int(dur_s * SR)
        phase = 0.0
        for i in range(count):
            t = i / SR
            phase += f / SR
            e = min(1.0, t / attack) if attack > 0 else 1.0
            tail = dur_s - t
            if tail < release:
                e *= tail / release
            if decay:
                e *= math.exp(-decay * t)
            buf[(start + i) % n] += osc(kind, phase) * vol * e

    chords = [
        (45, [57, 60, 64], [69, 72, 76]),   # Am
        (41, [53, 57, 60], [65, 69, 72]),   # F
        (48, [52, 55, 60], [67, 72, 76]),   # C
        (43, [50, 55, 59], [67, 71, 74]),   # G
    ]
    for ci, (bass, pad, arp) in enumerate(chords):
        start = ci * 8 * beat
        length = 8 * beat
        add(start, length + 0.6, bass, 0.20, "sine", 0.6, 0.6)
        for m in pad:
            add(start, length + 0.8, m, 0.075, "tri", 0.9, 0.9)
        pattern = [0, 1, 2, 1, 2, 1, 0, 1]
        for k in range(16):
            m = arp[pattern[k % len(pattern)]]
            add(start + k * beat / 2, beat * 1.4, m, 0.09, "sine", 0.005, 0.2, decay=2.4)
    peak = max(abs(s) for s in buf) or 1.0
    scale = 0.7 / peak
    write_wav(f"{OUT_MUSIC}/wilds.wav", [s * scale for s in buf])


if __name__ == "__main__":
    make_sfx()
    make_music()
    print("audio generated")
