""".env.example 과 config.py 의 기본값이 어긋나지 않는지.

**왜 테스트로 막는가** — `.env`가 있으면 그쪽이 `config.py`를 덮는다. 그래서
`.env.example`이 낡으면, 그걸 복사한 사람의 서버는 **코드에서 고친 결함을 그대로
재현한다.** 실제로 그런 일이 있었다 — `AI_RESPOND_EFFORT`가 `low`로 남아 있어서
복사하면 위기 응답의 109 안내가 잘리는 상태로 시작됐다
(`docs/request/ai/env-example-drift.md`, 백엔드가 발견).

문서를 고치라는 규칙으로는 반복된다. 값이 갈라지면 테스트가 깨지게 둔다.
"""

from pathlib import Path

import pytest

from app.config import Settings

ENV_EXAMPLE = Path(__file__).resolve().parent.parent / ".env.example"

# 비교하지 않는 것: 시크릿(빈 값이 정상)과 배포마다 달라지는 주소.
SKIP = {
    "GOOGLE_API_KEY",
    "INTERNAL_SHARED_SECRET",
    "AI_PUBLIC_URL",
    "BACKEND_BASE_URL",
    "AI_RULES_DIR",
    "AI_PROMPTS_DIR",
    "AI_CAPTURE_DIR",
    "HUME_API_KEY",
}


def parse_example() -> dict[str, str]:
    out: dict[str, str] = {}
    for line in ENV_EXAMPLE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip()
    return out


EXAMPLE = parse_example()
DEFAULTS = Settings.model_fields


@pytest.mark.parametrize("key", sorted(k for k in parse_example() if k not in SKIP))
def test_example_값이_코드_기본값과_같다(key):
    attr = key.lower()
    assert attr in DEFAULTS, f"{key}가 config.py에 없다 — 둘 중 하나가 낡았다"
    expected = DEFAULTS[attr].default
    actual = EXAMPLE[key]
    if isinstance(expected, bool):
        assert actual.lower() == str(expected).lower(), key
    else:
        assert actual == str(expected), (
            f"{key}: .env.example={actual!r} 인데 config.py={expected!r}. "
            "`.env`가 코드를 덮으므로 이 파일을 복사한 사람은 옛 동작을 얻는다"
        )


def test_시크릿은_비어_있다():
    """예시 파일에 실제 값이 들어가면 저장소에 시크릿이 올라간다."""
    for key in ("GOOGLE_API_KEY", "INTERNAL_SHARED_SECRET", "HUME_API_KEY"):
        assert EXAMPLE.get(key, "") == "", f"{key}에 값이 들어 있다"


def test_위기_응답_설정이_none이다():
    """FR-032·033. spec §11이 F4는 어떤 스코프 컷에서도 자르지 않는다고 못박은 자리다."""
    assert EXAMPLE["AI_RESPOND_EFFORT"] == "none"
