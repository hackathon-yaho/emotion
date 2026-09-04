"""분석 호출 — 전사만 읽고 텍스트 valence·태그·위기·조언 요청을 낸다.

설계: docs/02-architecture/ai-pipeline.md §2.3 · 프롬프트: prompts/analyze.system.md

**프로소디가 이 호출에 실리지 않는다** (FR-025). 톤을 본 모델이 텍스트 valence를 내면
갭은 자기 자신과의 차이가 되어 지표로서 죽는다. `assert_no_prosody`가 보내기 전에 막는다.

타임아웃은 400ms다. 넘기면 전부 비우고 진행한다 — 갭은 미산출, 되묻기는 생략,
**규칙 위기 감지와 응답은 정상**이다. 그것이 FR-024의 의미다.
"""

from __future__ import annotations

import asyncio
import hashlib
from dataclasses import dataclass, field
from typing import Any

from ..telemetry import error_log
from . import client as llm


@dataclass
class Analysis:
    text_valence: float | None = None
    tags: list[str] = field(default_factory=list)
    crisis: bool | None = None
    crisis_reason: str | None = None
    advice_requested: bool = False
    degraded: bool = False

    @classmethod
    def empty(cls, reason: str) -> "Analysis":
        error_log(f"analyze_{reason}")
        return cls(degraded=True, crisis=None)


def cache_key(transcript: str, known_tags: list[str]) -> str:
    """전사 해시. 같은 발화를 두 번 분석하지 않는다(재시도·중복 요청)."""
    raw = transcript + "\x00" + "\x00".join(sorted(known_tags))
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _clamp(value: Any) -> float | None:
    try:
        v = float(value)
    except (TypeError, ValueError):
        return None
    return round(max(-1.0, min(1.0, v)), 2)


def parse(body: dict[str, Any] | None) -> Analysis:
    if not body:
        return Analysis.empty("unparsable")
    tags = body.get("tags") or []
    return Analysis(
        text_valence=_clamp(body.get("text_valence")),
        tags=[t for t in tags if isinstance(t, str)][:3],
        crisis=bool(body.get("crisis")),
        crisis_reason=body.get("crisis_reason") or None,
        advice_requested=bool(body.get("advice_requested")),
    )


def build_user_content(
    transcript: str, recent_turns: list[dict[str, str]], known_tags: list[str]
) -> dict[str, Any]:
    payload = {
        "transcript": transcript,
        "recent_turns": recent_turns,
        "known_tags": known_tags,
    }
    llm.assert_no_prosody(payload)
    return payload


async def run(
    *,
    transcript: str,
    recent_turns: list[dict[str, str]],
    known_tags: list[str],
    model: str,
    timeout_ms: int,
    api_key: str = "",
    prompts_dir=None,
) -> Analysis:
    """실패·타임아웃은 예외를 올리지 않는다. 빈 결과로 대화를 계속한다."""
    if not transcript.strip():
        return Analysis(degraded=True)

    payload = build_user_content(transcript, recent_turns, known_tags)
    system = (
        llm.system_prompt("analyze", prompts_dir)
        if prompts_dir
        else llm.system_prompt("analyze")
    )
    kwargs = llm.build_kwargs(model=model, max_tokens=400, temperature=0.0)

    import json as _json

    async def _call() -> Analysis:
        try:
            msg = await llm.client(api_key).messages.create(
                system=system,
                messages=[
                    {"role": "user", "content": _json.dumps(payload, ensure_ascii=False)}
                ],
                **kwargs,
            )
        except llm.LLMRefusal:
            return Analysis.empty("refusal")
        return parse(llm.parse_json(llm.text_of(msg)))

    try:
        return await asyncio.wait_for(_call(), timeout=timeout_ms / 1000)
    except asyncio.TimeoutError:
        return Analysis.empty("timeout")
    except Exception:
        return Analysis.empty("failed")
