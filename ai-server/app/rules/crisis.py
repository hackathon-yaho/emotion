"""위기 감지 Tier A — 규칙 계층 (F4-02·F4-03).

설계: docs/02-architecture/ai-pipeline.md §5 · 키워드: rules/crisis_keywords.json

**이 계층은 LLM 호출이 실패해도 돈다**(FR-032). 분석 호출이 타임아웃 나든 API가 죽든
여기는 정규식이라 항상 동작한다. 그것이 이 계층이 존재하는 유일한 이유다.

**매칭된 표현을 돌려주지 않는다**(FR-092). 호출부가 실수로 로그에 남길 여지를 없앤다.
"""

from __future__ import annotations

import re
import unicodedata
from functools import lru_cache
from pathlib import Path

from .loader import DEFAULT_RULES_DIR, crisis_keywords

# 공백·구두점·이모지 제거. 한글/영숫자만 남긴다.
_KEEP = re.compile(r"[^0-9A-Za-z가-힣]+")


def normalize(text: str) -> str:
    """'죽고 싶어요' · '죽고... 싶어요' · '죽고싶어요'를 같은 문자열로.

    띄어쓰기로 규칙을 피해 가는 경우를 막는 것이 목적이다.
    """
    if not text:
        return ""
    return _KEEP.sub("", unicodedata.normalize("NFC", text))


@lru_cache(maxsize=8)
def _patterns(rules_dir: Path) -> tuple[str, ...]:
    data = crisis_keywords(rules_dir)
    return tuple(normalize(item["pattern"]) for item in data["tier_a_rule"])


def detect_tier_a(text: str, *, rules_dir: Path = DEFAULT_RULES_DIR) -> bool:
    """규칙 계층 감지. 참/거짓만 돌려준다.

    **부정어 예외를 두지 않는다.** '죽고 싶지 않아'도 True다 — 재현율 우선이고
    (PRD FR-032), 놓치는 비용과 한 번 더 묻는 비용이 비교 대상이 아니다.
    """
    if not text:
        return False
    norm = normalize(text)
    return any(p and p in norm for p in _patterns(rules_dir))


def tier_b_hints(*, rules_dir: Path = DEFAULT_RULES_DIR) -> list[str]:
    """분석 호출 프롬프트에 실어 보낼 간접 표현 예시.

    LLM이 맥락으로 판정하는 계층이라 규칙으로 매칭하지 않는다 — '이제 그만 쉬고 싶어요'는
    퇴근 이야기일 수도 있고 아닐 수도 있다.
    """
    data = crisis_keywords(rules_dir)
    return [h["phrase"] for h in data["tier_b_llm_hints"]]


def decide(
    rule_hit: bool, llm_hit: bool | None
) -> tuple[bool, str | None]:
    """두 계층을 합친다 (계약 §3-2의 `crisis.detected` · `crisis.by`).

    OR로 합치고, 규칙이 먼저다 — 근거가 결정적이고 재현 가능하기 때문이다.
    `llm_hit`이 None이면 분석 호출이 실패한 것이고, 그때도 규칙은 살아 있다.
    """
    if rule_hit:
        return True, "rule"
    if llm_hit:
        return True, "llm"
    return False, None
