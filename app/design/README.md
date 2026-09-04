# app/design — 화면 디자인

> **이 시안들은 2026-09-04의 결정 24(하단 탭 = 떠 있는 반투명 알약 칩 + 아이콘) 이전입니다.** 아트보드의 탭은 아이콘 없는 활자 + 밑줄로 그려져 있습니다. **지금 화면의 기준은 배포된 앱**입니다 — https://hackathon-yaho.github.io/emotion/ 를 열어 보세요. 시안은 나머지 화면의 타이포·간격 기준으로 계속 유효합니다.

시각 규약의 단일 출처는 [`../../docs/01-product/design-system.md`](../../docs/01-product/design-system.md)이고, 이 폴더는 그것을 실제 화면으로 그린 것입니다.

## 먼저 — 무엇을 보면 되는가

| 목적 | 파일 |
| --- | --- |
| **화면을 눈으로 본다** (팀원 포함 누구나) | **[`export/`](export/)의 PNG·PDF** |
| 구현하려고 정확한 값을 읽는다 | 이 폴더의 `*.dc.html` 소스 |
| 배치·페이지·주석을 본다 | `canvas.json` |

**`*.dc.html`은 브라우저에서 직접 열리지 않습니다.** 캔버스 런타임(`support.js`·템플릿 엔진·`DCLogic`)이 퍼블리시 시점에 주입되는 구조라, 더블클릭하면 빈 화면이 뜹니다. Flutter의 `lib/*.dart`와 `build/web/`의 관계와 같습니다 — 여기 있는 건 소스입니다.

그래서 **팀 공유는 `export/`의 이미지로 합니다.** 퍼블리시된 캔버스는 기본이 비공개이고, 내보내기 권한이 선언된 캔버스는 공유해도 조직 내부로 제한되므로 링크가 모든 팀원에게 열리지 않습니다.

| 파일 | 화면 |
| --- | --- |
| `Main.dc.html` | S01 홈 · S02 대화 · S02-1 요약 · S03 발견 · S04 추세 · S05 기록 — **탭·CTA가 동작하는 흐름** |
| `Onboarding.dc.html` | S00 진입 · 로그인 |
| `Conversation.dc.html` | S02 대화 — **상태 9종** (연결 중 / 이어하기 / 듣는 중 / 말하는 중 / 조용 / 마무리 임박 / 마이크 거부 / 네트워크 끊김 / 연결 불가) |
| `Crisis.dc.html` | S07 위기 안내 |
| `Evidence.dc.html` | S03-1 관찰 근거 |
| `SessionDetail.dc.html` | S05-1 대화 상세 |
| `Settings.dc.html` | S06 설정 |
| `TrendWide.dc.html` | S04 추세 — 넓은 화면 (900×880), 7·30·90일 + 이야기별 갭 |
| `canvas.json` | 캔버스 배치·주석 (페이지 2개 · 아트보드 8개 · 주석 8개) |
| `export/` | **팀 공유용 PNG·PDF** |

## 고치고 다시 내보내기 (앱 담당)

퍼블리시된 캔버스 파일(`voice-journal-screens.html`, 2.5MB)은 **생성물이라 저장소에 두지 않습니다.** 소스를 고친 뒤 다시 만들고, **`export/`의 이미지도 같은 작업 안에서 다시 뽑습니다** — 이미지가 낡으면 팀원이 없는 화면을 보고 논의하게 됩니다.

아래 명령은 Claude Code의 `/design` 스킬 경로를 요구하므로 **앱 담당만 실행합니다.** 다른 역할은 `export/`를 보면 됩니다.

```bash
node "<design 스킬 경로>/seed-canvas.mjs" --template "<design 스킬 경로>/payload.template.html" \
  --out voice-journal-screens.html --title "감정 케어 보이스 저널 화면" \
  --artboard Main.dc.html --artboard Onboarding.dc.html --artboard Conversation.dc.html \
  --artboard Crisis.dc.html --artboard Evidence.dc.html --artboard SessionDetail.dc.html \
  --artboard Settings.dc.html --artboard TrendWide.dc.html --canvas canvas.json
```

Claude Code에서 `/design`을 실행하면 스킬 경로가 나옵니다. 만든 뒤 같은 URL로 다시 퍼블리시하면 링크가 유지됩니다.

그다음 캔버스 툴바의 **Export**로 PNG·PDF를 뽑아 [`export/`](export/)에 넣습니다 — 파일 이름 규칙은 그 폴더의 README에 있습니다.

## 구현으로 옮길 때 지킬 것

- **S02에 valence·갭 수치를 그리지 않는다.** `demoMode == true`일 때만 예외 (FR-031)
- **감정에 반응하는 색을 쓰지 않는다.** 두 링은 색이 고정이고 간격·크기·투명도만 상태에 반응한다 — 색이 변하면 사실상 갭 노출이다 (FR-030)
- **차가운 색 = 말한 내용, 따뜻한 색 = 목소리.** 제품 전체에서 같은 의미로만 쓴다
- 그래프에서 **기록이 없는 날은 선을 끊는다.** 보간하지 않는다 (계약서 §1-3)
- 갭 음영은 **임계값을 넘은 날을 데이터에서 찾아** 칠하고, 경계는 점 중심이 아니라 반 보폭 밖에 둔다
- `care` 색은 **S07 전용**
