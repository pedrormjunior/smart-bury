# Smart Bury's animations

This directory holds the Manim animations explaining Smart Bury, outside
the package itself (the MELPA recipe lists only `smart-bury.el`):

- `smart_bury_intro.py`: the short, narrated introduction
  (`make intro`);
- `smart_bury_demo.py`: the longer, case-by-case animation
  (`make demo`);
- `smart_bury_sim.py`: a Python model of Smart Bury's algorithm, which
  both animations draw (`make demo-check` replays the README's cases on
  it);
- `narration.py`: the intro's narration, local text-to-speech with
  Kokoro through kokoro-onnx.

All `make` commands below run from the repository root.

## Prerequisites (manual)

- [`uv`](https://docs.astral.sh/uv/), which installs the Python versions
  and the packages needed (Python 3.13 here, 3.12 for the model export);
- `make`, `curl`, `sha256sum`, and `ffmpeg` (for Manim);
- about 2 GB of free disk space, mostly for the model export's PyTorch;
- a network connection for the first build only (see below); after
  that, everything runs offline.

## Rendering the intro

```
make intro                          # 480p15, narrated by am_michael
make intro INTRO_QUALITY=1440p60    # see the Makefile for qualities
make intro VOICE=                   # silent
```

The video lands in `demo/smart-bury-intro-<quality>.mp4`, with the
captions as subtitles in `demo/smart-bury-intro-<quality>.srt` (plain
text) and `demo/smart-bury-intro-<quality>.ttml` (styled as in the
video: italics, monospace, and colors, which YouTube keeps from TTML,
unlike SRT; mpv can't read TTML).  The
render's log ends with, per caption, how long its part lasts without
narration, how long its speech lasts, and the difference.

## The narration's model

A narrated `make intro` builds what it needs, once:

1. **`make voice-models`**: kokoro-onnx's voices (`voices-v1.0.bin`)
   and its prebuilt model (`kokoro-v1.0.onnx`), from kokoro-onnx's
   GitHub releases, into `demo/voice-models/`.
2. **`make voice-model-timed`**: Kokoro v1.0 exported to ONNX *with a
   durations output*, as `demo/voice-models/kokoro-v1.0-timed.onnx`.
   kokoro-onnx's prebuilt model only outputs audio; the durations enable
   *continuous synthesis* (the intonation flows across the chunks a
   text is split into) and *phoneme timings*, which place the intro's
   visual cues (e.g. the "initial" marker) on the actual speech.

Without the timed model, `narration.py` falls back to the prebuilt one:
no continuous synthesis, and cues estimated from where their words are
in the caption.

### What `make voice-model-timed` does

It runs `demo/kokoro-export/build.sh`, whose steps are each skipped once
their output exists, so it can simply be run again after a failure:

1. **Export script**: downloads `scripts/export.py` from
   [kokoro-onnx](https://github.com/thewh1teagle/kokoro-onnx) at the
   commit pinned in `build.sh` (`EXPORT_COMMIT`), into
   `demo/kokoro-export/export.py` (git-ignored).
2. **Weights**: downloads `config.json` and `kokoro-v1_0.pth` (327 MB)
   from [hexgrad/Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M)
   at the revision pinned in `build.sh` (`WEIGHTS_REVISION`), into
   `demo/voice-models/checkpoints/`, and checks their SHA-256 sums.
3. **Export**: runs `export.py` in its own environment,
   `demo/kokoro-export/` (Python 3.12, CPU-only PyTorch, locked in
   `uv.lock`), which also verifies the ONNX graph against PyTorch.  This
   takes a few minutes; PyTorch warnings during it are expected.
4. **Check**: runs `demo/kokoro-export/check.py` in the narration's
   environment (`make voice-model-check` runs it alone): the model must
   report durations, and a sample caption must synthesize with continuous
   synthesis and phoneme timings.  It writes
   `demo/voice-samples/timed-check.wav` to listen to.

`make voice-model-clean` removes what it builds (the checkpoints, the
export script, the export environment, and the timed model), to build it
again from scratch.

### Doing it by hand

If a step fails, the same steps as commands, from the repository root:

```
# 1. Export script
curl -fL -o demo/kokoro-export/export.py \
  https://raw.githubusercontent.com/thewh1teagle/kokoro-onnx/<EXPORT_COMMIT>/scripts/export.py

# 2. Weights (then compare with the sums in build.sh)
mkdir -p demo/voice-models/checkpoints
for file in config.json kokoro-v1_0.pth; do
  curl -fL -o demo/voice-models/checkpoints/$file \
    https://huggingface.co/hexgrad/Kokoro-82M/resolve/<WEIGHTS_REVISION>/$file
done
sha256sum demo/voice-models/checkpoints/*

# 3. Export, in the export environment
uv sync --project demo/kokoro-export
cd demo/kokoro-export
uv run --project . python export.py \
  -c ../voice-models/checkpoints/config.json \
  -p ../voice-models/checkpoints/kokoro-v1_0.pth \
  -o ../voice-models/kokoro-v1.0-timed.onnx -v am_michael
cd ../..

# 4. Check, in the narration's environment
cd demo && uv run python kokoro-export/check.py
```

### Network access

Needed during the first build only:

- GitHub (kokoro-onnx's releases and export script);
- Hugging Face (the weights, which are public, needing no token; the
  export's verification also fetches the voice it uses);
- PyTorch's CPU package index and PyPI, for the export environment;
- possibly spaCy's English model, which `kokoro`'s text pipeline can
  download at first use.

Synthesis itself is local: it runs with the network cut (e.g. under
`unshare -rn`).

### Updating

To use a newer kokoro-onnx export script or Kokoro revision, change
`EXPORT_COMMIT` or `WEIGHTS_REVISION` (and the sums, for new weights) in
`build.sh`, adjust `demo/kokoro-export/pyproject.toml` to the script's
requirements if needed (`uv lock --project demo/kokoro-export`), and
rebuild with `make voice-model-clean voice-model-timed`.  Changing the
model changes the narration's cache keys, so every caption is
synthesized again at the next render.

### Troubleshooting

- **Checksum mismatch**: the download was corrupted or the pinned
  revision changed; delete the file named in the message and run the
  build again.
- **A GPU build of PyTorch gets installed** (several GB of `nvidia-*`
  packages): the export must run through `uv run --project
  demo/kokoro-export`, whose lock pins the CPU index, not through
  `uv run export.py`, which would use the script's own header.
- **The export can't fetch its verification voice** (offline): it
  verifies with a random style instead, and says so; the model is fine.
- **Python 3.12 missing**: uv downloads it; nothing to install.
