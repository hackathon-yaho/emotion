"""세션 요약 사후 검사 (계약 §3-5, F2-05).

설계: docs/02-architecture/ai-pipeline.md §8.3

**갭이 요약으로 새지 않는 것이 이 검사의 핵심이다.** S02는 수치를 숨기는데(FR-031)
요약이 "말과 달리 지쳐 보이는 대화였습니다"라고 적으면 화면이 숨긴 것을 문장이 흘린다.

실패하면 `422 SUMMARY_REJECTED`. 백엔드는 재시도 없이 `summary: null`로 닫는다.
"""

from __future__ import annotations

import re
import unicodedata
from pathlib import Path

from .guard import find_violations
from .loader import DEFAULT_RULES_DIR, guard_terms
from .sentence import has_digit, has_question, sentence_count

_SPACE = re.compile(r"\s+")


def _norm(text: str) -> str:
    if not text:
        return ""
    return _SPACE.sub("", unicodedata.normalize("NFC", text))


def check(summary: str, *, rules_dir: Path = DEFAULT_RULES_DIR) -> list[str]:
    """폐기 사유 코드 목록. 빈 목록이면 통과. 문장 내용은 담지 않는다."""
    reasons: list[str] = []

    if not summary or not summary.strip():
        return ["empty"]
    if has_digit(summary):
        reasons.append("has_digit")
    if sentence_count(summary) > 1:
        reasons.append("multi_sentence")
    if has_question(summary):
        reasons.append("question")

    norm = _norm(summary)
    assertions = guard_terms(rules_dir)["emotion_assertion"]["terms"]
    if any(_norm(t) in norm for t in assertions):
        reasons.append("emotion_assertion")

    reasons += [f"forbidden:{c}" for c in find_violations(summary, rules_dir=rules_dir)]
    return reasons


def accepts(summary: str, *, rules_dir: Path = DEFAULT_RULES_DIR) -> bool:
    return not check(summary, rules_dir=rules_dir)
