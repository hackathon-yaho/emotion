"""턴 적재 · LLM 경계 · 로깅 — 계약 §3-2, ai-pipeline.md §9·§10"""

import json

import httpx
import pytest
import respx

from app.backend_client import BackendClient, build_turn_payload
from app.llm import analyze as analyze_call
from app.llm import client as llm
from app.llm import respond as respond_call
from app.telemetry import log, session_ref, turn_log

BASE = "http://backend.test"
URL = f"{BASE}/internal/turns"
SID = "550e8400-e29b-41d4-a716-446655440000"
REF = session_ref(SID)


def payload(**kw):
    base = dict(
        session_id=SID,
        turn_index=8,
        role="user",
        occurred_at="2026-09-18T12:31:02.417Z",
        transcript="오늘 완전 괜찮았어요",
    )
    base.update(kw)
    return build_turn_payload(**base)


# ── 페이로드 (계약 §3-2) ──────────────────────────────────────────


def test_음성_원본_필드가_없다():
    """FR-041 — 어떤 형태로도 전송하지 않는다."""
    keys = {k.lower() for k in payload()}
    assert not (keys & {"audio", "audiourl", "voice", "recording", "wav"})


def test_assistant_턴은_valence가_강제로_비워진다():
    """호출부가 실수로 값을 넣어도 계약을 어기지 않는다."""
    p = payload(role="assistant", text_valence=0.7, gap=1.3, gap_triggered=True, tags=["회의"])
    assert p["textValence"] is None and p["gap"] is None
    assert p["gapTriggered"] is False and p["tags"] == []


def test_위기_필드_모양이_계약과_같다():
    p = payload(crisis_detected=True, crisis_by="rule")
    assert p["crisis"] == {"detected": True, "by": "rule"}


# ── 재시도 (계약 §3-2, 재시도 3회) ────────────────────────────────


@respx.mock
async def test_5xx는_재시도한다():
    route = respx.post(URL)
    route.side_effect = [httpx.Response(500), httpx.Response(500), httpx.Response(202)]
    assert await BackendClient(base_url=BASE, secret="s", retries=3, backoff_ms=(0,)).post_turn(payload())
    assert route.call_count == 3


@respx.mock
async def test_4xx는_재시도하지_않는다():
    """우리가 잘못 보냈다. 다시 보내도 같다."""
    route = respx.post(URL).mock(return_value=httpx.Response(400))
    assert await BackendClient(base_url=BASE, secret="s", retries=3, backoff_ms=(0,)).post_turn(payload()) is False
    assert route.call_count == 1


@respx.mock
async def test_재시도는_occurredAt을_바꾸지_않는다():
    """바뀌면 백엔드가 재시도를 '다른 발화'로 오판해 같은 턴이 여러 번 저장된다."""
    route = respx.post(URL)
    route.side_effect = [httpx.Response(503), httpx.Response(503), httpx.Response(202)]
    await BackendClient(base_url=BASE, secret="s", retries=3, backoff_ms=(0,)).post_turn(payload())
    stamps = {json.loads(c.request.content)["occurredAt"] for c in route.calls}
    assert stamps == {"2026-09-18T12:31:02.417Z"}


@respx.mock
async def test_끝까지_실패해도_예외를_던지지_않는다():
    """fire-and-forget — 적재 실패가 대화를 막으면 안 된다(F5-04)."""
    respx.post(URL).mock(return_value=httpx.Response(503))
    assert await BackendClient(base_url=BASE, secret="s", retries=1, backoff_ms=(0,)).post_turn(payload()) is False


# ── 채널 독립성 (FR-025 · TC-24) ──────────────────────────────────


def test_프로소디가_섞이면_보내기_전에_막는다():
    with pytest.raises(AssertionError):
        llm.assert_no_prosody({"models": {"prosody": {"scores": {"Joy": 1.0}}}})


def test_분석_호출_payload에_프로소디가_없다():
    p = analyze_call.build_user_content("오늘 괜찮았어요", [], [])
    blob = json.dumps(p, ensure_ascii=False).lower()
    assert "prosody" not in blob and "scores" not in blob


def test_응답_플래그에_수치가_없다():
    """모델에게 가는 것은 판정 결과뿐이다. 갭이 얼마인지 알 필요가 없다."""
    flags = respond_call.build_flags(
        gap_triggered=True, crisis=False, crisis_by=None,
        soft_wrap=False, advice_requested=False, elapsed_min=3,
    )
    assert set(flags) == {
        "gapTriggered", "crisis", "crisisBy", "softWrap", "adviceRequested", "elapsedMin"
    }
    assert "gap" not in {k for k in flags if k != "gapTriggered"}


def test_응답_메시지에_프로소디가_섞이면_막는다():
    with pytest.raises(AssertionError):
        respond_call.build_messages(
            [{"role": "user", "content": "안녕", "models": {"prosody": {}}}], {}
        )


def test_시스템_프롬프트가_맨_앞에_붙는다():
    msgs = respond_call.build_messages(
        [{"role": "user", "content": "안녕"}], {"crisis": False}, "너는 …"
    )
    assert msgs[0]["role"] == "system"
    assert msgs[-1]["content"].startswith("[상태]")


# ── 모델별 파라미터 (§2.5) ────────────────────────────────────────


def test_기본_파라미터가_붙는다():
    k = llm.build_kwargs(
        model="gpt-5.6-luna", max_tokens=400, temperature=0.0, effort="low",
        json_output=True,
    )
    assert k["model"] == "gpt-5.6-luna"
    assert k["max_completion_tokens"] == 400
    assert k["temperature"] == 0.0
    assert k["reasoning_effort"] == "low"
    assert k["response_format"] == {"type": "json_object"}


def test_거부당한_파라미터를_빼고_다시_만든다():
    """모델 라인업이 바뀌어도 첫 호출의 400으로 서버가 죽지 않아야 한다."""
    from openai import BadRequestError

    kwargs = llm.build_kwargs(model="m", max_tokens=300, effort="low")
    exc = BadRequestError.__new__(BadRequestError)
    Exception.__init__(exc, "Unsupported parameter: 'reasoning_effort' is not supported")

    retry = llm.learn_unsupported(exc, kwargs)
    assert retry is not None and "reasoning_effort" not in retry

    # 한 번 배우면 다음부터는 처음부터 안 붙인다
    again = llm.build_kwargs(model="m", max_tokens=300, effort="low")
    assert "reasoning_effort" not in again
    llm._unsupported.discard("reasoning_effort")


def test_모르는_400은_그대로_올린다():
    """아무 파라미터나 빼면 원인을 못 찾는다."""
    from openai import BadRequestError

    kwargs = llm.build_kwargs(model="m", max_tokens=300)
    exc = BadRequestError.__new__(BadRequestError)
    Exception.__init__(exc, "insufficient_quota")
    assert llm.learn_unsupported(exc, kwargs) is None


# ── 분석 결과 파싱 (§2.3) ─────────────────────────────────────────


def test_코드펜스가_붙어도_읽는다():
    body = llm.parse_json('```json\n{"text_valence": 0.7}\n```')
    assert body == {"text_valence": 0.7}


def test_파싱_실패는_성능_저하로_진행한다():
    """예외를 올리지 않는다 — 대화는 계속된다(FR-024)."""
    a = analyze_call.parse(llm.parse_json("이건 JSON이 아니다"))
    assert a.degraded is True and a.text_valence is None


def test_valence는_범위를_벗어나지_않는다():
    assert analyze_call.parse({"text_valence": 9.9}).text_valence == 1.0
    assert analyze_call.parse({"text_valence": -9.9}).text_valence == -1.0


def test_태그는_최대_3개다():
    a = analyze_call.parse({"tags": ["a", "b", "c", "d", "e"]})
    assert len(a.tags) == 3


def test_같은_발화는_같은_캐시_키다():
    assert analyze_call.cache_key("안녕", ["회의"]) == analyze_call.cache_key("안녕", ["회의"])
    assert analyze_call.cache_key("안녕", []) != analyze_call.cache_key("잘가", [])


# ── 로깅 화이트리스트 (FR-092) ────────────────────────────────────


def test_전사는_로그에_실리지_않는다():
    """정책이 아니라 장치다. 실수로 넘겨도 버려진다."""
    out = turn_log(sessionRef=REF, turnIndex=3, transcript="오늘 완전 괜찮았어요")
    assert "transcript" not in out


def test_화이트리스트에_없는_필드는_버린다():
    out = log("test", sessionRef=REF, 매칭된표현="죽고싶")
    assert set(out) <= {"event", "sessionRef"}


def test_허용된_지표는_남는다():
    out = turn_log(sessionRef=REF, gap=1.32, gapTriggered=True, crisisBy="rule")
    assert out["gap"] == 1.32 and out["crisisBy"] == "rule"


def test_오류_로그에도_발화가_없다():
    from app.telemetry import error_log

    out = error_log("analyze_timeout", sessionRef=REF, transcript="비밀")
    assert "transcript" not in out and out["reason"] == "analyze_timeout"


# ── sessionId는 비밀과 동급이다 (계약 §1-1) ──────────────────────


def test_sessionId를_어떤_이름으로도_로그에_못_넣는다():
    """이 값이 곧 CLM 인증 수단이다. 로그를 본 사람이 그 세션인 척 CLM을 부를 수 있다."""
    out = log(
        "test",
        sid=SID,
        sessionId=SID,
        session_id=SID,
        custom_session_id=SID,
        customSessionId=SID,
    )
    assert SID not in json.dumps(out, ensure_ascii=False)
    assert set(out) == {"event"}


def test_sessionRef는_원본을_복원할_수_없다():
    ref = session_ref(SID)
    assert SID not in ref
    assert len(ref) == 8


def test_같은_세션은_같은_참조를_갖는다():
    """로그·오류를 한 세션으로 묶는 데는 이걸로 충분하다."""
    assert session_ref(SID) == session_ref(SID)
    assert session_ref(SID) != session_ref("다른-세션-아이디")


def test_세션이_없으면_대시다():
    assert session_ref(None) == "-" and session_ref("") == "-"
