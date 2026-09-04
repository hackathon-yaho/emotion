"""음성 valence — ai-pipeline.md §3, rules/valence_mapping.json"""

import pytest

from app.rules import valence
from app.rules.loader import valence_mapping


def test_매핑표가_48종이고_극성이_겹치지_않는다():
    m = valence_mapping()
    pos, neg, neu = set(m["positive"]), set(m["negative"]), set(m["neutral"])
    assert len(pos) + len(neg) + len(neu) == 48
    assert not (pos & neg) and not (pos & neu) and not (neg & neu)


def test_Tiredness는_부정이다():
    """데모 1번 장면의 전제. 뒤집히면 지친 톤에서 갭이 벌어지지 않는다."""
    assert "Tiredness" in valence_mapping()["negative"]


def test_긍정만_있으면_1에_가깝다():
    assert valence.voice_valence({"Joy": 0.8, "Excitement": 0.2}) == 1.0


def test_부정만_있으면_음수다():
    assert valence.voice_valence({"Tiredness": 0.7, "Sadness": 0.3}) == -1.0


def test_지친_톤은_음수를_준다():
    """S02 데모: '오늘 완전 괜찮았어요'를 지친 목소리로."""
    v = valence.voice_valence({"Tiredness": 0.71, "Sadness": 0.42, "Joy": 0.06})
    assert v is not None and v < -0.5


@pytest.mark.parametrize("scores", [None, {}, {"Concentration": 0.9}])
def test_측정할_수_없으면_None이다(scores):
    """0으로 대체하지 않는다 — 0은 '중립이었다'는 주장이고 그건 알 수 없다."""
    assert valence.voice_valence(scores) is None


def test_중립만_찍히면_질량_부족으로_None이다():
    """Concentration은 중립이라 P에도 N에도 들어가지 않는다."""
    assert valence.voice_valence({"Concentration": 0.99, "Contemplation": 0.4}) is None


def test_질량이_기준을_아슬아슬하게_넘으면_값이_나온다():
    assert valence.voice_valence({"Joy": 0.03, "Sadness": 0.03}) == 0.0
    assert valence.voice_valence({"Joy": 0.02, "Sadness": 0.02}) is None


def test_매핑표에_없는_감정은_계산에서_빠지고_보고된다():
    scores = {"Joy": 0.5, "Nonexistent Emotion": 0.9}
    assert valence.voice_valence(scores) == 1.0
    assert valence.unknown_emotions(scores) == {"Nonexistent Emotion"}


def test_top_prosody는_상위_5개를_점수순으로_자른다():
    scores = {f"E{i}": i / 10 for i in range(8)}
    top = valence.top_prosody(scores)
    assert list(top) == ["E7", "E6", "E5", "E4", "E3"]


def test_범위를_벗어나지_않는다():
    for s in ({"Joy": 1.0}, {"Sadness": 1.0}, {"Joy": 0.5, "Sadness": 0.5}):
        v = valence.voice_valence(s)
        assert -1.0 <= v <= 1.0
