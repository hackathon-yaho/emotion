"""`.env` 확인 도구 — 시크릿이 화면에 통째로 찍히면 안 된다."""

from app.envcheck import mask


def test_시크릿을_통째로_보여주지_않는다():
    """터미널 기록·화면 공유·스크린샷으로 새는 경로를 만들지 않는다."""
    secret = "sk-ant-api03-VERYLONGSECRETVALUE-abcdefghijklmnop"
    out = mask(secret)
    assert secret not in out
    assert out.startswith("sk-a")


def test_길이는_알려준다():
    """길이는 붙여넣기가 잘렸는지 보는 데 쓰인다."""
    assert "48자" in mask("x" * 48)


def test_짧은_값은_앞글자도_안_보여준다():
    """짧으면 앞 4글자만으로도 상당 부분이 드러난다."""
    out = mask("abc12345")
    assert "abc" not in out
    assert "설정됨" in out


def test_비어_있으면_비어_있다고_한다():
    assert mask("") == "(비어 있음)"


def test_출력이_cp949로_인코딩된다():
    """Windows 기본 콘솔이 cp949다. 여기서 죽으면 도구 자체가 못 돈다."""
    for value in ("", "abc12345", "sk-ant-" + "x" * 40):
        mask(value).encode("cp949")
