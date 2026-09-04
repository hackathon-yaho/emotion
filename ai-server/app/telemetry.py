"""구조화 로그 — 필드 화이트리스트로 발화 유출을 막는다 (NFR-07, FR-092).

설계: docs/02-architecture/ai-pipeline.md §10

**정책이 아니라 장치다.** "로그에 발화를 남기지 말자"는 약속은 언젠가 깨진다.
여기서는 화이트리스트에 없는 키가 오면 **버린다.** 실수로 `transcript=...`를 넘겨도
로그에 나가지 않는다.
"""

from __future__ import annotations

import json
import logging
import sys
from typing import Any

# 이 목록에 없는 필드는 로그로 나가지 않는다. 추가할 때는 "이 값이 발화를 재구성하는 데
# 쓰일 수 있는가"를 먼저 묻는다.
ALLOWED_FIELDS = frozenset(
    {
        "event",
        "sid",
        "turnIndex",
        "role",
        "latencyMs",
        "ctxMs",
        "analyzeMs",
        "respondTtftMs",
        "respondTotalMs",
        "postMs",
        "analyzeCacheHit",
        "gapTriggered",
        "gap",
        "textValence",
        "voiceValence",
        "thresholdMode",
        "thresholdSource",
        "crisisBy",
        "crisisDetected",
        "tagsKept",
        "tagsDropped",
        "dropReasons",
        "model",
        "tokensIn",
        "tokensOut",
        "status",
        "reason",
        "retries",
        "unknownEmotions",
        "sessionStatus",
        "refetch",
        "guardReasons",
        "demoMode",
    }
)

# 값이 문자열인 필드 중, 자유 텍스트가 들어올 수 있는 것은 아예 두지 않는다.
# 아래 키는 실수로 화이트리스트에 추가되더라도 거부한다.
NEVER = frozenset(
    {"transcript", "text", "content", "sentence", "summary", "message", "prompt", "tags"}
)

_logger = logging.getLogger("ai-server")


def configure(level: str = "info") -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter("%(message)s"))
    _logger.handlers = [handler]
    _logger.setLevel(getattr(logging, level.upper(), logging.INFO))
    _logger.propagate = False


def _clean(fields: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for k, v in fields.items():
        if k in NEVER:
            continue
        if k not in ALLOWED_FIELDS:
            continue
        out[k] = v
    return out


def log(event: str, level: str = "info", **fields: Any) -> dict[str, Any]:
    """구조화 로그 1건. 걸러진 뒤의 payload를 돌려준다(테스트가 검사한다)."""
    payload = _clean({"event": event, **fields})
    getattr(_logger, level, _logger.info)(
        json.dumps(payload, ensure_ascii=False, sort_keys=True)
    )
    return payload


def turn_log(**fields: Any) -> dict[str, Any]:
    return log("turn", **fields)


def error_log(reason: str, **fields: Any) -> dict[str, Any]:
    """오류에도 발화를 남기지 않는다. `reason`은 **코드**여야 하고 예외 메시지가 아니다."""
    return log("error", level="warning", reason=reason, **fields)
