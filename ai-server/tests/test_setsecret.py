"""시크릿 입력 도구 — 붙여넣기 사고를 먼저 잡는다.

여기서 안 잡으면 값이 조용히 틀린 채로 들어가고, 나중에 401을 몇 시간 디버깅하게 된다.
"""

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
