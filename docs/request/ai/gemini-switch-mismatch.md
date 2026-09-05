# Gemini로 다시 전환 — 모델명이 아직 Claude 그대로입니다

> **상태: ⏳ 회신 대기** (요청 2026-09-05)
> 회신은 `../../response/backend/gemini-switch-mismatch.md`에 들어옵니다.
> **막고 있는 작업**: 분석·응답·관찰·요약 호출 전부. 지금 상태로 붙이면 모델명 오류로 호출이 실패할 것으로 보입니다.

- 요청자: 백엔드
- 대상: AI
- 관련 문서: `ai-server/.env`, `ai-server/.env.example`, `docs/02-architecture/ai-pipeline.md` §13

---

## 배경

무료 티어를 쓰려고 Gemini로 다시 전환한다고 들었습니다. `ai-server/.env`에 `GOOGLE_API_KEY`를 채워 넣었는데, **나머지 값이 Claude 전환 당시 그대로 남아 있어서** 이대로면 호출이 안 될 것 같습니다.

## 발견

현재 `ai-server/.env`:

```
ANTHROPIC_API_KEY=
GOOGLE_API_KEY=<채워짐>
AI_MODEL_ANALYZE=claude-haiku-4-5
AI_MODEL_RESPOND=claude-sonnet-5
AI_MODEL_OBSERVE=claude-opus-5
AI_MODEL_SUMMARY=claude-haiku-4-5
AI_ANALYZE_TIMEOUT_MS=400
```

`AI_LLM_BASE_URL`은 `.env`에 없어서 `app/config.py`의 기본값(`generativelanguage.googleapis.com`, Gemini)이 그대로 적용됩니다.

1. **모델명이 Anthropic ID입니다.** Gemini 엔드포인트에 `claude-haiku-4-5`를 모델로 보내면 실패할 것으로 보입니다. `.env.example`이 쓰던 값(`gemini-3.5-flash-lite` · `gemini-3.8-flash` · `gemini-2.5-pro`)으로 되돌려야 할지 확인 부탁드립니다.
2. **`AI_ANALYZE_TIMEOUT_MS=400`이 너무 짧아 보입니다.** `.env.example` 주석에 "실측 p95 5473ms (2026-09-05, Gemini 무료 티어)"라고 남겨져 있던데, 이 값이 아직 유효하면 400ms로는 분석 호출이 거의 매번 타임아웃나서 갭 기능이 죽습니다.
3. **`ANTHROPIC_API_KEY`는 비어 있습니다.** Claude 경로로 되돌릴 계획이 없는지도 확인차 여쭤봅니다.

## 참고 — 이번 전환으로 안 풀리는 것

`docs/request/ai/hume-config-setup.md`(CLM 미등록)와 Hume 무료 플랜(동시 접속 1) 문제는 LLM 벤더와 무관해서 이번 전환으로 해결되지 않습니다. 별개로 진행 중인 회신 대기 건입니다.

## 확인 요청

1. Gemini로 확정인지, 모델명 4종을 Gemini 값으로 바꿔도 되는지
2. `AI_ANALYZE_TIMEOUT_MS`를 얼마로 둘지 (400ms 그대로면 근거를, 올린다면 값을)
3. `AI_LLM_BASE_URL`을 `.env`에 명시로 넣을지, 기본값(Gemini)에 맡길지
