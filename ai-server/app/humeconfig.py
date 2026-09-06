"""Hume Config를 읽어 우리 요구사항과 대조한다 — `python -m app.humeconfig`

    python -m app.humeconfig            # 검사만
    python -m app.humeconfig --raw      # 원문도 함께

**EVI 분수를 쓰지 않는다.** 토큰 발급·Config 조회는 REST라 소켓을 열지 않는다
(백엔드가 `request/ai/hume-config-setup.md`에서 실측으로 확인했다).

**읽기만 한다.** 이 도구는 Config를 고치지 않는다 — 콘솔에서 사람이 고치고,
여기서는 맞게 고쳐졌는지만 본다.

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

# 우리가 지켜야 하는 것들. 근거는 docs/response/backend/hume-config-setup.md.
REQUIRED_EVI_VERSION = "4-mini"
REQUIRED_INACTIVITY_SEC = 420
CLM_URL_SUFFIX = "/chat/completions"


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

    greeting = (cfg.get("prompt") or {}).get("text") if isinstance(cfg.get("prompt"), dict) else None
    first = cfg.get("first_message") or cfg.get("initial_message") or greeting
    out.append((bool(first), "첫 인사말", f"{(first or '(자동 생성)')[:40]}"))

    return out


def main(argv: list[str] | None = None) -> int:
    _safe_stdout()
    argv = sys.argv[1:] if argv is None else argv
    cfg_env = settings()

    api_key = cfg_env.hume_api_key
    config_id = cfg_env.hume_config_id
    if not api_key or not config_id:
        print("HUME_API_KEY 또는 HUME_CONFIG_ID 가 없습니다.")
        print("  python -m app.setsecret HUME_API_KEY")
        print("  .env 의 HUME_CONFIG_ID 도 채우세요.")
        return 1

    try:
        cfg = fetch(config_id, api_key)
    except httpx.HTTPStatusError as e:
        print(f"조회 실패: HTTP {e.response.status_code}")
        return 1
    except httpx.HTTPError:
        print("조회 실패: 네트워크")
        return 1

    expected = (cfg_env.ai_public_url or "").rstrip("/")
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
