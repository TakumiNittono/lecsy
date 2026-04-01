#!/bin/bash
#
# Download WhisperKit CoreML model for bundling in the app.
#
# Usage:
#   ./scripts/download_model.sh
#
# After running, add the "WhisperKitModels" folder to your Xcode project
# as a folder reference (blue folder icon) so it's copied into the app bundle.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/lecsy/WhisperKitModels"

echo "==> Downloading WhisperKit small multilingual model (~460 MB)..."

# Install huggingface-cli if not present
if ! command -v huggingface-cli &> /dev/null; then
    echo "    Installing huggingface-cli via pip..."
    pip3 install --quiet huggingface_hub[cli]
fi

mkdir -p "$OUTPUT_DIR"

# Download the openai_whisper-small (multilingual) CoreML model from Argmax's HuggingFace repo
# "small" supports all languages (en, ja, ko, zh, es, fr, de, pt, it, ru, ar, hi)
huggingface-cli download \
    argmaxinc/whisperkit-coreml \
    --include "openai_whisper-small/*" \
    --local-dir "$OUTPUT_DIR" \
    --local-dir-use-symlinks False

echo ""
echo "==> Model downloaded to: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "  1. Open lecsy.xcodeproj in Xcode"
echo "  2. Drag the 'WhisperKitModels' folder into the lecsy target"
echo "  3. Choose 'Create folder references' (blue folder icon)"
echo "  4. Make sure 'Copy items if needed' is unchecked (files are already in project)"
echo "  5. Build & run - the model will be bundled in the app"
echo ""
