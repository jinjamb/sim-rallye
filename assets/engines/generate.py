# Synthèse des sons moteur (SoundBank.RECORDINGS) : pour chaque moteur, une
# planche audio (un seul fichier à importer) qui enchaîne des boucles à régime
# stabilisé, à charge (OnLoad) puis pied levé (OffLoad). Le jeu lit chaque
# boucle par sa région (début, durée) : voir SoundBank.luau.
#
# Usage : python3 assets/engines/generate.py assets/engines
#   -> <moteur>.ogg et regions.luau (la table des régions, recopiée dans SoundBank.luau)
import os, subprocess, sys, zlib
import numpy as np

SR = 44100
LOOP = 1.2  # secondes par boucle (environ)
GAP = 0.05  # marge autour de chaque boucle de la planche
ON_RPMS = [1000, 1800, 2600, 3400, 4200, 5000, 5800, 6600, 7400, 8200]
OFF_RPMS = [900, 2000, 3200, 4400, 5600, 6800, 8000]

# Un moteur : allumages (degrés sur le cycle de 720°) et gain de chaque cylindre,
# résonances d'échappement (Hz, amortissement s), bruit, turbo, pétarades.
ENGINES = {
    "I3": dict(name="3 cylindres turbo (Rally4)", fire=[0, 240, 480], gain=[1, 0.93, 0.97],
               formants=[(140, .030), (430, .012), (1150, .006), (2600, .003)], pulse=.0007,
               noise=.35, rasp=2.2, turbo=.55, whistle=.012, pops=.10, low=.9),
    "I4": dict(name="4 cylindres turbo (Rally2)", fire=[0, 180, 360, 540], gain=[1, .96, .99, .95],
               formants=[(110, .035), (360, .014), (980, .006), (2300, .003)], pulse=.0008,
               noise=.28, rasp=2.6, turbo=.6, whistle=.010, pops=.18, low=1.0),
    "I4R": dict(name="4 cylindres anti-lag (WRC)", fire=[0, 180, 360, 540], gain=[1, .94, 1, .93],
                formants=[(125, .030), (420, .012), (1300, .005), (3100, .0025)], pulse=.0006,
                noise=.40, rasp=3.4, turbo=.75, whistle=.016, pops=.35, low=.95),
    "I5": dict(name="5 cylindres turbo (Groupe B)", fire=[0, 144, 288, 432, 576], gain=[1, .88, .97, .85, .94],
               formants=[(95, .040), (300, .016), (760, .008), (1900, .004)], pulse=.0009,
               noise=.30, rasp=3.0, turbo=.5, whistle=.009, pops=.25, low=1.15),
    "Boxer4": dict(name="4 cylindres à plat (boxer)", fire=[0, 205, 360, 565], gain=[1, .78, .95, .74],
                   formants=[(85, .045), (260, .018), (700, .008), (1700, .004)], pulse=.0011,
                   noise=.24, rasp=2.0, turbo=.45, whistle=.008, pops=.12, low=1.3),
    "V6": dict(name="V6 atmosphérique", fire=[0, 90, 240, 330, 480, 570], gain=[1, .9, .97, .88, .99, .9],
               formants=[(100, .038), (330, .015), (880, .007), (2100, .003)], pulse=.0008,
               noise=.22, rasp=2.4, turbo=0, whistle=0, pops=.08, low=1.1),
    "Flat6": dict(name="6 cylindres à plat", fire=[0, 120, 240, 360, 480, 600], gain=[1, .93, .98, .92, .99, .94],
                  formants=[(130, .032), (470, .013), (1400, .006), (3400, .0025)], pulse=.0006,
                  noise=.20, rasp=1.8, turbo=0, whistle=0, pops=.05, low=.85),
    "Rotary": dict(name="Rotatif 2 rotors", fire=[0, 180, 360, 540], gain=[1, .97, 1, .97],
                   formants=[(160, .020), (620, .010), (1800, .005), (4200, .002)], pulse=.0004,
                   noise=.55, rasp=4.0, turbo=0, whistle=0, pops=.30, low=.6),
}

def damped_ir(formants, length=.06):
    t = np.arange(int(length * SR)) / SR
    ir = np.zeros_like(t)
    ir[0] = 1.0
    for i, (f, decay) in enumerate(formants):
        ir += (0.9 / (1 + i * .35)) * np.exp(-t / decay) * np.sin(2 * np.pi * f * t)
    return ir / np.abs(ir).sum() * 40

def convolve(x, ir):
    n = len(x) + len(ir)
    size = 1 << (n - 1).bit_length()
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    return y[:len(x)]

def bandnoise(n, rng, lo, hi):
    spec = np.fft.rfft(rng.standard_normal(n))
    freqs = np.fft.rfftfreq(n, 1 / SR)
    spec[(freqs < lo) | (freqs > hi)] = 0
    out = np.fft.irfft(spec, n)
    return out / (np.abs(out).max() + 1e-9)

def loop(engine, rpm, load, seed):
    """Une boucle bouclable à `rpm` ; renvoie (signal, régime réel)."""
    rng = np.random.default_rng(seed)
    cycle = int(round(120 / rpm * SR))  # échantillons par cycle de 720°
    real_rpm = 120 * SR / cycle
    cycles = max(2, int(round(LOOP * SR / cycle)))
    length = cycle * cycles
    pre = cycle * 4  # régime établi avant la boucle, et suite pour le raccord
    xfade = min(int(.03 * SR), cycle)
    total = pre + length + xfade
    pulse_len = int(engine["pulse"] * SR * (1.4 if load else 1.0)) + 2
    pt = np.arange(pulse_len) / pulse_len
    pulse_shape = np.sin(np.pi * pt) ** 2 * np.exp(-3 * pt)
    exc = np.zeros(total + pulse_len + 1)
    turb = np.zeros_like(exc)
    strength = 1.0 if load else 0.22
    n_cycles = total // cycle + 1
    for c in range(n_cycles):
        for angle, g in zip(engine["fire"], engine["gain"]):
            pos = int(c * cycle + angle / 720 * cycle + rng.normal(0, cycle * .002))
            if pos < 0 or pos + pulse_len >= len(exc):
                continue
            amp = g * strength * (1 + rng.normal(0, .06))
            exc[pos:pos + pulse_len] += amp * pulse_shape
            env_len = min(int(.004 * SR), len(exc) - pos)
            turb[pos:pos + env_len] += amp * np.exp(-np.arange(env_len) / (.0012 * SR))
            # Pied levé : pétarades (allumage raté dans l'échappement).
            if not load and rng.random() < engine["pops"] / len(engine["fire"]) * min(1, rpm / 3000):
                pop_len = min(int(.012 * SR), len(exc) - pos)
                exc[pos:pos + pop_len] += rng.uniform(1.2, 2.4) * rng.standard_normal(pop_len) * np.exp(-np.arange(pop_len) / (.003 * SR))
    exc, turb = exc[:total], turb[:total]
    noise = rng.standard_normal(total)
    ir = damped_ir(engine["formants"])
    body = convolve(exc, ir)
    rasp = convolve(turb * noise, ir) * engine["noise"] * (1.0 if load else 1.6)
    sig = body + rasp
    sig = np.tanh(sig * engine["rasp"] * (1.0 if load else .7)) / np.tanh(engine["rasp"])
    # Graves : la fondamentale d'allumage renforcée (moteurs « ronds »).
    sig += engine["low"] * .25 * convolve(exc, np.exp(-np.arange(int(.02 * SR)) / (.008 * SR)) / 60)
    t = np.arange(total) / SR
    if engine["turbo"] and load:
        f = engine["whistle"] * rpm * 60 * .5
        f = min(f, 7500)
        wobble = 1 + .01 * np.sin(2 * np.pi * 3.1 * t)
        sig += engine["turbo"] * .05 * np.sin(2 * np.pi * f * t * wobble) * min(1, rpm / 4000)
        sig += engine["turbo"] * .04 * bandnoise(total, rng, 2500, 7000) * min(1, rpm / 5000)
    # Mécanique et admission : un souffle léger.
    sig += .02 * bandnoise(total, rng, 1500, 9000)
    out = sig[pre:pre + length].copy()
    w = np.linspace(0, 1, xfade)
    tail = sig[pre + length:pre + length + xfade]
    out[:xfade] = out[:xfade] * w + tail * (1 - w)
    rms = np.sqrt(np.mean(out ** 2)) + 1e-9
    out *= (.16 if load else .11) / rms
    return out, real_rpm

def build(key, engine, out_dir):
    pieces, regions = [], {"OnLoad": [], "OffLoad": []}
    # Autour de chaque boucle, sa propre fin (avant) et son début (après) : une
    # région lue à quelques millisecondes près reste sans coupure ni silence.
    pad = int(GAP * SR)
    cursor = 0
    for family, rpms, load in (("OnLoad", ON_RPMS, True), ("OffLoad", OFF_RPMS, False)):
        for i, rpm in enumerate(rpms):
            sig, real = loop(engine, rpm, load, zlib.crc32(f"{key}{family}{i}".encode()))
            pieces += [sig[-pad:], sig, sig[:pad]]
            regions[family].append((round(real), (cursor + pad) / SR, len(sig) / SR))
            cursor += len(sig) + 2 * pad
    audio = np.concatenate(pieces)
    # Même gain pour toute la planche : les boucles gardent leur équilibre.
    audio = np.clip(audio / max(1, np.abs(audio).max() / .98), -1, 1)
    wav = os.path.join(out_dir, key + ".wav")
    with open(wav, "wb") as f:
        import wave
        w = wave.open(f, "wb")
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((audio * 32767).astype("<i2").tobytes())
        w.close()
    ogg = os.path.join(out_dir, key + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "6", ogg], check=True)
    os.remove(wav)
    return regions

def main():
    out_dir = sys.argv[1]
    layout = None
    for key, engine in ENGINES.items():
        regions = build(key, engine, out_dir)
        # Tous les moteurs ont la même planche (mêmes régimes, mêmes durées).
        assert layout is None or layout == regions, key
        layout = regions
    lines = ["-- Régions des planches (communes à tous les moteurs) : régime, début, durée (s)."]
    for family in ("OnLoad", "OffLoad"):
        lines.append(f"{family} = {{")
        for rpm, start, length in layout[family]:
            lines.append(f"\t{{ Rpm = {rpm}, Start = {start:.6f}, Length = {length:.6f} }},")
        lines.append("},")
    with open(os.path.join(out_dir, "regions.luau"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("ok")

main()
