"""구조화 로그 — 필드 화이트리스트로 발화 유출을 막는다 (NFR-07, FR-092).

설계: docs/02-architecture/ai-pipeline.md §10

**정책이 아니라 장치다.** "로그에 발화를 남기지 말자"는 약속은 언젠가 깨진다.
여기서는 화이트리스트에 없는 키가 오면 **버린다.** 실수로 `transcript=...`를 넘겨도
로그에 나가지 않는다.
"""

from __future__ import annotations

import hashlib
import json
import logging
import sys
from typing import Any

# 이 목록에 없는 필드는 로그로 나가지 않는다. 추가할 때는 "이 값이 발화를 재구성하는 데
# 쓰일 수 있는가"를 먼저 묻는다.
ALLOWED_FIELDS = frozenset(
    {
        "event",
        "sessionRef",
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
    {
        "transcript", "text", "content", "sentence", "summary", "message", "prompt", "tags",
        # sessionId는 §4 CLM 인증 수단이다. 로그를 본 사람이 그 세션인 척 CLM을 부를 수 있다.
        # 계약 §1-1이 "비밀과 동급"으로 못 박았다 — 이름을 뭘로 붙이든 거부한다.
        "sid", "sessionId", "session_id", "customSessionId", "custom_session_id",
    }
)


def session_ref(session_id: str | None) -> str:
    """로그에 쓰는 세션 식별자 — `SHA-256(sessionId)[:8]` (계약 §1-1).

    원본을 복원할 수 없으면서 같은 세션의 로그·오류를 묶는 데는 충분하다.
    **백엔드의 `sessionRef`와 같은 방식이라** 양쪽 로그를 한 세션으로 맞춰 볼 수 있다.
    """
    if not session_id:
        return "-"
    return hashlib.sha256(session_id.encode("utf-8")).hexdigest()[:8]

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
