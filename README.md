# Mac Voice Agent + DashScope

Mac 上的实时中文语音助手部署配置：本地 Paraformer 识别、本地 Qwen3-TTS 语音合成，阿里云百炼 `qwen3.7-flash` 负责对话。语音服务使用 Hugging Face `speech-to-speech`，通过 WebSocket 连接本机麦克风和扬声器。

## 当前 Mac 快速启动

需要 Apple Silicon、Python 3.12 和本地 `.venv`。当前部署复用原有 `~/Documents/qwen-audio-agent/.venv`，没有重新安装依赖。首次使用请在 `.env` 配置百炼 API Key 和 Base URL。

```sh
./start_server_cloud.sh
```

在另一个终端运行：

```sh
./start_client.sh
```

按 `Ctrl+C` 停止各自终端中的进程。macOS 首次使用时，允许终端访问麦克风。

部署和换机说明见 [DEPLOYMENT.md](DEPLOYMENT.md)。API Key 只保存在本地 `.env`，模型文件保存在 Hugging Face 缓存，不进入 Git。
