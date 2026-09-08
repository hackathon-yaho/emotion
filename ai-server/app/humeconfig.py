"""Hume Config를 만들고, 우리 요구사항과 대조한다 — `python -m app.humeconfig`

    python -m app.humeconfig            # 검사만
    python -m app.humeconfig --raw      # 원문도 함께
    python -m app.humeconfig --create   # 새 Config 생성 (계정을 옮겼을 때)

**EVI 분수를 쓰지 않는다.** Config 조회·생성은 REST라 소켓을 열지 않는다
(백엔드가 `request/ai/hume-config-setup.md`에서 실측으로 확인했다).

**만드는 것과 검사하는 것이 같은 값을 본다.** 아래 상수와 `build_payload()`가
유일한 출처다 — 손으로 콘솔에서 열한 항목을 클릭하면 하나쯤 빠지고, 빠진 것은
조용히 다른 동작이 된다. 실제로 `turn_detection`은 콘솔에서 설정된 적이 없어
기본값(800ms)으로 남아 있었다.

**있는 Config를 고치지는 않는다.** `--create`는 새로 만들 뿐이고, 기존 Config를
덮어쓰지 않는다 — 계정이 잠겨 새로 만들어야 했던 경위(2026-09-07)에서 나온 기능이다.

`HUME_API_KEY`가 필요하다. `python -m app.setsecret HUME_API_KEY` 로 넣는다.
"""

from __future__ import annotations

import json
import sys
from typing import Any

import httpx

from .config import settings
from .envcheck import _safe_stdout

CONFIG_URL = "https://api.hume.ai/v0/evi/configs/{config_id}"
CREATE_URL = "https://api.hume.ai/v0/evi/configs"

# 우리가 지켜야 하는 것들. 근거는 docs/response/backend/hume-config-setup.md.
REQUIRED_EVI_VERSION = "4-mini"
REQUIRED_INACTIVITY_SEC = 420
CLM_URL_SUFFIX = "/chat/completions"
# Hume 기본값은 각각 800ms다(허용 범위 500~3000 / 50~2000). 이 제품에는 둘 다 짧다.
MIN_END_OF_TURN_MS = 1800
MIN_INTERRUPTION_MS = 1200

CONFIG_NAME = "emotion-voice-journal"
VOICE_NAME = "Jin-Hee"
GREETING = "안녕하세요. 오늘 하루는 어떠셨나요?"
MAX_DURATION_SEC = 1800


def build_payload(clm_url: str) -> dict[str, Any]:
    """새 Config의 본문. **검사 항목과 같은 상수를 쓴다.**

    각 값의 근거는 `check()`의 설명 문구에 붙어 있다. 여기서 한 줄 빼면
    거기서 「고쳐」로 잡힌다 — 그러라고 둘을 같은 상수에 묶어 놨다.
    """
    return {
        "evi_version": REQUIRED_EVI_VERSION,
        "name": CONFIG_NAME,
        # 한국어 음성. EVI 3에는 한국어가 없어서 버전과 짝이다.
        "voice": {"provider": "HUME_AI", "name": VOICE_NAME},
        "language_model": {
            "model_provider": "CUSTOM_LANGUAGE_MODEL",
            "model_resource": clm_url,
            "temperature": 1.0,
        },
        "event_messages": {
            # 자동 생성은 매번 달라진다 — 첫 문장은 우리가 정한다.
            "on_new_chat": {"enabled": True, "text": GREETING},
            "on_inactivity_timeout": {"enabled": False, "text": None},
            "on_max_duration_timeout": {"enabled": False, "text": None},
        },
        "timeouts": {
            # 하드컷(420초)보다 짧으면 침묵만으로 대화가 끊긴다.
            "inactivity": {"enabled": True, "duration_secs": REQUIRED_INACTIVITY_SEC},
            "max_duration": {"enabled": True, "duration_secs": MAX_DURATION_SEC},
        },
        # 감정 대화에서 짧은 넛지는 말을 고르는 사람을 재촉한다.
        "nudges": {"enabled": False},
        "turn_detection": {
            # 기본 800ms면 말 고르는 침묵을 턴 종료로 읽어 한 마디가 쪼개진다.
            "end_of_turn_silence_ms": MIN_END_OF_TURN_MS,
            "prefix_padding_ms": 300,
            "speech_detection_threshold": 0.5,
        },
        # 기본 800ms면 "음…" 같은 맞장구에도 AI가 말을 멈춘다.
        "interruption": {"min_interruption_ms": MIN_INTERRUPTION_MS},
        "ellm_model": {"allow_short_responses": False},
    }


def create(payload: dict[str, Any], api_key: str) -> dict[str, Any]:
    r = httpx.post(
        CREATE_URL, headers={"X-Hume-Api-Key": api_key}, json=payload, timeout=30
    )
    r.raise_for_status()
    return r.json()


def fetch(config_id: str, api_key: str) -> dict[str, Any]:
    r = httpx.get(
        CONFIG_URL.format(config_id=config_id),
        headers={"X-Hume-Api-Key": api_key},
        timeout=20,
    )
    r.raise_for_status()
    body = r.json()
    # 버전 목록으로 오는 경우가 있어 가장 최근 것을 본다.
    if isinstance(body, dict) and "configs_page" in body:
        pages = body["configs_page"]
        return pages[0] if pages else body
    return body


def dig(obj: Any, *path: str) -> Any:
    for key in path:
        if not isinstance(obj, dict):
            return None
        obj = obj.get(key)
    return obj


def check(cfg: dict[str, Any], expected_clm: str) -> list[tuple[bool, str, str]]:
    """(통과, 항목, 설명) 목록. 실패한 것만 봐도 무엇을 고쳐야 하는지 나온다."""
    out: list[tuple[bool, str, str]] = []

    version = str(cfg.get("evi_version") or cfg.get("version") or "")
    out.append((
        REQUIRED_EVI_VERSION in version,
        "EVI 버전",
        f"{version or '(없음)'} — 한국어는 {REQUIRED_EVI_VERSION} 에서만 된다",
    ))

    lm = cfg.get("language_model") or {}
    provider = str(lm.get("model_provider") or "")
    out.append((
        bool(lm) and "CUSTOM" in provider.upper(),
        "언어 모델",
        f"{provider or '(비어 있음)'} — 비면 Hume이 자기 모델로 답하고 우리 서버는 안 불린다",
    ))

    url = str(lm.get("model_resource") or "")
    out.append((
        url.endswith(CLM_URL_SUFFIX),
        "CLM 주소 형식",
        f"{url or '(없음)'} — {CLM_URL_SUFFIX} 로 끝나야 한다",
    ))
    if expected_clm:
        out.append((url == expected_clm, "CLM 주소 일치", f"기대: {expected_clm}"))

    inactivity = dig(cfg, "timeouts", "inactivity", "duration_secs")
    out.append((
        inactivity is not None and int(inactivity) >= REQUIRED_INACTIVITY_SEC,
        "비활성 타임아웃",
        f"{inactivity}초 — 하드 컷(420초)보다 짧으면 침묵으로 대화가 끊긴다",
    ))

    voice = cfg.get("voice") or {}
    voice_name = voice.get("name") or voice.get("id") or ""
    out.append((bool(voice_name), "음성", f"{voice_name or '(없음)'} — 한국어 음성인지 눈으로 확인"))

    # 스키마는 event_messages.on_new_chat 이다 (Hume Config API 레퍼런스).
    # 처음에 first_message/initial_message 로 찾다가 못 봤다.
    on_new = dig(cfg, "event_messages", "on_new_chat") or {}
    first = (on_new.get("text") or "").strip() if isinstance(on_new, dict) else ""
    out.append((
        bool(first),
        "첫 인사말",
        f"{first[:44] if first else '(자동 생성 — 매번 달라진다)'}",
    ))

    # 발화 종료 판정. **기본 800ms는 이 제품에 짧다** — 감정 대화에서 사람은 말을
    # 고르느라 1~2초를 쉰다. 그 침묵을 "끝났다"로 읽으면 한 마디가 여러 턴으로
    # 쪼개지고, (a) 대화가 끊기는 느낌이 들고 (b) CLM 호출이 그만큼 늘어 무료 티어
    # 한도를 더 빨리 먹는다. 실측: 2분에 assistant 턴 12번(평균 10초에 한 번).
    turn = cfg.get("turn_detection") or {}
    silence = turn.get("end_of_turn_silence_ms") if isinstance(turn, dict) else None
    out.append((
        silence is not None and int(silence) >= MIN_END_OF_TURN_MS,
        "발화 종료 대기",
        f"{silence if silence is not None else '(기본 800ms)'} — {MIN_END_OF_TURN_MS}ms 이상이어야"
        " 말을 고르는 침묵을 턴 종료로 읽지 않는다",
    ))

    # 끼어들기 판정. 짧으면 "음…", "네…" 같은 맞장구에 AI가 말을 멈춘다.
    interruption = cfg.get("interruption") or {}
    min_int = (
        interruption.get("min_interruption_ms") if isinstance(interruption, dict) else None
    )
    out.append((
        min_int is not None and int(min_int) >= MIN_INTERRUPTION_MS,
        "끼어들기 최소",
        f"{min_int if min_int is not None else '(기본 800ms)'} — 짧으면 맞장구에도 AI가 말을 끊는다",
    ))

    # 넛지: 켜져 있으면 간격을 본다. 감정 대화에서 짧은 넛지는 재촉이 된다.
    nudges = cfg.get("nudges") or {}
    if isinstance(nudges, dict) and nudges.get("enabled"):
        interval = nudges.get("interval_secs") or nudges.get("interval")
        out.append((
            interval is not None and int(interval) >= 60,
            "비활성 넛지",
            f"켜짐 · {interval}초 — 감정 대화에서 짧은 넛지는 말을 고르는 사람을 재촉한다",
        ))
    else:
        out.append((True, "비활성 넛지", "꺼짐"))

    return out


def main(argv: list[str] | None = None) -> int:
    _safe_stdout()
    argv = sys.argv[1:] if argv is None else argv
    cfg_env = settings()

    api_key = cfg_env.hume_api_key
    config_id = cfg_env.hume_config_id
    expected = (cfg_env.ai_public_url or "").rstrip("/")

    if "--create" in argv:
        if not api_key:
            print("HUME_API_KEY 가 없습니다.  python -m app.setsecret HUME_API_KEY")
            return 1
        if not expected:
            print("AI_PUBLIC_URL 이 없습니다 — CLM 주소를 만들 수 없습니다.")
            return 1
        if config_id:
            # 덮어쓰지 않는다. 다만 이미 하나 있는데 또 만드는 것은 대개 실수다.
            print(f"⚠ HUME_CONFIG_ID 가 이미 있습니다: {config_id}")
            print("  새로 만들면 .env 와 백엔드 환경변수를 새 id로 바꿔야 합니다.\n")
        payload = build_payload(f"{expected}{CLM_URL_SUFFIX}")
        try:
            made = create(payload, api_key)
        except httpx.HTTPStatusError as e:
            print(f"생성 실패: HTTP {e.response.status_code}")
            print(e.response.text[:600])
            return 1
        except httpx.HTTPError:
            print("생성 실패: 네트워크")
            return 1
        new_id = made.get("id", "(id 없음)")
        print(f"\n만들었습니다.  HUME_CONFIG_ID={new_id}\n")
        # **만든 것을 그 자리에서 검사한다.** 만들었다는 응답과 실제로 그렇게
        # 저장됐는지는 다른 문제다 — 무시된 필드가 있으면 여기서 드러난다.
        bad = 0
        for ok, label, detail in check(made, f"{expected}{CLM_URL_SUFFIX}"):
            print(f"  {'OK  ' if ok else '고쳐'}  {label:<14} {detail}")
            if not ok:
                bad += 1
        print()
        if bad:
            print(f"⚠ 만들어졌지만 {bad}개 항목이 뜻대로 안 들어갔습니다. 콘솔에서 확인하세요.")
            return 1
        print("전부 통과했습니다. 다음 순서로 넣으세요 —")
        print(f"  1) ai-server/.env 의  HUME_CONFIG_ID={new_id}")
        print( "  2) 백엔드 Render 환경변수  HUME_API_KEY · HUME_SECRET_KEY · HUME_CONFIG_ID")
        return 0

    if not api_key or not config_id:
        print("HUME_API_KEY 또는 HUME_CONFIG_ID 가 없습니다.")
        print("  python -m app.setsecret HUME_API_KEY")
        print("  .env 의 HUME_CONFIG_ID 도 채우세요.")
        print("  Config가 아직 없으면:  python -m app.humeconfig --create")
        return 1

    try:
        cfg = fetch(config_id, api_key)
    except httpx.HTTPStatusError as e:
        print(f"조회 실패: HTTP {e.response.status_code}")
        return 1
    except httpx.HTTPError:
        print("조회 실패: 네트워크")
        return 1

    expected_clm = f"{expected}{CLM_URL_SUFFIX}" if expected else ""

    print(f"\nConfig {config_id}\n")
    bad = 0
    for ok, label, detail in check(cfg, expected_clm):
        print(f"  {'OK  ' if ok else '고쳐'}  {label:<14} {detail}")
        if not ok:
            bad += 1

    if "--raw" in argv:
        print("\n--- 원문 ---")
        print(json.dumps(cfg, ensure_ascii=False, indent=2)[:4000])

    print()
    print("전부 통과했습니다." if bad == 0 else f"고칠 항목 {bad}개.")
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
