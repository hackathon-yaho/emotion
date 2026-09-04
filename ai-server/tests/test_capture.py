"""요청 캡처 — eval/README, ai-pipeline.md §11

첫 연결에서 Hume의 요청 모양을 남기지 못하면 무료 할당량을 한 번 더 써야 한다.
"""

import json

from app.capture import capture_shape, capture_snapshot, shape_of

BODY = {
    "messages": [
        {
            "role": "user",
            "content": "오늘 완전 괜찮았어요",
            "time": {"begin": 5000, "end": 7100},
            "models": {"prosody": {"scores": {"Tiredness": 0.71, "Joy": 0.06}}},
        }
    ],
    "stream": True,
}


def test_뼈대에_발화가_남지_않는다():
    """FR-092 — 그래서 이 캡처는 기본으로 켜 둘 수 있다."""
    blob = json.dumps(shape_of(BODY), ensure_ascii=False)
    assert "오늘 완전 괜찮았어요" not in blob


def test_뼈대에_점수_값이_남지_않는다():
    blob = json.dumps(shape_of(BODY), ensure_ascii=False)
    assert "0.71" not in blob and "0.06" not in blob


def test_뼈대는_키와_타입을_남긴다():
    """감정 이름은 dict 키라 그대로 보인다 — 발화가 아니라 스키마다."""
    s = shape_of(BODY)
    assert s["stream"] == "bool"
    first = s["messages"][0]
    assert first["role"].startswith("str(")
    assert first["models"]["prosody"]["scores"]["Tiredness"] == "float"


def test_문자열은_길이만_남는다():
    assert shape_of("가나다") == "str(3)"


def test_리스트는_첫_원소_모양과_개수만_남는다():
    assert shape_of([1, 2, 3]) == ["int", "…(3개)"]


def test_빈_리스트도_처리한다():
    assert shape_of([]) == []


def test_프로소디_점수까지_닿는다():
    """48종 점수는 6단계 아래에 있다. 여기가 잘리면 캡처의 의미가 없다."""
    s = shape_of(BODY)
    assert s["messages"][0]["models"]["prosody"]["scores"]["Tiredness"] == "float"


def test_깊이가_깊어도_멈춘다():
    deep: dict = {"leaf": 1}
    for i in range(20):
        deep = {f"k{i}": deep}
    assert "…" in json.dumps(shape_of(deep), ensure_ascii=False)


def test_같은_모양은_한_번만_저장한다(tmp_path):
    """파일이 쌓이면 오히려 안 보게 된다."""
    assert capture_shape(BODY, tmp_path) is not None
    assert capture_shape(BODY, tmp_path) is None
    assert len(list(tmp_path.glob("clm-request-*.json"))) == 1


def test_모양이_달라지면_새로_저장한다(tmp_path):
    capture_shape(BODY, tmp_path)
    changed = json.loads(json.dumps(BODY))
    changed["messages"][0]["models"]["prosody"]["새필드"] = 1
    assert capture_shape(changed, tmp_path) is not None
    assert len(list(tmp_path.glob("clm-request-*.json"))) == 2


def test_스냅샷은_전사와_점수만_담는다(tmp_path):
    """이력·시각·세션 ID를 담지 않는다 (eval/README)."""
    path = capture_snapshot("오늘 완전 괜찮았어요", {"Tiredness": 0.71}, tmp_path)
    saved = json.loads(path.read_text(encoding="utf-8"))
    assert set(saved) == {"transcript", "scores"}


def test_스냅샷은_프로소디가_없으면_만들지_않는다(tmp_path):
    """갭 재생에 쓸 수 없는 스냅샷은 파일만 늘린다."""
    assert capture_snapshot("안녕하세요", None, tmp_path) is None
    assert capture_snapshot("", {"Joy": 1.0}, tmp_path) is None
