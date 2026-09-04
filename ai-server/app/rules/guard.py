"""금칙어 검사 — 우리가 만든 문장에만 적용 (PRD §9.3 절대 규칙).

설계: docs/02-architecture/ai-pipeline.md §8 · 목록: rules/guard_terms.json

**사용자 발화를 거르는 목록이 아니다.** 사용자는 무슨 말이든 할 수 있다.
우리가 진단하지 않고 처방하지 않을 뿐이다.

프롬프트로도 막고 여기서 한 번 더 막는다. 프롬프트는 확률이고 이건 확정이다.
"""

from __future__ import annotations

import re
import unicodedata
from pathlib import Path

from .loader import DEFAULT_RULES_DIR, guard_terms

_SPACE = re.compile(r"\s+")
CATEGORIES = ("diagnosis", "medication", "treatment")


def _norm(text: str) -> str:
    if not text:
        return ""
    return _SPACE.sub("", unicodedata.normalize("NFC", text))


def find_violations(
    sentence: str, *, rules_dir: Path = DEFAULT_RULES_DIR
) -> list[str]:
    """걸린 **카테고리 이름**만 돌려준다.

    매칭된 표현 자체를 돌려주지 않는 이유는 호출부가 그걸 로그에 남길 수 있기 때문이다
    (FR-092). 어느 카테고리에 걸렸는지만 알면 원인 분석에는 충분하다.
    """
    if not sentence:
        return []

    data = guard_terms(rules_dir)
    norm = _norm(sentence)
    hits: list[str] = []

    for cat in CATEGORIES:
        terms = (_norm(t) for t in data[cat]["terms"])
        if any(t and t in norm for t in terms):
            hits.append(cat)
    return hits


def is_clean(sentence: str, *, rules_dir: Path = DEFAULT_RULES_DIR) -> bool:
    return not find_violations(sentence, rules_dir=rules_dir)
