"""Hume CLM 요청 파싱 (계약 §4 — 외부 계약, 변경 불가).

설계: docs/02-architecture/ai-pipeline.md §2.8

Hume은 매 턴 **이력 전체**를 보낸다. 우리는 상태 없는 요청 하나에서
① 마지막 user 발화와 그 prosody ② 텍스트 이력을 뽑아낸다.

**프로소디는 여기서 딱 한 번 갈라져 나가고, 그 뒤로 텍스트 경로에 다시 합류하지 않는다**
(FR-025). `text_history()`가 prosody를 절대 싣지 않는 것이 그 장치다.
"""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class ProsodyModel(BaseModel):
    model_config = ConfigDict(extra="ignore")
    scores: dict[str, float] = Field(default_factory=dict)


class Models(BaseModel):
    model_config = ConfigDict(extra="ignore")
    prosody: ProsodyModel | None = None


class TimeRange(BaseModel):
    model_config = ConfigDict(extra="ignore")
    begin: int | None = None
    end: int | None = None


class Message(BaseModel):
    model_config = ConfigDict(extra="ignore")
    role: str
    content: str = ""
    time: TimeRange | None = None
    models: Models | None = None

    @property
    def prosody_scores(self) -> dict[str, float] | None:
        if self.models and self.models.prosody and self.models.prosody.scores:
            return self.models.prosody.scores
        return None


class ChatRequest(BaseModel):
    """Hume이 보내는 OpenAI 호환 요청. 모르는 필드는 무시한다."""

    model_config = ConfigDict(extra="ignore")
    messages: list[Message] = Field(default_factory=list)
    stream: bool = True

    # ── 뽑아내기 ──────────────────────────────────────────────────

    def last_user_message(self) -> Message | None:
        for m in reversed(self.messages):
            if m.role == "user":
                return m
        return None

    def transcript(self) -> str:
        m = self.last_user_message()
        return m.content if m else ""

    def prosody(self) -> dict[str, float] | None:
        m = self.last_user_message()
        return m.prosody_scores if m else None

    def user_turn_count(self) -> int:
        """이력에 담긴 user 발화 수. 이어하기 감지의 보조 신호로 쓴다(§7.2)."""
        return sum(1 for m in self.messages if m.role == "user")

    def text_history(self, limit: int | None = None) -> list[dict[str, str]]:
        """**텍스트만.** prosody·time을 싣지 않는다 — 이것이 FR-025의 구현이다.

        `system` 역할은 뺀다. 시스템 프롬프트는 우리가 붙인다.
        """
        turns = [
            {"role": m.role, "content": m.content}
            for m in self.messages
            if m.role in ("user", "assistant") and m.content
        ]
        return turns[-limit:] if limit else turns

    def recent_text_turns(self, limit: int = 6) -> list[dict[str, str]]:
        """분석 호출에 붙이는 짧은 맥락. 마지막 user 발화는 별도로 전달하므로 제외한다."""
        history = self.text_history()
        if history and history[-1]["role"] == "user":
            history = history[:-1]
        return history[-limit:]
