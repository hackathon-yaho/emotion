""".env 또는 Secret Manager에 시크릿 한 줄을 넣는다.

    python -m app.setsecret INTERNAL_SHARED_SECRET            # 로컬 .env
    python -m app.setsecret INTERNAL_SHARED_SECRET --cloud    # 배포용 Secret Manager

**PowerShell 스크립트가 아니라 Python인 이유**: 이 머신은 실행 정책이 `.ps1`을
막아서 `set-secret.ps1`이 한 줄도 돌지 않는다. Python은 그 정책의 영향을 받지 않는다.

값은 `getpass`로 받으므로 **화면에 찍히지 않고 셸 명령 기록에도 남지 않는다.**
값을 명령 인자로 받지 않는 것도 같은 이유다 — 인자는 기록과 프로세스 목록에 남는다.

근거: 계약 §3-1 (시크릿은 양쪽 환경변수로만, 저장소에 넣지 않는다)
"""

from __future__ import annotations

import getpass
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ENV_PATH = Path(__file__).resolve().parent.parent / ".env"
NAME_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")
GCP_PROJECT = "emotion-voice-ai"


def mask(value: str) -> str:
    if len(value) <= 8:
        return f"(설정됨, {len(value)}자)"
    return f"{value[:4]}...{value[-2:]} ({len(value)}자)"


def validate(value: str, name: str = "") -> str | None:
    """붙여넣기 사고를 먼저 잡는다. 여기서 안 잡으면 나중에 401을 디버깅하게 된다.

    **`=`가 들어 있다는 것만으로 거부하지 않는다.** `openssl rand -base64 32`가 만드는
    시크릿은 `=`로 끝나고, 그게 바로 `INTERNAL_SHARED_SECRET`의 형식이다. 거부하는 것은
    **지금 넣으려는 키 이름으로 시작하는 경우**뿐이다.
    """
    if not value.strip():
        return "빈 값입니다."
    if value.startswith(('"', "'")) or value.endswith(('"', "'")):
        return "값의 앞이나 뒤에 따옴표가 있습니다. 따옴표는 빼고 넣으세요."
    if name and value.upper().startswith(f"{name.upper()}="):
        return f"'{name}=값' 통째로 붙여넣으신 것 같습니다. 값만 넣으세요."
    if "\n" in value or "\r" in value:
        return "값에 줄바꿈이 있습니다. 한 줄로 붙여넣으세요."
    return None


def apply_to_lines(lines: list[str], name: str, value: str) -> list[str]:
    """해당 키 줄만 갈아끼운다. 없으면 끝에 붙인다. 나머지 줄은 그대로 둔다."""
    pattern = re.compile(rf"^\s*{re.escape(name)}\s*=")
    out = list(lines)
    for i, line in enumerate(out):
        if pattern.match(line):
            out[i] = f"{name}={value}"
            return out
    out.append(f"{name}={value}")
    return out


def find_gcloud() -> str | None:
    """`gcloud.cmd`를 찾는다. `.ps1`이 아니라 `.cmd`여야 실행 정책에 안 막힌다."""
    for candidate in ("gcloud.cmd", "gcloud"):
        found = shutil.which(candidate)
        if found:
            return found
    guess = Path(
        r"C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"
    )
    return str(guess) if guess.exists() else None


def write_to_cloud(name: str, value: str, project: str = GCP_PROJECT) -> int:
    """Secret Manager에 **새 버전**을 추가한다.

    값을 명령 인자로 넘기지 않는다 — 셸 기록과 프로세스 목록에 평문으로 남는다.
    임시 파일은 **BOM 없이** 쓰고 `finally`에서 반드시 지운다. gcloud가 도중에
    실패해도 평문 키 파일이 디스크에 남으면 안 된다.
    """
    gcloud = find_gcloud()
    if gcloud is None:
        print("gcloud를 찾지 못했습니다. Cloud SDK 설치 경로를 확인하세요.")
        return 1

    fd, tmp = tempfile.mkstemp(suffix=".secret")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(value.encode("utf-8"))  # BOM 없음
        result = subprocess.run(
            [gcloud, "secrets", "versions", "add", name,
             f"--data-file={tmp}", f"--project={project}"],
            capture_output=True, text=True,
        )
    finally:
        try:
            os.unlink(tmp)
        except OSError:
            pass

    if result.returncode != 0:
        # gcloud 출력에 값이 섞일 일은 없지만, 그래도 마지막 줄만 보여준다.
        tail = (result.stderr or result.stdout or "").strip().splitlines()
        print("Secret Manager 등록 실패:", tail[-1] if tail else "(원인 불명)")
        return 1

    print(f"\n{name} 을(를) Secret Manager에 새 버전으로 넣었습니다.  {mask(value)}")
    print(f"프로젝트: {project}")
    print("\n★ 아직 반영되지 않았습니다 — Cloud Run이 배포 시점에 값을 읽습니다.")
    print("  재배포해야 적용됩니다. AI 담당에게 알려주세요.")
    return 0


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    cloud = "--cloud" in argv
    names = [a for a in argv if not a.startswith("-")]

    if len(names) != 1 or not NAME_RE.match(names[0]):
        print("사용법:")
        print("  python -m app.setsecret INTERNAL_SHARED_SECRET           # 로컬 .env")
        print("  python -m app.setsecret INTERNAL_SHARED_SECRET --cloud   # 배포용")
        return 2

    name = names[0]
    if not cloud and not ENV_PATH.exists():
        print(f".env 가 없습니다: {ENV_PATH}")
        print("  .env.example 을 복사해서 만드세요:  copy .env.example .env")
        return 1

    target = "Secret Manager (배포용)" if cloud else ".env (로컬용)"
    print(f"\n{name} 값을 붙여넣고 Enter. 화면에 표시되지 않습니다.")
    print(f"넣을 곳: {target}")
    try:
        value = getpass.getpass("> ").strip()
    except (EOFError, KeyboardInterrupt):
        print("\n취소했습니다. 아무것도 바꾸지 않았습니다.")
        return 1

    problem = validate(value, name)
    if problem:
        print(problem)
        print("아무것도 바꾸지 않았습니다.")
        return 1

    if cloud:
        return write_to_cloud(name, value)

    text = ENV_PATH.read_text(encoding="utf-8")
    lines = text.split("\n")
    ENV_PATH.write_text(
        "\n".join(apply_to_lines(lines, name, value)), encoding="utf-8", newline="\n"
    )
    print(f"\n{name} 을(를) .env 에 넣었습니다.  {mask(value)}")
    print("확인:  python -m app.envcheck\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
