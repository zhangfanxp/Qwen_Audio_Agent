#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "$0")" && pwd)"
cd "$ROOT"

PYTHON="$ROOT/.venv/bin/python"
if [[ ! -x "$PYTHON" ]]; then
  echo "Missing .venv. See DEPLOYMENT.md for environment setup." >&2
  exit 1
fi

MODEL_ID="mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-8bit"
if ! .venv/bin/hf --help >/dev/null 2>&1; then
  echo "Hugging Face CLI (hf) is missing from .venv." >&2
  echo "Install it with: uv pip install --python .venv/bin/python 'huggingface_hub[hf_xet]'" >&2
  exit 1
fi

echo "Downloading or verifying $MODEL_ID in the Hugging Face Hub cache..."
.venv/bin/hf download "$MODEL_ID"
"$PYTHON" -c 'from huggingface_hub import snapshot_download; import sys; print(snapshot_download(repo_id=sys.argv[1], local_files_only=True))' "$MODEL_ID"
