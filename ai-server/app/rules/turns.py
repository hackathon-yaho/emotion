"""턴 번호와 발화 시각 (계약 §3-2 v1.5).

설계: docs/02-architecture/ai-pipeline.md §7.3 · 회신: docs/response/backend/turn-index-numbering.md

백엔드는 `unique (session_id, turn_index)` 위반을 만나면 `occurred_at`을 보고
**재시도(무시)와 충돌(max+1로 저장)** 을 가른다. 그 판별의 전제가 이 모듈이다.

- 재시도는 최초 시도와 **문자열까지 같은** `occurredAt`을 보낸다.
- 같은 세션의 서로 다른 발화는 값이 겹치지 않는다.

시각은 순수 함수로 다룬다 — `now`를 인자로 받아 테스트가 시계에 의존하지 않게 한다.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone


def next_indices(last_turn_index: int, issued: int) -> tuple[int, int]:
    """(user 턴 번호, assistant 턴 번호).

    한 번의 주고받기에서 두 개를 **미리 함께** 잡는다. assistant 적재는 스트림이
    끝난 뒤라 지연되는데, 미리 잡아두면 순서가 뒤집히지 않는다.

    `last_turn_index`는 세션 컨텍스트 조회(계약 §3-4)가 준 값이고 `issued`는 그 조회
    이후 이 프로세스가 발급한 개수다. 카운터가 세션 캐시 안에 살기 때문에
    **캐시가 죽으면 재조회가 돌아 재시드된다** — 0부터 시작하는 경로가 없다.
    """
    if last_turn_index < 0:
        raise ValueError("last_turn_index는 음수일 수 없다")
    if issued < 0:
        raise ValueError("issued는 음수일 수 없다")
    base = last_turn_index + issued
    return base + 1, base + 2


def format_occurred_at(moment: datetime) -> str:
    """RFC 3339 · 밀리초 · UTC (`2026-09-18T12:31:02.417Z`)."""
    utc = moment.astimezone(timezone.utc)
    return utc.strftime("%Y-%m-%dT%H:%M:%S.") + f"{utc.microsecond // 1000:03d}Z"


def stamp(moment: datetime, previous: str | None = None) -> str:
    """발화 시각을 찍는다. 같은 세션 직전 값과 같으면 1ms를 더한다.

    한 세션의 턴은 순차 처리되고 사이에 LLM 호출이 끼므로 실제로 겹칠 일이 없지만,
    백엔드의 판별이 이 필드 하나에 걸려 있어 방어한다. 겹치면 "다르다 → 충돌" 가지가
    재시도를 충돌로 오판하고, 같은 턴이 두 번 저장된다.
    """
    value = format_occurred_at(moment)
    if previous is not None and value == previous:
        return format_occurred_at(moment + timedelta(milliseconds=1))
    return value


def should_refetch_session(
    idle_sec: float, threshold_sec: int, *, history_user_turns: int | None = None,
    issued_user_turns: int | None = None,
) -> bool:
    """세션 컨텍스트를 다시 조회할 때인가 (§7.2).

    재연결은 AI서버에 보이지 않는다 — Hume은 매 턴 상태 없는 요청에
    `custom_session_id`만 실어 보낸다. 그래서 **유휴 간격**으로 간접 감지한다.

    거짓 양성은 조회 1회로 끝나고 거짓 음성은 인덱스가 어긋나므로, 느슨하게 잡는다.
    """
    if idle_sec >= threshold_sec:
        return True
    # 보조 신호: 들어온 이력이 내 카운터보다 앞서 있으면 그 사이에 무슨 일이 있었다.
    if history_user_turns is not None and issued_user_turns is not None:
        if history_user_turns > issued_user_turns:
            return True
    return False
