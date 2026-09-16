"""Hume CLM 요청 파싱 (계약 §4 — 외부 계약, 변경 불가).

설계: docs/02-architecture/ai-pipeline.md §2.8

Hume은 매 턴 **이력 전체**를 보낸다. 우리는 상태 없는 요청 하나에서
① 마지막 user 발화와 그 prosody ② 텍스트 이력을 뽑아낸다.

**프로소디는 여기서 딱 한 번 갈라져 나가고, 그 뒤로 텍스트 경로에 다시 합류하지 않는다**
(FR-025). `text_history()`가 prosody를 절대 싣지 않는 것이 그 장치다.
"""

from __future__ import annotations

import re
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, PrivateAttr

# **Hume은 user 발화 끝에 상위 3개 표정을 영문으로 덧붙인다** — 프로소디를 못 받는
# LLM을 위한 Hume 쪽 편의 기능이고(Prompt Engineering 가이드), 끄는 설정은 없다.
#     "아 내가 이거 합격하면은 좀. {slightly doubtful, slightly calm, very slightly interested}"
# 우리는 프로소디를 `models.prosody.scores`로 따로 받으므로 이 꼬리는 **순수한 오염**이다.
# 두면 텍스트 valence LLM이 음성 채널을 읽어 **갭의 전제(두 채널 독립)가 깨지고**(FR-025),
# 사용자가 말한 적 없는 문장이 기록에 저장된다(백엔드가 발견, 2026-09-16).
#
# 영문자로 시작하는 중괄호 묶음만 떼므로 한글 발화 속 `{진짜 괜찮았어요}`는 건드리지 않는다.
# 표정 이름에 괄호가 들어가는 것(`surprise (positive)`)까지 받는다.
_EXPRESSION_SUFFIX = re.compile(r"\s*\{[A-Za-z][A-Za-z ,'()\-]*\}\s*$")


def strip_expression_suffix(text: str) -> tuple[str, bool]:
    """(뗀 문장, 꼬리가 있었는가)."""
    stripped = _EXPRESSION_SUFFIX.sub("", text)
    return stripped, stripped != text


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

    _had_expression_suffix: bool = PrivateAttr(default=False)

    def model_post_init(self, __context: Any) -> None:
        # **파싱할 때 한 번만 뗀다.** `content`가 지나는 자리가 여기 하나라, 여기서
        # 잘라내면 분석·응답 이력·태그 대조·위기 규칙·백엔드 적재가 같이 깨끗해진다.
        # 아래로 내려간 뒤 경로마다 처리하면 빠지는 곳이 생긴다.
        # assistant에는 붙지 않는다고 문서에 있지만, 떼는 쪽이 손해가 없어 역할을 가리지 않는다.
        self.content, self._had_expression_suffix = strip_expression_suffix(self.content)

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

    def expression_suffix_seen(self) -> bool:
        """마지막 user 발화에 Hume 표정 꼬리가 붙어 왔었는가 — 로그용(내용 없음)."""
        m = self.last_user_message()
        return bool(m and m._had_expression_suffix)

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
