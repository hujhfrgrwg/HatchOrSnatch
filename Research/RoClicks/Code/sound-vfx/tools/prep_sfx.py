#!/usr/bin/env python3
"""prep_sfx.py: get audio files ready for a Roblox upload.

Per file: decode (ffmpeg) -> trim silence -> loudness-normalise to the group target
(gated RMS) -> peak limit -> edge fades (one-shots) or a seamless crossfade wrap (loops)
-> Ogg Vorbis ~q6, 44.1 kHz. The output is named after the input stem, which should be
the registry key (cash_collect.wav -> cash_collect.ogg).

  python3 prep_sfx.py --group UI  --out final/ raw/ui_click.wav raw/ui_reward.wav
  python3 prep_sfx.py --group Ambience --loop 20 --out final/ raw/rain_loop.wav

Needs ffmpeg on PATH and numpy.
"""
import argparse
import os
import subprocess
import sys

import numpy as np

SR = 44100
TARGET_DB = {"UI": -17.0, "SFX": -14.0, "Ambience": -20.0, "Music": -18.0}
CEILING = 0.89  # about -1 dBFS


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def encode(x, path):
    data = np.clip(x, -1, 1).astype(np.float32).tobytes()
    base = ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-"]
    for codec in (["-c:a", "libvorbis", "-q:a", "6"], ["-c:a", "vorbis", "-strict", "-2", "-q:a", "6"]):
        r = subprocess.run(base + codec + [path], input=data, capture_output=True)
        if r.returncode == 0:
            return
    sys.exit("ffmpeg could not encode Ogg Vorbis: " + r.stderr.decode()[-300:])


def trim(x, thresh_db=-50.0, pad=0.01):
    """Cut leading/trailing silence; a gap at the start makes clicks feel laggy."""
    env = np.abs(x).max(axis=1)
    idx = np.where(env > 10 ** (thresh_db / 20))[0]
    if len(idx) == 0:
        return x
    p = int(pad * SR)
    return x[max(0, idx[0] - p): min(len(x), idx[-1] + p)]


def loudnorm(x, target_db):
    """Gated RMS: only 50 ms frames within 30 dB of the loudest count, so tails don't skew it."""
    f = int(0.05 * SR)
    n = max(1, len(x) // f)
    frames = x[: n * f].reshape(n, f, 2) if len(x) >= f else x[None, :, :]
    rms = np.sqrt((frames ** 2).mean(axis=(1, 2)) + 1e-12)
    gated = rms[rms > rms.max() * 10 ** (-30 / 20)]
    level = np.sqrt((gated ** 2).mean())
    return x * (10 ** (target_db / 20) / level)


def limit(x, ceiling=CEILING, block=0.005, release=0.06):
    """Block look-ahead limiter: per-5 ms gain, instant attack, exponential release."""
    b = max(1, int(block * SR))
    n = -(-len(x) // b)
    padded = np.zeros((n * b, 2), dtype=x.dtype)
    padded[: len(x)] = x
    peaks = np.abs(padded).reshape(n, b, 2).max(axis=(1, 2))
    want = np.minimum(1.0, ceiling / np.maximum(peaks, 1e-9))
    rel = np.exp(-block / release)
    g = np.empty(n)
    cur = 1.0
    for i in range(n):
        cur = want[i] if want[i] < cur else want[i] + (cur - want[i]) * rel
        g[i] = cur
    gain = np.repeat(g, b)[: len(x)]
    return x * gain[:, None]


def fade(x, fade_in=0.003, fade_out=0.06):
    y = x.copy()
    a = min(int(fade_in * SR), len(y) // 2)
    z = min(int(fade_out * SR), len(y) // 4)
    if a:
        y[:a] *= np.linspace(0, 1, a)[:, None]
    if z:
        y[-z:] *= np.linspace(1, 0, z)[:, None]
    return y


def loop_wrap(x, seconds, xfade=0.5):
    """Seamless loop of `seconds`: crossfade the material after the loop point into the head."""
    n, xf = int(seconds * SR), int(xfade * SR)
    if len(x) < n + xf:
        n = len(x) - xf
        if n <= xf:
            sys.exit("file too short to loop")
    out = x[:n].copy()
    t = np.linspace(0, 1, xf)[:, None]
    out[:xf] = x[:xf] * np.sqrt(t) + x[n: n + xf] * np.sqrt(1 - t)  # equal-power
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+")
    ap.add_argument("--group", choices=sorted(TARGET_DB), required=True)
    ap.add_argument("--gain", type=float, default=0.0, help="extra dB on top of the group target")
    ap.add_argument("--loop", type=float, help="make a seamless loop of this many seconds")
    ap.add_argument("--out", default="final")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for path in a.files:
        x = decode(path)
        if not a.loop:
            x = trim(x)
        x = limit(loudnorm(x, TARGET_DB[a.group] + a.gain))
        x = loop_wrap(x, a.loop) if a.loop else fade(x)
        name = os.path.splitext(os.path.basename(path))[0]
        dest = os.path.join(a.out, name + ".ogg")
        encode(x, dest)
        print(f"{dest}  {len(x) / SR:.2f}s  peak {np.abs(x).max():.2f}")


if __name__ == "__main__":
    main()
