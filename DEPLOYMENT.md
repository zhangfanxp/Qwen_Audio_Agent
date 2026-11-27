# Mac 本地语音助手部署手册

## 架构

- Silero VAD、Smart Turn、Paraformer-zh：Mac 本地。
- Qwen3-TTS 0.6B CustomVoice 8bit（MLX）：Mac 本地。
- Qwen3.7-Flash：阿里云百炼 OpenAI 兼容 Chat Completions API。
- 服务端监听 `127.0.0.1:8765`，客户端经 WebSocket 连接。

识别后的文字和必要的对话上下文会发送到百炼。LLM 文本流和 TTS 音频流均启用。

## 环境

目标为 Apple Silicon、macOS、Python 3.12、uv。部署时保留已工作的虚拟环境，不升级依赖。当前 Mac 的 `speech-to-speech` 版本为 1.1.0，运行环境位于 `~/Documents/qwen-audio-agent/.venv`；本目录的 `.venv` 是本机忽略的符号链接。换机时创建自己的 `.venv`，不要复制或提交虚拟环境：

```sh
uv venv --python 3.12 .venv
uv pip sync --python .venv/bin/python requirements-macos-arm64.lock.txt
```

## 模型缓存

Hugging Face Hub 在 macOS 的默认缓存目录是 `~/.cache/huggingface/hub`。TTS 模型使用仓库 ID `mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-8bit`，不要将模型权重提交到 Git。

首次下载：

```sh
./download_models.sh
```

下载脚本会使用 Hugging Face CLI 的默认 Hub 缓存。Paraformer、Smart Turn 和 Silero VAD 在首次加载时各自下载到 ModelScope、Hugging Face Hub 和 Torch Hub 缓存。

## 配置百炼

在 `.env` 设置以下变量：

```dotenv
DASHSCOPE_API_KEY='你的真实 API Key'
DASHSCOPE_BASE_URL='https://你的工作空间.cn-beijing.maas.aliyuncs.com/compatible-mode/v1'
DASHSCOPE_MODEL='qwen3.7-flash'
QWEN3_TTS_MODEL_PATH='mlx-community/Qwen3-TTS-12Hz-0.6B-CustomVoice-8bit'
QWEN3_TTS_STREAMING_CHUNK_SIZE='4'
STREAM_BATCH_SENTENCES='2'
VOICE_REPLY_MAX_SENTENCES='3'
VOICE_REPLY_MAX_CHARS='120'
S2S_PORT='8765'
PLAYBACK_BUFFER_MS='100'
```

`.env` 权限应为 `600`，`.gitignore` 已排除该文件。不要把 API Key 放入命令行参数、文档或 Git。

## API 与服务启动

先检查 API 连通性：

```sh
./.venv/bin/python test_dashscope.py
```

测试只会输出模型名、响应文本和耗时，不会打印 API Key。

服务端和客户端分别在两个终端启动：

```sh
./start_server_cloud.sh
./start_client.sh
```

服务端启动时会检查 NLTK 的 `punkt_tab` 分句资源；若新 Mac 尚未缓存，会自动下载到项目内的 `.nltk_data/`。该目录已加入 `.gitignore`。

服务端启用 Paraformer-zh、Smart Turn、Silero VAD、流式 Chat Completions、关闭百炼思考模式，以及 Vivian 音色的 Qwen3-TTS 分块生成。语音回答默认最多 3 个短句、约 120 字；TTS 分块大小设为 4，句子批次设为 2，客户端播放缓冲设为 100ms，以提升较长回答的连续播放稳定性。服务绑定回环地址，不对局域网开放。客户端显示 `Ready — start speaking.` 后即可讲话。按 `Ctrl+C` 停止。

当前 PyTorch 环境没有可用的 MPS 后端，因此 Paraformer 显式使用 CPU；Qwen3-TTS 在 Apple Silicon 上使用 MLX。`start_dashscope.py` 会优先从现有 ModelScope 快照目录加载 Paraformer，换机时若缓存不存在则回退到 FunASR 的正常下载流程。

## 常见问题

- 401：检查 `.env` 是否存在、API Key 是否有效，以及脚本是否能读取变量。
- 404：核对百炼工作空间 Base URL 和模型可用性。
- TTS 模型未找到：运行 `./download_models.sh`，并确认 `~/.cache/huggingface/hub` 下模型快照完整。
- `Resource 'punkt_tab' not found`：重新运行 `./start_server_cloud.sh`，脚本会自动下载缺少的分句资源。
- 音频仍有断续：将 `PLAYBACK_BUFFER_MS` 从 `100` 调到 `150`，并保持 `QWEN3_TTS_STREAMING_CHUNK_SIZE='4'`。
- 麦克风不可用：在 macOS“系统设置 → 隐私与安全性 → 麦克风”允许所用终端。

## Git 安全检查

```sh
git status --short
git check-ignore -v .env .venv
git ls-files .env models
```

`.env`、`.venv`、模型权重、日志和录音不应出现在提交中。锁定文件记录本机现有依赖版本；换机时在兼容的 Python 3.12 / Apple Silicon 环境中同步依赖。
