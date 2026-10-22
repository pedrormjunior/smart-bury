"""Narration for the intro: captions spoken by Kokoro, through kokoro-onnx.

Everything runs locally: the model and its voices are files downloaded
once by `make voice-models' (into voice-models/), and speech is
synthesized on the CPU by ONNX Runtime, with espeak-ng (bundled by
espeakng-loader) turning text into phonemes.

Captions use the intro's markup (see `parse_rich' in
smart_bury_intro.py); `spoken' turns it into the words to say.  Clips
are cached by model, voice, speed, and text, so a render only
synthesizes the captions that changed.

Run directly:

    python narration.py --samples
        writes voice-samples/VOICE.wav for each candidate voice, a few
        captions each, to pick a voice by ear;
    python narration.py --voice VOICE --out FILE.wav CAPTION
        writes one caption.
"""

from __future__ import annotations

import argparse
import hashlib
import re
from pathlib import Path

import numpy as np
import soundfile

HERE = Path(__file__).parent
MODEL = HERE / "voice-models" / "kokoro-v1.0.onnx"   # full precision
VOICES = HERE / "voice-models" / "voices-v1.0.bin"
CACHE = HERE / "media" / "voice"

CANDIDATE_VOICES = ["af_heart", "am_michael", "bf_emma", "bm_george"]
SAMPLE_CAPTIONS = [
    "Emacs keeps a “list of all buffers” (most recently used first).",
    "`C-x M--` buries the ~current buffer~.",
    '…and `M--` buries "B", going on to "C", not back to "A".',
    "…and, listed in {smart-bury-repeatable-commands}, it arms the "
    "repeat map.",
]

MODIFIERS = {"C": "control", "M": "meta", "S": "shift"}
KEY_NAMES = {"_": "underscore", "-": "minus", "RET": "return",
             "TAB": "tab", "SPC": "space",
             **{str(digit): word for digit, word in enumerate(
                 ["zero", "one", "two", "three", "four", "five", "six",
                  "seven", "eight", "nine"])}}


def spoken_key(key: str) -> str:
    """How to say KEY, e.g. "M--" -> "meta minus"."""
    words = []
    while len(key) > 2 and key[1] == "-" and key[0] in MODIFIERS:
        words.append(MODIFIERS[key[0]])
        key = key[2:]
    words.append(KEY_NAMES.get(key, key))
    return " ".join(words)


def spoken_keys(keys: list[str]) -> str:
    """How to say the key sequence KEYS: commas between keys, but "plus"
    before a digit, e.g. ["C-x", "3"] -> "control x plus three"."""
    words = spoken_key(keys[0])
    for key in keys[1:]:
        words += (" plus " if key.isdigit() else ", ") + spoken_key(key)
    return words


def spoken(text: str) -> str:
    """The words to say for caption TEXT, in the intro's markup.

    Keys are named, in double quotes, which make Kokoro say them as a
    unit, a comma between the keys of a sequence, adjacent key spans
    making one sequence (`C-x _` `_` -> "control x, underscore,
    underscore");
    symbols ({smart-bury-mode}, |quit-window|) lose their hyphens; italics (~other
    buffer~) are plain; footnote markers (^) go.  Buffer names stay in their double quotes ("A"),
    which make Kokoro say the letter rather than the article "a".
    """
    # A footnote marker (^) right after a key doesn't break a sequence.
    text = re.sub(r"`[^`]*`\^?(?:\s+`[^`]*`\^?)*",
                  lambda m: '"' + spoken_keys(re.sub(
                      r"[`^]", " ", m.group(0)).split()) + '"',
                  text)
    text = re.sub(r"\{([^}]*)\}|\|([^|]*)\|",
                  lambda m: (m.group(1) or m.group(2)).replace("-", " "),
                  text)
    return text.replace("~", "").replace("^", "")


class Narrator:
    """Speaks captions in VOICE at SPEED, caching each clip."""

    def __init__(self, voice: str, speed: float = 1.0) -> None:
        self.voice = voice
        self.speed = speed
        self._kokoro = None

    def kokoro(self):
        if self._kokoro is None:
            from kokoro_onnx import Kokoro    # slow import: only when needed
            self._kokoro = Kokoro(str(MODEL), str(VOICES))
        return self._kokoro

    def synthesize(self, words: str) -> tuple[np.ndarray, int]:
        return self.kokoro().create(words, voice=self.voice,
                                    speed=self.speed, lang="en-us")

    def clip(self, words: str) -> tuple[Path, float]:
        """The WAV file saying WORDS, and its duration in seconds."""
        key = f"{MODEL.name}|{self.voice}|{self.speed}|{words}"
        path = CACHE / f"{hashlib.sha1(key.encode()).hexdigest()}.wav"
        if not path.exists():
            samples, rate = self.synthesize(words)
            path.parent.mkdir(parents=True, exist_ok=True)
            partial = path.with_suffix(".part.wav")
            soundfile.write(partial, samples, rate)
            partial.rename(path)
        return path, soundfile.info(path).duration


def write_samples() -> None:
    """Write voice-samples/VOICE.wav: SAMPLE_CAPTIONS in each voice."""
    out = HERE / "voice-samples"
    out.mkdir(exist_ok=True)
    for voice in CANDIDATE_VOICES:
        narrator = Narrator(voice)
        parts, rate = [], 24000
        for caption in SAMPLE_CAPTIONS:
            samples, rate = narrator.synthesize(spoken(caption))
            parts += [samples, np.zeros(int(0.7 * rate), dtype=samples.dtype)]
        soundfile.write(out / f"{voice}.wav", np.concatenate(parts), rate)
        print(f"wrote {out / f'{voice}.wav'}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--samples", action="store_true",
                        help="write a sample per candidate voice")
    parser.add_argument("--voice", default=CANDIDATE_VOICES[0])
    parser.add_argument("--out", type=Path, default=Path("caption.wav"))
    parser.add_argument("caption", nargs="?")
    args = parser.parse_args()
    if args.samples:
        write_samples()
    elif args.caption:
        samples, rate = Narrator(args.voice).synthesize(spoken(args.caption))
        soundfile.write(args.out, samples, rate)
        print(f"wrote {args.out}: {spoken(args.caption)!r}")
    else:
        parser.error("give --samples or a CAPTION")


if __name__ == "__main__":
    main()
