# 회신 — 배포 주소와 새 공유 시크릿

- 원본 요청: [`../../request/ai/deploy-handoff.md`](../../request/ai/deploy-handoff.md) (백엔드 → AI, 2026-09-05)
- 회신자: AI
- 회신일: 2026-09-05

---

## 결론

| 질문 | 답 |
| --- | --- |
| 1. `BACKEND_BASE_URL` 반영 시점 | **AI서버 배포와 동시에.** 로컬 개발은 `localhost:8080` 그대로 둡니다 |
| 2. 슬립 복귀 대 fail-closed | **cron이 맞습니다.** 타임아웃으로는 못 막습니다 — 이유는 아래 |
| 3. AI서버 배포 예정 | **Cloud Run으로 갑니다.** 주소가 나오는 대로 드립니다 |

## 2. 타임아웃을 늘려도 못 막습니다 — cron이 맞습니다

**Render 복귀가 약 60초인데, 그 60초를 기다리는 선택지가 없습니다.**

- 타임아웃을 60초로 늘리면 **Hume 쪽이 먼저 끊습니다.** CLM 요청을 1분씩 붙들 수 없습니다
- 타임아웃 안에 재시도를 넣어도 같습니다. 3초든 5초든 60초를 덮지 못합니다
- 지적하신 대로 **슬립 복귀는 연결이 되고 응답만 늦는 형태**라 `AI_SESSION_LOOKUP_CONNECT_RETRY`가 안 걸립니다. 정확한 관찰입니다

**그래서 cron으로 재우지 않는 것이 유일한 실질적 방어입니다.** 그 판단에 동의합니다.

**다만 cron이 죽은 구간의 첫 대화 한 번은 실패합니다.** 이건 감수합니다 — 사용자가 다시 시도하면 그 사이 백엔드가 깨어 있습니다. fail-closed를 푸는 것보다 낫습니다. 실패가 조용하지 않도록 `clm_unauthorized:lookup_timeout`으로 남습니다.

### ⚠️ cron이 **두 곳**을 찔러야 합니다

**AI서버도 Cloud Run 무료라 잠듭니다.** 백엔드만 깨우면 이번엔 AI서버가 자고 있습니다.

| 대상 | 엔드포인트 | 왜 |
| --- | --- | --- |
| 백엔드 | `https://emotion-6yeh.onrender.com/api/health` | 15분 유휴에 슬립, 복귀 약 60초 |
| **AI서버** | `<배포 주소>/healthz` | `min-instances 0`이라 유휴 시 인스턴스 소멸. 콜드 스타트 있음 |

### ✅ cron 등록 완료 (2026-09-06) — **두 개 다 걸었습니다**

**별도 서비스에 가입하지 않았습니다.** GCP에 Cloud Scheduler가 있어서 거기에 걸었습니다. 계정이 이미 있고, 무료 한도가 결제 계정당 3개인데 해빙이 1개를 쓰고 있어 **정확히 2개가 남아 있었습니다.**

| 작업 이름 | 대상 | 주기 |
| --- | --- | --- |
| `emotion-ai-keepalive` | `https://emotion-ai-server-gq7yhdrrlq-du.a.run.app/health` | 10분 |
| `emotion-backend-keepalive` | `https://emotion-6yeh.onrender.com/api/health` | 10분 |

프로젝트 `emotion-voice-ai` · 리전 `asia-northeast3` · 시간대 `Asia/Seoul` · 응답 대기 60초(콜드 스타트 감안). 둘 다 즉시 실행해 정상 동작을 확인했습니다.

**`phase-7` 7-4의 cron 체크박스를 닫으셔도 됩니다.** 계정이 필요해 팀장이 직접 해야 한다고 적어두셨는데, 기존 GCP 계정으로 해결됐습니다.

**끄거나 주기를 바꾸려면**:

```powershell
gcloud.cmd scheduler jobs pause emotion-backend-keepalive --project=emotion-voice-ai --location=asia-northeast3
```

## 1·4. 배포 계획 — Cloud Run

**터널이 아니라 배포로 갑니다.** 백엔드가 이미 공개 주소를 가졌으니, AI서버도 배포하면 서로 닿습니다. 그리고 **Hume Config의 CLM URL이 고정**됩니다 — 터널이면 껐다 켤 때마다 Config를 고쳐야 합니다.

배포 시 환경변수는 이렇게 갈립니다.

| 변수 | 로컬 | 배포 |
| --- | --- | --- |
| `BACKEND_BASE_URL` | `http://localhost:8080` | `https://emotion-6yeh.onrender.com` |
| `INTERNAL_SHARED_SECRET` | 기존 값 | **새 값** (별도 경로로 받겠습니다) |

**배포됐습니다 (2026-09-06)** — **`https://emotion-ai-server-gq7yhdrrlq-du.a.run.app`**

Cloud Run `asia-northeast3`, 프로젝트 `emotion-voice-ai`, `min-instances 0` · `max-instances 2`.

| 확인 | 결과 |
| --- | --- |
| `GET /health` | ✅ 200 `{"status":"ok"}` (콜드 0.33초) |
| 시크릿 없이 `/internal/summaries` | ✅ 401 |
| 없는 세션으로 CLM | ✅ 401 (배포 백엔드까지 실제로 조회함) |

**⚠️ cron은 `/healthz`가 아니라 `/health`입니다.** Cloud Run이 `/healthz`를 앞단에서 가로채 자기 404를 돌려줍니다 — 같은 호스트에서 `/healthzz`·`/nope`는 우리 앱의 JSON 404가 오는데 그 경로만 구글 HTML 404입니다. 문서에 없는 동작이라 배포해 보고 알았습니다.

**⚠️ 아직 공유 시크릿이 안 맞습니다.** 배포본에 로컬 값이 들어 있어 세션 조회가 401입니다(`lookup_bad_status:401`). **새 값을 주시면 그 자리에서 교체합니다.** 그 전까지 대화는 성립하지 않습니다.

## 시크릿 전달

새 값은 **로컬용과 같은 경로**로 주세요. 저장소에는 넣지 않습니다.

배포본의 시크릿은 Google Secret Manager에 넣습니다. 명령줄 인자로 넘기지 않고 파일로 넘긴 뒤 즉시 지웁니다 — PowerShell 기록에 평문으로 남기 때문입니다.

## 요청자 후속 작업

- 새 `INTERNAL_SHARED_SECRET` 전달
- **cron 서비스 이름 알려주기** — AI서버 킵얼라이브를 같은 곳에 등록하겠습니다
- AI서버 주소가 나오면 `AI_SERVER_BASE_URL` 반영
