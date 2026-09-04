"""환경변수 — 단일 출처는 `.env.example`과 docs/02-architecture/ai-pipeline.md §13.

여기서 기본값을 바꾸면 `.env.example`도 같이 바꾼다. 두 곳이 다르면 `.env.example`이 맞다.
매핑표·임계값·키워드는 여기 두지 않는다 — `rules/`의 JSON이 단일 출처다.
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

ROOT = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )

    # 서버
    ai_port: int = 8100
    ai_public_url: str = ""

    # 백엔드 연동
    backend_base_url: str = "http://localhost:8080"
    internal_shared_secret: str = ""
    ai_turn_post_retries: int = 3
    ai_session_lookup_timeout_ms: int = 800
    ai_session_lookup_connect_retry: int = 1
    ai_session_refetch_idle_sec: int = 60

    # LLM
    anthropic_api_key: str = ""
    ai_model_analyze: str = "claude-haiku-4-5"
    ai_model_respond: str = "claude-sonnet-5"
    ai_respond_effort: str = "low"
    ai_model_observe: str = "claude-opus-5"
    ai_observe_effort: str = "medium"
    ai_model_summary: str = "claude-haiku-4-5"
    ai_analyze_timeout_ms: int = 400
    ai_summary_timeout_ms: int = 2500
    ai_speculative_respond: bool = False

    # 규칙
    ai_gap_threshold_fixed: float = 0.85
    ai_voice_valence_min_mass: float = 0.05
    ai_rules_dir: Path = ROOT / "rules"
    ai_prompts_dir: Path = ROOT / "prompts"

    # 로깅
    ai_log_level: str = "info"


@lru_cache(maxsize=1)
def settings() -> Settings:
    return Settings()
