"""FastAPI 엔트리 — Hume CLM · 내부 API.

설계: docs/02-architecture/ai-pipeline.md §2 (실시간) · §8 (배치)
계약: docs/02-architecture/api-contract.md §3 (내부) · §4 (Hume, 변경 불가)

실시간 경로에서 **대화를 멈추는 실패는 인증 실패 하나뿐이다.** 분석이 죽어도, 백엔드가
죽어도, 태그가 다 걸러져도 사용자는 계속 말할 수 있다.
"""

from __future__ import annotations

import asyncio
import time
from datetime import datetime, timezone
from typing import Any, AsyncIterator

from fastapi import FastAPI, Header, HTTPException, Query, Request
from fastapi.responses import JSONResponse, StreamingResponse

from .backend_client import BackendClient, build_turn_payload
from .clm import sse
from .clm.request import ChatRequest
from .config import settings
from .llm import analyze as analyze_call
from .llm import batch as batch_call
from .llm import respond as respond_call
from .rules import crisis, gap as gap_rules, tags as tag_rules, valence
from .session import SessionStore, SessionUnauthorized
from .telemetry import configure, error_log, turn_log

app = FastAPI(title="emotion ai-server", version="0.1.0")

_cfg = settings()
configure(_cfg.ai_log_level)

_sessions = SessionStore(
    base_url=_cfg.backend_base_url,
    secret=_cfg.internal_shared_secret,
    timeout_ms=_cfg.ai_session_lookup_timeout_ms,
    connect_retry=_cfg.ai_session_lookup_connect_retry,
    refetch_idle_sec=_cfg.ai_session_refetch_idle_sec,
)
_backend = BackendClient(
    base_url=_cfg.backend_base_url,
    secret=_cfg.internal_shared_secret,
    retries=_cfg.ai_turn_post_retries,
)
_analyze_cache: dict[str, analyze_call.Analysis] = {}
_tasks: set[asyncio.Task] = set()


def _spawn(coro) -> None:
    """fire-and-forget. 참조를 들고 있어야 가비지 컬렉터가 태스크를 죽이지 않는다."""
    task = asyncio.create_task(coro)
    _tasks.add(task)
    task.add_done_callback(_tasks.discard)


def _require_internal(secret: str | None) -> None:
    if not _cfg.internal_shared_secret or secret != _cfg.internal_shared_secret:
        raise HTTPException(status_code=401, detail={"code": "INTERNAL_AUTH_FAILED"})


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


# ── Hume → AI서버 (계약 §4, 외부·변경 불가) ──────────────────────


@app.post("/chat/completions")
async def chat_completions(
    request: Request, custom_session_id: str = Query(default="")
) -> Any:
    started = time.monotonic()
    if not custom_session_id:
        raise HTTPException(status_code=401, detail="missing custom_session_id")

    body = ChatRequest.model_validate(await request.json())
    transcript = body.transcript()
    prosody = body.prosody()

    # ② 세션 컨텍스트 — 이 조회가 곧 인증이다 (§7.1). 실패하면 여기서 끝난다.
    try:
        ctx = await _sessions.resolve(
            custom_session_id, history_user_turns=body.user_turn_count()
        )
    except SessionUnauthorized as exc:
        error_log("clm_unauthorized", sid=custom_session_id, reason=exc.reason)
        raise HTTPException(status_code=401, detail=exc.reason) from exc

    ctx_ms = int((time.monotonic() - started) * 1000)

    # ③ 병렬 — 음성(규칙) · 위기(규칙) · 분석(LLM)
    voice_v = valence.voice_valence(prosody, min_mass=_cfg.ai_voice_valence_min_mass)
    unknown = valence.unknown_emotions(prosody)
    rule_hit = crisis.detect_tier_a(transcript)

    known_tags = [o.get("tag", "") for o in ctx.recent_observations if o.get("tag")]
    key = analyze_call.cache_key(transcript, known_tags)
    analyze_started = time.monotonic()
    if key in _analyze_cache:
        analysis = _analyze_cache[key]
        analyze_hit = True
    else:
        analysis = await analyze_call.run(
            transcript=transcript,
            recent_turns=body.recent_text_turns(),
            known_tags=known_tags,
            model=_cfg.ai_model_analyze,
            timeout_ms=_cfg.ai_analyze_timeout_ms,
            api_key=_cfg.anthropic_api_key,
        )
        _analyze_cache[key] = analysis
        analyze_hit = False
    analyze_ms = int((time.monotonic() - analyze_started) * 1000)

    # ④ 판정 — 전부 코드가 한다
    threshold, threshold_source = gap_rules.resolve_threshold(
        ctx.gap_threshold, _cfg.ai_gap_threshold_fixed
    )
    gap_value = gap_rules.gap(analysis.text_valence, voice_v)
    gap_triggered = gap_rules.gap_triggered(gap_value, threshold)
    crisis_detected, crisis_by = crisis.decide(rule_hit, analysis.crisis)
    kept_tags, dropped = tag_rules.filter_tags(analysis.tags, transcript)

    elapsed = ctx.elapsed_sec(datetime.now(timezone.utc))
    soft_wrap = elapsed is not None and elapsed >= ctx.soft_wrap_sec

    user_idx, assistant_idx = _sessions.allocate_turn_indices(ctx)
    now_utc = datetime.now(timezone.utc)
    user_occurred = _sessions.stamp(ctx, now_utc)

    # ⑦-1 user 턴 적재 — 응답을 기다리지 않는다
    _spawn(
        _backend.post_turn(
            build_turn_payload(
                session_id=custom_session_id,
                turn_index=user_idx,
                role="user",
                occurred_at=user_occurred,
                transcript=transcript,
                text_valence=analysis.text_valence,
                voice_valence=voice_v,
                gap=gap_value,
                gap_triggered=gap_triggered,
                threshold_mode=ctx.threshold_mode,
                tags=kept_tags,
                top_prosody=valence.top_prosody(prosody),
                crisis_detected=crisis_detected,
                crisis_by=crisis_by,
            )
        )
    )

    flags = respond_call.build_flags(
        gap_triggered=gap_triggered,
        crisis=crisis_detected,
        crisis_by=crisis_by,
        soft_wrap=soft_wrap,
        advice_requested=analysis.advice_requested,
        elapsed_min=(elapsed // 60) if elapsed is not None else None,
    )

    turn_log(
        sid=custom_session_id,
        turnIndex=user_idx,
        ctxMs=ctx_ms,
        analyzeMs=analyze_ms,
        analyzeCacheHit=analyze_hit,
        gap=gap_value,
        gapTriggered=gap_triggered,
        textValence=analysis.text_valence,
        voiceValence=voice_v,
        thresholdMode=ctx.threshold_mode,
        thresholdSource=threshold_source,
        crisisDetected=crisis_detected,
        crisisBy=crisis_by,
        tagsKept=len(kept_tags),
        tagsDropped=len(dropped),
        dropReasons=sorted(set(dropped)),
        unknownEmotions=sorted(unknown) if unknown else None,
        demoMode=ctx.demo_mode,
    )

    # ⑤⑥ 응답 스트림 — 버퍼링 없음, 메타 태그 없음
    async def body_stream() -> AsyncIterator[str]:
        yield sse.first_chunk(custom_session_id)
        collected: list[str] = []
        try:
            async for piece in respond_call.stream(
                history=body.text_history(),
                flags=flags,
                model=_cfg.ai_model_respond,
                effort=_cfg.ai_respond_effort,
                api_key=_cfg.anthropic_api_key,
            ):
                collected.append(piece)
                yield sse.content_chunk(custom_session_id, piece)
        finally:
            for line in sse.close(custom_session_id):
                yield line
            _sessions.mark_turn(ctx)
            # ⑦-2 assistant 턴 — 스트림이 끊겨도 보낸 만큼은 적재한다
            _spawn(
                _backend.post_turn(
                    build_turn_payload(
                        session_id=custom_session_id,
                        turn_index=assistant_idx,
                        role="assistant",
                        occurred_at=_sessions.stamp(ctx, datetime.now(timezone.utc)),
                        transcript="".join(collected),
                        threshold_mode=ctx.threshold_mode,
                    )
                )
            )

    return StreamingResponse(
        body_stream(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


# ── 백엔드 → AI서버 (계약 §3-3·§3-5) ─────────────────────────────


@app.post("/internal/observations")
async def observations(
    request: Request, x_internal_secret: str | None = Header(default=None)
) -> Any:
    _require_internal(x_internal_secret)
    payload = await request.json()
    try:
        sentence = await batch_call.observe(
            payload=payload,
            model=_cfg.ai_model_observe,
            effort=_cfg.ai_observe_effort,
            api_key=_cfg.anthropic_api_key,
        )
    except batch_call.Rejected as exc:
        return JSONResponse(
            status_code=422,
            content={"error": {"code": "SENTENCE_REJECTED", "reasons": exc.reasons}},
        )
    return {"sentence": sentence}


@app.post("/internal/summaries")
async def summaries(
    request: Request, x_internal_secret: str | None = Header(default=None)
) -> Any:
    _require_internal(x_internal_secret)
    payload = await request.json()
    try:
        summary = await batch_call.summarize(
            turns=payload.get("turns") or [],
            model=_cfg.ai_model_summary,
            api_key=_cfg.anthropic_api_key,
        )
    except batch_call.Rejected as exc:
        return JSONResponse(
            status_code=422,
            content={"error": {"code": "SUMMARY_REJECTED", "reasons": exc.reasons}},
        )
    return {"summary": summary}
