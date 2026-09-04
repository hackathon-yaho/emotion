"""턴 번호·발화 시각 — 계약 §3-2 v1.5, ai-pipeline.md §7.3

백엔드의 중복 판별 가드가 `occurredAt` 하나에 걸려 있다
(docs/response/backend/turn-index-numbering.md). 여기가 그 전제를 지킨다.
"""

from datetime import datetime, timedelta, timezone

import pytest

from app.rules import turns


def _t(ms: int) -> datetime:
    return datetime(2026, 9, 18, 12, 31, 2, ms * 1000, tzinfo=timezone.utc)


# ── 채번 ──────────────────────────────────────────────────────────


def test_lastTurnIndex에서_이어_붙인다():
    """이어하기 세션: 백엔드가 7을 줬으면 8·9로 간다. 0으로 돌아가지 않는다."""
    assert turns.next_indices(7, 0) == (8, 9)


def test_같은_주고받기에서_두_개를_미리_잡는다():
    user, assistant = turns.next_indices(0, 0)
    assert (user, assistant) == (1, 2)


def test_발급할수록_증가한다():
    assert turns.next_indices(7, 2) == (10, 11)


def test_적재된_턴이_없으면_1부터():
    assert turns.next_indices(0, 0)[0] == 1


@pytest.mark.parametrize("last,issued", [(-1, 0), (0, -1)])
def test_음수는_거부한다(last, issued):
    with pytest.raises(ValueError):
        turns.next_indices(last, issued)


# ── occurredAt ────────────────────────────────────────────────────


def test_밀리초_정밀도로_찍는다():
    assert turns.format_occurred_at(_t(417)) == "2026-09-18T12:31:02.417Z"


def test_UTC로_변환한다():
    kst = datetime(2026, 9, 18, 21, 31, 2, 417000, tzinfo=timezone(timedelta(hours=9)))
    assert turns.format_occurred_at(kst) == "2026-09-18T12:31:02.417Z"


def test_재시도는_같은_값을_쓴다():
    """페이로드를 만들 때 한 번 찍고 그 문자열을 그대로 재전송한다.
    여기서 값이 달라지면 백엔드가 재시도를 충돌로 오판해 같은 턴이 세 번 저장된다."""
    stamped = turns.stamp(_t(417))
    payload = {"occurredAt": stamped}
    for _ in range(3):
        assert payload["occurredAt"] == stamped


def test_직전_턴과_겹치면_1ms를_더한다():
    """겹치면 '다르다 → 충돌' 가지가 오판한다."""
    first = turns.stamp(_t(417))
    second = turns.stamp(_t(417), previous=first)
    assert first == "2026-09-18T12:31:02.417Z"
    assert second == "2026-09-18T12:31:02.418Z"


def test_겹치지_않으면_그대로_둔다():
    first = turns.stamp(_t(417))
    second = turns.stamp(_t(902), previous=first)
    assert second == "2026-09-18T12:31:02.902Z"


# ── 재조회 판단 (§7.2) ────────────────────────────────────────────


def test_유휴가_길면_재조회한다():
    """이어하기는 AI서버에 보이지 않으므로 유휴 간격으로 간접 감지한다."""
    assert turns.should_refetch_session(61, 60) is True


def test_대화가_이어지는_중이면_재조회하지_않는다():
    assert turns.should_refetch_session(3.2, 60) is False


def test_경계는_이상이다():
    assert turns.should_refetch_session(60, 60) is True


def test_이력이_카운터보다_앞서면_재조회한다():
    """보조 신호 — 그 사이에 무슨 일이 있었다는 뜻이다."""
    assert turns.should_refetch_session(
        5, 60, history_user_turns=9, issued_user_turns=3
    ) is True


def test_보조_신호가_없으면_유휴만_본다():
    assert turns.should_refetch_session(
        5, 60, history_user_turns=3, issued_user_turns=3
    ) is False
