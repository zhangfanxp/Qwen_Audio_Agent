#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "$0")" && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi
: "${S2S_PORT:=8765}"
: "${PLAYBACK_BUFFER_MS:=0}"

if [[ ! -x .venv/bin/speech-to-speech ]]; then
  echo "Missing .venv or speech-to-speech. See DEPLOYMENT.md." >&2
  exit 1
fi

exec .venv/bin/speech-to-speech talk \
  --url "ws://127.0.0.1:${S2S_PORT}/v1/realtime" \
  --block-mic-during-playback \
  --playback-buffer-ms "$PLAYBACK_BUFFER_MS"
