# app — 모바일 앱 (웹·iOS·Android)

담당: **앱**. **Flutter — 웹과 모바일 앱을 모두 지원하고, 배포는 웹으로 합니다** (2026-09-03 확정, 근거는 PRD §14-4).

- 웹·iOS·Android 빌드가 하나의 코드베이스에서 나옵니다. **둘 사이에 우선순위를 두지 않고 셋 다 도는 상태를 유지합니다.**
- **배포·도그푸딩·심사 시연·제출은 전부 같은 웹 URL**로 합니다. 화면은 웹·앱 모두 모바일 폭 기준으로 만듭니다.
- EVI SDK 연동, 대화 UI(S02), 발견·트렌드·기록 화면, 설정 — 화면 정의는 [`../docs/00-context/spec.md`](../docs/00-context/spec.md) §4
- 호출하는 API는 [`../docs/02-architecture/api-contract.md`](../docs/02-architecture/api-contract.md) §2 · 화면↔엔드포인트 매핑은 §5

## 지켜야 하는 것

- **S02 대화 화면에 valence·갭 수치를 그리지 않는다.** `demoMode == true`일 때만 예외 (FR-031, F11-01)
- **Hume API 키를 앱에 내장하지 않는다.** 백엔드가 발급하는 단기 토큰만 쓴다 (FR-013). **웹은 번들이 전부 공개되므로 더 엄격하다**
- `softWrapSec`·`hardCutSec`을 상수로 박지 않는다. 서버 응답값을 쓴다 (계약서 §2-4)
- 음성 파일을 쓰지 않는다 — `.wav`·`.mp3` 저장이나 오디오 업로드 코드가 어디에도 없어야 한다 (FR-041, TC-11)
- 트렌드 그래프에서 **없는 날을 보간하지 않는다.** `points`에 없는 날은 선을 끊는다 (계약서 §1-3, F9-01)
- 관찰이 0건이면 안내 문구만 띄운다. 가짜 관찰을 만들지 않는다 (FR-052)

## 기술 선택

| 항목 | 선택 | 비고 |
| --- | --- | --- |
| 프레임워크 | Flutter (stable 3.47.1에서 검증) | 지원 타깃 **웹 · iOS · Android** (우선순위 없음). 기능을 넣을 때마다 세 빌드가 도는지 확인 |
| 상태·서버 캐시 | Riverpod + Dio | 계약서 §2-11이 세션 삭제 후 **관찰 목록 캐시 무효화**를 요구하고, 여기에 대화 중 폴링이 더해진다 |
| 차트 | `fl_chart` 우선 검증, 미달 시 `CustomPainter` | 검증 조건 5개 — ① 두 선 ② 축 −1~+1 고정 ③ **없는 날 선 끊김** ④ 구간 음영 ⑤ **음영 탭 → S05-1 이동** |
| 토큰 저장 | `flutter_secure_storage` | JWT 만료 7일. **대화 중 401은 대화를 끊지 않고** 다음 요청부터 갱신 (F1-02) |
| 오디오 | iOS는 네이티브 플러그인, 웹·Android는 `record` + `audioplayers` (`kIsWeb` 분기) | PCM16 48kHz 모노, `echoCancel`·`noiseSuppress`·`autoGain`. iOS는 `Info.plist` 마이크 사용 설명 필요 |
| 배포 | **웹 — 정적 호스팅 (Vercel 등)** | 도그푸딩·시연·제출이 전부 같은 URL. **마이크 때문에 HTTPS 필수.** 도메인은 제품 이름 확정 후 (PRD §14-6) |

## EVI 연결 메모 (공식 예제 실측, 2026-09-03)

```
wss://api.hume.ai/v0/evi/chat?access_token={백엔드 발급}&config_id={미정}&custom_session_id={sessionId}
```

- `access_token` — 계약서 §2-4의 `humeAccessToken`. 공식 예제도 자기 서버에서 받아오는 경로를 갖고 있다
- `config_id` — **계약에 아직 없다.** `docs/request/backend/hume-config-id.md`로 요청 중(⏳). 회신 전까지 로컬 `.env`로 개발하고 **저장소에 상수로 커밋하지 않는다**
- `custom_session_id` — 예제에 없어 우리가 추가한다 (spec F2-02, CLM 계약 §4)
- 연결 성공 시 `chat_metadata`로 `chat_group_id`가 내려온다 → F2-07 이어하기의 `resumedChatGroupId` 원천
- **공식 예제의 오류 처리는 그대로 쓰지 않는다.** 인증 실패·마이크 거부에서 처리되지 않은 예외를 던져 F2-04 수용 기준("어떤 경우에도 앱이 멈추지 않는다")을 못 지킨다

## 실행

```bash
flutter run -d chrome
```

웹 빌드는 `flutter build web --release` — **배포 채널이라 항상 도는 상태로 유지한다.** 초기 로드 실측은 `main.dart.js` 2.0MB + CanvasKit 5.2MB ≈ 7MB로, 제출 링크의 첫인상에 영향이 있어 축소를 검토 항목으로 둔다.

---

이 폴더에 대한 요청은 `../docs/request/app/`, 앱이 보낸 요청의 회신은 `../docs/response/app/`.
