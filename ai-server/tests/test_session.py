"""세션 컨텍스트 · CLM 인증 — 계약 §3-4, ai-pipeline.md §7"""

import json
from datetime import datetime, timezone
from pathlib import Path

import httpx
import pytest
import respx

from app.session import SessionStore, SessionUnauthorized

BASE = "http://backend.test"
SID = "550e8400-e29b-41d4-a716-446655440000"
URL = f"{BASE}/internal/sessions/{SID}"
FIXTURES = Path(__file__).resolve().parent.parent / "eval" / "fixtures" / "internal"


def fx(name: str) -> dict:
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


def store(**kw) -> SessionStore:
    return SessionStore(base_url=BASE, secret="s3cret", **kw)


@respx.mock
async def test_정상_세션을_읽는다():
    respx.get(URL).mock(return_value=httpx.Response(200, json=fx("sessions.200.open.json")))
    ctx = await store().resolve(SID)
    assert ctx.status == "open"
    assert ctx.gap_threshold == 0.85
    assert ctx.last_turn_index == 0


@respx.mock
async def test_시크릿을_헤더로_보낸다():
    route = respx.get(URL).mock(
        return_value=httpx.Response(200, json=fx("sessions.200.open.json"))
    )
    await store().resolve(SID)
    assert route.calls[0].request.headers["X-Internal-Secret"] == "s3cret"


@respx.mock
async def test_종료된_세션은_401이다():
    """백엔드는 200으로 준다. 401로 바꾸는 판단이 우리 몫이다(계약 §3-4)."""
    respx.get(URL).mock(return_value=httpx.Response(200, json=fx("sessions.200.ended.json")))
    with pytest.raises(SessionUnauthorized) as e:
        await store().resolve(SID)
    assert e.value.reason == "session_ended"


@respx.mock
async def test_없는_세션은_401이다():
    respx.get(URL).mock(return_value=httpx.Response(404))
    with pytest.raises(SessionUnauthorized) as e:
        await store().resolve(SID)
    assert e.value.reason == "session_not_found"


@respx.mock
async def test_캐시_미스에_5xx면_fail_closed다():
    """fail-open이면 '백엔드 장애 시간 = 인증 무방비 시간'이 된다 (AI-17)."""
    respx.get(URL).mock(return_value=httpx.Response(503))
    with pytest.raises(SessionUnauthorized) as e:
        await store().resolve(SID)
    assert e.value.reason == "lookup_5xx"


@respx.mock
async def test_연결_실패는_한_번_재시도한다():
    route = respx.get(URL)
    route.side_effect = [
        httpx.ConnectError("refused"),
        httpx.Response(200, json=fx("sessions.200.open.json")),
    ]
    ctx = await store(connect_retry=1).resolve(SID)
    assert ctx.status == "open"
    assert route.call_count == 2


@respx.mock
async def test_세션당_한_번만_조회한다():
    route = respx.get(URL).mock(
        return_value=httpx.Response(200, json=fx("sessions.200.open.json"))
    )
    s = store()
    await s.resolve(SID, now=100.0)
    await s.resolve(SID, now=101.0)
    await s.resolve(SID, now=102.0)
    assert route.call_count == 1


@respx.mock
async def test_캐시가_있으면_백엔드가_죽어도_통과한다():
    """진행 중인 대화는 캐시가 지킨다 (F5-04)."""
    route = respx.get(URL)
    route.side_effect = [
        httpx.Response(200, json=fx("sessions.200.open.json")),
        httpx.Response(503),
    ]
    s = store(refetch_idle_sec=60)
    await s.resolve(SID, now=100.0)
    ctx = await s.resolve(SID, now=200.0)  # 유휴 100초 → 재조회 시도 → 503
    assert ctx.status == "open"  # 그래도 끊기지 않는다


@respx.mock
async def test_유휴가_길면_재조회해_lastTurnIndex를_다시_읽는다():
    """이어하기 감지 (§7.2). 재연결은 우리에게 보이지 않는다."""
    route = respx.get(URL)
    route.side_effect = [
        httpx.Response(200, json=fx("sessions.200.open.json")),
        httpx.Response(200, json=fx("sessions.200.resumed.json")),
    ]
    s = store(refetch_idle_sec=60)
    first = await s.resolve(SID, now=100.0)
    assert first.last_turn_index == 0
    second = await s.resolve(SID, now=200.0)
    assert second.last_turn_index == 7
    assert route.call_count == 2


@respx.mock
async def test_재조회_후_채번이_이어_붙는다():
    """0으로 돌아가면 이후 모든 턴이 조용히 버려진다."""
    route = respx.get(URL)
    route.side_effect = [
        httpx.Response(200, json=fx("sessions.200.open.json")),
        httpx.Response(200, json=fx("sessions.200.resumed.json")),
    ]
    s = store(refetch_idle_sec=60)
    ctx = await s.resolve(SID, now=100.0)
    assert s.allocate_turn_indices(ctx) == (1, 2)
    ctx2 = await s.resolve(SID, now=200.0)
    assert s.allocate_turn_indices(ctx2) == (8, 9)


@respx.mock
async def test_대화가_이어지면_재조회하지_않는다():
    route = respx.get(URL).mock(
        return_value=httpx.Response(200, json=fx("sessions.200.open.json"))
    )
    s = store(refetch_idle_sec=60)
    await s.resolve(SID, now=100.0)
    await s.resolve(SID, now=110.0)
    assert route.call_count == 1


@respx.mock
async def test_발화_시각이_겹치지_않는다():
    respx.get(URL).mock(return_value=httpx.Response(200, json=fx("sessions.200.open.json")))
    s = store()
    ctx = await s.resolve(SID)
    moment = datetime(2026, 9, 18, 12, 31, 2, 417000, tzinfo=timezone.utc)
    first = s.stamp(ctx, moment)
    second = s.stamp(ctx, moment)
    assert first != second


@respx.mock
async def test_경과_시간은_usedSec을_더한다():
    """이어하기 세션은 이미 쓴 시간이 있다 (계약 §3-4)."""
    respx.get(URL).mock(
        return_value=httpx.Response(200, json=fx("sessions.200.resumed.json"))
    )
    ctx = await store().resolve(SID)
    now = datetime(2026, 9, 18, 12, 32, 0, tzinfo=timezone.utc)  # startedAt +120초
    assert ctx.elapsed_sec(now) == 120 + 186


@respx.mock
async def test_TTL은_하드컷에_이어하기_창을_더한다():
    respx.get(URL).mock(return_value=httpx.Response(200, json=fx("sessions.200.open.json")))
    ctx = await store().resolve(SID)
    assert ctx.ttl_sec() == 420 + 1800
