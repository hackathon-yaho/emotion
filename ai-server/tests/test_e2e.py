"""종단 확인 — 앱이 실제로 뜨고 SSE가 계약대로 나오는가.

Hume도 Anthropic도 없이 도는 경로만 본다. **LLM이 죽어 있을 때도 스트림이
계약대로 닫히는지**가 핵심이다 — 그 상태가 지금 우리 기본값이고(키 미발급),
9/6 통합에서 백엔드가 처음 만나는 상태이기도 하다.
"""

import json
from pathlib import Path

import httpx
import respx
from fastapi.testclient import TestClient

from app.main import app

BASE = "http://localhost:8080"
SID = "550e8400-e29b-41d4-a716-446655440000"
SESSION_URL = f"{BASE}/internal/sessions/{SID}"
TURNS_URL = f"{BASE}/internal/turns"
FIXTURES = Path(__file__).resolve().parent.parent / "eval" / "fixtures" / "internal"

CLM_BODY = {
    "messages": [
        {
            "role": "user",
            "content": "오늘 완전 괜찮았어요",
            "time": {"begin": 0, "end": 2100},
            "models": {"prosody": {"scores": {"Tiredness": 0.71, "Joy": 0.06}}},
        }
    ],
    "stream": True,
}


def fx(name: str) -> dict:
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


def events(text: str) -> list[str]:
    return [ln for ln in text.split("\n\n") if ln.strip()]


def test_헬스체크가_뜬다():
    with TestClient(app) as c:
        assert c.get("/healthz").json() == {"status": "ok"}


def test_세션_ID가_없으면_401이다():
    with TestClient(app) as c:
        assert c.post("/chat/completions", json=CLM_BODY).status_code == 401


@respx.mock
def test_없는_세션은_401이다():
    respx.get(SESSION_URL).mock(return_value=httpx.Response(404))
    with TestClient(app) as c:
        r = c.post(f"/chat/completions?custom_session_id={SID}", json=CLM_BODY)
    assert r.status_code == 401


@respx.mock
def test_종료된_세션은_401이다():
    """백엔드는 200으로 준다. 401로 바꾸는 판단이 우리 몫이다(계약 §3-4)."""
    respx.get(SESSION_URL).mock(
        return_value=httpx.Response(200, json=fx("sessions.200.ended.json"))
    )
    with TestClient(app) as c:
        r = c.post(f"/chat/completions?custom_session_id={SID}", json=CLM_BODY)
    assert r.status_code == 401


@respx.mock
def test_LLM이_죽어도_스트림이_계약대로_닫힌다():
    """지금 상태가 정확히 이것이다 — Anthropic 키가 없다.

    Hume 입장에서 중요한 건 **응답이 오고 [DONE]으로 닫히는 것**이다.
    여기가 깨지면 사용자 화면에서는 대화가 멈춘 것처럼 보인다.
    """
    respx.get(SESSION_URL).mock(
        return_value=httpx.Response(200, json=fx("sessions.200.open.json"))
    )
    respx.post(TURNS_URL).mock(return_value=httpx.Response(202))

    with TestClient(app) as c:
        r = c.post(f"/chat/completions?custom_session_id={SID}", json=CLM_BODY)

    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/event-stream")

    lines = events(r.text)
    assert lines[-1] == "data: [DONE]"

    payloads = [json.loads(ln[len("data: ") :]) for ln in lines[:-1]]
    assert all(p["object"] == "chat.completion.chunk" for p in payloads)
    assert all(p["system_fingerprint"] == SID for p in payloads)
    assert payloads[0]["choices"][0]["delta"]["role"] == "assistant"
    assert payloads[-1]["choices"][0]["finish_reason"] == "stop"

    spoken = "".join(
        p["choices"][0]["delta"].get("content", "") for p in payloads
    )
    assert spoken.strip()  # 빈 응답을 내보내지 않는다


@respx.mock
def test_스트림에_메타_태그도_JSON도_없다():
    """AI-13 — 파싱·제거 로직 자체가 없으므로, 새어 나갈 것도 없어야 한다."""
    respx.get(SESSION_URL).mock(
        return_value=httpx.Response(200, json=fx("sessions.200.open.json"))
    )
    respx.post(TURNS_URL).mock(return_value=httpx.Response(202))

    with TestClient(app) as c:
        r = c.post(f"/chat/completions?custom_session_id={SID}", json=CLM_BODY)

    payloads = [json.loads(ln[len("data: ") :]) for ln in events(r.text)[:-1]]
    spoken = "".join(p["choices"][0]["delta"].get("content", "") for p in payloads)
    for token in ("<v>", "<m>", "gapTriggered", "{", "}", "prosody"):
        assert token not in spoken


@respx.mock
def test_턴이_계약대로_적재된다():
    """user 턴과 assistant 턴이 각각 한 번씩, 번호가 이어져서."""
    respx.get(SESSION_URL).mock(
        return_value=httpx.Response(200, json=fx("sessions.200.open.json"))
    )
    route = respx.post(TURNS_URL).mock(return_value=httpx.Response(202))

    with TestClient(app) as c:
        c.post(f"/chat/completions?custom_session_id={SID}", json=CLM_BODY)

    sent = [json.loads(call.request.content) for call in route.calls]
    by_role = {t["role"]: t for t in sent}
    assert set(by_role) == {"user", "assistant"}
    assert by_role["user"]["turnIndex"] == 1
    assert by_role["assistant"]["turnIndex"] == 2
    # 음성 채널은 LLM과 무관하게 살아 있다
    assert by_role["user"]["voiceValence"] is not None
    # 분석이 죽었으므로 텍스트 채널과 갭은 없다
    assert by_role["user"]["textValence"] is None
    assert by_role["user"]["gap"] is None
    assert by_role["user"]["gapTriggered"] is False
    # assistant 턴은 비어 있어야 한다
    assert by_role["assistant"]["voiceValence"] is None
    assert by_role["assistant"]["tags"] == []


@respx.mock
def test_백엔드가_턴_적재에_실패해도_대화는_끝난다():
    """fire-and-forget (F5-04). 적재 실패가 응답을 막으면 안 된다."""
    respx.get(SESSION_URL).mock(
        return_value=httpx.Response(200, json=fx("sessions.200.open.json"))
    )
    respx.post(TURNS_URL).mock(return_value=httpx.Response(500))

    with TestClient(app) as c:
        r = c.post(f"/chat/completions?custom_session_id={SID}", json=CLM_BODY)

    assert r.status_code == 200
    assert events(r.text)[-1] == "data: [DONE]"


def test_깨진_본문은_400이다():
    """500으로 두면 우리 서버 장애처럼 보이고 실제 장애와 섞인다."""
    with TestClient(app) as c:
        r = c.post(
            f"/chat/completions?custom_session_id={SID}",
            # UTF-8이 아닌 바이트. cp949 콘솔에서 보낸 한글이 이렇게 도착한다.
            content=(
                b'{"messages":[{"role":"user","content":"'
                + bytes([0xBE, 0xC8])
                + b'"}]}'
            ),
            headers={"Content-Type": "application/json"},
        )
    assert r.status_code == 400


def test_JSON이_아닌_본문도_400이다():
    with TestClient(app) as c:
        r = c.post(
            f"/chat/completions?custom_session_id={SID}",
            content=b"not json at all",
            headers={"Content-Type": "application/json"},
        )
    assert r.status_code == 400


def test_내부_API는_시크릿_없이는_401이다():
    with TestClient(app) as c:
        assert c.post("/internal/observations", json={}).status_code == 401
        assert c.post("/internal/summaries", json={}).status_code == 401
