"""시크릿 입력 도구 — 붙여넣기 사고를 먼저 잡는다.

여기서 안 잡으면 값이 조용히 틀린 채로 들어가고, 나중에 401을 몇 시간 디버깅하게 된다.
"""

from pathlib import Path

import pytest

from app.setsecret import apply_to_lines, mask, validate


# ── 붙여넣기 사고 ─────────────────────────────────────────────────


@pytest.mark.parametrize(
    "value",
    ['"abc123"', "'abc123'", '"abc123', "abc123'"],
)
def test_따옴표째_붙여넣으면_거부한다(value):
    assert validate(value) is not None


def test_이름까지_붙여넣으면_거부한다():
    assert validate("GOOGLE_API_KEY=abc123", "GOOGLE_API_KEY") is not None


def test_줄바꿈이_섞이면_거부한다():
    assert validate("abc\n123") is not None


def test_빈_값을_거부한다():
    assert validate("") is not None and validate("   ") is not None


def test_정상_값은_통과한다():
    assert validate("AIzaSyABCDEF1234567890abcdefGHIJKLMNOP") is None
    assert validate("k3n8Zq+Lm2/aB9cD1eF4gH6iJ8kL0mN2oP4qR6sT8u=") is None


def test_base64_시크릿의_등호는_문제가_아니다():
    """`openssl rand -base64 32` 는 = 로 끝난다. 백엔드가 준 공유 시크릿이 이 형식이다.

    = 가 있다는 이유로 거부하면 **진짜 값이 안 들어간다.** 실제로 그 버그가 있었고,
    이 테스트가 잡았다.
    """
    assert validate("abcd1234==", "INTERNAL_SHARED_SECRET") is None
    assert (
        validate("k3n8Zq+Lm2/aB9cD1eF4gH6iJ8kL0mN2oP4qR6sT8u=", "INTERNAL_SHARED_SECRET")
        is None
    )


# ── .env 갈아끼우기 ───────────────────────────────────────────────


def test_있는_키를_갈아끼운다():
    lines = ["FOO=1", "GOOGLE_API_KEY=", "BAR=2"]
    out = apply_to_lines(lines, "GOOGLE_API_KEY", "new")
    assert out == ["FOO=1", "GOOGLE_API_KEY=new", "BAR=2"]


def test_없는_키는_끝에_붙인다():
    out = apply_to_lines(["FOO=1"], "NEW_KEY", "v")
    assert out == ["FOO=1", "NEW_KEY=v"]


def test_주석과_빈_줄을_건드리지_않는다():
    """.env 는 사람이 읽는 파일이다. 안내 주석이 사라지면 다음 사람이 헤맨다."""
    lines = ["# 안내", "", "FOO=1", "# ★ 여기에 넣으세요", "GOOGLE_API_KEY=", ""]
    out = apply_to_lines(lines, "GOOGLE_API_KEY", "v")
    assert out == ["# 안내", "", "FOO=1", "# ★ 여기에 넣으세요", "GOOGLE_API_KEY=v", ""]


def test_주석_처리된_같은_이름은_건드리지_않는다():
    """`# GOOGLE_API_KEY=` 같은 줄을 진짜 설정으로 착각하면 안 된다."""
    lines = ["# GOOGLE_API_KEY=예시", "GOOGLE_API_KEY="]
    out = apply_to_lines(lines, "GOOGLE_API_KEY", "v")
    assert out[0] == "# GOOGLE_API_KEY=예시"
    assert out[1] == "GOOGLE_API_KEY=v"


def test_이름이_비슷한_키를_건드리지_않는다():
    lines = ["GOOGLE_API_KEY_OLD=x", "GOOGLE_API_KEY="]
    out = apply_to_lines(lines, "GOOGLE_API_KEY", "v")
    assert out[0] == "GOOGLE_API_KEY_OLD=x"
    assert out[1] == "GOOGLE_API_KEY=v"


def test_첫_번째_것만_바꾼다():
    out = apply_to_lines(["K=1", "K=2"], "K", "v")
    assert out == ["K=v", "K=2"]


# ── 마스킹 ────────────────────────────────────────────────────────


def test_값을_통째로_보여주지_않는다():
    secret = "AIzaSyABCDEF1234567890abcdefGHIJKLMNOP"
    assert secret not in mask(secret)


# ── Secret Manager 경로 ───────────────────────────────────────────


def test_gcloud를_cmd로_찾는다():
    """`.ps1`이면 실행 정책에 막힌다. `.cmd`나 확장자 없는 실행 파일이어야 한다."""
    from app.setsecret import find_gcloud

    found = find_gcloud()
    if found is not None:
        assert not found.lower().endswith(".ps1")


def test_임시_파일이_남지_않는다(monkeypatch, tmp_path):
    """gcloud가 실패해도 평문 키 파일이 디스크에 남으면 안 된다.

    런북이 실제로 당한 사고다 — 루프 중간에 멈춰서 임시 키 파일이 남았다.
    """
    import subprocess

    from app import setsecret

    seen = {}

    def fake_run(cmd, **kw):
        # gcloud가 보는 시점에는 파일이 있어야 하고, 그 경로를 기억해 둔다.
        path = [c for c in cmd if str(c).startswith("--data-file=")][0].split("=", 1)[1]
        seen["path"] = path
        assert Path(path).exists()
        return subprocess.CompletedProcess(cmd, 1, "", "boom")

    monkeypatch.setattr(setsecret, "find_gcloud", lambda: "gcloud.cmd")
    monkeypatch.setattr(subprocess, "run", fake_run)

    assert setsecret.write_to_cloud("X", "v" * 20) == 1
    assert not Path(seen["path"]).exists()


def test_값을_명령_인자로_넘기지_않는다(monkeypatch):
    """인자는 셸 기록과 프로세스 목록에 평문으로 남는다."""
    import subprocess

    from app import setsecret

    SECRET = "s3cr3t-value-do-not-log-0123456789"
    captured = {}

    def fake_run(cmd, **kw):
        captured["cmd"] = [str(c) for c in cmd]
        return subprocess.CompletedProcess(cmd, 0, "", "")

    monkeypatch.setattr(setsecret, "find_gcloud", lambda: "gcloud.cmd")
    monkeypatch.setattr(subprocess, "run", fake_run)
    setsecret.write_to_cloud("X", SECRET)

    assert all(SECRET not in part for part in captured["cmd"])


def test_시크릿이_없으면_만들고_다시_넣는다(monkeypatch):
    """여기서 멈추면 사람이 gcloud 명령을 따로 찾아 치고, 그 과정에서 값을
    명령 인자로 넘기게 된다 — 셸 기록에 평문으로 남는다. 그 길을 막는다."""
    import subprocess

    from app import setsecret

    calls: list[list[str]] = []

    class R:
        def __init__(self, code, err=""):
            self.returncode, self.stderr, self.stdout = code, err, ""

    def fake_run(cmd, **_kw):
        calls.append(cmd)
        if cmd[1:4] == ["secrets", "versions", "add"] and len(calls) == 1:
            return R(1, "ERROR: NOT_FOUND: Secret [GOOGLE_API_KEY_2] not found.")
        return R(0)

    monkeypatch.setattr(setsecret, "find_gcloud", lambda: "gcloud.cmd")
    monkeypatch.setattr(subprocess, "run", fake_run)

    assert setsecret.write_to_cloud("GOOGLE_API_KEY_2", "AIzaSyTEST") == 0
    verbs = [c[2] for c in calls]
    assert verbs == ["versions", "create", "add-iam-policy-binding", "versions"]
    # **만들면서 Cloud Run 읽기 권한까지 붙인다.** 안 붙이면 나중에 배포가
    # `Permission denied on secret`으로 실패한다(실측 2026-09-09).
    bind = " ".join(calls[2])
    assert "roles/secretmanager.secretAccessor" in bind
    assert setsecret.CLOUD_RUN_SA in bind
    # 값은 어느 명령에도 인자로 들어가지 않는다.
    assert all("AIzaSyTEST" not in " ".join(c) for c in calls)
