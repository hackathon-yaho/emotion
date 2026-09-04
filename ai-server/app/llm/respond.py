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

from openai import BadRequestError

from ..telemetry import error_log
from . import client as llm

# 응답 호출이 실패했을 때 내보내는 문장. 템플릿이지만 대화를 멈추지 않는다.
FALLBACK = "지금은 제가 잘 듣지 못했어요. 한 번만 다시 말씀해 주시겠어요?"
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
            error_log("respond_failed_midstream")
            return
        retry = llm.learn_unsupported(exc, kwargs)
        if retry is None:
            error_log("respond_bad_request")
            yield FALLBACK_CRISIS if flags.get("crisis") else FALLBACK
            return
        kwargs = retry
    except Exception:
        # 이미 말을 시작했다면 정형 문장을 덧붙이지 않는다 — 문장이 겹쳐 들린다.
        error_log("respond_failed_midstream" if sent else "respond_failed")
        if not sent:
            yield FALLBACK_CRISIS if flags.get("crisis") else FALLBACK
        return

    try:
        async for piece in _iter(messages, kwargs, api_key, base_url):
            yield piece
    except Exception:
        error_log("respond_failed")
        yield FALLBACK_CRISIS if flags.get("crisis") else FALLBACK
