# 배포본이 샘플 모드로 굳어 있어 실제 대화를 걸 수 없습니다

> **상태: ⏳ 회신 대기** (요청 2026-09-07)
> 회신은 `../../response/ai/sample-mode-blocks-live-test.md`에 들어옵니다.
> **막고 있는 작업**: **TC-02(실제 3분 대화)와 종단 검증 전체.** AI서버·백엔드·Hume Config가 전부 준비됐는데, **대화를 시작할 화면이 없습니다.**

- 요청자: AI
- 대상: 앱
- 관련 문서: `app/lib/core/providers.dart` · `app/lib/core/config/env.dart` · `../../00-context/spec.md` F2-02

---

## 상황 — 나머지가 전부 준비됐습니다

| 구간 | 상태 |
| --- | --- |
| AI서버 배포 | ✅ `https://emotion-ai-server-gq7yhdrrlq-du.a.run.app` |
| AI서버 → 백엔드 인증 | ✅ 통과 (`session_not_found` = 404를 받았다는 뜻) |
| 배포본에서 Gemini 호출 | ✅ 두 모델 워밍업 성공 |
| Hume Config | ✅ EVI 4-mini · CLM 등록 · 한국어 음성 · 비활성 420초 |
| 킵얼라이브 | ✅ 두 서버 10분 주기 |
| **실제 대화** | ⛔ **여기서 막힙니다** |

## 무엇이 막는가

배포본이 `SAMPLE_DATA=true`로 빌드돼 있고, `providers.dart`의 판정이 이렇습니다.

```dart
final fromUrl = Uri.base.queryParameters['sample'] == '1';
return Env.sampleData || fromUrl ? DataMode.sample : DataMode.live;
```

**`Env.sampleData`가 참이면 URL로 끌 방법이 없습니다.** `?sample=1`은 켜는 쪽으로만 동작하고, 끄는 쪽 스위치가 없습니다. 그래서 지금 배포된 링크로는 **어떤 주소를 붙여도 실제 세션이 열리지 않습니다.**

샘플 모드를 켜 두신 판단 자체는 맞습니다 — 배포 링크가 팀 밖에서도 열리고, EVI는 분당 과금이니까요. **다만 지금은 그것 때문에 한 번도 실제로 못 돌려보는 상태입니다.**

## 부탁드리는 것 — 둘 중 하나

**① `?sample=0`으로 끌 수 있게** (권장)

```dart
final q = Uri.base.queryParameters['sample'];
final fromUrl = q == '1';
final offFromUrl = q == '0';
return offFromUrl ? DataMode.live : (Env.sampleData || fromUrl ? DataMode.sample : DataMode.live);
```

**기본은 지금처럼 샘플로 두고**, 아는 사람만 `?sample=0`으로 실제 모드에 들어갑니다. 재빌드 없이 시연과 실측을 오갈 수 있어서, 원래 `?sample=1`을 만드신 이유와 같은 이유로 쓸모가 있습니다.

**② `SAMPLE_DATA=false`로 다시 빌드**

단순합니다. 대신 배포 링크를 여는 모든 사람이 실제 세션을 열 수 있게 되고, **그건 곧 Hume 분수입니다.** 무료 티어가 월 5분이라 링크가 새면 그날로 소진됩니다. ①을 권하는 이유입니다.

## 왜 지금 급한가

**Hume 무료 티어가 월 5분입니다.** 그 5분으로 확인해야 하는 것이 이것들입니다.

- Hume이 실제로 우리 CLM을 부르는가
- 한국어 전사가 쓸 만한가
- 되묻기가 같은 턴에 나오는가 (F4-01)
- 응답이 몇 초 만에 나오는가 (NFR-01)

**저는 문서만 보고 파서를 짰습니다.** Hume이 실제로 보내는 요청 모양을 한 번도 본 적이 없습니다. 그 5분이 그걸 확인할 유일한 기회이고, **지금은 화면이 없어서 못 쓰고 있습니다.**

## 그 사이에 AI 쪽에서 해둔 것

**요청이 오면 그 모양이 자동으로 로그에 남습니다.** 인증보다 먼저 남기므로, 설정이 어긋나 401이 나더라도 **모양은 건집니다.** 발화도 점수 값도 담기지 않고 키 이름과 타입만 남습니다(FR-092).

로그는 누구나 이 명령으로 볼 수 있습니다.

```powershell
cd ai-server
.\.venv\Scripts\python.exe -m app.logs        # 최근 30분
```

대화가 끝나면 제가 이걸 읽고 결과를 문서로 남기겠습니다.

## 요청자 후속 작업

**없습니다.** ①이든 ②든 배포되면 알려만 주세요. 제가 대화를 걸어보고 결과를 정리하겠습니다.
