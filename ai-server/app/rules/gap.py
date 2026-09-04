"""갭과 트리거 (F3-03·F3-04).

설계: docs/02-architecture/ai-pipeline.md §4

갭은 **말한 내용과 목소리가 얼마나 어긋났는가**이지 감정의 세기가 아니다.
그래서 두 채널 중 하나라도 없으면 갭도 없다 — 한쪽만으로 어긋남을 말할 수 없다.
"""

from __future__ import annotations


def gap(text_valence: float | None, voice_valence: float | None) -> float | None:
    """|텍스트 − 음성|. 한쪽이라도 null이면 null (계약 §1-3)."""
    if text_valence is None or voice_valence is None:
        return None
    return round(abs(text_valence - voice_valence), 2)


def gap_triggered(gap_value: float | None, threshold: float) -> bool:
    """되묻기 트리거. 갭이 없으면 항상 False — 모르면 묻지 않는다."""
    if gap_value is None:
        return False
    return gap_value >= threshold


def resolve_threshold(
    session_threshold: float | None, fallback: float
) -> tuple[float, str]:
    """백엔드 조회값이 있으면 그것이 우선, 없으면 `.env` 폴백.

    어느 쪽을 썼는지 함께 돌려준다 — 로그에서 "왜 이 임계값이었나"가 보여야
    20쌍 측정 결과를 해석할 수 있다.
    """
    if session_threshold is not None:
        return session_threshold, "session"
    return fallback, "fallback"
