"""Hume 표정 꼬리 — 발화 원문에서 떼어낸다 (request/ai/prosody-suffix-in-transcript.md).

Hume은 user 발화 끝에 상위 3개 표정을 영문으로 붙여 보낸다.
    "아 내가 이거 합격하면은 좀. {slightly doubtful, slightly calm, very slightly interested}"
두면 텍스트 valence LLM이 음성 채널을 읽어 **갭의 전제가 깨지고**(FR-025),
사용자가 말한 적 없는 문장이 기록으로 저장된다. 백엔드가 근거 화면에서 발견했다.
"""

import pytest

from app.clm.request import ChatRequest, strip_expression_suffix

SEEN = "아 내가 이거 합격하면은 좀. {slightly doubtful, slightly calm, very slightly interested}"


def test_실제로_본_꼬리를_뗀다():
    text, had = strip_expression_suffix(SEEN)
    assert text == "아 내가 이거 합격하면은 좀."
    assert had is True


@pytest.mark.parametrize(
    "tail",
    [
        "{very happy, quite anxious, moderately amused}",
        "{tired, sad, calm}",
        "{slightly surprise (positive), very slightly empathic pain, quite awe}",
        "{extremely determination}",
    ],
)
def test_여러_형태의_꼬리를_뗀다(tail):
    text, had = strip_expression_suffix(f"오늘 완전 괜찮았어요 {tail}")
    assert text == "오늘 완전 괜찮았어요"
    assert had


@pytest.mark.parametrize(
    "said",
    [
        "오늘 완전 괜찮았어요",
        "제가 {진짜 괜찮았어요} 라고 했잖아요",          # 한글 중괄호는 사용자가 한 말이다
        "{진짜 괜찮았어요}",
        "",
    ],
)
def test_꼬리가_아니면_건드리지_않는다(said):
    assert strip_expression_suffix(said) == (said, False)


def test_중간의_영문_중괄호는_두고_끝의_꼬리만_뗀다():
    text, had = strip_expression_suffix("영어로 {hello} 라고 했어요 {slightly calm}")
    assert text == "영어로 {hello} 라고 했어요"
    assert had


def _req(*contents: tuple[str, str]) -> ChatRequest:
    return ChatRequest.model_validate(
        {"messages": [{"role": r, "content": c} for r, c in contents]}
    )


def test_파싱_한_번으로_모든_경로가_깨끗하다():
    """분석 입력·응답 이력·태그 대조·위기 규칙·백엔드 적재가 전부 이 두 곳에서 나간다."""
    body = _req(
        ("assistant", "안녕하세요. 오늘 하루는 어떠셨나요?"),
        ("user", "그냥 그랬어요. {slightly tired, slightly sad, very slightly calm}"),
        ("assistant", "그러셨군요."),
        ("user", SEEN),
    )
    assert body.transcript() == "아 내가 이거 합격하면은 좀."
    history = " ".join(t["content"] for t in body.text_history())
    assert "{" not in history
    assert "tired" not in history and "doubtful" not in history
    assert all("{" not in t["content"] for t in body.recent_text_turns())


def test_꼬리가_있었는지는_참거짓으로만_알린다():
    assert _req(("user", SEEN)).expression_suffix_seen() is True
    assert _req(("user", "오늘 괜찮았어요")).expression_suffix_seen() is False
    assert ChatRequest.model_validate({"messages": []}).expression_suffix_seen() is False


def test_꼬리를_떼도_프로소디_점수는_그대로다():
    """떼는 것은 텍스트 표현뿐이다. 음성 채널은 `models.prosody.scores`로 온다."""
    body = ChatRequest.model_validate(
        {
            "messages": [
                {
                    "role": "user",
                    "content": SEEN,
                    "models": {"prosody": {"scores": {"Doubt": 0.4, "Calmness": 0.3}}},
                }
            ]
        }
    )
    assert body.prosody() == {"Doubt": 0.4, "Calmness": 0.3}
