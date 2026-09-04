"""Hume CLM 요청 파싱과 SSE — 계약 §4 (외부, 변경 불가)"""

import json

from app.clm import sse
from app.clm.request import ChatRequest

SID = "550e8400-e29b-41d4-a716-446655440000"

PAYLOAD = {
    "messages": [
        {"role": "system", "content": "무시되어야 한다"},
        {
            "role": "user",
            "content": "오늘 회의가 세 개나 있었어요",
            "time": {"begin": 0, "end": 2100},
            "models": {"prosody": {"scores": {"Tiredness": 0.4}}},
        },
        {"role": "assistant", "content": "많이 바쁘셨겠어요."},
        {
            "role": "user",
            "content": "오늘 완전 괜찮았어요",
            "time": {"begin": 5000, "end": 7100},
            "models": {"prosody": {"scores": {"Tiredness": 0.71, "Joy": 0.06}}},
        },
    ],
    "stream": True,
    "알수없는필드": "무시",
}


def _req() -> ChatRequest:
    return ChatRequest.model_validate(PAYLOAD)


def test_마지막_user_발화를_고른다():
    assert _req().transcript() == "오늘 완전 괜찮았어요"


def test_마지막_발화의_프로소디를_고른다():
    assert _req().prosody() == {"Tiredness": 0.71, "Joy": 0.06}


def test_모르는_필드가_있어도_파싱된다():
    """Hume이 필드를 추가해도 서버가 죽지 않아야 한다."""
    assert _req().stream is True


def test_이력에는_프로소디가_없다():
    """FR-025 — 채널 독립성은 여기서 시작된다."""
    blob = json.dumps(_req().text_history(), ensure_ascii=False)
    assert "prosody" not in blob and "scores" not in blob and "time" not in blob


def test_이력에서_system을_뺀다():
    roles = {t["role"] for t in _req().text_history()}
    assert roles == {"user", "assistant"}


def test_분석용_맥락은_마지막_발화를_뺀다():
    """마지막 user 발화는 따로 전달하므로 중복해서 넣지 않는다."""
    recent = _req().recent_text_turns()
    assert all(t["content"] != "오늘 완전 괜찮았어요" for t in recent)


def test_user_턴_수를_센다():
    """이어하기 감지의 보조 신호(§7.2)."""
    assert _req().user_turn_count() == 2


def test_빈_요청도_죽지_않는다():
    empty = ChatRequest.model_validate({"messages": []})
    assert empty.transcript() == "" and empty.prosody() is None


# ── SSE ───────────────────────────────────────────────────────────


def _data(line: str) -> dict:
    assert line.startswith("data: ") and line.endswith("\n\n")
    return json.loads(line[len("data: ") : -2])


def test_첫_청크는_역할을_싣는다():
    d = _data(sse.first_chunk(SID))
    assert d["choices"][0]["delta"]["role"] == "assistant"
    assert d["object"] == "chat.completion.chunk"


def test_세션_ID가_system_fingerprint에_실린다():
    """계약 §4 — Hume이 이걸로 세션을 잇는다."""
    assert _data(sse.content_chunk(SID, "안녕"))["system_fingerprint"] == SID


def test_내용_청크는_delta_content에_들어간다():
    assert _data(sse.content_chunk(SID, "안녕"))["choices"][0]["delta"]["content"] == "안녕"


def test_스트림은_stop_다음_DONE으로_닫는다():
    lines = sse.close(SID)
    assert _data(lines[0])["choices"][0]["finish_reason"] == "stop"
    assert lines[1] == "data: [DONE]\n\n"


def test_한글이_이스케이프되지_않는다():
    assert "안녕" in sse.content_chunk(SID, "안녕")
