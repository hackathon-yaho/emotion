"""음성 valence — Hume 48종 prosody 점수를 하나의 방향값으로 (F3-01).

설계: docs/02-architecture/ai-pipeline.md §3 · 매핑표: rules/valence_mapping.json

이 모듈은 **텍스트를 보지 않는다.** 텍스트 valence는 분석 호출(LLM)이 전사만 읽고 내며,
두 채널이 섞이면 갭이라는 지표 자체가 무의미해진다(FR-025).
"""

from __future__ import annotations

from pathlib import Path

from .loader import DEFAULT_RULES_DIR, valence_mapping

Scores = dict[str, float]


def voice_valence(
    scores: Scores | None,
    *,
    min_mass: float | None = None,
    rules_dir: Path = DEFAULT_RULES_DIR,
) -> float | None:
    """긍정·부정 질량의 상대 우위를 -1.0 ~ 1.0으로.

    `None`은 "측정하지 못했다"는 뜻이다(계약 §1-3). 0으로 대체하지 않는다 —
    0은 "중립이었다"는 주장이고, 그건 우리가 알 수 없는 것이다.
    """
    if not scores:
        return None

    m = valence_mapping(rules_dir)
    if min_mass is None:
        min_mass = m["formula"]["min_mass"]

    p = sum(scores.get(e, 0.0) for e in m["positive"])
    n = sum(scores.get(e, 0.0) for e in m["negative"])

    if p + n < min_mass:
        # 중립 감정만 찍힌 발화. 방향을 말할 근거가 없다.
        return None

    return round((p - n) / (p + n), 2)


def top_prosody(scores: Scores | None, limit: int = 5) -> dict[str, float] | None:
    """적재용 상위 N개(계약 §3-2). valence 계산과 무관하게 점수 내림차순으로 자른다."""
    if not scores:
        return None
    ranked = sorted(scores.items(), key=lambda kv: (-kv[1], kv[0]))
    return {k: v for k, v in ranked[:limit]}


def known_emotions(rules_dir: Path = DEFAULT_RULES_DIR) -> set[str]:
    m = valence_mapping(rules_dir)
    return set(m["positive"]) | set(m["negative"]) | set(m["neutral"])


def unknown_emotions(
    scores: Scores | None, *, rules_dir: Path = DEFAULT_RULES_DIR
) -> set[str]:
    """Hume이 매핑표에 없는 감정을 보내면 알려준다.

    조용히 무시하면 새 감정이 추가된 날 갭이 소리 없이 틀어진다. 호출부가 경고 로그를
    남기되 대화는 계속한다(§9).
    """
    if not scores:
        return set()
    return set(scores) - known_emotions(rules_dir)
