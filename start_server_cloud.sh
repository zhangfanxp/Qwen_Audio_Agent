#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "$0")" && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "Missing .env. Copy .env.example to .env and configure DashScope." >&2
  exit 1
fi
set -a
source .env
set +a

: "${DASHSCOPE_API_KEY:?DASHSCOPE_API_KEY is empty in .env}"
: "${DASHSCOPE_BASE_URL:?DASHSCOPE_BASE_URL is empty in .env}"
: "${DASHSCOPE_MODEL:=qwen3.7-flash}"
: "${QWEN3_TTS_MODEL_PATH:=mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-8bit}"
: "${QWEN3_TTS_STREAMING_CHUNK_SIZE:=4}"
: "${STREAM_BATCH_SENTENCES:=2}"
: "${VOICE_REPLY_MAX_SENTENCES:=3}"
: "${VOICE_REPLY_MAX_CHARS:=120}"
: "${S2S_PORT:=8765}"
export OPENAI_API_KEY="$DASHSCOPE_API_KEY"
VOICE_PROMPT="你叫小智，是一名智能语音助手。请用自然、简洁的中文口语回答。语音回复默认最多${VOICE_REPLY_MAX_SENTENCES}个短句、约${VOICE_REPLY_MAX_CHARS}个汉字；即使问题复杂，也先完整说出最重要的结论。用户明确要求详细内容时，用短句分段表达，避免长段落、列表和Markdown。每个句子都要完整，不要生成超长答复。"

PYTHON="$ROOT/.venv/bin/python"
if [[ ! -x "$PYTHON" ]]; then
  echo "Missing .venv. See DEPLOYMENT.md for environment setup." >&2
  exit 1
fi

# NLTK 3.9+ needs punkt_tab for sentence splitting; prepare it before requests arrive.
NLTK_DATA_DIR="$ROOT/.nltk_data"
export NLTK_DATA="$NLTK_DATA_DIR${NLTK_DATA:+:$NLTK_DATA}"
if ! "$PYTHON" -c 'import nltk; nltk.data.find("tokenizers/punkt_tab/english/")' >/dev/null 2>&1; then
  echo "Downloading NLTK punkt_tab sentence data..."
  mkdir -p "$NLTK_DATA_DIR"
  "$PYTHON" -c 'import nltk, os, sys; ok = nltk.download("punkt_tab", download_dir=os.environ["NLTK_DATA"].split(os.pathsep)[0], quiet=True); sys.exit(0 if ok else 1)'
  "$PYTHON" -c 'import nltk; nltk.data.find("tokenizers/punkt_tab/english/")'
fi

if [[ -d "$QWEN3_TTS_MODEL_PATH" ]]; then
  [[ -f "$QWEN3_TTS_MODEL_PATH/config.json" ]] || {
    echo "TTS model directory is incomplete: $QWEN3_TTS_MODEL_PATH" >&2
    exit 1
  }
else
  "$PYTHON" -c 'from huggingface_hub import snapshot_download; import sys; snapshot_download(repo_id=sys.argv[1], local_files_only=True)' "$QWEN3_TTS_MODEL_PATH" || {
    echo "TTS model is not present in the local Hugging Face cache. Run ./download_models.sh." >&2
    exit 1
  }
fi

echo "Python: $("$PYTHON" --version 2>&1)"
echo "LLM model: $DASHSCOPE_MODEL"
echo "TTS model: $QWEN3_TTS_MODEL_PATH"
exec "$PYTHON" start_dashscope.py serve \
  --stt paraformer \
  --paraformer_stt_model_name paraformer-zh \
  --llm_backend chat-completions \
  --model_name "$DASHSCOPE_MODEL" \
  --responses_api_base_url "$DASHSCOPE_BASE_URL" \
  --responses_api_stream \
  --responses_api_disable_thinking \
  --tts qwen3 \
  --qwen3_tts_model_name "$QWEN3_TTS_MODEL_PATH" \
  --qwen3_tts_mlx_quantization 8bit \
  --qwen3_tts_speaker Vivian \
  --qwen3_tts_language chinese \
  --qwen3_tts_streaming_chunk_size "$QWEN3_TTS_STREAMING_CHUNK_SIZE" \
  --paraformer_stt_device cpu \
  --init_chat_prompt "$VOICE_PROMPT" \
  --stream_batch_sentences "$STREAM_BATCH_SENTENCES" \
  --host 127.0.0.1 \
  --port "$S2S_PORT"
