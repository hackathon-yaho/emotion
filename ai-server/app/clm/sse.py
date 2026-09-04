"""Hume에게 돌려주는 SSE 스트림 (계약 §4 — 외부 계약, 변경 불가).

설계: docs/02-architecture/ai-pipeline.md §2.8

OpenAI `chat.completion.chunk` 형식이고 `system_fingerprint`에 세션 ID를 실어
마지막에 `data: [DONE]`으로 닫는다. Hume 공식 예제(`evi-python-clm-sse`)와 같은 형태다.

**버퍼링하지 않는다.** 응답 스트림에는 메타 태그도 JSON도 없으므로(AI-13) 받는 즉시
그대로 흘려보낸다. 파싱해서 무언가를 떼어내는 코드가 여기 존재하지 않아야 한다.
"""

from __future__ import annotations

import json
import time
import uuid
from typing import Any

DONE = "data: [DONE]\n\n"


def _envelope(
    session_id: str, delta: dict[str, Any], finish_reason: str | None
) -> dict[str, Any]:
    return {
        "id": f"chatcmpl-{uuid.uuid4().hex[:24]}",
        "object": "chat.completion.chunk",
        "created": int(time.time()),
        "model": "clm",
        "system_fingerprint": session_id,
        "choices": [{"index": 0, "delta": delta, "finish_reason": finish_reason}],
    }


def _line(payload: dict[str, Any]) -> str:
    return f"data: {json.dumps(payload, ensure_ascii=False)}\n\n"


def first_chunk(session_id: str) -> str:
    """역할만 실은 첫 청크. 내용은 다음 청크부터."""
    return _line(_envelope(session_id, {"role": "assistant", "content": ""}, None))


def content_chunk(session_id: str, text: str) -> str:
    return _line(_envelope(session_id, {"content": text}, None))


def stop_chunk(session_id: str) -> str:
    return _line(_envelope(session_id, {}, "stop"))


def close(session_id: str) -> list[str]:
    """스트림을 닫는 두 줄. 순서가 바뀌면 Hume이 응답을 끝내지 못한다."""
    return [stop_chunk(session_id), DONE]
