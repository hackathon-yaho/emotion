"""백엔드 내부 API 호출 — 턴 적재 (계약 §3-2).

설계: docs/02-architecture/ai-pipeline.md §9

**fire-and-forget이다.** 실패해도 대화 응답을 막지 않는다(F5-04). 백엔드가 내려가 있어도
사용자는 계속 말할 수 있어야 한다.

**재시도는 같은 페이로드를 그대로 다시 보낸다.** `occurredAt`이 재시도마다 달라지면
백엔드가 재시도를 "다른 발화"로 오판해 같은 턴이 여러 번 저장된다
(docs/response/backend/turn-index-numbering.md 3번).
"""

from __future__ import annotations

import asyncio
from typing import Any

import httpx

from .telemetry import error_log, log, session_ref

BACKOFF_MS = (200, 600, 1800)


class BackendClient:
    def __init__(
        self,
        *,
        base_url: str,
        secret: str,
        retries: int = 3,
        timeout_ms: int = 2000,
        backoff_ms: tuple[int, ...] = BACKOFF_MS,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._secret = secret
        self._retries = retries
        self._timeout = timeout_ms / 1000
        self._backoff = backoff_ms or (0,)
        self._client = client

    async def _post(self, path: str, payload: dict[str, Any]) -> httpx.Response:
        url = f"{self._base_url}{path}"
        headers = {"X-Internal-Secret": self._secret}
        if self._client is not None:
            return await self._client.post(
                url, json=payload, headers=headers, timeout=self._timeout
            )
        async with httpx.AsyncClient(timeout=self._timeout) as c:
            return await c.post(url, json=payload, headers=headers)

    async def post_turn(self, payload: dict[str, Any]) -> bool:
        """턴 적재. 성공 여부를 돌려주지만 **호출부는 기다리지 않아도 된다.**

        4xx는 재시도하지 않는다 — 우리가 잘못 보낸 것이고 다시 보내도 같다.
        5xx·타임아웃만 지수 백오프로 재시도한다.
        """
        ref = session_ref(payload.get("sessionId"))
        turn_index = payload.get("turnIndex")

        for attempt in range(self._retries + 1):
            try:
                resp = await self._post("/internal/turns", payload)
            except httpx.HTTPError:
                if attempt >= self._retries:
                    error_log(
                        "turn_post_failed",
                        sessionRef=ref,
                        turnIndex=turn_index,
                        retries=attempt,
                        status="timeout",
                    )
                    return False
                await asyncio.sleep(self._backoff[min(attempt, len(self._backoff) - 1)] / 1000)
                continue

            if resp.status_code < 300:
                if attempt:
                    log("turn_post_recovered", sessionRef=ref, turnIndex=turn_index, retries=attempt)
                return True

            if resp.status_code < 500:
                # 우리가 잘못 보냈다. 다시 보내도 같으므로 기록만 남기고 진행한다.
                error_log(
                    "turn_post_rejected",
                    sessionRef=ref,
                    turnIndex=turn_index,
                    status=resp.status_code,
                )
                return False

            if attempt >= self._retries:
                error_log(
                    "turn_post_failed",
                    sessionRef=ref,
                    turnIndex=turn_index,
                    retries=attempt,
                    status=resp.status_code,
                )
                return False
            await asyncio.sleep(self._backoff[min(attempt, len(self._backoff) - 1)] / 1000)

        return False


def build_turn_payload(
    *,
    session_id: str,
    turn_index: int,
    role: str,
    occurred_at: str,
    transcript: str,
    text_valence: float | None = None,
    voice_valence: float | None = None,
    gap: float | None = None,
    gap_triggered: bool = False,
    threshold_mode: str = "fixed",
    tags: list[str] | None = None,
    top_prosody: dict[str, float] | None = None,
    crisis_detected: bool = False,
    crisis_by: str | None = None,
) -> dict[str, Any]:
    """계약 §3-2 페이로드. **음성 원본 필드가 존재하지 않는다** (FR-041).

    assistant 턴은 valence·gap·tags가 전부 null/빈 배열이어야 하므로, 호출부가
    실수하지 않도록 여기서 강제한다.
    """
    if role == "assistant":
        text_valence = voice_valence = gap = None
        gap_triggered = False
        tags = []
        top_prosody = None

    return {
        "sessionId": session_id,
        "turnIndex": turn_index,
        "role": role,
        "occurredAt": occurred_at,
        "transcript": transcript,
        "textValence": text_valence,
        "voiceValence": voice_valence,
        "gap": gap,
        "gapTriggered": gap_triggered,
        "thresholdMode": threshold_mode,
        "tags": tags or [],
        "topProsody": top_prosody,
        "crisis": {"detected": crisis_detected, "by": crisis_by},
    }
