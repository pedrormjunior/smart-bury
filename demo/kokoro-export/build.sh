#!/usr/bin/env bash
# Build demo/voice-models/kokoro-v1.0-timed.onnx: Kokoro v1.0 exported to
# ONNX with a durations output, which kokoro-onnx needs for continuous
# synthesis and phoneme timings.  See ../README.md.
#
# Every step is skipped once its output exists, so the script can be
# rerun after a failure; `make voice-model-clean' starts over.

set -euo pipefail

# kokoro-onnx's export script, and the Kokoro weights, at fixed versions.
EXPORT_COMMIT="${EXPORT_COMMIT:-3596b26764286a7de9d90c363e988d50578918e5}"
EXPORT_URL="https://raw.githubusercontent.com/thewh1teagle/kokoro-onnx/$EXPORT_COMMIT/scripts/export.py"
WEIGHTS_REVISION="${WEIGHTS_REVISION:-f3ff3571791e39611d31c381e3a41a3af07b4987}"
WEIGHTS_URL="https://huggingface.co/hexgrad/Kokoro-82M/resolve/$WEIGHTS_REVISION"
CONFIG_SHA256=5abb01e2403b072bf03d04fde160443e209d7a0dad49a423be15196b9b43c17f
CHECKPOINT_SHA256=496dba118d1a58f5f3db2efc88dbdc216e0483fc89fe6e47ee1f2c53f18ad1e4
# The voice export.py's verification uses.
VOICE="${VOICE:-am_michael}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO="$(dirname "$HERE")"
MODELS="$DEMO/voice-models"
CHECKPOINTS="$MODELS/checkpoints"
OUTPUT="$MODELS/kokoro-v1.0-timed.onnx"

step() { printf '\n== %s\n' "$*"; }

# download URL FILE [SHA256]: fetch URL into FILE unless it exists,
# through a .part file, then check its SHA256 if given.
download() {
    local url=$1 file=$2 sha256=${3:-}
    if [[ ! -f $file ]]; then
        curl -fL --retry 3 -o "$file.part" "$url"
        mv "$file.part" "$file"
    else
        echo "already there: $file"
    fi
    if [[ -n $sha256 ]] && ! echo "$sha256  $file" | sha256sum --check --quiet; then
        echo "checksum mismatch for $file (delete it to download it again)" >&2
        exit 1
    fi
}

step "Export script (kokoro-onnx $EXPORT_COMMIT)"
download "$EXPORT_URL" "$HERE/export.py"

step "Kokoro v1.0 weights (hexgrad/Kokoro-82M $WEIGHTS_REVISION)"
mkdir -p "$CHECKPOINTS"
download "$WEIGHTS_URL/config.json" "$CHECKPOINTS/config.json" "$CONFIG_SHA256"
download "$WEIGHTS_URL/kokoro-v1_0.pth" "$CHECKPOINTS/kokoro-v1_0.pth" \
         "$CHECKPOINT_SHA256"

step "Export to $OUTPUT"
if [[ ! -f $OUTPUT ]]; then
    # In the export environment (Python 3.12, CPU-only torch), not
    # export.py's own PEP 723 header, which would pull in GPU torch.
    (cd "$HERE" && uv run --project "$HERE" python export.py \
         -c "$CHECKPOINTS/config.json" -p "$CHECKPOINTS/kokoro-v1_0.pth" \
         -o "$OUTPUT.part.onnx" -v "$VOICE")
    mv "$OUTPUT.part.onnx" "$OUTPUT"
else
    echo "already there: $OUTPUT"
fi

step "Check"
(cd "$DEMO" && uv run python kokoro-export/check.py)
