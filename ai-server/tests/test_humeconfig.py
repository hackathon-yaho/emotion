"""Hume Config — 만드는 것과 검사하는 것이 어긋나지 않는지.

**계정이 잠겨 Config를 새로 만들어야 했던 데서 나온 테스트다**(2026-09-07).
손으로 콘솔에서 열한 항목을 클릭하면 하나쯤 빠지고, 빠진 것은 조용히 다른
동작이 된다 — 실제로 `turn_detection`이 설정된 적 없이 기본값(800ms)으로
남아 있었고, 그것이 대화가 잘게 끊기던 원인이었다.

그래서 **생성 본문과 검사 항목을 같은 상수에 묶었다.** 이 테스트가 그 매듭이다.
"""

from app import humeconfig as H

CLM = "https://example.run.app/chat/completions"


def test_우리가_만든_설정은_우리_검사를_통과한다():
    """생성과 검사가 갈라지면 여기서 깨진다 — 그러라고 있는 테스트다."""
    failed = [
        (label, detail)
        for ok, label, detail in H.check(H.build_payload(CLM), CLM)
        if not ok
    ]
    assert failed == []


def test_한국어가_되는_버전과_음성이다():
    """EVI 3은 영어 전용이다. 이 둘은 짝이라 따로 못 바꾼다."""
    payload = H.build_payload(CLM)
    assert payload["evi_version"] == "4-mini"
    assert payload["voice"]["name"] == "Jin-Hee"


def test_CLM이_비면_Hume이_자기_모델로_답한다():
    payload = H.build_payload(CLM)
    assert payload["language_model"]["model_provider"] == "CUSTOM_LANGUAGE_MODEL"
    assert payload["language_model"]["model_resource"] == CLM


def test_턴_종료와_끼어들기가_기본값보다_길다():
    """Hume 기본은 둘 다 800ms다. 감정 대화에서는 짧다."""
    payload = H.build_payload(CLM)
    assert payload["turn_detection"]["end_of_turn_silence_ms"] > 800
    assert payload["interruption"]["min_interruption_ms"] > 800


def test_비활성_타임아웃이_하드컷보다_짧지_않다():
    """짧으면 침묵만으로 대화가 끊긴다 — 하드컷은 420초다."""
    secs = H.build_payload(CLM)["timeouts"]["inactivity"]["duration_secs"]
    assert secs >= 420


def test_검사는_기본값_Config를_잡아낸다():
    """turn_detection 이 없는 Config(= 콘솔 기본값)는 통과하면 안 된다."""
    payload = H.build_payload(CLM)
    payload["turn_detection"] = None
    payload["interruption"] = None
    labels = [label for ok, label, _ in H.check(payload, CLM) if not ok]
    assert "발화 종료 대기" in labels
    assert "끼어들기 최소" in labels
