"""Check the Kokoro model exported by build.sh, in the narration's environment.

Run from demo/ (as build.sh and `make voice-model-check' do):

    uv run python kokoro-export/check.py

It asserts the model reports durations, synthesizes a caption with
continuous synthesis and phoneme timings, and writes it to
voice-samples/timed-check.wav to listen to.  It exits non-zero on any
failure.
"""

from __future__ import annotations

import sys
from pathlib import Path

import soundfile
from kokoro_onnx import Kokoro

DEMO = Path(__file__).resolve().parent.parent
MODEL = DEMO / "voice-models" / "kokoro-v1.0-timed.onnx"
VOICES = DEMO / "voice-models" / "voices-v1.0.bin"
SAMPLE = DEMO / "voice-samples" / "timed-check.wav"
TEXT = ('Smart Bury remembers where a sequence started and how deep it is: '
        '"control x, underscore".')


def fail(message: str) -> None:
    print(f"check failed: {message}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    for path in (MODEL, VOICES):
        if not path.exists():
            fail(f"{path} is missing (make voice-model-timed, voice-models)")
    kokoro = Kokoro(str(MODEL), str(VOICES))
    outputs = [output.name for output in kokoro.sess.get_outputs()]
    print(f"model outputs: {outputs}")
    if len(outputs) < 2:
        fail("the model reports no durations")
    audio, rate, timings = kokoro.create_timed(TEXT, voice="am_michael",
                                               continuous=True)
    if not timings:
        fail("continuous synthesis returned no phoneme timings")
    print(f"synthesized {len(audio) / rate:.2f} s, {len(timings)} phonemes, "
          f"the last ending at {timings[-1].end:.2f} s")
    SAMPLE.parent.mkdir(exist_ok=True)
    soundfile.write(SAMPLE, audio, rate)
    print(f"wrote {SAMPLE}")


if __name__ == "__main__":
    main()
