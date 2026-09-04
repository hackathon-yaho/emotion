"""LLM 호출의 공용 부분 — 클라이언트 · 프롬프트 로딩 · 모델별 파라미터 차이.

설계: docs/02-architecture/ai-pipeline.md §2.3·§2.5·§8

**LLM SDK를 import하는 곳은 `app/llm/` 안뿐이다.** 밖에서 import하면 리뷰에서 반려한다
(ai-server/README.md 경계). 그래야 "어디서 모델을 부르는가"가 한 곳으로 모인다.

프롬프트 전문은 `prompts/*.system.md`가 단일 출처다. 문서에는 요지만 둔다(PRD §9.3).
"""

from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path
from typing import Any

from anthropic import AsyncAnthropic

from ..telemetry import error_log

DEFAULT_PROMPTS_DIR = Path(__file__).resolve().parent.parent.parent / "prompts"

# sonnet-5·opus-5는 샘플링 파라미터를 받지 않는다(400). haiku-4-5는 받는다.
_NO_SAMPLING = ("sonnet-5", "opus-5")

# effort 파라미터를 서버가 거부하면 한 번만 배우고 다시 붙이지 않는다.
_effort_supported = True

_FENCE = re.compile(r"^```(?:json)?\s*|\s*```$", re.MULTILINE)


class LLMRefusal(Exception):
    """모델이 응답을 거부했다. 발화 내용을 담지 않는다."""


@lru_cache(maxsize=1)
def client(api_key: str = "") -> AsyncAnthropic:
    return AsyncAnthropic(api_key=api_key) if api_key else AsyncAnthropic()


@lru_cache(maxsize=16)
def system_prompt(name: str, prompts_dir: Path = DEFAULT_PROMPTS_DIR) -> str:
    path = prompts_dir / f"{name}.system.md"
    if not path.exists():
        raise FileNotFoundError(f"프롬프트가 없다: {path}")
    return path.read_text(encoding="utf-8")


def build_kwargs(
    *,
    model: str,
    max_tokens: int,
    temperature: float | None = None,
    effort: str | None = None,
) -> dict[str, Any]:
    """모델별로 받는 파라미터가 달라서 여기서 갈라 준다."""
    kwargs: dict[str, Any] = {"model": model, "max_tokens": max_tokens}
    if temperature is not None and not any(m in model for m in _NO_SAMPLING):
        kwargs["temperature"] = temperature
    if effort and _effort_supported:
        kwargs["extra_body"] = {"output_config": {"effort": effort}}
    return kwargs


def drop_effort(kwargs: dict[str, Any]) -> dict[str, Any]:
    """400을 맞으면 effort를 빼고 한 번 더 시도한다. 이후 호출은 아예 안 붙인다."""
    global _effort_supported
    _effort_supported = False
    out = dict(kwargs)
    body = out.get("extra_body")
    if isinstance(body, dict):
        body.pop("output_config", None)
        if not body:
            out.pop("extra_body")
    return out


def text_of(message: Any) -> str:
    """응답에서 텍스트만 뽑는다. 거부는 예외로 올린다."""
    if getattr(message, "stop_reason", None) == "refusal":
        raise LLMRefusal("refusal")
    parts = []
    for block in getattr(message, "content", []) or []:
        if getattr(block, "type", None) == "text":
            parts.append(block.text)
    return "".join(parts).strip()


def parse_json(raw: str) -> dict[str, Any] | None:
    """모델이 코드펜스를 붙여도 읽는다. 실패하면 None — 호출부가 성능 저하로 진행한다."""
    if not raw:
        return None
    cleaned = _FENCE.sub("", raw).strip()
    try:
        value = json.loads(cleaned)
    except json.JSONDecodeError:
        start, end = cleaned.find("{"), cleaned.rfind("}")
        if start == -1 or end <= start:
            error_log("analyze_json_unparsable")
            return None
        try:
            value = json.loads(cleaned[start : end + 1])
        except json.JSONDecodeError:
            error_log("analyze_json_unparsable")
            return None
    return value if isinstance(value, dict) else None


def assert_no_prosody(payload: Any) -> None:
    """FR-025·TC-24 — 분석·응답 호출 payload에 프로소디가 실리면 즉시 실패시킨다.

    프롬프트로 막는 게 아니라 **보내기 전에** 막는다. 테스트도 이 함수를 검사한다.
    """
    banned = ("prosody", "models", "scores", "voiceValence", "voice_valence")
    blob = json.dumps(payload, ensure_ascii=False, default=str).lower()
    for token in banned:
        if token.lower() in blob:
            raise AssertionError(f"채널 독립성 위반: payload에 '{token}'이 있다")
