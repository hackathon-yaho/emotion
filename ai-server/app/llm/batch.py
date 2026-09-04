"""배치 호출 — 관찰 문장화와 세션 요약 (계약 §3-3·§3-5).

설계: docs/02-architecture/ai-pipeline.md §8

둘 다 **실패하면 만들지 않는다.** 템플릿 문장으로 대체하지 않는다 —
표현이 어색한 것보다 근거 없는 문장이 나가는 쪽이 위험하다.

사후 검사는 `app/rules/`의 순수 함수가 한다. 여기는 호출만 한다.
"""

from __future__ import annotations

import json
from typing import Any

from ..rules import observe_guard, summary_guard
from ..telemetry import error_log
from . import client as llm


class Rejected(Exception):
    """사후 검사 실패. 이유 코드만 들고 다닌다."""

    def __init__(self, reasons: list[str]) -> None:
        super().__init__(",".join(reasons))
        self.reasons = reasons


async def observe(
    *, payload: dict[str, Any], model: str, effort: str = "medium",
    api_key: str = "", prompts_dir=None, rules_dir=None,
) -> str:
    """숫자와 태그만 받아 한 문장. 원본 대화는 오지 않는다(계약 §3-3)."""
    system = (
        llm.system_prompt("observe", prompts_dir)
        if prompts_dir
        else llm.system_prompt("observe")
    )
    kwargs = llm.build_kwargs(model=model, max_tokens=200, effort=effort)

    try:
        msg = await llm.client(api_key).messages.create(
            system=system,
            messages=[{"role": "user", "content": json.dumps(payload, ensure_ascii=False)}],
            **kwargs,
        )
        body = llm.parse_json(llm.text_of(msg)) or {}
    except llm.LLMRefusal:
        raise Rejected(["refusal"])
    except Exception:
        error_log("observe_failed")
        raise Rejected(["call_failed"])

    sentence = (body.get("sentence") or "").strip()
    tag = payload.get("tag", "")
    reasons = (
        observe_guard.check(sentence, tag, rules_dir=rules_dir)
        if rules_dir
        else observe_guard.check(sentence, tag)
    )
    if reasons:
        error_log("observe_rejected", guardReasons=reasons)
        raise Rejected(reasons)
    return sentence


async def summarize(
    *, turns: list[dict[str, str]], model: str, api_key: str = "",
    prompts_dir=None, rules_dir=None,
) -> str:
    """턴 텍스트만 받아 한 문장. valence·갭·태그는 오지 않는다(계약 §3-5)."""
    system = (
        llm.system_prompt("summary", prompts_dir)
        if prompts_dir
        else llm.system_prompt("summary")
    )
    payload = {"turns": turns}
    llm.assert_no_prosody(payload)
    kwargs = llm.build_kwargs(model=model, max_tokens=200, temperature=0.0)

    try:
        msg = await llm.client(api_key).messages.create(
            system=system,
            messages=[{"role": "user", "content": json.dumps(payload, ensure_ascii=False)}],
            **kwargs,
        )
        body = llm.parse_json(llm.text_of(msg)) or {}
    except llm.LLMRefusal:
        raise Rejected(["refusal"])
    except Exception:
        error_log("summary_failed")
        raise Rejected(["call_failed"])

    summary = (body.get("summary") or "").strip()
    reasons = (
        summary_guard.check(summary, rules_dir=rules_dir)
        if rules_dir
        else summary_guard.check(summary)
    )
    if reasons:
        error_log("summary_rejected", guardReasons=reasons)
        raise Rejected(reasons)
    return summary
