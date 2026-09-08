#!/usr/bin/env python3
"""Rebuild Stormwright's original synthesized sounds with only Python's stdlib.

No recordings, downloaded samples, external services or dependencies are used.
Sound design: icy modal harmonics over filtered air, electric transients and stone.
All samples have tapered edges and conservative peaks; the game adds voice limits.
"""

from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio"
RATE = 32000
TAU = math.tau


def envelope(t, duration, attack=0.008, decay=3.0):
    return min(1.0, t / attack) * max(0.0, 1.0 - t / duration) ** decay


def render(name, duration, fn, gain=0.72, echo=0.0, loop=False):
    n = int(duration * RATE)
    rng = random.Random("stormwright_" + name)
    raw = []
    lo = 0.0
    mid = 0.0
    for i in range(n):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        lo += 0.023 * (noise - lo)
        mid += 0.19 * (noise - mid)
        sample = fn(t, duration, noise, lo, mid)
        if not loop:
            sample *= min(1.0, t / 0.003, max(0.0, (duration - t) / 0.018))
        raw.append(sample)
    if echo:
        dry = raw[:]
        for delay, scale in [(0.083, echo), (0.137, echo * 0.55), (0.231, echo * 0.30)]:
            offset = int(RATE * delay)
            for i in range(offset, n):
                raw[i] += dry[i - offset] * scale
    peak = max(abs(v) for v in raw) or 1.0
    norm = gain / max(1.0, peak)
    data = bytearray()
    for i, v in enumerate(raw):
        # The low body remains centered; a restrained decorrelated tail gives width.
        side = raw[max(0, i - 191)] * 0.075
        left = max(-0.94, min(0.94, (v + side) * norm))
        right = max(-0.94, min(0.94, (v - side) * norm))
        data.extend(struct.pack("<hh", round(left * 32767), round(right * 32767)))
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / (name + ".wav")), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(data)
    print(f"{name}: {duration:.2f}s, stereo, {len(data):,} bytes")


def lance_charge(t, d, n, lo, mid):
    swell = math.sin(math.pi * t / d) ** 0.7
    return swell * (0.15 * math.sin(TAU * (230 * t + 1900 * t * t)) + 0.12 * mid + 0.08 * math.sin(TAU * 587.33 * t))


def lance(t, d, n, lo, mid):
    core = 0.52 * math.sin(TAU * (86 * t + 15 * math.exp(-t * 22))) * math.exp(-t * 13)
    crack = (n - mid) * 0.54 * math.exp(-t * 34)
    electric = (math.sin(TAU * 1174.66 * t + math.sin(TAU * 43 * t) * 4) + 0.4 * math.sin(TAU * 2349.32 * t)) * 0.13 * math.exp(-t * 8)
    tail = mid * 0.38 * math.exp(-t * 4) + 0.07 * math.sin(TAU * 293.665 * t) * math.exp(-t * 5)
    return (core + crack + electric + tail) * min(1, t / 0.004)


def crown(t, d, n, lo, mid):
    bloom = min(1, t / 0.25) * math.exp(-t * 1.9)
    choir = sum(math.sin(TAU * f * t + math.sin(TAU * 1.3 * t) * 0.2) / (i + 2) for i, f in enumerate([293.665, 440, 587.33, 698.46, 880]))
    shimmer = 0.0
    for i in range(7):
        a = t - i * 0.067
        if a >= 0:
            shimmer += 0.05 * math.sin(TAU * (1174.66 + i * 71.2) * a) * math.exp(-a * 12)
    return choir * bloom * 0.25 + shimmer + mid * 0.12 * bloom


def crown_fire(t, d, n, lo, mid):
    phase = TAU * (1150 * t - 1050 * t * t)
    whisper = mid * 0.25 * envelope(t, d, 0.01, 2)
    return (0.25 * math.sin(phase) + 0.11 * math.sin(phase * 1.5)) * math.exp(-t * 14) + whisper + 0.22 * (n - mid) * math.exp(-t * 70)


def cataclysm_charge(t, d, n, lo, mid):
    a = min(t / 0.65, 1)
    swell = math.sin(math.pi * min(t / d, 1)) ** 0.65
    gravity = 0.27 * math.sin(TAU * (54 * t + 45 * t * t)) + 0.12 * math.sin(TAU * (147 * t + 250 * t * t))
    climbing = math.sin(TAU * (360 * t + 700 * t * t)) * a * 0.15
    return (gravity + climbing + mid * 0.32 * a) * swell


def cataclysm(t, d, n, lo, mid):
    sub = (math.sin(TAU * (46 * t + 2.8 * (1 - math.exp(-t * 12)))) * 0.65 + math.sin(TAU * 73.416 * t) * 0.22) * math.exp(-t * 3.5)
    fracture = (n - mid) * 0.75 * math.exp(-t * 34)
    thunder = (mid * 0.45 + lo * 2.0) * math.exp(-t * 1.7)
    rim = math.sin(TAU * 587.33 * t + math.sin(TAU * 19 * t)) * 0.13 * math.exp(-t * 5)
    debris = 0.0
    for delay in [0.15, 0.31, 0.49, 0.73, 1.06]:
        a = t - delay
        if a >= 0:
            debris += mid * 0.28 * math.exp(-a * 22)
    return sub + fracture + thunder + rim + debris


def hit(t, d, n, lo, mid):
    return (0.43 * mid + 0.19 * math.sin(TAU * (180 * t - 120 * t * t))) * math.exp(-t * 20) + 0.13 * math.sin(TAU * 1760 * t) * math.exp(-t * 35)


def death(t, d, n, lo, mid):
    return (mid * 0.50 + lo * 0.70 + math.sin(TAU * (80 * t - 20 * t * t)) * 0.26) * math.exp(-t * 6) + 0.04 * math.sin(TAU * 880 * t) * math.exp(-t * 9)


def dash(t, d, n, lo, mid):
    env = math.sin(math.pi * t / d) ** 1.5
    return env * (mid * 0.36 + 0.17 * math.sin(TAU * (190 * t - 125 * t * t)))


def step(t, d, n, lo, mid):
    return (lo * 0.8 + mid * 0.24 + 0.13 * math.sin(TAU * 95 * t)) * math.exp(-t * 38)


def enemy_charge(t, d, n, lo, mid):
    env = math.sin(math.pi * t / d) ** 0.7
    return env * (math.sin(TAU * (170 * t + 45 * t * t)) * 0.22 + math.sin(TAU * 181 * t) * 0.10 + mid * 0.09)


def enemy_attack(t, d, n, lo, mid):
    return (mid * 0.49 + 0.25 * math.sin(TAU * (125 * t - 82 * t * t))) * math.exp(-t * 11)


def melody(notes, length, bright=1.0):
    def fn(t, d, n, lo, mid):
        total = 0.0
        for i, freq in enumerate(notes):
            a = t - i * length
            if a >= 0:
                env = min(a / 0.008, 1) * math.exp(-a * 3.4)
                total += (math.sin(TAU * freq * a) + 0.24 * math.sin(TAU * freq * 2.002 * a) + 0.07 * math.sin(TAU * freq * 3.99 * a)) * env * 0.23 * bright
        return total
    return fn


def ambience(t, d, n, lo, mid):
    # Integer cycles across 16 seconds keep harmonic loop boundaries continuous.
    base = (math.sin(TAU * 73.4375 * t) * 0.047 + math.sin(TAU * 110 * t) * 0.025 + math.sin(TAU * 146.875 * t) * 0.016)
    breath = 0.65 + 0.35 * math.sin(TAU * t / 16)
    air = lo * 0.23 * breath
    wind = math.sin(TAU * 0.125 * t) * math.sin(TAU * 440 * t) * 0.005
    # Noise cross-fades itself down to silence at the loop seam; the tones continue.
    seam = min(1.0, t / 0.5, (d - t) / 0.5)
    return base + (air + wind) * seam


if __name__ == "__main__":
    specs = [
        ("lance_charge", 0.22, lance_charge, 0.72, 0.1),
        ("lance", 0.92, lance, 0.75, 0.21),
        ("crown", 1.55, crown, 0.72, 0.24),
        ("crown_fire", 0.48, crown_fire, 0.72, 0.18),
        ("cataclysm_charge", 0.73, cataclysm_charge, 0.72, 0.05),
        ("cataclysm", 2.70, cataclysm, 0.82, 0.24),
        ("hit", 0.28, hit, 0.63, 0.07),
        ("death", 0.81, death, 0.73, 0.1),
        ("dash", 0.30, dash, 0.80, 0.1),
        ("step", 0.12, step, 0.52, 0),
        ("enemy_charge", 0.48, enemy_charge, 0.72, 0.1),
        ("enemy_attack", 0.49, enemy_attack, 0.71, 0.12),
        ("upgrade", 1.15, melody([587.33, 739.99, 880], 0.105), 0.72, 0.22),
        ("victory", 3.2, melody([293.665, 440, 587.33, 739.99, 880, 1174.66], 0.24), 0.74, 0.28),
        ("defeat", 2.8, melody([440, 349.23, 293.665, 220], 0.32, 0.85), 0.75, 0.2),
    ]
    for spec in specs:
        render(*spec)
    render("arena_ambience", 16.0, ambience, gain=0.83, loop=True)
