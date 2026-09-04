"""태그 원문 대조 (F6-01·F6-02).

설계: docs/02-architecture/ai-pipeline.md §6 · 불용어: rules/tag_stopwords.json

**LLM이 만든 태그를 그대로 믿지 않는다.** 원문에 없는 단어가 태그로 붙으면
"발견" 화면이 사용자가 하지 않은 말을 근거로 제시하게 된다(FR-043).

**동의어 병합을 하지 않는다.** '미팅'이라고 말한 턴에 '회의'를 달면 이 대조에 걸린다.
활용형 정규화까지만 한다 (§6.2).
"""

from __future__ import annotations

import re
import unicodedata
from pathlib import Path

from .loader import DEFAULT_RULES_DIR, tag_stopwords

_KEEP = re.compile(r"[^0-9A-Za-z가-힣]+")
MAX_TAGS = 3
MIN_LEN = 2


def _norm(text: str) -> str:
    if not text:
        return ""
    return _KEEP.sub("", unicodedata.normalize("NFC", text))


def verify_in_transcript(tag: str, transcript: str) -> bool:
    """태그가 원문에 실제로 등장하는가. 부분 문자열 포함으로 본다.

    '회의'는 '회의가'·'회의를'에 포함되므로 활용형이 통과한다. 반대로 '미팅' 발화에
    '회의'는 포함되지 않아 걸러진다 — 그것이 이 함수의 목적이다.
    """
    if not tag or not transcript:
        return False
    return _norm(tag) in _norm(transcript)


def filter_tags(
    candidates: list[str] | None,
    transcript: str,
    *,
    rules_dir: Path = DEFAULT_RULES_DIR,
    max_tags: int = MAX_TAGS,
) -> tuple[list[str], list[str]]:
    """(남긴 태그, 폐기 사유 코드) 를 돌려준다.

    폐기된 **태그 문자열은 돌려주지 않는다** — 로그에 남으면 발화 내용이 새기 때문이다
    (FR-092). 사유 코드만 집계용으로 준다.
    """
    if not candidates:
        return [], []

    stop = {_norm(w) for w in tag_stopwords(rules_dir)["stopwords"]}
    kept: list[str] = []
    dropped: list[str] = []
    seen: set[str] = set()

    for raw in candidates:
        tag = (raw or "").strip()
        norm = _norm(tag)

        if not norm or len(norm) < MIN_LEN:
            dropped.append("too_short")
            continue
        if norm in stop:
            dropped.append("stopword")
            continue
        if any(norm.startswith(s) for s in stop if s):
            # '괜찮'·'힘들' 같은 어간 불용어를 활용형까지 막는다.
            dropped.append("stopword")
            continue
        if norm in seen:
            dropped.append("duplicate")
            continue
        if not verify_in_transcript(tag, transcript):
            dropped.append("not_in_transcript")
            continue

        seen.add(norm)
        kept.append(tag)
        if len(kept) >= max_tags:
            break

    return kept, dropped
