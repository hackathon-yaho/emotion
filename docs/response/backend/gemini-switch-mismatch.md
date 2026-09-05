# 회신 — Gemini 전환, 모델명 불일치

- 원본 요청: [`../../request/ai/gemini-switch-mismatch.md`](../../request/ai/gemini-switch-mismatch.md) (백엔드 → AI, 2026-09-05)
- 회신자: AI
- 회신일: 2026-09-05

---

## 결론 — **보고 계신 `.env`는 그쪽 로컬 파일이고, 낡았습니다**

`.env`는 `.gitignore` 대상이라 **사람마다 다른 파일**입니다. 저장소에서 공유되는 것은 `.env.example`뿐이고, 그건 이미 Gemini 값으로 맞춰져 있습니다(커밋 `976eddd`, 2026-09-05).

**그쪽 파일이 Claude 전환 시점에 만들어진 뒤로 갱신되지 않은 것**으로 보입니다. 제 로컬 `.env`는 Gemini 값으로 돌고 있고, 실제 호출도 확인했습니다.

**고치는 법**: `.env.example`을 다시 복사하시고 시크릿 두 줄만 넣으시면 됩니다.

```powershell
copy .env.example .env
.\.venv\Scripts\python.exe -m app.setsecret GOOGLE_API_KEY
.\.venv\Scripts\python.exe -m app.setsecret INTERNAL_SHARED_SECRET
.\.venv\Scripts\python.exe -m app.envcheck
```

`setsecret`은 값이 화면에도 셸 기록에도 남지 않습니다. `envcheck`는 들어간 값을 마스킹해서 보여줍니다.

## 확인 요청 3건

| 질문 | 답 |
| --- | --- |
| 1. Gemini 확정인지, 모델명을 바꿔도 되는지 | **확정입니다.** 다만 아래 표대로 바꿔 주세요 — 요청서에 적힌 `gemini-2.5-pro`는 **쓰면 안 됩니다** |
| 2. `AI_ANALYZE_TIMEOUT_MS` | **3000**. 실측 p95 1,209ms + 여유 |
| 3. `AI_LLM_BASE_URL`을 명시할지 | **명시하는 쪽으로 바꿨습니다.** 기본값에 맡기면 벤더가 어디인지 파일만 봐서는 모릅니다 |

**현재 값 (`.env.example` 그대로)**

```
GOOGLE_API_KEY=<발급받은 값>
AI_LLM_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai/
AI_MODEL_ANALYZE=gemini-3.5-flash-lite
AI_MODEL_RESPOND=gemini-3.8-flash
AI_RESPOND_EFFORT=none
AI_MODEL_OBSERVE=gemini-3.8-flash
AI_OBSERVE_EFFORT=none
AI_MODEL_SUMMARY=gemini-3.5-flash-lite
AI_ANALYZE_TIMEOUT_MS=3000
```

## ⚠️ `gemini-2.5-pro`는 404입니다

요청서에 `.env.example`이 쓰던 값으로 `gemini-2.5-pro`를 적어 주셨는데, **실물로 붙여보니 404가 납니다.**

> "This model models/gemini-2.5-pro is no longer available to new users."

Google 공식 모델 문서에는 **정식 제공 모델로 적혀 있습니다.** 문서만 보고는 알 수 없었고, 호출해 봐야 나왔습니다. 관찰 문장화 모델을 `gemini-3.8-flash`로 바꿨습니다.

## `ANTHROPIC_API_KEY`는 지웠습니다

Claude로 되돌릴 계획이 없습니다. 오늘만 Anthropic → OpenAI → Google로 두 번 옮겼는데, **세 번 다 설계·프롬프트·가드는 한 줄도 안 바뀌었습니다.** 고친 범위는 `app/llm/`과 환경변수뿐입니다. 또 옮기게 돼도 같습니다.

## 요청자 후속 작업

- **`.env`를 `.env.example`에서 다시 만들어 주세요.** 그게 전부입니다
- 참고로 `AI_RESPOND_EFFORT=none`이 중요합니다 — 이걸 빼면 **위기 응답의 109 안내가 문장 중간에서 잘립니다**(실측). 사고 토큰이 출력 예산을 함께 쓰기 때문입니다
