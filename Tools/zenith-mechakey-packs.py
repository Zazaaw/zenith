#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Satu Visual
"""Rebuild Mechakey's bundled sound packs from Mechvibes' own.

Mechvibes (https://github.com/hainguyents13/mechvibes, MIT, (c) Hai Nguyen)
ships each keyboard pack as one long Ogg Vorbis file plus a V2 `config.json`
whose `definitions` give every key a press and a release slice, as
`[start_ms, end_ms]` pairs. macOS cannot decode Vorbis, and most of each file
is silence between the clips, so this keeps only the audio the slices use:

1. Decode the pack with ffmpeg to mono 16-bit PCM at the file's own rate.
2. Merge the slices into clusters (a key's press and release touch).
3. Write the clusters one after another, 20 ms of silence between them, so
   the encoder never smears one clip into the next.
4. Encode that with Apple's afconvert to AAC in an .m4a, which AVAudioFile
   reads back sample-aligned (afconvert records the encoder priming).
5. Write a V2 `config.json` with the same keys and the slices moved to where
   their audio now sits.

Run on a checkout of Mechvibes (or a folder holding its
`soundpacks/keyboard/<pack>` folders), then commit the result:

    python3 Tools/zenith-mechakey-packs.py <mechvibes>/soundpacks/keyboard Resources/Mechakey
"""
from pathlib import Path
import json
import subprocess
import sys
import tempfile
import wave

FFMPEG = "/opt/homebrew/bin/ffmpeg"
AFCONVERT = "/usr/bin/afconvert"
BITRATE = 128_000
GAP_MS = 20

# Folder in Mechvibes -> (folder here, name shown in Settings). Order is the picker's.
PACKS = [
    ("cherrymx-blue-abs", "cherry-mx-blue", "Cherry MX Blue"),
    ("cherrymx-brown-abs", "cherry-mx-brown", "Cherry MX Brown"),
    ("cherrymx-red-abs", "cherry-mx-red", "Cherry MX Red"),
    ("cherrymx-black-abs", "cherry-mx-black", "Cherry MX Black"),
    ("topre-purple-hybrid-pbt", "topre-purple", "Topre Purple Hybrid"),
    ("eg-oreo", "eg-oreo", "EG Oreo"),
    ("eg-crystal-purple", "eg-crystal-purple", "EG Crystal Purple"),
]


def decode(source, rate):
    """Mono signed 16-bit samples of the whole file."""
    raw = subprocess.run([FFMPEG, "-v", "error", "-i", str(source), "-ac", "1", "-ar", str(rate),
                          "-f", "s16le", "-acodec", "pcm_s16le", "-"], check=True, capture_output=True).stdout
    return raw


def probe_rate(source):
    out = subprocess.run([FFMPEG.replace("ffmpeg", "ffprobe"), "-v", "error", "-select_streams", "a:0",
                          "-show_entries", "stream=sample_rate", "-of", "csv=p=0", str(source)],
                         check=True, capture_output=True, text=True).stdout
    return int(out.strip())


def clusters(segments):
    """Sorted, merged [start, end] spans (ms) covering every segment."""
    spans = []
    for start, end in sorted(segments):
        if spans and start <= spans[-1][1] + 0.5:
            spans[-1][1] = max(spans[-1][1], end)
        else:
            spans.append([start, end])
    return spans


def build(source_dir, out_dir, folder, title):
    config = json.loads((source_dir / "config.json").read_text())
    definitions = config.get("definitions") or config.get("defs")
    audio = source_dir / config["audio_file"]
    rate = probe_rate(audio)
    pcm = decode(audio, rate)
    total = len(pcm) // 2

    def frame(ms):
        return max(0, min(total, round(ms * rate / 1000)))

    segments = [tuple(s) for value in definitions.values() for s in value["timing"]]
    spans = clusters(segments)
    gap = bytes(2 * frame(GAP_MS))
    body = bytearray(gap)
    placed = []  # (span start ms, span start frame in the old file, start frame in the new one)
    for start, end in spans:
        a, b = frame(start), frame(end)
        placed.append((start, end, a, len(body) // 2))
        body += pcm[2 * a:2 * b]
        body += gap

    def moved(ms):
        for start, end, old, new in placed:
            if start - 0.001 <= ms <= end + 0.001:
                return round((new + frame(ms) - old) * 1000 / rate, 3)
        raise ValueError(f"{ms} ms is in no span")

    out = out_dir / folder
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "sound.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(bytes(body))
        target = out / "sound.m4a"
        target.unlink(missing_ok=True)
        subprocess.run([AFCONVERT, "-f", "m4af", "-d", "aac", "-b", str(BITRATE), str(wav), str(target)], check=True)

    keys = {key: {"timing": [[moved(a), moved(b)] for a, b in value["timing"]]}
            for key, value in sorted(definitions.items())}
    pack = {
        "config_version": "2",
        "id": folder,
        "name": title,
        "author": config.get("author") or config.get("m_author") or "Mechvibes",
        "source": f"https://github.com/hainguyents13/mechvibes/tree/main/soundpacks/keyboard/{source_dir.name}",
        "license": "MIT",
        "definition_method": "single",
        "audio_file": "sound.m4a",
        "options": {"recommended_volume": config.get("options", {}).get("recommended_volume", 1.0)},
        "definitions": keys,
    }
    # One key per line, so a diff of a rebuilt pack stays readable.
    head = json.dumps({k: v for k, v in pack.items() if k != "definitions"}, indent=2, ensure_ascii=False)
    lines = [f'    {json.dumps(key)}: {json.dumps(value)}' for key, value in keys.items()]
    text = head[:-2] + ',\n  "definitions": {\n' + ",\n".join(lines) + "\n  }\n}\n"
    json.loads(text)
    (out / "config.json").write_text(text)
    seconds = len(body) / 2 / rate
    print(f"{folder}: {len(spans)} clips, {seconds:.1f} s, {target.stat().st_size // 1024} KB")


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    source, out = Path(sys.argv[1]), Path(sys.argv[2])
    for name, folder, title in PACKS:
        build(source / name, out, folder, title)


if __name__ == "__main__":
    main()
