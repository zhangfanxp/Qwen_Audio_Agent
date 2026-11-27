import os
from pathlib import Path
from urllib.parse import urlparse

from speech_to_speech.LLM.base_openai_compatible_language_model import (
    BaseOpenAICompatibleHandler,
)
from speech_to_speech.STT.paraformer_handler import ParaformerSTTHandler
from speech_to_speech.utils.utils import TORCH_DEVICES, resolve_device
from speech_to_speech.cli import main


_original_build_extra_body = BaseOpenAICompatibleHandler._build_extra_body


def _build_extra_body(cls, base_url, disable_thinking, reasoning_effort):
    hostname = urlparse(base_url or "").hostname or ""
    if hostname.endswith((".aliyuncs.com", ".dashscope.aliyun.com")):
        print("[DashScope] enable_thinking=False")
        return {"enable_thinking": False}
    return _original_build_extra_body(
        base_url,
        disable_thinking,
        reasoning_effort,
    )


BaseOpenAICompatibleHandler._build_extra_body = classmethod(_build_extra_body)


# FunASR's current Paraformer handler strips namespace/path components from
# model names. Reuse the already-downloaded ModelScope snapshot directly when
# present, while preserving the normal hub download behavior on a fresh Mac.
_original_paraformer_setup = ParaformerSTTHandler.setup
_paraformer_cache = (
    Path.home()
    / ".cache/modelscope/models/iic--speech_seaco_paraformer_large_asr_nat-zh-cn-16k-common-vocab8404-pytorch/snapshots/master"
)


def _setup_paraformer(self, model_name="paraformer-zh", device="cuda", gen_kwargs=None):
    local_model = Path(os.environ.get("S2S_PARAFORMER_MODEL_PATH", _paraformer_cache))
    if model_name == "paraformer-zh" and (local_model / "model.pt").is_file():
        from funasr import AutoModel

        self.language = "zh"
        self.device = resolve_device(device, TORCH_DEVICES, "Paraformer STT")
        self.model = AutoModel(model=str(local_model), device=self.device)
        self.warmup()
        return
    if gen_kwargs is None:
        _original_paraformer_setup(self, model_name=model_name, device=device)
    else:
        _original_paraformer_setup(
            self,
            model_name=model_name,
            device=device,
            gen_kwargs=gen_kwargs,
        )


ParaformerSTTHandler.setup = _setup_paraformer


if __name__ == "__main__":
    main()
