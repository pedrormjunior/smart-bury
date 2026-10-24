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
import json
import re
from pathlib import Path

import numpy as np
import soundfile

HERE = Path(__file__).parent
# Kokoro v1.0, full precision: exported with a durations output when
# `make voice-model-timed' has built it (continuous synthesis, phoneme
# timings; see README.md), else kokoro-onnx's prebuilt one.
MODEL_TIMED = HERE / "voice-models" / "kokoro-v1.0-timed.onnx"
MODEL = (MODEL_TIMED if MODEL_TIMED.exists()
         else HERE / "voice-models" / "kokoro-v1.0.onnx")
VOICES = HERE / "voice-models" / "voices-v1.0.bin"
CACHE = HERE / "media" / "voice"

# Pauses Kokoro inserts after sentence and clause marks, in seconds (its
# defaults are 0.25 and 0.1); with phoneme timings, after every mark.
SENTENCE_PAUSE = 0.15
CLAUSE_PAUSE = 0.05

CANDIDATE_VOICES = ["af_heart", "am_michael", "bf_emma", "bm_george"]
SAMPLE_CAPTIONS = [
    "Emacs keeps a “list of all buffers” (most recently used first).",
    "`C-x M--` buries the ~current buffer~.",
    '…and `M--` buries "B", going on to "C", not back to "A".',
    "…and, listed in {smart-bury-repeatable-commands}, it arms the "
    "repeat map.",
]

PUNCTUATION = set(".,;:!?…—–-'\"“”()")

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
        words += (", " if key.isdigit() else ", ") + spoken_key(key)
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
    """Speaks captions in VOICE at SPEED, caching each clip.

    With a model reporting durations (see MODEL), synthesis is
    continuous, keeping the intonation flowing across the chunks a text
    is split into, and each clip comes with phoneme timings.
    """

    def __init__(self, voice: str, speed: float = 1.0) -> None:
        self.voice = voice
        self.speed = speed
        self._kokoro = None
        self.timed = False      # whether the model reports durations

    def kokoro(self):
        if self._kokoro is None:
            from kokoro_onnx import Kokoro    # slow import: only when needed
            self._kokoro = Kokoro(str(MODEL), str(VOICES))
            self.timed = len(self._kokoro.sess.get_outputs()) > 1
        return self._kokoro

    def synthesize_timed(self, words: str) -> tuple[np.ndarray, int, list]:
        """WORDS' audio, its sample rate, and its phoneme timings (none
        without a model reporting durations)."""
        kokoro = self.kokoro()
        return kokoro.create_timed(words, voice=self.voice, speed=self.speed,
                                   lang="en-us", continuous=self.timed,
                                   sentence_pause=SENTENCE_PAUSE,
                                   clause_pause=CLAUSE_PAUSE)

    def synthesize(self, words: str) -> tuple[np.ndarray, int]:
        samples, rate, _ = self.synthesize_timed(words)
        return samples, rate

    def clip(self, words: str) -> tuple[Path, float, list[tuple]]:
        """The WAV file saying WORDS, its duration in seconds, and its
        phoneme timings, as (phoneme, start, end) tuples, cached in a
        JSON file next to it."""
        key = (f"{MODEL.name}|{self.voice}|{self.speed}|"
               f"{SENTENCE_PAUSE}|{CLAUSE_PAUSE}|{words}")
        path = CACHE / f"{hashlib.sha1(key.encode()).hexdigest()}.wav"
        timings_path = path.with_suffix(".json")
        if not path.exists():
            samples, rate, timings = self.synthesize_timed(words)
            path.parent.mkdir(parents=True, exist_ok=True)
            timings_path.write_text(json.dumps(
                [(t.phoneme, t.start, t.end) for t in timings]))
            partial = path.with_suffix(".part.wav")
            soundfile.write(partial, samples, rate)
            partial.rename(path)
        timings = (json.loads(timings_path.read_text())
                   if timings_path.exists() else [])
        return path, soundfile.info(path).duration, timings

    @staticmethod
    def spoken_length(duration: float, timings: list) -> float:
        """How long a clip of DURATION seconds is spoken for: until its
        last phoneme that isn't punctuation or a space ends, a final mark
        carrying the silence after it; DURATION without TIMINGS."""
        ends = [end for phoneme, _, end in timings
                if phoneme.strip() and phoneme not in PUNCTUATION]
        return max(ends) if ends else duration

    def time_at(self, words: str, index: int,
                timings: list) -> float | None:
        """When WORDS' INDEXth character starts being said, from TIMINGS
        (see `clip'), or None without timings.

        The phonemes of the words before it, counted as the model
        tokenizes them, give the index of its first phoneme.
        """
        if not timings:
            return None
        tokenizer = self.kokoro().tokenizer
        before = " ".join(tokenizer.phonemize(words[:index]).split())
        count = len(tokenizer.known(before)) + (1 if before else 0)
        return timings[min(count, len(timings) - 1)][1]


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
