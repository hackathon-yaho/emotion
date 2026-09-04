"""세션 컨텍스트 — 조회 · 캐시 · CLM 인증 (계약 §3-4).

설계: docs/02-architecture/ai-pipeline.md §7

**이 조회가 곧 인증이다.** Hume이 실어 보내는 것은 `custom_session_id` 하나뿐이고,
그게 백엔드에 실재하는 열린 세션인지 확인하는 유일한 경로가 여기다.

fail-closed다. 캐시가 없고 조회도 실패하면 401을 돌려준다. 백엔드가 죽어 있으면
`POST /api/session/start`도 죽어 있어 새 세션 자체가 생기지 않으므로 잃는 가용성이 없고,
진행 중인 대화는 캐시가 지킨다.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

import httpx

from .rules import turns as turn_rules
from .telemetry import error_log

CACHE_TAIL_SEC = 30 * 60  # 이어하기 창 (계약 §2-5-1)


class SessionUnauthorized(Exception):
    """Hume에 401로 돌려줘야 하는 상태. 이유 코드만 들고 다닌다(FR-092)."""

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


@dataclass
class SessionContext:
    session_id: str
    status: str
    started_at: str | None
    used_sec: int
    last_turn_index: int
    threshold_mode: str
    gap_threshold: float | None
    soft_wrap_sec: int
    hard_cut_sec: int
    demo_mode: bool
    recent_observations: list[dict[str, Any]] = field(default_factory=list)

    # 로컬 상태 — 백엔드가 주는 값이 아니다.
    fetched_at: float = 0.0
    issued: int = 0
    last_turn_at: float | None = None
    last_occurred_at: str | None = None

    @classmethod
    def from_response(cls, body: dict[str, Any], *, now: float) -> "SessionContext":
        return cls(
            session_id=body.get("sessionId", ""),
            status=body.get("status", "open"),
            started_at=body.get("startedAt"),
            used_sec=int(body.get("usedSec") or 0),
            last_turn_index=int(body.get("lastTurnIndex") or 0),
            threshold_mode=body.get("thresholdMode") or "fixed",
            gap_threshold=body.get("gapThreshold"),
            soft_wrap_sec=int(body.get("softWrapSec") or 300),
            hard_cut_sec=int(body.get("hardCutSec") or 420),
            demo_mode=bool(body.get("demoMode")),
            recent_observations=list(body.get("recentObservations") or []),
            fetched_at=now,
        )

    def ttl_sec(self) -> int:
        return self.hard_cut_sec + CACHE_TAIL_SEC

    def expired(self, now: float) -> bool:
        return now - self.fetched_at >= self.ttl_sec()

    def elapsed_sec(self, now_utc: datetime) -> int | None:
        """세션 경과 시간. 마무리 유도(F2-03) 판단용."""
        if not self.started_at:
            return None
        try:
            started = datetime.fromisoformat(self.started_at.replace("Z", "+00:00"))
        except ValueError:
            return None
        return int((now_utc - started).total_seconds()) + self.used_sec


class SessionStore:
    """세션당 1회 조회 + 메모리 캐시. 실시간 경로에 매 턴 홉을 더하지 않는다."""

    def __init__(
        self,
        *,
        base_url: str,
        secret: str,
        timeout_ms: int = 800,
        connect_retry: int = 1,
        refetch_idle_sec: int = 60,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._secret = secret
        self._timeout = timeout_ms / 1000
        self._connect_retry = connect_retry
        self._refetch_idle_sec = refetch_idle_sec
        self._client = client
        self._cache: dict[str, SessionContext] = {}

    # ── 조회 ──────────────────────────────────────────────────────

    async def _fetch(self, session_id: str, *, now: float) -> SessionContext:
        url = f"{self._base_url}/internal/sessions/{session_id}"
        headers = {"X-Internal-Secret": self._secret}
        attempts = self._connect_retry + 1
        last_reason = "lookup_failed"

        for attempt in range(attempts):
            try:
                if self._client is not None:
                    resp = await self._client.get(
                        url, headers=headers, timeout=self._timeout
                    )
                else:
                    async with httpx.AsyncClient(timeout=self._timeout) as c:
                        resp = await c.get(url, headers=headers)
            except (httpx.ConnectError, httpx.ConnectTimeout):
                # 연결 단계 실패만 재시도한다 — 터널 재시작의 연결 거부와
                # 백엔드의 실제 거절은 다르다.
                last_reason = "lookup_connect_failed"
                if attempt < attempts - 1:
                    continue
                raise SessionUnauthorized(last_reason)
            except httpx.HTTPError:
                raise SessionUnauthorized("lookup_timeout")

            if resp.status_code == 404:
                raise SessionUnauthorized("session_not_found")
            if resp.status_code >= 500:
                raise SessionUnauthorized("lookup_5xx")
            if resp.status_code != 200:
                raise SessionUnauthorized("lookup_bad_status")

            ctx = SessionContext.from_response(resp.json(), now=now)
            if ctx.status != "open":
                # 백엔드는 200으로 주고, 401로 바꾸는 판단은 우리 몫이다(계약 §3-4).
                raise SessionUnauthorized("session_ended")
            return ctx

        raise SessionUnauthorized(last_reason)

    async def resolve(
        self,
        session_id: str,
        *,
        now: float | None = None,
        history_user_turns: int | None = None,
    ) -> SessionContext:
        """캐시 → 없거나 만료·재조회 조건이면 백엔드. 실패 시 401(캐시가 없을 때만)."""
        now = time.monotonic() if now is None else now
        cached = self._cache.get(session_id)

        if cached and not cached.expired(now):
            idle = now - (cached.last_turn_at or cached.fetched_at)
            refetch = turn_rules.should_refetch_session(
                idle,
                self._refetch_idle_sec,
                history_user_turns=history_user_turns,
                issued_user_turns=cached.issued // 2,
            )
            if not refetch:
                return cached

            # 재조회는 **최선 노력**이다. 실패해도 이미 인증된 대화를 끊지 않는다.
            try:
                fresh = await self._fetch(session_id, now=now)
            except SessionUnauthorized as exc:
                if exc.reason == "session_ended":
                    raise
                error_log(f"session_refetch_failed:{exc.reason}", sid=session_id)
                cached.fetched_at = now
                return cached

            fresh.last_turn_at = cached.last_turn_at
            fresh.last_occurred_at = cached.last_occurred_at
            fresh.issued = 0  # lastTurnIndex를 새로 받았으므로 카운터를 다시 센다
            self._cache[session_id] = fresh
            return fresh

        ctx = await self._fetch(session_id, now=now)
        self._cache[session_id] = ctx
        return ctx

    # ── 턴 번호와 시각 ────────────────────────────────────────────

    def allocate_turn_indices(self, ctx: SessionContext) -> tuple[int, int]:
        """user·assistant 번호를 함께 잡는다 (§7.3). 스트림이 길어져도 순서가 안 뒤집힌다."""
        user_idx, assistant_idx = turn_rules.next_indices(
            ctx.last_turn_index, ctx.issued
        )
        ctx.issued += 2
        return user_idx, assistant_idx

    def stamp(self, ctx: SessionContext, moment: datetime) -> str:
        """발화 시각. 같은 세션 직전 값과 겹치면 1ms를 더한다 (계약 §3-2 v1.5)."""
        value = turn_rules.stamp(moment, ctx.last_occurred_at)
        ctx.last_occurred_at = value
        return value

    def mark_turn(self, ctx: SessionContext, *, now: float | None = None) -> None:
        ctx.last_turn_at = time.monotonic() if now is None else now

    # ── 테스트·운영 보조 ──────────────────────────────────────────

    def peek(self, session_id: str) -> SessionContext | None:
        return self._cache.get(session_id)

    def forget(self, session_id: str) -> None:
        self._cache.pop(session_id, None)
