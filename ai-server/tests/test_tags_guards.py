"""태그 대조와 사후 검사 — ai-pipeline.md §6·§8"""

import pytest

from app.rules import guard, observe_guard, summary_guard, tags


# ── 태그 원문 대조 (F6-02) ────────────────────────────────────────


def test_원문에_있는_태그만_남는다():
    kept, _ = tags.filter_tags(["회의"], "오늘 회의가 세 개나 있었어요")
    assert kept == ["회의"]


def test_동의어를_병합하지_않는다():
    """'미팅'이라고 말한 턴에 '회의'를 달면 안 된다 — ai-pipeline §6.2."""
    kept, _ = tags.filter_tags(["회의"], "오늘 미팅이 세 개나 있었어요")
    assert kept == []


def test_활용형은_통과한다():
    """'회의'는 '회의가'에 포함된다."""
    assert tags.verify_in_transcript("회의", "회의가 길었어요") is True


def test_불용어는_버린다():
    kept, dropped = tags.filter_tags(["오늘", "기분", "회의"], "오늘 기분이 회의 때문에")
    assert kept == ["회의"]
    assert dropped.count("stopword") == 2


def test_어간_불용어는_활용형까지_막는다():
    """'괜찮'이 불용어라 '괜찮았어'도 태그가 되지 않는다."""
    kept, _ = tags.filter_tags(["괜찮았어"], "오늘 완전 괜찮았어요")
    assert kept == []


def test_한_글자는_버린다():
    kept, dropped = tags.filter_tags(["일"], "일이 많았어요")
    assert kept == [] and "too_short" in dropped


def test_최대_3개까지만_남긴다():
    t = "회의 야근 보고서 발표 출장 회식"
    kept, _ = tags.filter_tags(["회의", "야근", "보고서", "발표", "출장"], t)
    assert len(kept) == 3


def test_중복은_한_번만():
    kept, dropped = tags.filter_tags(["회의", "회의"], "회의가 길었어요")
    assert kept == ["회의"] and "duplicate" in dropped


def test_폐기_사유에_태그_문자열이_들어가지_않는다():
    """FR-092 — 폐기된 태그가 로그로 새면 발화 내용이 샌다."""
    _, dropped = tags.filter_tags(["회식", "미팅"], "오늘은 조용했어요")
    assert all(d in {"too_short", "stopword", "duplicate", "not_in_transcript"} for d in dropped)
    assert "회식" not in dropped and "미팅" not in dropped


def test_후보가_없으면_빈_결과다():
    assert tags.filter_tags(None, "아무 말") == ([], [])


# ── 금칙어 (PRD §9.3) ─────────────────────────────────────────────


@pytest.mark.parametrize(
    "sentence,category",
    [
        ("우울증인 것 같아요", "diagnosis"),
        ("공황장애가 의심됩니다", "diagnosis"),
        ("항우울제를 드셔보세요", "medication"),
        ("수면제 처방받아 보세요", "medication"),
        ("인지행동치료를 받아보세요", "treatment"),
    ],
)
def test_진단_처방_치료_권유는_걸린다(sentence, category):
    assert category in guard.find_violations(sentence)


def test_109_안내는_걸리지_않는다():
    """막히면 F4-03 위기 대응이 동작하지 않는다."""
    s = "혼자 견디지 않으셔도 됩니다. 자살예방 상담전화 109로 지금 이야기하실 수 있어요."
    assert guard.is_clean(s)


def test_평범한_되묻기는_걸리지_않는다():
    assert guard.is_clean("괜찮다고 하시는데 목소리는 좀 다르네요. 무슨 일 있으셨어요?")


def test_위반은_카테고리만_돌려준다():
    """매칭된 표현을 돌려주면 호출부가 로그에 남길 수 있다(FR-092)."""
    hits = guard.find_violations("우울증 같아요")
    assert hits == ["diagnosis"]


# ── 관찰 문장 사후 검사 (§8.1) ────────────────────────────────────


def test_관찰_문장_정상():
    assert observe_guard.accepts("회의 얘기를 하실 때만 목소리가 유독 무거워지시네요.", "회의")


def test_관찰_문장에_숫자가_있으면_폐기():
    r = observe_guard.check("회의 얘기를 7번 하셨네요.", "회의")
    assert "has_digit" in r


def test_관찰_문장에_태그가_없으면_폐기():
    r = observe_guard.check("업무 얘기를 하실 때 목소리가 무거워지시네요.", "회의")
    assert "tag_missing" in r


def test_관찰_문장이_두_문장이면_폐기():
    r = observe_guard.check("회의 얘기를 하시네요. 목소리가 무겁습니다.", "회의")
    assert "multi_sentence" in r


def test_관찰_문장은_질문이_아니다():
    r = observe_guard.check("회의 얘기를 하실 때 힘드신가요?", "회의")
    assert "question" in r


def test_관찰_문장의_금칙어는_카테고리로_보고된다():
    r = observe_guard.check("회의 때문에 우울증이 온 것 같네요.", "회의")
    assert "forbidden:diagnosis" in r


# ── 요약 사후 검사 (§8.3) ─────────────────────────────────────────


def test_요약_정상():
    assert summary_guard.accepts("회의가 많았던 하루에 대해 이야기했습니다.")


@pytest.mark.parametrize(
    "s", ["힘든 하루였네요.", "괜찮은 하루를 보내셨습니다.", "많이 지치셨던 것 같습니다."]
)
def test_감정을_단정하면_폐기(s):
    assert "emotion_assertion" in summary_guard.check(s)


def test_갭을_흘리면_폐기():
    """S02가 숨기는 것을 요약이 흘리면 FR-031이 무의미해진다."""
    assert "emotion_assertion" in summary_guard.check("말과 달리 지쳐 보이는 대화였습니다.")


def test_요약에_숫자가_있으면_폐기():
    assert "has_digit" in summary_guard.check("회의 3개에 대해 이야기했습니다.")


def test_요약이_비면_폐기():
    assert summary_guard.check("   ") == ["empty"]
