"""Synthesises Lanternfall's own sound effects (soft, short, quiet) into assets/sfx/.

Every sound is made from sine/triangle tones and filtered noise with soft attacks, so nothing clicks or hisses.
Run: python3 tools/sfx/generate.py  (needs numpy; ffmpeg turns the .wav files into .ogg for Roblox uploads).
The numbers here only shape the audio files; in-game volume, pitch and timing live in src/shared/Config/Audio.luau.
"""

import math
import os
import shutil
import subprocess
import wave

import numpy as np

RATE = 44100
PEAK = 0.7  # every file is normalised to this peak; Config.Audio sets the real loudness
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sfx")
rng = np.random.default_rng(7)


def t_of(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(seconds, attack=0.004, decay=None):
    """Soft attack, then an exponential decay that reaches about -60 dB at the end."""
    t = t_of(seconds)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    a = np.sin(a * math.pi / 2) ** 2
    d = np.exp(-t / (decay or seconds / 6.9))
    tail = np.clip((seconds - t) / 0.006, 0, 1)  # last 6 ms fade, no click at the end
    return a * d * tail


def sweep(f0, f1, seconds, shape="sine", curve=1.0):
    t = t_of(seconds)
    k = (t / seconds) ** curve
    freq = f0 * (f1 / f0) ** k
    phase = 2 * math.pi * np.cumsum(freq) / RATE
    if shape == "triangle":
        return 2 / math.pi * np.arcsin(np.sin(phase))
    return np.sin(phase)


def tone(freq, seconds, shape="sine"):
    return sweep(freq, freq, seconds, shape)


def lowpass(x, cutoff):
    """One-pole lowpass; cutoff may be a number or an array (a moving filter)."""
    cut = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    alpha = 1 - np.exp(-2 * math.pi * cut / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha[i] * (x[i] - acc)
        y[i] = acc
    return y


def bandpass(x, low, high):
    return lowpass(x, high) - lowpass(x, low)


def noise(seconds):
    return rng.uniform(-1, 1, int(RATE * seconds))


def pad(x, seconds):
    return np.concatenate([x, np.zeros(int(RATE * seconds))])


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, delay):
    return np.concatenate([np.zeros(int(RATE * delay)), x])


def note(freq, seconds, shape="sine", attack=0.005, gain=1.0, overtone=0.0):
    x = tone(freq, seconds, shape) + overtone * tone(freq * 2, seconds)
    return gain * x * env(seconds, attack)


# --- the sounds -------------------------------------------------------------------------------------------------


def tick():  # UI click: tiny wooden tick
    s = 0.035
    return note(1800, s, attack=0.001) * 0.5 + lowpass(noise(s), 3000) * env(s, 0.001, 0.004) * 0.6


def pop():  # ranged shot: soft "puk"
    s = 0.07
    return sweep(820, 360, s, curve=0.5) * env(s, 0.002) + lowpass(noise(s), 1500) * env(s, 0.001, 0.006) * 0.3


def swish():  # melee swing / dash: airy whoosh, no metal
    s = 0.14
    t = t_of(s)
    cutoff = 600 + 2200 * np.sin(math.pi * t / s)
    shape = np.sin(math.pi * np.clip(t / s, 0, 1)) ** 2
    return bandpass(noise(s), 300, cutoff) * shape


def thump():  # pulse / heavy drop: round low thump
    s = 0.18
    return sweep(150, 55, s, curve=0.4) * env(s, 0.003) + lowpass(noise(s), 400) * env(s, 0.001, 0.01) * 0.4


def zap():  # chain lightning: short soft buzz with a falling tone
    s = 0.11
    t = t_of(s)
    wobble = np.sin(2 * math.pi * 55 * t) * 0.5 + 0.5
    x = sweep(1300, 700, s, "triangle") * (0.6 + 0.4 * wobble)
    return lowpass(x, 2500) * env(s, 0.002)


def boom():  # explosion: muffled, soft boom
    s = 0.42
    t = t_of(s)
    body = lowpass(noise(s), 300 + 900 * np.exp(-t / 0.05)) * env(s, 0.004, 0.09) * 1.4
    sub = sweep(90, 40, s, curve=0.5) * env(s, 0.004, 0.1)
    return body + sub


def thock():  # own hit: dull, short "thock"
    s = 0.06
    return sweep(420, 180, s, curve=0.4) * env(s, 0.001) + bandpass(noise(s), 800, 2500) * env(s, 0.001, 0.004) * 0.35


def tink():  # crit: bright but quiet glass tink (sines only)
    s = 0.22
    return mix(note(1760, s, attack=0.001) * 0.6, note(2637, s, attack=0.001) * 0.25, thock() * 0.6)


def puff():  # enemy death: little bubble pop with a puff
    s = 0.09
    return sweep(260, 620, s, curve=0.6) * env(s, 0.002) * 0.8 + lowpass(noise(s), 1200) * env(s, 0.002, 0.02) * 0.5


def blip():  # XP orb / fruit: clean pickup blip
    s = 0.08
    return note(988, s, attack=0.002, overtone=0.15)


def chime():  # crate / chest / wave cleared: two-note chime
    s = 0.35
    return mix(note(784, s, attack=0.003, overtone=0.2), at(note(1175, s, attack=0.003, overtone=0.2) * 0.8, 0.07))


def arp():  # level up: rising four-note arpeggio
    notes = [523, 659, 784, 1047]
    parts = [at(note(f, 0.26, "triangle", attack=0.004) * (0.8 + 0.06 * i), 0.065 * i) for i, f in enumerate(notes)]
    return lowpass(mix(*parts), 5000)


def gong():  # wave start / boss / downed: soft low bell
    s = 1.1
    parts = [note(196 * r, s, attack=0.01, gain=g) for r, g in ((1, 1), (2.01, 0.35), (2.76, 0.18), (4.07, 0.08))]
    return lowpass(mix(*parts), 2500)


def warn():  # boss attack warning: two soft low beeps
    s = 0.09
    b = note(330, s, "triangle", attack=0.006)
    return lowpass(mix(b, at(b, 0.12)), 1800)


def oof():  # the local player hurt: muffled low knock
    s = 0.12
    return sweep(240, 110, s, curve=0.5) * env(s, 0.002) + lowpass(noise(s), 700) * env(s, 0.001, 0.015) * 0.5


# Upload order = priority: the first ones play most often.
SOUNDS = {
    "blip": blip,
    "thock": thock,
    "puff": puff,
    "pop": pop,
    "swish": swish,
    "tick": tick,
    "arp": arp,
    "chime": chime,
    "oof": oof,
    "gong": gong,
    "thump": thump,
    "boom": boom,
    "zap": zap,
    "tink": tink,
    "warn": warn,
}


def write_wav(path, x):
    x = x / max(np.max(np.abs(x)), 1e-9) * PEAK
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


def main():
    os.makedirs(OUT, exist_ok=True)
    ffmpeg = shutil.which("ffmpeg")
    for index, (name, make) in enumerate(SOUNDS.items(), start=1):
        stem = f"lf_{index:02d}_{name}"
        wav_path = os.path.join(OUT, stem + ".wav")
        write_wav(wav_path, pad(make(), 0.02))
        if ffmpeg:
            ogg_path = os.path.join(OUT, stem + ".ogg")
            subprocess.run(
                [ffmpeg, "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "6", ogg_path],
                check=True,
            )
            os.remove(wav_path)
        print(stem)


if __name__ == "__main__":
    main()
