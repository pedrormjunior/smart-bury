"""Dubbed audio tracks of the intro, for YouTube's multi-language audio.

Each caption's translation (see translations.py) is spoken in its language
and placed where the English speech of that caption starts, in a silent track
as long as the video.  The video stays the same, so key presses and buffer
pulses keep the English timing.

`make intro' runs this with the render's output name, after the scene has
written when each caption's speech starts (`write_speech_cues'); without
arguments, as `make demo-check' does, it only checks `place'.

"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile

from narration import KEY_NAMES, Narrator, phonemes_with, spoken
from translations import DUB_VOICES, KEY_WORDS, SPOKEN_PHONEMES, translated

HERE = Path(__file__).parent
CUES = HERE / "media" / "dub" / "cues.json"
GAP = 0.15  # the least silence between two clips, in seconds


def place(starts: list[float], lengths: list[float]) -> list[float]:
    """Where to place clips spoken for LENGTHS seconds: each at its time in
    STARTS, or GAP after the previous clip, if that one runs past it.

    """
    placed, free = [], 0.0
    for start, length in zip(starts, lengths):
        placed.append(max(start, free))
        free = placed[-1] + length + GAP
    return placed


def mix(track: np.ndarray, samples: np.ndarray, first: int) -> None:
    """Add SAMPLES into TRACK from index FIRST, cutting what falls past it."""
    samples = samples[: max(0, len(track) - first)]
    track[first : first + len(samples)] += samples


def write_track(language: str, cues: dict, path: Path, loudness: str) -> None:
    """Write LANGUAGE's dub of CUES (see `write_speech_cues') into PATH, a WAV
    file at LOUDNESS LUFS, reporting how late its speech runs."""
    voice, lang = DUB_VOICES[language]
    narrator = Narrator(voice, lang=lang, fixed=SPOKEN_PHONEMES.get(language))
    names = {**KEY_NAMES, **KEY_WORDS[language]}
    clips, lengths = [], []
    for text, _ in cues["cues"]:
        words = spoken(translated(text, language), names)
        clip, duration, timings = narrator.clip(words)
        clips.append(clip)
        lengths.append(Narrator.spoken_length(duration, timings))
    starts = [start for _, start in cues["cues"]]
    placed = place(starts, lengths)
    rate = soundfile.info(clips[0]).samplerate
    track = np.zeros(round(cues["duration"] * rate), dtype=np.float32)
    for clip, start in zip(clips, placed):
        samples, _ = soundfile.read(clip, dtype="float32")
        mix(track, samples, round(start * rate))
    end = placed[-1] + lengths[-1]
    if end > cues["duration"]:
        print(f"{language}: speech ends past the video, cut", file=sys.stderr)
    late = [at - start for at, start in zip(placed, starts) if at > start]
    print(
        f"{language}: {voice}, {len(late)} of {len(starts)} captions late, "
        f"at most {max(late, default=0):.1f} s"
    )
    raw = CUES.with_name(f"{language}.wav")
    soundfile.write(raw, track, rate)
    normalize(raw, path, loudness)


def measure(path: Path, target: str) -> dict:
    """PATH's loudness, as `loudnorm' reports it for TARGET."""
    report = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af",
         f"{target}:print_format=json", "-f", "null", "-"],
        check=True, capture_output=True, text=True,
    ).stderr  # fmt: skip
    return json.loads(report[report.rindex("{") : report.rindex("}") + 1])


def normalize(raw: Path, path: Path, loudness: str) -> None:
    """Write RAW into PATH at LOUDNESS LUFS: `loudnorm' in two passes, which
    falls short on a track with long silences, then the gain left, up to a
    true peak of -1 dBTP."""
    target = f"loudnorm=I={loudness}:TP=-1:LRA=11"
    found = measure(raw, target)
    levelled = raw.with_suffix(".levelled.wav")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af",
         f"{target}:measured_I={found['input_i']}"
         f":measured_TP={found['input_tp']}"
         f":measured_LRA={found['input_lra']}"
         f":measured_thresh={found['input_thresh']}"
         f":offset={found['target_offset']}:linear=true",
         "-ar", "48000", "-ac", "2", levelled],
        check=True,
    )  # fmt: skip
    found = measure(levelled, target)
    gain = min(
        float(loudness) - float(found["input_i"]),
        -1 - float(found["input_tp"]),
    )
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", levelled,
         "-af", f"volume={gain:.2f}dB", path],
        check=True,
    )  # fmt: skip


def check() -> None:
    """Exit with an error if `place' or the keys' names go wrong."""
    assert place([0.0, 5.0], [2.0, 1.0]) == [0.0, 5.0]  # on time
    assert place([0.0, 1.0, 10.0], [2.0, 1.0, 1.0]) == [0.0, 2.15, 10.0]
    words = spoken("`M--` `RET`", {**KEY_NAMES, **KEY_WORDS["pt-BR"]})
    assert words == '"meta menos, enter"', words
    track = np.zeros(4, dtype=np.float32)
    mix(track, np.ones(1, dtype=np.float32), 1)  # shorter than the rest
    mix(track, np.ones(3, dtype=np.float32), 3)  # past the track's end
    assert track.tolist() == [0.0, 1.0, 0.0, 1.0], track
    fixed = {"smart": "SM", "bury": "BR"}
    words = phonemes_with("O Smart Bury, smart.", fixed, str.lower)
    assert words == "o SM BR, SM.", words
    assert phonemes_with("nada", fixed, str.upper) == "NADA"
    print("dub.py: placement, mixing, and spoken words are fine.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("output", nargs="?", help="name before .LANGUAGE.wav")
    parser.add_argument("--loudness", default="-14", help="in LUFS")
    args = parser.parse_args()
    if args.output is None:
        check()
        return
    cues = json.loads(CUES.read_text(encoding="utf-8"))
    for language in DUB_VOICES:
        path = HERE / f"{args.output}.{language}.wav"
        write_track(language, cues, path, args.loudness)


if __name__ == "__main__":
    main()
