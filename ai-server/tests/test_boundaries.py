"""경계 검사 — ai-server/README.md "지켜야 하는 것", CLAUDE.md 경계 감시.

이 파일은 기능이 아니라 **설계 제약**을 검사한다. 리뷰에서 사람이 눈으로 잡던 것을
테스트로 내린 것이라, 여기가 깨지면 코드가 아니라 설계가 어긋난 것이다.
"""

import ast
import json
from pathlib import Path

import pytest

from app.rules.valence import known_emotions

ROOT = Path(__file__).resolve().parent.parent
RULES_SRC = ROOT / "app" / "rules"
FIXTURES = ROOT / "eval" / "fixtures" / "internal"

# 순수 함수 계층에 들어오면 안 되는 것들.
FORBIDDEN_IN_RULES = {
    "httpx", "requests", "urllib", "urllib3", "socket", "http",
    "anthropic", "openai", "fastapi", "uvicorn", "asyncio", "aiohttp",
}


def _imported_modules(path: Path) -> set[str]:
    tree = ast.parse(path.read_text(encoding="utf-8"))
    mods: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            mods |= {a.name.split(".")[0] for a in node.names}
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            mods.add(node.module.split(".")[0])
    return mods


@pytest.mark.parametrize("src", sorted(RULES_SRC.glob("*.py")), ids=lambda p: p.name)
def test_rules에는_네트워크도_LLM도_없다(src):
    """`app/rules/`는 순수 함수만. 위반은 반려한다(README 경계)."""
    hit = _imported_modules(src) & FORBIDDEN_IN_RULES
    assert not hit, f"{src.name}이 {sorted(hit)}를 import한다"


def test_rules는_설정에도_의존하지_않는다():
    """임계값·경로는 인자로 받는다. `config`를 읽으면 테스트가 환경에 묶인다."""
    for src in RULES_SRC.glob("*.py"):
        assert "from ..config" not in src.read_text(encoding="utf-8")
        assert "from app.config" not in src.read_text(encoding="utf-8")


def test_음성_파일을_다루는_코드가_없다():
    """FR-041 — 음성 원본을 받지도 저장하지도 않는다."""
    banned = (".wav", ".mp3", ".m4a", "audio/", "soundfile", "librosa", "pydub")
    for src in (ROOT / "app").rglob("*.py"):
        text = src.read_text(encoding="utf-8").lower()
        for token in banned:
            assert token not in text, f"{src.name}에 '{token}'이 있다"


# ── 픽스처가 계약과 어긋나지 않는가 ───────────────────────────────


def _fx(name: str) -> dict:
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


def test_턴_픽스처에_음성_필드가_없다():
    """계약 §3-2 — 음성 원본은 필드 자체가 없다."""
    for name in ("turns.user.request.json", "turns.assistant.request.json"):
        keys = {k.lower() for k in _fx(name)}
        assert not (keys & {"audio", "audiourl", "voice", "wav", "recording"})


def test_assistant_턴은_valence가_비어_있다():
    """계약 §3-2 — assistant 턴은 valence·gap·tags가 전부 null/빈 배열."""
    t = _fx("turns.assistant.request.json")
    assert t["textValence"] is None
    assert t["voiceValence"] is None
    assert t["gap"] is None
    assert t["gapTriggered"] is False
    assert t["tags"] == []


def test_occurredAt은_밀리초_정밀도다():
    """계약 §3-2 v1.5 — 백엔드의 중복 판별이 이 정밀도에 걸려 있다."""
    for name in FIXTURES.glob("turns.*.json"):
        value = json.loads(name.read_text(encoding="utf-8"))["occurredAt"]
        assert value.endswith("Z") and "." in value
        assert len(value.split(".")[1]) == 4  # 'mmmZ'


def test_분석_실패_픽스처는_갭이_없고_트리거도_없다():
    """FR-024 — 분석이 죽어도 대화는 계속되고 턴은 적재된다."""
    t = _fx("turns.user.degraded.request.json")
    assert t["textValence"] is None and t["gap"] is None
    assert t["gapTriggered"] is False
    assert t["voiceValence"] is not None  # 음성 채널은 살아 있다


def test_topProsody_감정명이_매핑표에_있다():
    """오타 하나면 그 감정이 조용히 0으로 잡힌다."""
    known = known_emotions()
    for name in FIXTURES.glob("turns.*.json"):
        top = json.loads(name.read_text(encoding="utf-8")).get("topProsody")
        if top:
            assert set(top) <= known, f"{name.name}: {set(top) - known}"


def test_세션_픽스처에_전사가_없다():
    """계약 §3-4 — `transcript`류는 포함하지 않는다."""
    for name in FIXTURES.glob("sessions.*.json"):
        keys = {k.lower() for k in json.loads(name.read_text(encoding="utf-8"))}
        assert not any("transcript" in k for k in keys)


def test_이어하기_픽스처의_lastTurnIndex는_0이_아니다():
    """0이면 이 픽스처가 검사하려는 상황 자체가 아니다."""
    assert _fx("sessions.200.resumed.json")["lastTurnIndex"] > 0
