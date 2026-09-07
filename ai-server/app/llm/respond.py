"""응답 호출 — 대화 텍스트만 스트리밍한다.

설계: docs/02-architecture/ai-pipeline.md §2.5 · 프롬프트: prompts/respond.system.md

**스트림에 메타 태그도 JSON도 없다** (AI-13). 그래서 여기에는 파싱·제거 로직이 없고,
받은 조각을 그대로 흘려보낸다. 첫 글자까지 걸리는 시간이 버퍼링으로 늘지 않고,
태그가 음성으로 새어 나가는 실패 모드 자체가 존재하지 않는다.

**수치를 보내지 않는다.** 갭이 얼마인지 모델이 알 필요가 없다. 판정은 코드가 끝냈고,
모델에게는 "되물어라"라는 **플래그**만 간다.
"""

from __future__ import annotations

import json
from typing import Any, AsyncIterator

from openai import BadRequestError, RateLimitError

from ..telemetry import error_log
from . import client as llm


def _log_failure(exc: Exception, *, sent: bool, model: str | None) -> None:
    """실패에 **원인 코드를 반드시 붙인다.**

    종전에는 `respond_failed` 한 줄뿐이라 429인지 끊김인지 타임아웃인지 구별할
    수 없었다. 그래서 앱이 원인을 마이크·샘플레이트 쪽에서 반나절 찾았다
    (`docs/request/ai/respond-fallback.md`). **구별할 수 없는 실패는 진단을 늦춘다.**

    **메시지 본문은 담지 않는다.** 벤더 오류에는 우리가 보낸 내용이 되비쳐 오는
    경우가 있다 — 클래스 이름과 HTTP 상태까지만 남긴다(FR-092).

    **스트리밍 경로에는 `client.create()`의 429 로그가 없다.** 그쪽은 비스트리밍
    전용이라, 응답 호출이 한도에 걸려도 `llm_rate_limited`가 한 번도 안 찍혔다.
    여기서 같이 남긴다.
    """
    if isinstance(exc, RateLimitError):
        error_log("llm_rate_limited", model=model)
    code = llm.failure_code(exc)
    error_log(f"respond_failed_midstream:{code}" if sent else f"respond_failed:{code}")

# 응답 호출이 실패했을 때 내보내는 문장. 템플릿이지만 대화를 멈추지 않는다.
# **실패 원인은 우리 쪽인데 종전 문장은 사용자의 말을 탓했다** — "잘 듣지 못했어요.
# 한 번만 다시 말씀해 주시겠어요?". 그래서 사용자는 더 크게 또박또박 다시 말하고 또
# 실패한다. 앱 개발자도 같은 이유로 마이크·샘플레이트를 반나절 팠다
# (`docs/request/ai/respond-fallback.md`, 앱 제안 채택).
# 원인을 노출하지 않으면서 **헛수고를 시키지 않는** 문장으로 바꾼다.
FALLBACK = "잠깐 제가 말이 막혔어요. 조금 뒤에 다시 이어가도 될까요?"
FALLBACK_CRISIS = (
    "지금 많이 힘드신 것 같아요. 혼자 견디지 않으셔도 됩니다. "
    "자살예방 상담전화 109에서 24시간 이야기하실 수 있어요. 저도 여기 있을게요."
)


def build_flags(
    *,
    gap_triggered: bool,
    crisis: bool,
    crisis_by: str | None,
    soft_wrap: bool,
    advice_requested: bool,
    elapsed_min: int | None,
) -> dict[str, Any]:
    """모델에게 가는 것은 **판정 결과**뿐이다. 수치는 없다."""
    flags = {
        "gapTriggered": gap_triggered,
        "crisis": crisis,
        "crisisBy": crisis_by,
        "softWrap": soft_wrap,
        "adviceRequested": advice_requested,
        "elapsedMin": elapsed_min,
    }
    llm.assert_no_prosody(flags)
    return flags


def build_messages(
    history: list[dict[str, str]], flags: dict[str, Any], system: str = ""
) -> list[dict[str, str]]:
    """시스템 프롬프트 + 대화 이력(텍스트만) + 플래그 블록.

    플래그는 마지막 user 메시지 뒤에 별도 블록으로 붙인다. 이력 자체를 건드리면
    다음 턴에 Hume이 보내는 이력과 어긋난다.
    """
    llm.assert_no_prosody(history)
    messages: list[dict[str, str]] = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.extend(history)
    messages.append(
        {"role": "user", "content": "[상태]\n" + json.dumps(flags, ensure_ascii=False)}
    )
    return messages


async def _iter(
    messages: list[dict[str, str]], kwargs: dict[str, Any], api_key: str, base_url: str = ""
):
    stream = await llm.client(api_key, base_url).chat.completions.create(
        messages=messages, stream=True, **kwargs
    )
    async for chunk in stream:
        if not chunk.choices:
            continue
        choice = chunk.choices[0]
        # 사고 토큰이 출력 예산을 먹으면 문장 중간에서 끊긴다. 그 상태로 TTS에 가면
        # 사용자는 말이 잘리는 걸 듣는다 — 원인을 알 수 있게 남긴다.
        if getattr(choice, "finish_reason", None) == "length":
            error_log("respond_truncated", model=kwargs.get("model"))
        piece = getattr(choice.delta, "content", None)
        if piece:
            yield piece


async def stream(
    *,
    history: list[dict[str, str]],
    flags: dict[str, Any],
    model: str,
    effort: str = "low",
    api_key: str = "",
    base_url: str = "",
    prompts_dir=None,
) -> AsyncIterator[str]:
    """텍스트 조각을 그대로 흘린다. 실패하면 정형 문장 하나를 흘리고 끝낸다."""
    system = (
        llm.system_prompt("respond", prompts_dir)
        if prompts_dir
        else llm.system_prompt("respond")
    )
    messages = build_messages(history, flags, system)
    # 사고 토큰이 이 예산을 함께 쓰므로 넉넉히 준다. 길이는 프롬프트가 잡는다(1~3문장).
    kwargs = llm.build_kwargs(model=model, max_tokens=1000, effort=effort)

    sent = False
    try:
        async for piece in _iter(messages, kwargs, api_key, base_url):
            sent = True
            yield piece
        return
    except BadRequestError as exc:
        if sent:
            _log_failure(exc, sent=True, model=kwargs.get("model"))
            return
        retry = llm.learn_unsupported(exc, kwargs)
        if retry is None:
            error_log("respond_bad_request")
            yield FALLBACK_CRISIS if flags.get("crisis") else FALLBACK
            return
        kwargs = retry
    except Exception as exc:
        # 이미 말을 시작했다면 정형 문장을 덧붙이지 않는다 — 문장이 겹쳐 들린다.
        _log_failure(exc, sent=sent, model=kwargs.get("model"))
        if not sent:
            yield FALLBACK_CRISIS if flags.get("crisis") else FALLBACK
        return

    try:
        async for piece in _iter(messages, kwargs, api_key, base_url):
            yield piece
    except Exception as exc:
        _log_failure(exc, sent=False, model=kwargs.get("model"))
        yield FALLBACK_CRISIS if flags.get("crisis") else FALLBACK
