"""`rules/*.json`을 읽는 유일한 통로.

규칙 데이터를 코드 상수로 박지 않는다(ai-server/README.md 경계). 매핑표·키워드·불용어를
바꾸려면 JSON만 고치면 되고, 코드는 손대지 않는다.

로드 시점에 불변식을 검사한다 — 48종 합계나 극성 개수가 어긋난 채로 서버가 뜨면
갭 계산이 조용히 틀린다. 뜨지 않는 편이 낫다.
"""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

DEFAULT_RULES_DIR = Path(__file__).resolve().parent.parent.parent / "rules"


class RulesError(RuntimeError):
    """규칙 파일이 스스로 선언한 불변식을 어겼을 때."""


def _read(rules_dir: Path, name: str) -> dict[str, Any]:
    path = rules_dir / name
    if not path.exists():
        raise RulesError(f"규칙 파일이 없다: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


@lru_cache(maxsize=8)
def valence_mapping(rules_dir: Path = DEFAULT_RULES_DIR) -> dict[str, Any]:
    data = _read(rules_dir, "valence_mapping.json")
    pos, neg, neu = data["positive"], data["negative"], data["neutral"]
    inv = data["invariants"]

    if len(pos) != inv["positive_count"]:
        raise RulesError(f"positive {len(pos)}개, 선언은 {inv['positive_count']}개")
    if len(neg) != inv["negative_count"]:
        raise RulesError(f"negative {len(neg)}개, 선언은 {inv['negative_count']}개")
    if len(neu) != inv["neutral_count"]:
        raise RulesError(f"neutral {len(neu)}개, 선언은 {inv['neutral_count']}개")

    total = len(pos) + len(neg) + len(neu)
    if total != inv["total"]:
        raise RulesError(f"합계 {total}종, 선언은 {inv['total']}종")

    overlap = (set(pos) & set(neg)) | (set(pos) & set(neu)) | (set(neg) & set(neu))
    if overlap:
        raise RulesError(f"극성이 겹치는 감정: {sorted(overlap)}")

    # 데모 1번 장면의 전제. 이게 뒤집히면 지친 톤에서 갭이 벌어지지 않는다.
    if "Tiredness" not in neg:
        raise RulesError("Tiredness가 negative에 없다 — invariants.tiredness_is_negative 위반")

    return data


@lru_cache(maxsize=8)
def crisis_keywords(rules_dir: Path = DEFAULT_RULES_DIR) -> dict[str, Any]:
    data = _read(rules_dir, "crisis_keywords.json")
    if not data.get("tier_a_rule"):
        raise RulesError("tier_a_rule이 비었다 — 규칙 계층 위기 감지가 사라진다")
    for item in data["tier_a_rule"]:
        if not item.get("pattern"):
            raise RulesError(f"pattern이 없는 tier_a 항목: {item}")
        if not item.get("source"):
            raise RulesError(f"출처가 없는 tier_a 항목: {item['pattern']}")
    return data


@lru_cache(maxsize=8)
def tag_stopwords(rules_dir: Path = DEFAULT_RULES_DIR) -> dict[str, Any]:
    return _read(rules_dir, "tag_stopwords.json")


@lru_cache(maxsize=8)
def guard_terms(rules_dir: Path = DEFAULT_RULES_DIR) -> dict[str, Any]:
    data = _read(rules_dir, "guard_terms.json")
    forbidden = set()
    for cat in ("diagnosis", "medication", "treatment"):
        forbidden |= {t.replace(" ", "") for t in data[cat]["terms"]}

    # 위기 안내가 쓰는 표현이 금칙어에 걸리면 F4-03이 동작하지 않는다.
    for allowed in data["not_forbidden"]["terms"]:
        a = allowed.replace(" ", "")
        for f in forbidden:
            if f in a:
                raise RulesError(f"허용 표현 '{allowed}'이 금칙어 '{f}'에 걸린다")
    return data
