"""`.env`가 제대로 들어갔는지 확인한다 — `python -m app.envcheck`

**시크릿 값을 절대 전부 출력하지 않는다.** 앞뒤 몇 글자와 길이만 보여준다.
터미널 기록·화면 공유·스크린샷으로 값이 새는 경로를 만들지 않기 위함이다
(계약 §3-1, PRD FR-092의 취지).

값이 맞는지는 확인해 주지 못한다. **비어 있는지 아닌지**만 본다.
"""

from __future__ import annotations

import sys

from .config import settings

# (환경변수 이름, 설정 속성, 시크릿인가, 무엇이 막히는가)
REQUIRED = [
    ("INTERNAL_SHARED_SECRET", "internal_shared_secret", True,
     "백엔드와의 내부 API 전부 (계약 §3-1)"),
    ("GOOGLE_API_KEY", "google_api_key", True,
     "분석, 응답, 관찰, 요약. 없으면 정형 문장만 나간다"),
]

INTEGRATION = [
    ("BACKEND_BASE_URL", "backend_base_url", False,
     "세션 조회·턴 적재. 통합 때는 백엔드 터널 주소로 바꾼다"),
    ("AI_PUBLIC_URL", "ai_public_url", False,
     "Hume Config에 등록할 주소. 터널을 열어야 생긴다"),
]

INFO = [
    ("AI_LLM_BASE_URL", "ai_llm_base_url", False, "Gemini의 OpenAI 호환 엔드포인트"),
    ("AI_MODEL_ANALYZE", "ai_model_analyze", False, ""),
    ("AI_MODEL_RESPOND", "ai_model_respond", False, ""),
    ("AI_MODEL_OBSERVE", "ai_model_observe", False, ""),
    ("AI_MODEL_SUMMARY", "ai_model_summary", False, ""),
    ("AI_GAP_THRESHOLD_FIXED", "ai_gap_threshold_fixed", False, "임시값 — 20쌍 측정 후 교체"),
    ("AI_TURN_POST_RETRIES", "ai_turn_post_retries", False, ""),
    ("AI_EVAL_CAPTURE", "ai_eval_capture", False, "켜면 발화가 저장된다"),
]


def _safe_stdout() -> None:
    """Windows 기본 콘솔은 cp949라 일부 문자에서 죽는다.

    한글은 cp949로 나가지만 em dash 같은 문자는 인코딩되지 않아 UnicodeEncodeError가
    난다. 인코딩을 바꾸지 않고 **인코딩 못 하는 문자만 치환**하도록 바꾼다 —
    인코딩을 utf-8로 강제하면 cp949 콘솔에서 한글이 깨진다.
    """
    try:
        sys.stdout.reconfigure(errors="replace")
    except (AttributeError, ValueError):
        pass


def mask(value: str) -> str:
    """앞 4글자와 길이만. 짧으면 길이만 보여준다."""
    if not value:
        return "(비어 있음)"
    if len(value) <= 8:
        return f"(설정됨, {len(value)}자)"
    return f"{value[:4]}...{value[-2:]} ({len(value)}자)"


def _row(name: str, raw, secret: bool) -> tuple[bool, str]:
    text = "" if raw is None else str(raw)
    ok = bool(text.strip())
    shown = mask(text) if secret else (text if ok else "(비어 있음)")
    return ok, shown


def main() -> int:
    _safe_stdout()
    cfg = settings()
    missing: list[tuple[str, str]] = []

    print("\n필수 - 없으면 그 기능이 통째로 안 돈다")
    for name, attr, secret, blocks in REQUIRED:
        ok, shown = _row(name, getattr(cfg, attr, None), secret)
        print(f"  {'OK  ' if ok else '없음'}  {name:<26} {shown}")
        if not ok:
            missing.append((name, blocks))

    print("\n통합에 필요 - 지금은 비어 있어도 된다")
    for name, attr, secret, note in INTEGRATION:
        ok, shown = _row(name, getattr(cfg, attr, None), secret)
        print(f"  {'OK  ' if ok else '.   '}  {name:<26} {shown}")
        if note:
            print(f"        {note}")

    print("\n설정값")
    for name, attr, secret, note in INFO:
        _, shown = _row(name, getattr(cfg, attr, None), secret)
        tail = f"   ({note})" if note else ""
        print(f"        {name:<26} {shown}{tail}")

    if missing:
        print("\n채워야 할 것:")
        for name, blocks in missing:
            print(f"  {name} : {blocks}")
        print("\n  ai-server/.env 를 열어 값을 넣으세요. 이 파일은 저장소에 올라가지 않습니다.")
        return 1

    print("\n필수 값이 전부 들어 있습니다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
