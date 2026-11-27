import os
import time
from pathlib import Path

from openai import OpenAI


def load_local_env() -> None:
    env_path = Path(__file__).with_name(".env")
    if not env_path.exists():
        return
    for raw_line in env_path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip().strip("\"'")
        os.environ.setdefault(key.strip(), value)


load_local_env()
api_key = os.getenv("DASHSCOPE_API_KEY", "").strip()
base_url = os.getenv("DASHSCOPE_BASE_URL", "").strip()
model_name = os.getenv("DASHSCOPE_MODEL", "qwen3.7-flash").strip()

if not api_key:
    raise SystemExit("DASHSCOPE_API_KEY is missing from .env")
if not base_url:
    raise SystemExit("DASHSCOPE_BASE_URL is missing from .env")

client = OpenAI(api_key=api_key, base_url=base_url)
print(f"Testing DashScope model {model_name} with streaming enabled...")
started = time.perf_counter()
first_token = True

stream = client.chat.completions.create(
    model=model_name,
    messages=[{"role": "user", "content": "你好，请用一句话介绍一下自己。"}],
    extra_body={"enable_thinking": False},
    stream=True,
)
for chunk in stream:
    if not chunk.choices:
        continue
    content = chunk.choices[0].delta.content
    if content:
        if first_token:
            print(f"\nFirst token: {time.perf_counter() - started:.3f}s\n")
            first_token = False
        print(content, end="", flush=True)
print(f"\n\nAPI test complete in {time.perf_counter() - started:.3f}s")
