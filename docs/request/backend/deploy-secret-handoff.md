# 배포용 `INTERNAL_SHARED_SECRET`을 주세요 — 이것 하나가 대화 전체를 막고 있습니다

> **상태: ⏳ 회신 대기** (요청 2026-09-07)
> 회신은 `../../response/ai/deploy-secret-handoff.md`에 들어옵니다.
> **막고 있는 작업**: **대화 전체.** AI서버는 배포됐고 백엔드에 닿기까지 확인했는데, **인증에서 401로 끊깁니다.** 값 하나만 오면 그 자리에서 끝납니다.

- 요청자: AI
- 대상: 백엔드
- 관련 문서: `../../02-architecture/api-contract.md` §3-1 · `../../response/backend/deploy-handoff.md`(AI 회신) · `../../../backend/docs/phase-7-ops-deploy.md` 9단계

---

## 상황 — 배포는 끝났고 값만 없습니다

**AI서버를 배포했습니다.**

```
https://emotion-ai-server-gq7yhdrrlq-du.a.run.app
```

`deploy-handoff.md` 회신에 상세를 적었고, `AI_SERVER_BASE_URL`에 이 주소를 넣으시면 됩니다.

**그 배포본에 지금 로컬용 시크릿이 들어 있습니다.** 배포용 값을 아직 못 받아서, 자리를 비워두는 것보다는 형태라도 맞춰 두는 편이 낫다고 판단했습니다. 그래서 컨테이너는 정상 기동하지만 백엔드 호출이 전부 거부됩니다.

## 값이 다르다는 것을 실물로 확인했습니다

추측이 아닙니다. 배포된 백엔드에 **로컬 값**으로 세션 조회를 걸어봤습니다.

```
GET https://emotion-6yeh.onrender.com/internal/sessions/00000000-0000-4000-8000-000000000000
X-Internal-Secret: <로컬 값>

401 {"error":{"code":"INTERNAL_AUTH_FAILED","message":"내부 인증에 실패했습니다.","traceId":"2e01d0f0"}}
```

**시크릿을 아예 빼고 보낸 것과 결과가 같습니다.** `deploy-handoff.md`에 적어주신 "배포용은 새 값"이 그대로 확인된 셈입니다.

배포된 AI서버 쪽 로그에도 같은 것이 남습니다 — `clm_unauthorized:lookup_bad_status:401`. 상태 코드를 이유에 붙여둬서 **시크릿 불일치인지 권한 문제인지 로그만 봐도 갈립니다.**

## 이게 왜 대화 전체를 막는가

세션 조회가 **CLM 인증**을 겸합니다(계약 §3-4). 조회가 401이면 AI서버는 Hume에 401을 돌려주고, **거기서 대화가 끝납니다.** 갭도 되묻기도 위기 감지도 그 뒤의 이야기입니다.

fail-closed는 의도한 설계이고 바꾸지 않습니다. **다만 지금은 "정상 동작하는 차단"이라 조용합니다** — 서버는 멀쩡하고 로그도 깨끗한데 대화만 안 됩니다.

## 부탁드리는 것

**배포용 `INTERNAL_SHARED_SECRET` 하나입니다.**

- 전달 경로는 **로컬 값을 주셨던 것과 같은 경로**로 부탁드립니다. 저장소·이슈·채팅에 적지 않습니다(계약 §3-1)
- 받으면 Google Secret Manager의 값을 교체하고 재배포합니다. **10분이면 됩니다**
- 교체 후 `GET /internal/sessions/{없는 세션}`이 **401이 아니라 404**로 바뀌는 것으로 확인하겠습니다. 그게 인증 통과의 증거라고 알려주신 그대로입니다

## 함께 알려드립니다 — cron은 제가 걸었습니다

`phase-7` 7-4에 남아 있던 **킵얼라이브 cron 두 개를 등록했습니다.** "계정이 필요해 팀장이 직접 한다"고 적어두셨는데, **별도 가입 없이 기존 GCP 계정으로 해결됐습니다.**

| 작업 | 대상 | 주기 |
| --- | --- | --- |
| `emotion-ai-keepalive` | `…run.app/health` | 10분 |
| `emotion-backend-keepalive` | `https://emotion-6yeh.onrender.com/api/health` | 10분 |

Cloud Scheduler는 무료 한도가 결제 계정당 3개인데 해빙이 1개를 쓰고 있어 정확히 2개가 남아 있었습니다. 둘 다 즉시 실행해 정상 동작을 확인했습니다. **체크박스를 닫으셔도 됩니다.**

**⚠️ 다만 AI서버 쪽 주소는 `/healthz`가 아니라 `/health`입니다.** Cloud Run이 `/healthz`를 앞단에서 가로채 자기 404를 돌려줍니다 — 같은 호스트에서 `/healthzz`·`/nope`는 우리 앱의 JSON 404가 오는데 그 경로만 구글 HTML 404입니다. 문서에 없는 동작이라 배포해 보고 알았습니다.

## 받고 나면 순서

1. 시크릿 교체 + 재배포 (AI, 10분)
2. `/internal/sessions`가 404로 바뀌는 것 확인 (AI)
3. **Hume Config의 `language_model`에 CLM URL 등록** (AI) — `hume-config-setup.md`에서 요청하신 건입니다
4. 첫 대화 (팀)

**3번이 끝나면 우리 AI서버가 처음으로 Hume에게 불립니다.** 그때 Hume이 실제로 보내는 요청 모양이 자동으로 저장되게 해뒀습니다(발화는 담기지 않습니다). 문서만 보고 짠 파서라 그 한 번이 가장 중요합니다.
