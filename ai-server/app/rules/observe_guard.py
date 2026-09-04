"""관찰 문장 사후 검사 (계약 §3-3, F7-04).

설계: docs/02-architecture/ai-pipeline.md §8.1

**실패하면 관찰을 만들지 않는다. 템플릿 문장으로 대체하지 않는다.**
표현이 어색한 것보다 근거 없는 문장이 나가는 쪽이 위험하다.
"""

from __future__ import annotations

from pathlib import Path

from .guard import find_violations
from .loader import DEFAULT_RULES_DIR
from .sentence import has_digit, has_question, sentence_count
from .tags import _norm


def check(
    sentence: str, tag: str, *, rules_dir: Path = DEFAULT_RULES_DIR
) -> list[str]:
    """폐기 사유 코드 목록. 빈 목록이면 통과.

    **문장 내용을 사유에 담지 않는다** — 호출부가 그대로 로그에 넣을 수 있다(FR-092).
    """
    reasons: list[str] = []

    if not sentence or not sentence.strip():
        return ["empty"]
    if has_digit(sentence):
        reasons.append("has_digit")
    if not tag or _norm(tag) not in _norm(sentence):
        reasons.append("tag_missing")
    if sentence_count(sentence) > 1:
        reasons.append("multi_sentence")
    if has_question(sentence):
        reasons.append("question")
    reasons += [f"forbidden:{c}" for c in find_violations(sentence, rules_dir=rules_dir)]

    return reasons


def accepts(sentence: str, tag: str, *, rules_dir: Path = DEFAULT_RULES_DIR) -> bool:
    return not check(sentence, tag, rules_dir=rules_dir)
