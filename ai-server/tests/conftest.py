"""테스트 공용 준비.

**테스트는 실제 LLM을 부르지 않는다.** `.env`에 진짜 키가 들어오자 종단 테스트가
Gemini를 실제로 호출해 버렸고, 그 결과 "LLM이 죽었을 때"를 검증하려던 테스트가
살아 있는 응답을 받아 실패했다. 느리고, 무료 티어 할당량을 먹고, 결과가 흔들린다.

그래서 **conftest가 import되는 시점에** 환경변수를 덮어쓴다. `app.config`는
`.env`보다 환경변수를 우선하므로, 테스트 모듈이 앱을 import하기 전에 여기서 막으면 된다.
"""

import os

# 포트 9는 discard 서비스 자리라 아무도 듣지 않는다. LLM 호출이 즉시 실패한다.
os.environ["AI_LLM_BASE_URL"] = "http://127.0.0.1:9/v1/"
os.environ["GOOGLE_API_KEY"] = ""
os.environ["AI_WARMUP_ON_START"] = "false"
os.environ["AI_ANALYZE_TIMEOUT_MS"] = "400"
os.environ.setdefault("AI_CAPTURE_DIR", os.path.join(os.environ.get("TEMP", "/tmp"), "ai-capture-test"))

import pytest  # noqa: E402


@pytest.fixture(autouse=True)
def _reset_app_state():
    """`app/main.py`의 세션 캐시와 분석 캐시는 프로세스 수명 동안 유지되는 것이 정상이다
    (같은 세션의 다음 턴이 그걸 쓴다). 테스트마다 비우지 않으면 앞 테스트가 남긴
    턴 번호·분석 결과가 다음 테스트로 새어 순서에 따라 결과가 달라진다."""
    from app import main

    main._sessions._cache.clear()
    main._analyze_cache.clear()
    yield
    main._sessions._cache.clear()
    main._analyze_cache.clear()
