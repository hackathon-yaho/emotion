# app/design/export — 팀원이 보는 디자인

**여기가 팀 공유용입니다.** 소스(`../*.dc.html`)는 캔버스 런타임 안에서만 렌더되므로 팀원이 직접 열 수 없습니다. 그래서 화면을 이미지로 뽑아 저장소에 넣습니다 — 계정·조직·도구와 무관하게 GitHub에서 바로 보입니다.

## 파일 이름 규칙

화면 ID를 앞에 둡니다. spec §4의 ID와 1:1로 맞춰야 문서에서 찾아갈 수 있습니다.

```
S00-onboarding.png          진입 · 로그인
S01-home.png                오늘 (홈)
S02-conversation.png        대화 — 기본 상태
S02-states.png              대화 — 상태 9종
S02-1-summary.png           대화 종료 요약
S03-discover.png            발견
S03-1-evidence.png          관찰 근거
S04-trend.png               추세 (모바일)
S04-trend-wide.png          추세 — 넓은 화면
S05-records.png             기록
S05-1-detail.png            대화 상세
S06-settings.png            설정
S07-crisis.png              위기 안내
all-screens.pdf             전체 (한 파일)
```

상태를 따로 보여줄 것이 있으면 뒤에 붙입니다 — `S01-home-empty.png`(빈 상태), `S02-conversation-demo.png`(데모 모드) 처럼.

## 화면

| 화면 | 이미지 |
| --- | --- |
| S00 진입 · 로그인 | [S00-onboarding.png](S00-onboarding.png) |
| S01 오늘 (홈) | [S01-home.png](S01-home.png) |
| S02 대화 — 상태 9종 | [S02-states.png](S02-states.png) |
| S03-1 관찰 근거 | [S03-1-evidence.png](S03-1-evidence.png) |
| S04 추세 — 넓은 화면 | [S04-trend-wide.png](S04-trend-wide.png) |
| S05-1 대화 상세 | [S05-1-detail.png](S05-1-detail.png) |
| S06 설정 | [S06-settings.png](S06-settings.png) |
| S07 위기 안내 | [S07-crisis.png](S07-crisis.png) |

`Main.dc.html`은 탭 4개(오늘·발견·추세·기록)와 대화·요약이 한 아트보드에 들어 있어서, PNG로는 **처음 열리는 오늘 탭**만 담깁니다. 나머지 탭과 상태(빈 상태·로딩·이어하기)는 캔버스에서 눌러 봐야 합니다.

## 뽑는 방법

**앱 담당이 헤드리스 Chrome으로 자동 생성합니다.** 아트보드마다 포커스 캔버스를 시드해서 실제 렌더가 끝난 뒤 캡처하므로, 캔버스 툴바의 Export를 손으로 누를 필요가 없습니다.

캔버스 툴바의 **Export**(오른쪽 위)로 직접 뽑을 수도 있습니다 — PNG는 아트보드별, PDF는 그 페이지 전체입니다. 다만 브라우저 저장 대화상자를 거쳐야 하고, 샌드박스라 저장이 막히면 드래그로 꺼내야 합니다.

## 언제 다시 뽑는가

**디자인이 바뀌면 같은 작업 안에서 다시 뽑아 커밋합니다.** 이미지가 낡으면 팀원이 없는 화면을 보고 논의하게 됩니다 — 문서가 낡는 것보다 나쁩니다.

소스만 고치고 이미지를 안 바꾸면 `git log`로는 구분이 안 되니, 커밋 메시지에 `design: … (export 갱신)`처럼 남깁니다.
