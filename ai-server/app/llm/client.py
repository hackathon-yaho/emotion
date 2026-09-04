"""LLM 호출의 공용 부분 — 클라이언트 · 프롬프트 로딩 · 모델별 파라미터 차이.

설계: docs/02-architecture/ai-pipeline.md §2.3·§2.5·§8

**LLM SDK를 import하는 곳은 `app/llm/` 안뿐이다.** 밖에서 import하면 리뷰에서 반려한다
(ai-server/README.md 경계). 벤더를 바꿀 때 고쳐야 하는 범위가 이 폴더로 한정된다 —
2026-09-05에 Anthropic → OpenAI → Google로 두 번 옮길 때 실제로 그랬다.

현재 벤더는 **Google Gemini 무료 티어**이고, Gemini가 제공하는 **OpenAI 호환
엔드포인트**를 쓴다. 그래서 SDK는 `openai`를 그대로 두고 `base_url`만 바꾼다.
또 옮기게 되면 키·`base_url`·모델 이름만 환경변수로 갈면 된다.

프롬프트 전문은 `prompts/*.system.md`가 단일 출처다. 문서에는 요지만 둔다(PRD §9.3).

## 파라미터를 방어적으로 다루는 이유

모델마다 받는 파라미터가 다르고 문서에 다 적혀 있지도 않다. 그래서 **거부당하면 한 번
배우고 다시 붙이지 않는다.** 첫 호출에서 400을 맞아도 대화가 죽지 않는다.
"""

from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path
from typing import Any

from openai import AsyncOpenAI, BadRequestError, RateLimitError

from ..telemetry import error_log, log

DEFAULT_PROMPTS_DIR = Path(__file__).resolve().parent.parent.parent / "prompts"

# 서버가 거부한 파라미터. 프로세스 수명 동안 기억해 다시 붙이지 않는다.
_unsupported: set[str] = set()

_FENCE = re.compile(r"^```(?:json)?\s*|\s*```$", re.MULTILINE)

# 400 메시지에서 문제 파라미터를 찾을 때 볼 후보들.
_TUNABLE = ("reasoning_effort", "temperature", "response_format", "max_completion_tokens")


class LLMRefusal(Exception):
    """모델이 응답을 거부했다. 발화 내용을 담지 않는다."""


@lru_cache(maxsize=4)
def client(api_key: str = "", base_url: str = "") -> AsyncOpenAI:
    kwargs: dict[str, Any] = {}
    if api_key:
        kwargs["api_key"] = api_key
    if base_url:
        kwargs["base_url"] = base_url
    return AsyncOpenAI(**kwargs)


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
    json_output: bool = False,
) -> dict[str, Any]:
    """호출 파라미터. 이미 거부당한 것은 처음부터 붙이지 않는다."""
    kwargs: dict[str, Any] = {"model": model}
    if "max_completion_tokens" not in _unsupported:
        kwargs["max_completion_tokens"] = max_tokens
    else:
        kwargs["max_tokens"] = max_tokens
    if temperature is not None and "temperature" not in _unsupported:
        kwargs["temperature"] = temperature
    if effort and "reasoning_effort" not in _unsupported:
        kwargs["reasoning_effort"] = effort
    if json_output and "response_format" not in _unsupported:
        kwargs["response_format"] = {"type": "json_object"}
    return kwargs


def _offending_param(message: str) -> str | None:
    lowered = message.lower()
    for name in _TUNABLE:
        if name in lowered:
            return name
    return None


def learn_unsupported(exc: BadRequestError, kwargs: dict[str, Any]) -> dict[str, Any] | None:
    """400을 보고 문제 파라미터를 빼낸다. 뺄 게 없으면 None.

    모델 라인업이 바뀌어도 서버가 죽지 않게 하려는 장치다. 어떤 파라미터가 거부됐는지만
    로그에 남기고, 요청 본문은 남기지 않는다.
    """
    name = _offending_param(str(exc))
    if name is None or name not in kwargs:
        return None
    _unsupported.add(name)
    log("llm_param_dropped", status=name)
    out = {k: v for k, v in kwargs.items() if k != name}
    if name == "max_completion_tokens":
        out["max_tokens"] = kwargs[name]
    return out


async def create(
    messages: list[dict[str, Any]],
    kwargs: dict[str, Any],
    api_key: str,
    base_url: str = "",
):
    """비스트리밍 호출. 파라미터가 거부되면 한 번만 고쳐서 다시 시도한다."""
    c = client(api_key, base_url)
    try:
        return await c.chat.completions.create(messages=messages, **kwargs)
    except RateLimitError:
        # 무료 티어는 분당 요청 수가 낮다. 다른 실패와 구분해서 남겨야
        # "왜 정형 문장만 나왔나"를 나중에 설명할 수 있다.
        error_log("llm_rate_limited", model=kwargs.get("model"))
        raise
    except BadRequestError as exc:
        retry = learn_unsupported(exc, kwargs)
        if retry is None:
            raise
        return await c.chat.completions.create(messages=messages, **retry)


def text_of(completion: Any) -> str:
    """응답에서 텍스트만 뽑는다. 거부는 예외로 올린다."""
    choice = completion.choices[0]
    if getattr(choice.message, "refusal", None):
        raise LLMRefusal("refusal")
    if getattr(choice, "finish_reason", None) == "content_filter":
        raise LLMRefusal("content_filter")
    return (choice.message.content or "").strip()


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
