"""배포본 로그를 읽는다 — `python -m app.logs`

    python -m app.logs              # 최근 30분, 구조화 로그만
    python -m app.logs --all        # uvicorn 접속 로그까지
    python -m app.logs --min 120    # 시간 범위

**대화가 끝난 뒤 무엇이 일어났는지 보는 창구다.** Cloud Run 인스턴스는 사라지지만
로그는 남는다 — 첫 Hume 연결의 요청 뼈대도 여기 있다(app/capture.py).

로그에는 발화가 없다(FR-092). 세션 식별자도 해시(`sessionRef`)로만 나온다.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from .envcheck import _safe_stdout

PROJECT = "emotion-voice-ai"
SERVICE = "emotion-ai-server"


def find_gcloud() -> str | None:
    for candidate in ("gcloud.cmd", "gcloud"):
        found = shutil.which(candidate)
        if found:
            return found
    guess = Path(
        r"C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"
    )
    return str(guess) if guess.exists() else None


def fetch(minutes: int) -> list[dict]:
    """Cloud Logging은 stdout의 JSON 한 줄을 `jsonPayload`로 파싱해 넣는다.

    처음에 `textPayload`만 읽다가 구조화 로그를 통째로 놓쳤다 — 그쪽에는 uvicorn의
    평문만 온다. 그래서 `--format=json`으로 받아 둘 다 본다.

    **시간 범위는 필터에 직접 쓴다.** 종전에는 `--freshness`에 맡겼는데 `--order=asc`
    와 함께 쓰면 걸리지 않아서, "최근 10분"을 달래도 두 시간 전 것이 딸려 나왔다.
    낡은 줄을 방금 것으로 읽는 것이 안 보이는 것보다 나쁘다 — 그 착각으로 손으로 찌른
    탐침을 Hume의 첫 연결로 읽었다(2026-09-07).
    """
    gcloud = find_gcloud()
    if gcloud is None:
        print("gcloud를 찾지 못했습니다.")
        return []
    since = datetime.now(timezone.utc) - timedelta(minutes=minutes)
    stamp = since.strftime("%Y-%m-%dT%H:%M:%SZ")
    result = subprocess.run(
        [
            gcloud, "logging", "read",
            f"resource.type=cloud_run_revision"
            f" AND resource.labels.service_name={SERVICE}"
            f' AND timestamp>="{stamp}"',
            f"--project={PROJECT}", "--limit=300",
            "--format=json", "--order=asc",
        ],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    if result.returncode != 0:
        tail = (result.stderr or "").strip().splitlines()
        print("로그 조회 실패:", tail[-1] if tail else "(원인 불명)")
        return []
    try:
        return json.loads(result.stdout or "[]")
    except json.JSONDecodeError:
        print("로그 파싱 실패")
        return []


def main(argv: list[str] | None = None) -> int:
    _safe_stdout()
    argv = sys.argv[1:] if argv is None else argv
    minutes = 30
    if "--min" in argv:
        try:
            minutes = int(argv[argv.index("--min") + 1])
        except (IndexError, ValueError):
            pass
    show_all = "--all" in argv

    lines = fetch(minutes)
    if not lines:
        print(f"최근 {minutes}분 로그가 없습니다. 인스턴스가 자고 있었을 수 있습니다.")
        return 0

    shown = 0
    for entry in lines:
        ts = (entry.get("timestamp") or "")[11:19]
        data = entry.get("jsonPayload")
        if isinstance(data, dict) and data:
            data = dict(data)
            event = data.pop("event", "?")
            shape = data.pop("shape", None)  # 뼈대는 길어서 따로 보여준다
            rest = " ".join(f"{k}={v}" for k, v in sorted(data.items()) if v is not None)
            print(f"{ts}  {event:<26} {rest}")
            if shape is not None:
                # **"Hume이 보낸 모양"이라고 쓰지 않는다.** 처음에 그렇게 적었다가
                # 손으로 찌른 curl 탐침을 Hume의 요청으로 읽었다(2026-09-07).
                # 이 자리는 누가 불렀는지 모른다 — 판별은 앞줄의 event가 한다.
                print("    ── 들어온 요청의 모양 ──")
                for line in json.dumps(shape, ensure_ascii=False, indent=2).splitlines():
                    print("    " + line)
            shown += 1
        elif show_all:
            text = (entry.get("textPayload") or "").strip()
            if text:
                print(f"{ts}  {text}")
                shown += 1

    if shown == 0:
        print(f"최근 {minutes}분에 구조화 로그가 없습니다. `--all`로 접속 로그를 보세요.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
