"""첫 실제 요청을 남긴다 — 구조 캡처와 평가 스냅샷 (F11-04).

설계: ai-server/eval/README.md · docs/02-architecture/ai-pipeline.md §11

Hume이 실제로 보내는 요청을 우리는 아직 본 적이 없다. 문서만 보고 파서를 짰으므로
**첫 연결에서 그 모양을 반드시 남겨야 한다.** 안 남기면 다음에 또 무료 할당량을 쓴다.

두 가지를 따로 둔다. 성질이 다르고, 켜는 조건도 다르다.

| | 담는 것 | 기본값 | 목적 |
| --- | --- | --- | --- |
| 구조 캡처 | **키 이름과 값의 타입만.** 발화·점수 값 없음 | **켜짐** | 파서 가정 검증 |
| 평가 스냅샷 | 마지막 user 발화의 `content`와 `prosody.scores` | **꺼짐** | 갭 20쌍 재생 |

구조 캡처가 기본으로 켜져 있는 이유는 **발화가 들어가지 않기 때문**이다(FR-092).
평가 스냅샷은 발화가 들어가므로 `AI_EVAL_CAPTURE=true`일 때만, 그리고 팀원이
정해진 문장을 읽는 도그푸딩에서만 켠다.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .telemetry import error_log, log

# 48종 점수는 messages[].models.prosody.scores.{감정} 로 6단계 아래에 있다.
# 여기가 얕으면 캡처의 핵심이 잘린다 — 넉넉히 둔다.
MAX_DEPTH = 12


def shape_of(value: Any, depth: int = 0) -> Any:
    """값을 **타입 이름으로** 바꾼 뼈대. 내용은 하나도 남지 않는다.

    리스트는 첫 원소의 모양과 길이만 남긴다 — 48종 감정 이름은 dict 키라서
    그대로 보이고, 그건 발화가 아니라 스키마다.
    """
    if depth >= MAX_DEPTH:
        return "…"
    if isinstance(value, dict):
        return {k: shape_of(v, depth + 1) for k, v in value.items()}
    if isinstance(value, list):
        if not value:
            return []
        return [shape_of(value[0], depth + 1), f"…({len(value)}개)"]
    if isinstance(value, bool):
        return "bool"
    if isinstance(value, int):
        return "int"
    if isinstance(value, float):
        return "float"
    if isinstance(value, str):
        return f"str({len(value)})"
    if value is None:
        return "null"
    return type(value).__name__


def _stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%f")[:-3]


def capture_shape(body: dict[str, Any], out_dir: Path) -> Path | None:
    """요청 뼈대를 한 번만 남긴다. 같은 모양이면 다시 쓰지 않는다.

    파일이 쌓이면 오히려 안 보게 되므로, **모양이 달라졌을 때만** 새 파일을 만든다.
    """
    try:
        skeleton = shape_of(body)
        blob = json.dumps(skeleton, ensure_ascii=False, indent=2, sort_keys=True)
        out_dir.mkdir(parents=True, exist_ok=True)

        for existing in out_dir.glob("clm-request-*.json"):
            if existing.read_text(encoding="utf-8") == blob + "\n":
                return None  # 이미 아는 모양이다

        path = out_dir / f"clm-request-{_stamp()}.json"
        path.write_text(blob + "\n", encoding="utf-8", newline="\n")
        log("clm_shape_captured", status=path.name)
        return path
    except OSError:
        error_log("shape_capture_failed")
        return None


def capture_snapshot(
    transcript: str, scores: dict[str, float] | None, out_dir: Path
) -> Path | None:
    """갭 평가용 스냅샷 — 전사와 프로소디 점수만.

    **이력·시각·세션 ID를 담지 않는다**(eval/README). 음성 파일은 어디에도
    저장하지 않으므로(FR-041) 20쌍 재생은 이 JSON으로 한다.
    """
    if not transcript or not scores:
        return None
    try:
        out_dir.mkdir(parents=True, exist_ok=True)
        path = out_dir / f"turn-{_stamp()}.json"
        path.write_text(
            json.dumps(
                {"transcript": transcript, "scores": scores},
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
            newline="\n",
        )
        return path
    except OSError:
        error_log("snapshot_capture_failed")
        return None
