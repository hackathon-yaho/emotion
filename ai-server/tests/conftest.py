"""테스트 공용 준비.

`app/main.py`의 세션 캐시와 분석 캐시는 **프로세스 수명 동안 유지되는 것이 정상**이다
(같은 세션의 다음 턴이 그걸 쓴다). 그래서 테스트마다 비워 주지 않으면 앞 테스트가
남긴 턴 번호·분석 결과가 다음 테스트로 새어 순서에 따라 결과가 달라진다.
"""

import pytest


@pytest.fixture(autouse=True)
def _reset_app_state():
    from app import main

    main._sessions._cache.clear()
    main._analyze_cache.clear()
    yield
    main._sessions._cache.clear()
    main._analyze_cache.clear()
