# app/design — 화면 디자인 캔버스

화면 8개의 **작업 파일**입니다. 시각 규약의 단일 출처는 [`../../docs/01-product/design-system.md`](../../docs/01-product/design-system.md)이고, 이 폴더는 그것을 실제 화면으로 그린 것입니다.

| 파일 | 화면 |
| --- | --- |
| `Main.dc.html` | S01 홈 · S02 대화 · S02-1 요약 · S03 발견 · S04 추세 · S05 기록 — **탭·CTA가 동작하는 흐름** |
| `Onboarding.dc.html` | S00 진입 · 로그인 |
| `Conversation.dc.html` | S02 대화 — 상태 6종 (연결 중 / 듣는 중 / 말하는 중 / 조용 / 마무리 임박 / 마이크 거부) |
| `Crisis.dc.html` | S07 위기 안내 |
| `Evidence.dc.html` | S03-1 관찰 근거 |
| `SessionDetail.dc.html` | S05-1 대화 상세 |
| `Settings.dc.html` | S06 설정 |
| `TrendWide.dc.html` | S04 추세 — 넓은 화면 (900×620) |
| `canvas.json` | 캔버스 배치·주석 |

## 다시 만들기

퍼블리시된 캔버스 파일(`voice-journal-screens.html`, 2.4MB)은 **생성물이라 저장소에 두지 않습니다.** 작업 파일을 고친 뒤 다시 만듭니다.

```bash
node "<design 스킬 경로>/seed-canvas.mjs" --template "<design 스킬 경로>/payload.template.html" \
  --out voice-journal-screens.html --title "감정 케어 보이스 저널 화면" \
  --artboard Main.dc.html --artboard Onboarding.dc.html --artboard Conversation.dc.html \
  --artboard Crisis.dc.html --artboard Evidence.dc.html --artboard SessionDetail.dc.html \
  --artboard Settings.dc.html --artboard TrendWide.dc.html --canvas canvas.json
```

Claude Code에서 `/design`을 실행하면 스킬 경로가 나옵니다. 만든 뒤 같은 URL로 다시 퍼블리시하면 링크가 유지됩니다.

## 구현으로 옮길 때 지킬 것

- **S02에 valence·갭 수치를 그리지 않는다.** `demoMode == true`일 때만 예외 (FR-031)
- **감정에 반응하는 색을 쓰지 않는다.** 두 링은 색이 고정이고 간격·크기·투명도만 상태에 반응한다 — 색이 변하면 사실상 갭 노출이다 (FR-030)
- **차가운 색 = 말한 내용, 따뜻한 색 = 목소리.** 제품 전체에서 같은 의미로만 쓴다
- 그래프에서 **기록이 없는 날은 선을 끊는다.** 보간하지 않는다 (계약서 §1-3)
- 갭 음영은 **임계값을 넘은 날을 데이터에서 찾아** 칠하고, 경계는 점 중심이 아니라 반 보폭 밖에 둔다
- `care` 색은 **S07 전용**
