# 백엔드가 배포됐습니다 — 주소와 새 공유 시크릿을 받아 가세요

> **상태: ⏳ 회신 대기** (요청 2026-09-05)
> 회신은 `../../response/backend/deploy-handoff.md`에 들어옵니다.
> **막고 있는 작업**: 없음(AI서버 로컬 개발은 그대로 됩니다). 다만 **AI서버가 배포될 때 이 값들이 안 맞으면 요약·관찰이 조용히 죽습니다.**

- 요청자: 백엔드
- 대상: AI
- 관련 문서: `../../02-architecture/api-contract.md` §3-1 · `../../../backend/docs/phase-7-ops-deploy.md`

---

## 배포 주소

**`https://emotion-6yeh.onrender.com`** (Render, 무료 플랜)

실동작 확인한 것 (2026-09-05):

| 확인 | 결과 |
| --- | --- |
| `GET /api/health` | ✅ `{"status":"ok","db":"ok"}` |
| DB (Supabase Session pooler 5432) | ✅ 연결됨, Postgres 17.6, 11테이블 |
| `GET /internal/sessions/{id}` 시크릿 없음 | ✅ **401 `INTERNAL_AUTH_FAILED`** |
| 〃 틀린 시크릿 | ✅ 401 |
| 〃 올바른 시크릿 + 없는 세션 | ✅ **404** (인증 통과) |
| CORS (`https://hackathon-yaho.github.io`) | ✅ 통과 |

## 1. `BACKEND_BASE_URL`을 바꿔 주세요

`ai-server/.env`가 지금 `http://localhost:8080`입니다. 배포된 AI서버에서는 이 주소로 가야 합니다.

```
BACKEND_BASE_URL=https://emotion-6yeh.onrender.com
```

**로컬 개발은 그대로 두셔도 됩니다** — 터널로 붙는 기존 방식이 여전히 유효합니다.

## 2. `INTERNAL_SHARED_SECRET`이 **새 값**입니다

배포용으로 새로 생성했습니다. **로컬용과 다른 값입니다**(`phase-7` 3단계 — 배포용 시크릿은 새로 만드는 것이 원칙입니다).

**값은 이 문서에 적지 않습니다**(계약 §3-1). 로컬용을 드렸던 것과 같은 경로로 전달하겠습니다.

- 로컬에서 로컬 백엔드에 붙을 때는 **기존 값** 그대로
- 배포된 AI서버가 배포된 백엔드에 붙을 때는 **새 값**

## 3. ⚠️ Render 무료 플랜은 **잠듭니다** — 이게 fail-closed와 부딪힙니다

Render 무료는 15분 유휴면 인스턴스가 내려가고, 복귀에 **약 1분**이 걸립니다.

**AI서버의 `GET /internal/sessions/{id}`는 타임아웃 2초에 fail-closed(401)입니다.** 백엔드가 자고 있을 때 대화가 시작되면 그 조회가 타임아웃나고, **CLM 인증이 막혀 대화 전체가 성립하지 않습니다.**

- **백엔드 쪽 대책**: cron으로 10분마다 `GET /api/health`를 때려 재우지 않습니다(`phase-7` 8단계). 이걸 켜면 이 문제는 사라집니다
- **다만 cron이 죽거나 멈춘 구간이 생기면** 첫 대화 한 번이 이 경로를 밟습니다. `AI_SESSION_LOOKUP_CONNECT_RETRY`가 연결 실패에만 걸리는데, **슬립 복귀는 연결이 되고 응답이 늦는 형태**라 그 재시도가 안 걸릴 수 있습니다
- **판단을 부탁드립니다** — 타임아웃을 늘릴지, 아니면 cron을 신뢰하고 그대로 둘지. 저희는 **cron으로 막는 쪽이 맞다**고 보지만, 그쪽 fail-closed 설계라 결정은 AI 몫입니다

## 4. AI서버가 배포되면 **주소를 알려주세요**

백엔드 환경변수 `AI_SERVER_BASE_URL`이 지금 기본값(`http://localhost:8100`)입니다. 배포에서는 이게 안 맞으면 —

**요약은 `null`, 관찰은 0건이 됩니다. 그리고 둘 다 정상 동작과 구분이 안 됩니다** — 설계상 AI 호출이 실패해도 대화·기록은 멀쩡하게 굴러가기 때문입니다(`phase-7` 10단계 경고).

주소를 주시면 그 자리에서 넣겠습니다. **재배포 없이 환경변수만 바꾸면 됩니다.**

## 5. Hume Config의 CLM URL도 배포 주소여야 합니다

별건으로 요청드린 `hume-config-setup.md`(⏳)의 `language_model` 등록 건인데, **거기 넣을 URL이 AI서버 배포 주소**입니다. 로컬 ngrok으로 등록해두면 터널이 끊길 때마다 대화가 죽습니다.

## 회신 부탁드립니다

1. `BACKEND_BASE_URL` 반영 시점
2. **3번 — 슬립 복귀 대 fail-closed 타임아웃**을 어떻게 할지
3. AI서버 배포 예정 시점 (주소를 받으면 `AI_SERVER_BASE_URL`을 그날 넣습니다)
