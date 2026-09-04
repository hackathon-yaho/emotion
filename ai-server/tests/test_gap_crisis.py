"""갭·위기 — ai-pipeline.md §4·§5, rules/crisis_keywords.json"""

import pytest

from app.rules import crisis, gap


# ── 갭 ────────────────────────────────────────────────────────────


def test_갭은_두_채널의_거리다():
    assert gap.gap(0.70, -0.62) == 1.32


@pytest.mark.parametrize(
    "t,v", [(None, -0.5), (0.5, None), (None, None)]
)
def test_한쪽이라도_없으면_갭도_없다(t, v):
    """계약 §1-3. 한쪽만으로 '어긋났다'를 말할 수 없다."""
    assert gap.gap(t, v) is None


def test_갭이_없으면_되묻지_않는다():
    """모르면 묻지 않는다. FR-024의 의미."""
    assert gap.gap_triggered(None, 0.85) is False


def test_임계값_경계는_이상이다():
    assert gap.gap_triggered(0.85, 0.85) is True
    assert gap.gap_triggered(0.84, 0.85) is False


def test_세션_조회값이_env_폴백보다_우선한다():
    assert gap.resolve_threshold(0.92, 0.85) == (0.92, "session")
    assert gap.resolve_threshold(None, 0.85) == (0.85, "fallback")


# ── 위기 Tier A ───────────────────────────────────────────────────


@pytest.mark.parametrize(
    "text",
    [
        "정말 죽고 싶어요",
        "차라리 죽었으면 좋겠어",
        "죽어야 편해질 것 같아요",
        "내가 없어지는 것이 낫다는 생각이 들어요",
        "내가 사라지면 다 해결될 것 같아",
        "그냥 살기 싫어요",
        "다 끝내고 싶어요",
        "자해를 했어요",
        "유서를 써봤어요",
    ],
)
def test_직접_표현은_규칙만으로_잡는다(text):
    """Tier A 단독 재현율 목표 100%. LLM이 죽어도 이 경로는 돈다(FR-032)."""
    assert crisis.detect_tier_a(text) is True


@pytest.mark.parametrize(
    "text",
    ["죽고싶어요", "죽고  싶어요", "죽고... 싶어요", "죽고 싶어요!!!", "죽고 🥲 싶어요"],
)
def test_띄어쓰기와_구두점으로_피해갈_수_없다(text):
    assert crisis.detect_tier_a(text) is True


def test_부정어가_붙어도_잡는다():
    """재현율 우선. 놓치는 비용과 한 번 더 묻는 비용은 비교 대상이 아니다."""
    assert crisis.detect_tier_a("죽고 싶지 않아요") is True


@pytest.mark.parametrize(
    "text",
    [
        "오늘 회의가 세 개나 있었어요",
        "그냥 좀 피곤하네요",
        "걱정이 사라지면 좋겠어요",
        "",
    ],
)
def test_평범한_발화는_잡지_않는다(text):
    assert crisis.detect_tier_a(text) is False


def test_사라지면은_내가가_붙어야_잡는다():
    """'걱정이 사라지면' 오탐을 막으려고 패턴을 '내가사라지'로 좁혔다."""
    assert crisis.detect_tier_a("걱정이 사라지면 좋겠어요") is False
    assert crisis.detect_tier_a("내가 사라지면 좋겠어요") is True


def test_규칙이_LLM보다_먼저다():
    assert crisis.decide(True, False) == (True, "rule")
    assert crisis.decide(True, True) == (True, "rule")


def test_LLM_판정이_없어도_규칙이_살아있다():
    """분석 호출 실패 시 llm_hit은 None으로 온다."""
    assert crisis.decide(True, None) == (True, "rule")
    assert crisis.decide(False, None) == (False, None)


def test_LLM만_잡으면_by는_llm이다():
    assert crisis.decide(False, True) == (True, "llm")


def test_Tier_B_힌트는_규칙으로_매칭하지_않는다():
    """'이제 그만 쉬고 싶어요'는 퇴근 이야기일 수도 있다. 맥락은 LLM이 본다."""
    assert "이제 그만 쉬고 싶어요" in crisis.tier_b_hints()
    assert crisis.detect_tier_a("이제 그만 쉬고 싶어요") is False
