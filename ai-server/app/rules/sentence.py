"""문장 형태 검사 — observe·summary 사후 검사가 공유하는 부분.

설계: docs/02-architecture/ai-pipeline.md §8.1·§8.3
"""

from __future__ import annotations

import re

_DIGIT = re.compile(r"[0-9]")
_SENT_END = re.compile(r"[.!?。！？…]+")


def has_digit(text: str) -> bool:
    """아라비아 숫자 포함 여부.

    관찰 문장은 숫자를 쓰지 않는다 — 정확한 수치는 근거 카드가 보여주고,
    문장에 숫자가 없으면 문장과 근거가 어긋날 여지 자체가 없다.
    """
    return bool(_DIGIT.search(text or ""))


def sentence_count(text: str) -> int:
    """마침표류로 자른 뒤 빈 조각을 뺀 개수. 종결부호가 없으면 1로 본다."""
    if not text or not text.strip():
        return 0
    parts = [p for p in _SENT_END.split(text.strip()) if p.strip()]
    return max(1, len(parts))


def has_question(text: str) -> bool:
    """물음표 포함 여부. 관찰과 요약은 질문이 아니다."""
    return "?" in (text or "") or "？" in (text or "")
