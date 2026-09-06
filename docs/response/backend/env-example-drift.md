# 회신 — `.env.example`이 낡았습니다

- 원본 요청: [`../../request/ai/env-example-drift.md`](../../request/ai/env-example-drift.md) (백엔드 → AI, 2026-09-05)
- 회신자: AI
- 회신일: 2026-09-06

---

## 결론 — 지적이 전부 맞습니다. 고쳤고, 다시는 어긋나지 않게 테스트로 막았습니다

**세 줄 다 제 실수입니다.** 모델과 effort를 고칠 때 `config.py`와 `.env`만 바꾸고 `.env.example`을 빠뜨렸습니다. 그리고 회신에는 **고쳐진 값**을 적어서, 문서끼리도 어긋났습니다.

| 변수 | 낡은 값 | 고친 값 |
| --- | --- | --- |
| `AI_RESPOND_EFFORT` | `low` | **`none`** |
| `AI_MODEL_OBSERVE` | `gemini-2.5-pro` | **`gemini-3.8-flash`** |
| `AI_OBSERVE_EFFORT` | `medium` | **`none`** |

**"`.env`가 `config.py`를 덮는다"는 지적이 이 문제의 핵심입니다.** 낡은 예시 파일은 그냥 낡은 문서가 아니라 **코드에서 고친 결함을 되살리는 장치**입니다. 복사한 사람의 서버에서만 재현되고, 코드를 아무리 봐도 안 보입니다.

특히 `AI_RESPOND_EFFORT=low`는 **위기 응답의 109 안내가 잘리는** 값입니다. 등급이 다르다는 판단에 동의합니다.

## 규칙이 아니라 테스트로 막았습니다

"고칠 때 `.env.example`도 같이 고친다"는 규칙으로는 또 빠뜨립니다. **이번에 실제로 빠뜨렸습니다.**

`tests/test_env_example.py`를 만들었습니다. `.env.example`의 모든 키를 `config.py`의 기본값과 대조하고, 하나라도 다르면 테스트가 깨집니다.

```
AI_RESPOND_EFFORT: .env.example='low' 인데 config.py='none'.
`.env`가 코드를 덮으므로 이 파일을 복사한 사람은 옛 동작을 얻는다
```

세 가지를 검사합니다.

- **값이 같은가** — 시크릿과 배포마다 달라지는 주소는 제외
- **시크릿이 비어 있는가** — 예시 파일에 실제 값이 들어가면 저장소에 시크릿이 올라갑니다
- **`AI_RESPOND_EFFORT`가 `none`인가** — 이건 따로 한 번 더 봅니다. FR-032·033이고 `spec.md` §11이 "F4는 어떤 스코프 컷에서도 자르지 않는다"고 못박은 자리라, 다른 값과 등급이 다릅니다

**이제 `.env.example`을 복사하셔도 안전합니다.**

## 요청자 후속 작업

- **`.env`를 다시 복사해 주세요.** 이번에는 값이 맞습니다
- 복사 후 `python -m app.envcheck`로 확인하시면 됩니다

## 함께 알려드립니다 — AI서버가 배포됐습니다

**`https://emotion-ai-server-gq7yhdrrlq-du.a.run.app`** (Cloud Run, `asia-northeast3`)

`deploy-handoff.md`에서 요청하신 주소입니다. `AI_SERVER_BASE_URL`에 넣으시면 됩니다.

**⚠️ 킵얼라이브 cron은 `/healthz`가 아니라 `/health`를 찔러야 합니다.**

**Cloud Run이 `/healthz`를 앞단에서 가로챕니다.** 같은 호스트에서 `/healthzz`·`/health`·`/nope`는 전부 우리 앱의 JSON 404가 오는데 **`/healthz`만 구글 HTML 404**가 옵니다. 문서에 없는 동작이라 배포해 보고 알았습니다. `/health`를 정식 경로로 두고 `/healthz`는 로컬용 별칭으로 남겼습니다.

```
https://emotion-ai-server-gq7yhdrrlq-du.a.run.app/health  →  {"status":"ok"}
```

**그리고 아직 공유 시크릿이 안 맞습니다.** 배포본에 로컬 값을 넣어 둔 상태라 세션 조회가 `401`로 떨어집니다(`lookup_bad_status:401`로 로그에 남게 코드도 보강했습니다). **새 `INTERNAL_SHARED_SECRET`을 받으면 그 자리에서 교체하겠습니다.** 그 전까지는 대화가 성립하지 않습니다.
