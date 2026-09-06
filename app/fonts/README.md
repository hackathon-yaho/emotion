# fonts/

**Pretendard** — 산세리프 본문 서체 (design-system §3). SIL Open Font License 1.1,
전문은 [`Pretendard-LICENSE.txt`](Pretendard-LICENSE.txt).

- 출처: [orioncactus/pretendard](https://github.com/orioncactus/pretendard) v1.3.9 `public/static/Pretendard-Regular.otf`
- **원본 1.57MB → 1.27MB로 서브셋했습니다.** 쓰지 않는 문자와 힌팅을 뺐습니다

```sh
python3 -m fontTools.subset Pretendard-Regular.otf \
  --output-file=Pretendard-Regular.otf \
  --unicodes="U+0020-007E,U+00A0-00FF,U+2000-206F,U+20A9,U+2190-2193,U+3000-303F,U+3130-318F,U+AC00-D7A3,U+FF01-FF60" \
  --layout-features="kern,liga,calt" --no-hinting
```

**한글 음절 전체(U+AC00–D7A3)를 남깁니다.** 상용 2,350자로 줄이면 400KB까지
내려가지만, 화면에 뜨는 글의 상당수가 **사용자가 말한 문장**이라 흔치 않은
음절 하나에 두부(□)가 보입니다. 그건 서체를 바꾸는 목적과 정반대입니다.

**웹 폰트 CSS(`@font-face`)로는 안 됩니다.** CanvasKit이 글자를 직접 그리므로
브라우저 CSS 서체가 적용되지 않습니다 — 에셋으로 넣고 `pubspec.yaml`에
등록해야 합니다.

**굵기는 Regular 하나만 넣습니다.** 앱에서 `w500`을 쓰는 곳이 두 군데뿐이라
1.27MB를 한 벌 더 실을 값이 없습니다. Flutter가 가장 가까운 굵기를 씁니다.
