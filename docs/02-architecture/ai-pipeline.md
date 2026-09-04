# AI 파이프라인 설계 — 감정 케어 보이스 저널

| 항목 | 내용 |
| --- | --- |
| 문서 버전 | v1.0 |
| 작성일 | 2026. 09. 03. |
| 담당 | AI (ai-server) |
| 상위 문서 | [prd.md](../00-context/prd.md) §9 · [spec.md](../00-context/spec.md) F3~F8 · [api-contract.md](api-contract.md) §3·§4 |
| 이 문서의 위치 | **AI서버 내부 설계의 단일 출처.** PRD §9는 요지만 두고 상세는 여기로 위임한다. 계약(필드·스키마)은 여전히 `api-contract.md`가 우선한다 |

> **이 문서가 답하는 것**: Hume이 우리 서버를 호출한 순간부터 SSE가 끝나기까지 무슨 일이 어떤 순서로 일어나는지, 어디까지가 코드이고 어디부터가 LLM인지, LLM이 건드릴 수 없는 것이 무엇인지, 무엇이 실패해도 대화가 계속되는지.
> **이 문서가 답하지 않는 것**: 프롬프트 전문(`ai-server/prompts/`가 단일 출처), 매핑표·키워드 원본(`ai-server/rules/`가 단일 출처). 여기에는 조항 요지와 근거만 둔다.

---

# 0. 결정 요약 (M0 확정 항목)

| # | 결정 | 값 | 근거 |
| --- | --- | --- | --- |
| AI-01 | AI서버 언어·프레임워크 | **Python 3.12 · FastAPI · uvicorn** | Hume CLM 공식 예제(`evi-python-clm-sse`)가 FastAPI SSE. 계약 형태를 그대로 따라가면 검증 비용이 가장 낮다 |
| AI-02 | 실시간 LLM 호출 구조 | **분석 호출 1 + 응답 호출 1** (§2) | PRD §9.1의 순환 의존·채널 독립성 문제 해소. `request/ai/clm-turn-pipeline-review.md` 채택 |
| AI-03 | 응답 스트림 형식 | **순수 대화 텍스트만. 메타 태그 없음** | 텍스트 valence·태그·위기 판정을 전부 분석 호출로 옮겨, `<v>`·`<m>`류가 Hume TTS로 새는 실패 모드를 **구조적으로 제거** |
| AI-04 | 텍스트 valence 산출 수단 | **경량 LLM 호출 (전사만 입력, 구조화 출력)** + 전사 해시 캐시 | 가장 빨리 붙고, 동일 전사에 대해 캐시로 결정성 확보. 로컬 한국어 감성 모델은 인터페이스만 열어둔다 (§2.4) |
| AI-05 | 추측 실행(speculative respond) | **기본 OFF.** TC-12(p95 2초) 미달 시 플래그로 ON | 정확성 먼저, 최적화는 측정 후 |
| AI-06 | LLM 모델 (초기값, 전부 환경변수) | **2026-09-05 Google Gemini 무료 티어** — 분석 `gemini-3.5-flash-lite` · 응답 `gemini-3.8-flash` · 관찰 `gemini-2.5-pro` · 요약 `gemini-3.5-flash-lite` | 분석은 지연 예산 400ms, 응답은 한국어 품질과 TTFT의 균형, 배치는 지연이 없으니 최상위. §2.6 |
| AI-07 | 48종 → valence 매핑 | **긍정 18 / 부정 21 / 중립 9, 균일 가중치 ±1** | PRD §14-1 해소. 자유도 최소화(20쌍 과적합 방지). §3 |
| AI-08 | 위기 키워드 규칙 | **직접 표현(Tier A)만 규칙 감지, 간접·절망 표현(Tier B)은 LLM 판정 힌트** | PRD §14-2 해소. 공개 자료 기반. §5 |
| AI-09 | 고정 임계값 | **20쌍 측정 후 결정. 개발용 임시값은 `.env`에만** (코드 상수 금지) | PRD §14-5. 결정 절차는 §4.3 |
| AI-10 | 태그 규칙 | **활용형 정규화만, 동의어 병합 없음** | spec F6-01의 `미팅→회의` 예시는 FR-043·§1.4 "원문 외 태그 0건"과 충돌. §6 |
| AI-11 | CLM 인증 | **`custom_session_id`를 백엔드 세션 조회로 검증** (앱에 비밀 없음) | `language_model_api_key`는 앱이 보내야 해서 웹 번들에 노출됨. §7 · `request/backend/session-context-lookup.md` |

미결(백엔드 회신 대기): 세션 컨텍스트 조회(§7), 세션 요약 생성 경로(§8.2).

---

# 1. 경계 — LLM이 할 수 없는 것

이 절이 이 문서의 핵심이다. 아래는 프롬프트로 부탁하는 것이 아니라 **코드 구조로 불가능하게** 만든다.

| # | LLM이 할 수 없는 것 | 그것을 하는 주체 | 구조적 보장 |
| --- | --- | --- | --- |
| 1 | **음성 valence를 정할 수 없다** | `rules/valence.py` 순수 함수 | LLM 호출 어디에도 prosody 점수가 입력되지 않는다 (§2.3) |
| 2 | **갭·트리거를 판정할 수 없다** | `rules/gap.py` 순수 함수 | 응답 LLM은 `gapTriggered: true/false` **플래그만** 받는다. 수치도 받지 않는다 |
| 3 | **위기 규칙 감지를 끌 수 없다** | `rules/crisis.py` 순수 함수 | LLM 호출과 무관한 코드 경로. LLM이 죽어도 돈다 |
| 4 | **원문에 없는 태그를 남길 수 없다** | `rules/tags.py` 대조 함수 | LLM 출력 태그를 전사와 대조해 미포함 태그를 폐기 |
| 5 | **관찰의 존재·강도를 판정할 수 없다** | 백엔드 F7-03 | AI서버는 `/internal/observations`로 **이미 판정된 숫자**만 받는다 |
| 6 | **관찰 문장에 숫자·새 사실을 넣을 수 없다** | `rules/observe_guard.py` | 문장에 숫자가 있거나 태그가 없으면 폐기. 템플릿 대체 없음 |
| 7 | **응답 스트림에 메타데이터를 실을 수 없다** | 설계 자체 | 응답 호출의 출력은 대화 텍스트뿐. 파싱·제거 로직이 **존재하지 않는다** |
| 8 | **진단명·약물·치료를 말할 수 없다** | 프롬프트 조항 + `rules/guard.py` 금칙어 사후 검사 | 사후 검사에 걸리면 해당 문장을 정형 문장으로 치환하고 `ops_error_log` 적재 |

> 8번만 사후 검사다. 스트리밍 중에는 문장 단위로 검사해 흘려보내므로 지연에 영향이 없고, 걸린 문장만 치환된다. 완전한 차단은 불가능하지만 "프롬프트만 믿는다"보다는 한 겹 더 있다.

---

# 2. 실시간 턴 처리 (PRD §9.1 대체)

## 2.1 흐름

```
① 수신        Hume → POST /chat/completions?custom_session_id={sid}
              body.messages[] = 전체 대화 이력 (user/assistant, content, time, models.prosody.scores)
              ↓ 마지막 user 메시지 = 이번 턴. transcript T, prosody P, 시각 time

② 세션 컨텍스트  cache[sid] 없으면 백엔드 GET /internal/sessions/{sid}   ← §7, 세션당 1회
              → thresholdMode, gapThreshold, startedAt, softWrapSec, demoMode
              (실패 시 .env 고정 임계값으로 대화 계속. 인증 실패면 401)

③ 병렬 ─┬─ (a) voice_valence = valence(P)                  코드, <1ms          §3
        ├─ (b) crisis_rule   = crisis_keywords(T)           코드, <1ms, 항상    §5
        └─ (c) analyze(T, recent_text_turns, known_tags)    LLM 경량 호출       §2.3
               → { text_valence, tags[], crisis_llm }       타임아웃 400ms
               ※ (c)의 입력에 P는 없다. 전사만.

④ gap          = |text_valence − voice_valence|             코드                §4
   gapTriggered = gap ≥ threshold(mode)
   crisis       = crisis_rule OR crisis_llm                 코드
   tags         = verify_in_transcript(tags, T)             코드                §6
   elapsedSec   = now − startedAt (fallback: time.end/1000)

⑤ respond(history_text, flags)                              LLM 스트리밍 호출   §2.5
   flags = { gapTriggered, crisis, crisisBy, softWrap: elapsedSec ≥ softWrapSec, adviceRequested }
   입력에 prosody 원본·valence 수치·gap 수치는 없다. 플래그만.
   출력: 대화 텍스트만.

⑥ SSE → Hume   토큰이 오는 즉시 OpenAI chunk로 변환해 흘려보낸다. 버퍼링 없음.
              system_fingerprint = sid. 끝에 data: [DONE]

⑦ 적재         POST /internal/turns ×2 (user 턴, assistant 턴) — 비동기, fire-and-forget
              user 턴: valence 2종·gap·gapTriggered·tags·topProsody·crisis
              assistant 턴: transcript만, 나머지 null/[]
```

- ③(a)(b)는 즉시 끝나고, ③(c)가 ④⑤ 앞에 **직렬**로 붙는다. 평시 추가 지연은 (c)의 왕복 시간 하나(목표 ≤ 400ms)다.
- (c)가 타임아웃·실패하면 `text_valence = null, tags = [], crisis_llm = null`로 ④로 진행한다. 갭은 미산출, 되묻기는 생략, **규칙 위기 감지와 응답은 정상**이다. 이것이 FR-024의 의미다.
- ⑦은 ⑥이 끝난 뒤가 아니라 **④ 직후 user 턴을 먼저 적재**한다. 응답 스트림이 중간에 끊겨도(끼어들기) 측정값은 남는다.

## 2.2 왜 이 구조인가 — 요청 문서와 다른 점

`request/ai/clm-turn-pipeline-review.md`의 제안(경량 호출 분리 + 프로소디 미노출)을 채택하되 한 가지를 바꿨다. **태그와 위기 LLM 판정도 분석 호출로 옮기고, 응답 호출에서는 메타 태그를 완전히 없앴다.**

| 항목 | 요청 문서 제안 | 이 설계 | 이유 |
| --- | --- | --- | --- |
| 텍스트 valence | 분석 호출 | 분석 호출 | 동일 |
| 태그·위기(LLM) | 응답 호출 첫 줄 `<m>{…}</m>` | **분석 호출** | ① 첫 줄 버퍼링이 TTFT에 그대로 얹힌다(15~20토큰 ≈ 100~200ms) ② 위기 판정이 응답 **앞에** 확정되어 톤 전환이 플래그로 결정된다 ③ 스트림에서 태그를 파싱·제거하는 코드가 사라지므로 **새는 실패 모드 자체가 없다** |
| 분석 호출 입력 | 전사만 | 전사 + **직전 4턴 텍스트** + 세션 기존 태그 | 위기 간접 표현("이제 그만 쉬고 싶어요")은 맥락이 있어야 판정된다. 텍스트만 주므로 채널 독립성은 유지 |

비용: 분석 호출 출력이 JSON 30토큰 안팎으로 늘지만 빠른 모델에서 400ms 예산 안이다. 응답 호출은 오히려 가벼워진다.

## 2.3 분석 호출 (analyze)

| 항목 | 내용 |
| --- | --- |
| 모델 | `AI_MODEL_ANALYZE` (초기 `gemini-3.5-flash-lite`), temperature 0, `response_format: json_object` |
| 입력 | `transcript`(이번 턴), `recent`(직전 최대 4턴의 **텍스트만**), `known_tags`(이 세션에서 이미 통과한 태그) |
| **입력에 없는 것** | prosody 점수 · 음성 valence · 갭 · 임계값 · 세션 메타. **어떤 형태의 음성 정보도 없다** (FR-025) |
| 출력 (구조화, 스키마 강제) | `{ "text_valence": -1.0~1.0, "tags": [최대 3], "crisis": bool, "crisis_reason": string\|null, "advice_requested": bool }` |
| 타임아웃 | `AI_ANALYZE_TIMEOUT_MS` (초기 400). 초과 시 전부 null/빈값 |
| 캐시 | `sha256(transcript)` → 결과, 세션 스코프. 같은 문장을 두 번 말하면 두 번째는 0ms. 데모 1번 장면(같은 문장 두 번)이 정확히 이 경로를 탄다 — **텍스트 valence가 두 번 동일함이 캐시로 보장된다** |
| 프롬프트 요지 | valence는 "글자만 읽었을 때"의 정서 방향. 태그는 원문에 등장한 명사의 기본형만. 위기는 재현율 우선(애매하면 true). `advice_requested`는 사용자가 조언을 요청한 발화인지 (F8-01) |
| 전문 | `ai-server/prompts/analyze.system.md` |

## 2.4 텍스트 valence 수단 — 인터페이스

```python
class TextAnalyzer(Protocol):
    async def analyze(self, transcript: str, recent: list[str], known_tags: list[str]) -> AnalyzeResult: ...
```

초기 구현은 LLM(§2.3). 로컬 한국어 감성 모델로 바꿀 때 이 프로토콜만 지키면 나머지는 그대로다. 단 로컬 모델은 valence만 내므로 태그·위기는 LLM 경로를 유지해야 한다 — 그래서 v1에서 로컬 모델을 넣지 않는다. 두 호출로 갈라지는 순간 지연 이득이 사라진다.

## 2.5 응답 호출 (respond)

| 항목 | 내용 |
| --- | --- |
| 모델 | `AI_MODEL_RESPOND` (초기 `gemini-3.8-flash`), `reasoning_effort: low`, 스트리밍 |
| 입력 | 시스템 프롬프트 + 대화 이력(텍스트만, Hume이 준 전체 이력에서 `system` role 제거) + **플래그 블록** |
| 플래그 블록 | `gapTriggered`, `crisis`(+`crisisBy`), `softWrap`, `adviceRequested`, `elapsedMin`. **수치는 없다** |
| 출력 | 대화 텍스트. 1~3문장, 구어체. 메타 태그·JSON·마크다운 없음 |
| 프롬프트 요지 | PRD §9.3 조항 2~5. 되묻기는 "감정을 단정하지 않고 묻는다". 위기면 톤 전환 + 109 안내 + 대화 계속. 조언은 `adviceRequested`일 때만, 그것도 관찰 근거가 있을 때만(F8-02 — 근거 관찰은 §7 세션 컨텍스트에 실어 받는다) |
| 실패 | 호출 실패·`stop_reason: refusal` → 정형 응답 1문장으로 대체, `ops_error_log`. 위기 플래그가 켜져 있으면 정형 응답에도 109 안내 포함 |
| 전문 | `ai-server/prompts/respond.system.md` |

**주의 — 모델 파라미터**: 모델마다 받는 파라미터가 다르고 문서에 다 적혀 있지도 않다. 그래서 `app/llm/client.py`가 **400을 맞으면 문제 파라미터를 빼고 한 번만 다시 시도하고, 그 사실을 프로세스 수명 동안 기억한다.** 모델 라인업이 바뀌어도 첫 호출의 400으로 서버가 죽지 않는다. 분석 호출은 temperature 0을 받는다.

## 2.6 지연 예산 (NFR-01 p95 2초)

```
[발화 종료] → Hume STT·프로소디 확정 → CLM 요청 → ② (첫 턴만 ~20ms)
           → ③(c) analyze  ≤ 400ms
           → ⑤ respond TTFT ≤ 600ms 목표
           → Hume TTS 첫 오디오
```

- 우리가 통제하는 구간은 ②③⑤이고 목표 합계 **≤ 1.0초**. Hume 양단(STT 확정·TTS 첫 바이트)이 나머지를 쓴다.
- 턴마다 구간별 지연을 계측해 로그(발화 내용 없이)로 남긴다. TC-12의 수치는 여기서 나온다.
- **p95가 깨지면** 순서대로: ① `AI_MODEL_RESPOND`를 `gemini-3.5-flash-lite`로 ② 추측 실행 ON(§2.7) ③ 분석 타임아웃 축소(300ms). 세 개를 한 번에 바꾸지 않는다.

## 2.9 무료 티어의 제약 — 분당 요청 수

**2026-09-05 현재 LLM은 Google Gemini 무료 티어다.** 비용이 0이라 예산 걱정은 없지만,
**분당 요청 수(RPM)와 일일 요청 수(RPD)에 상한이 있고 그게 실질적 제약**이다.

턴 하나가 LLM을 **2번** 부른다(분석 + 응답). 대화가 15초에 한 턴씩 돌면 **분당 약 8건**이다.

| 상황 | 분당 요청 | 비고 |
| --- | ---: | --- |
| 1인 대화 | 약 8 | 대체로 여유 |
| 3인 동시 (도그푸딩) | 약 24 | **한 키로는 넘칠 가능성이 높다** |

**"각자 자기 무료 티어 키를 쓴다"는 이 구조에서 성립하지 않는다.** AI서버는 한 대이고
키를 하나 들고 있어서, 누가 말하든 같은 키로 나간다. 사용자별 키 라우팅은 만들지 않는다 —
계약에도 없고 만들 이유도 없다.

**그래서 도그푸딩은 시간을 나눠서 한다.** 3인이 동시에 말하지 않고 순서대로 한다.
동시성이 정말 필요해지면 그때 유료 티어로 올린다.

**한도를 넘으면 어떻게 되나** — 분석은 빈 결과로, 응답은 정형 문장으로 떨어진다(§9).
대화가 멈추지는 않는다. 다만 **왜 정형 문장만 나왔는지 알 수 있어야** 하므로
`llm_rate_limited`를 다른 실패와 구분해서 남긴다.

**정확한 한도는 AI Studio에서 확인한다.** 공식 문서가 표로 주지 않고 콘솔을 가리키며,
3자 문서의 수치는 PRD §2.5에 따라 확정값으로 쓰지 않는다.

---

## 2.7 추측 실행 (speculative respond, 기본 OFF)

`AI_SPECULATIVE_RESPOND=true`일 때:

```
③(c) analyze 와 ⑤ respond(플래그 전부 false) 를 동시에 시작
⑤의 출력은 버퍼에 쌓고 Hume에 보내지 않는다
③(c) 완료 → ④ 판정
  플래그 전부 false  → 버퍼를 즉시 flush, 이후 토큰은 그대로 통과   (추가 지연 0)
  하나라도 true      → ⑤ 스트림 폐기, 플래그를 넣어 ⑤ 재호출          (트리거 턴만 +1호출)
```

트리거는 드물어야 정상(정밀도 우선)이므로 p95는 영향받지 않는다. 단 폐기된 호출도 과금되므로 ON은 측정 후에만.

## 2.8 Hume 계약 처리 세부

| 항목 | 처리 |
| --- | --- |
| 전체 이력 | Hume은 매 요청에 전체 이력을 보낸다. 우리는 **상태를 갖지 않는다** — 세션 캐시(§7)와 analyze 캐시만 메모리에 둔다 |
| `system` role 메시지 | Hume 콘솔 Config의 프롬프트가 실려 올 수 있다. **무시하고 우리 시스템 프롬프트를 쓴다.** 콘솔 프롬프트는 비워둔다 |
| user 메시지가 없는 요청 | 첫 인사 등. 고정 인사 문장 1개를 SSE로 반환하고 적재하지 않는다 |
| `time` | ms 단위. `elapsedSec` 폴백 계산에만 쓴다 |
| 청크 형식 | `{"id","object":"chat.completion.chunk","created","model":"clm","system_fingerprint":sid,"choices":[{"index":0,"delta":{"role":"assistant","content":…},"finish_reason":null}]}` → 마지막 `finish_reason:"stop"` → `data: [DONE]`. 공식 예제와 동일 |
| 끼어들기(barge-in) | Hume이 연결을 끊는다. 서버는 `respond` 스트림을 취소하고, **그때까지 보낸 텍스트로 assistant 턴을 적재**한다. user 턴은 이미 적재됨(§2.1 ⑦) |
| 배포 요건 | Hume이 공인 HTTPS로 호출한다. 로컬은 ngrok. URL은 `https://…/chat/completions`로 끝나야 한다 |
| 콘솔 Config | AI 담당이 생성·소유. CLM URL·언어(한국어) 설정. 프롬프트는 비움. 발급된 `config_id`를 백엔드 환경변수로 전달 (`request/backend/hume-config-id.md` 5번) |

---

# 3. 음성 valence 규칙 (F3-01, PRD §14-1 해소)

## 3.1 매핑표

`ai-server/rules/valence_mapping.json`이 단일 출처. 48종 이름은 Hume Python SDK `EmotionScores`의 alias와 **철자·대소문자·괄호까지 동일**하다.

| 극성 | 수 | 감정 |
| --- | :---: | --- |
| **+1 긍정** | 18 | Admiration, Adoration, Aesthetic Appreciation, Amusement, Awe, Calmness, Contentment, Ecstasy, Excitement, Interest, Joy, Love, Pride, Relief, Romance, Satisfaction, Surprise (positive), Triumph |
| **−1 부정** | 21 | Anger, Anxiety, Awkwardness, Boredom, Confusion, Contempt, Disappointment, Disgust, Distress, Doubt, Embarrassment, Empathic Pain, Envy, Fear, Guilt, Horror, Pain, Sadness, Shame, Surprise (negative), Tiredness |
| **0 중립 (제외)** | 9 | Concentration, Contemplation, Craving, Desire, Determination, Entrancement, Nostalgia, Realization, Sympathy |

중립으로 뺀 이유: 방향이 없는 인지·각성 상태(Concentration·Contemplation·Determination·Realization), 양가적(Nostalgia·Craving·Desire·Entrancement), 타인 지향(Sympathy). 넣으면 노이즈만 는다. **Tiredness가 부정인 것이 데모 1번 장면의 전제다** — 지친 톤에서 음성 valence가 음수로 가야 갭이 벌어진다.

## 3.2 계산

```
P = Σ scores[e] for e in 긍정
N = Σ scores[e] for e in 부정
if P + N < 0.05:  voice_valence = null        # 측정 불가 — 중립만 찍힌 발화
else:             voice_valence = round((P − N) / (P + N), 2)   # −1.00 ~ +1.00
```

- 정규화 차분을 쓰는 이유: 목소리 크기·발화 길이에 따른 점수 총량 변화에 불변이고, 범위가 자연히 ±1이다.
- 가중치는 전부 1. **20쌍에서 갭 방향 일치율이 90% 미만일 때만** 개별 감정의 극성 분류를 재검토한다. 가중치 값을 조정하는 것은 하지 않는다 — 20쌍으로 48개 가중치를 맞추는 것은 과적합이다.
- 동일 입력 → 동일 출력(결정적). 재현성 ±0.1 지표(§1.4)의 음성 쪽 절반은 Hume 점수의 안정성에 달렸고, 우리 함수는 편차를 더하지 않는다.
- `topProsody`(적재용 상위 5개)는 이 함수와 무관하게 점수 내림차순으로 자른다.

---

# 4. 갭·임계값 (F3-03·F3-04, PRD §14-5)

## 4.1 갭

```
gap = null                          if text_valence is null or voice_valence is null
gap = round(|text − voice|, 2)      otherwise        # 0.00 ~ 2.00
```

## 4.2 트리거

| 모드 | 임계값 | 출처 |
| --- | --- | --- |
| `fixed` (세션 5회 미만) | `gapThreshold` (세션 컨텍스트 §7) | 백엔드가 내려주는 값. 없으면 `.env` `AI_GAP_THRESHOLD_FIXED` |
| `personal` (5회 이상) | `gapThreshold` = 개인 평균 + 표준편차 | 백엔드가 계산해 내려준다. AI서버는 계산하지 않는다 |

`gapTriggered = gap is not null and gap >= threshold`. 갭이 `null`이면 항상 `false`.

## 4.3 고정 임계값 결정 절차 (착수 항목)

1. 20쌍(같은 문장 × 밝은/지친 톤)을 파이프라인에 넣어 쌍마다 `gap_밝음`, `gap_지침`을 얻는다.
2. 후보 임계값 θ를 0.30~1.20, 0.05 간격으로 훑는다.
3. 각 θ에서 **트리거 정확도** = (지친 톤에서 트리거 ∧ 밝은 톤에서 미트리거)인 쌍의 비율.
4. 정확도가 최대인 θ 구간의 **중앙값**을 택한다 (경계값을 피한다).
5. 결과와 표를 `ai-server/eval/reports/threshold-{date}.md`에 남기고 `.env`·백엔드 설정을 갱신한다.

측정 전까지 `.env.example`의 값은 **임시**이며 코드 상수로 박지 않는다. 계약서 §2-4의 `0.85` 예시와 같은 값을 임시로 쓴다.

---

# 5. 위기 감지 (F4-02·F4-03, PRD §14-2 해소)

## 5.1 두 계층

| 계층 | 감지 주체 | 대상 | 항상 동작 |
| --- | --- | --- | :---: |
| **Tier A — 직접 표현** | `rules/crisis.py` 정규식 | 죽음·자살·자해 의도를 직접 말하는 표현 | **예.** LLM 실패 경로에서도 |
| **Tier B — 간접·절망 표현** | 분석 호출의 `crisis` 판정 | "이제 그만 쉬고 싶어요", "내가 없어지는 게 낫겠어" 류 | LLM 실패 시 미감지 (수용된 한계) |

`crisis = tierA OR tierB`. `crisis.by`는 Tier A면 `"rule"`, Tier B만이면 `"llm"`.

Tier B를 규칙으로도 잡지 않는 이유: "희망이 없다"는 시험·프로젝트 얘기에도 나온다. 재현율 우선이지만 **일상 발화마다 109가 뜨면 사용자가 떠난다**(FR-034의 근거와 같다). 그래서 간접 표현은 맥락을 볼 수 있는 LLM에 맡기고, 규칙은 문맥 없이도 위기가 명확한 표현만 잡는다. 대신 Tier B 표현 목록을 분석 프롬프트에 **힌트로 실어** LLM의 재현율을 끌어올린다.

## 5.2 키워드 출처

`ai-server/rules/crisis_keywords.json`이 단일 출처이며 항목마다 출처를 적는다. 자체 추정 표현은 넣지 않는다 (PRD §2.5).

| 출처 | 확인 내용 |
| --- | --- |
| 보건복지부·한국생명존중희망재단 심리부검 (2015~2023, 9년) | 자살사망자의 **96.6%**가 사망 전 경고신호를 보였고, 주변이 인지한 비율은 **23.8%**. 언어적 신호: "죽고 싶다", "죽어야 편해질 것 같다", "희망이 없다", "나는 가망이 없다", "내가 없어지는 것이 낫다" — [하이닥 보도](https://news.hidoc.co.kr/news/articleView.html?idxno=33198) |
| 광주광역시자살예방센터 자살위험신호 | 직접: "정말 죽고 싶어", "차라리 죽었으면 좋겠어", "자살하는 사람의 마음을 알 것 같아" / 절망·죄책: "내가 없어지는 것이 낫겠어", "나는 아무짝에 쓸모없어", "내가 사라지면 모든 것이 해결될거야" — [gmhc.kr](https://www.gmhc.kr/contents.do?S=S02&M=0202000000) |
| 국립정신건강센터 국가트라우마센터 (정책브리핑) | 언어적 신호: 죽음에 대한 이야기, 자살 계획 이야기, SNS 게시 — [korea.kr](https://www.korea.kr/news/healthView.do?newsId=148894818) |

## 5.3 매칭 규칙

- 전사에서 공백·구두점을 제거한 문자열에 대해 **어간 패턴** 매칭 (`죽고싶`, `죽어버리`, `죽었으면`, `자살`, `목숨을끊`, `생을마감`, `사라지고싶`, `없어지고싶`, `살기싫`, `살고싶지않`, `다끝내고싶`, `뛰어내리`, `목을매`, `자해`, `손목`…). 전체 목록과 각 항목의 출처는 JSON.
- 부정어 예외를 두지 않는다 ("죽고 싶지 않아"도 감지). 재현율 우선이고, 이 문장을 말하는 사람에게 109 안내가 뜨는 것은 오탐이 아니다.
- 감지 결과에 **매칭된 표현을 남기지 않는다.** `crisis_event`·로그·`/internal/turns` 어디에도 발화 내용이 가지 않는다 (FR-092). `by: "rule"`만.

## 5.4 합성 평가 세트

`ai-server/eval/crisis_set.jsonl` — 직접 표현 / 간접 표현 / **유사하지만 위기가 아닌 문장**(오탐 확인) 3군. 실제 상담 사례를 쓰지 않고 팀이 작성한다(spec F11-04). 목표: 전체 재현율 ≥ 95%, **Tier A 단독 재현율(직접 표현 군) = 100%**. 후자가 100%가 아니면 규칙을 늘린다.

---

# 6. 태깅 (F6-01·F6-02)

## 6.1 규칙

1. 분석 호출이 태그 후보를 **기본형 명사**로 최대 3개 반환한다 (`회의`, `팀장`, `야근`).
2. 코드가 각 태그를 전사와 대조한다: `normalize(tag) in normalize(transcript)` — 공백·구두점 제거 후 **부분 문자열 포함**. `회의가 세 개나` ⊃ `회의` ✓, `팀장님이` ⊃ `팀장` ✓.
3. 미포함 태그는 폐기하고 `ops_error_log`에 **태그 문자열 없이** 건수만 남긴다.
4. 통과한 태그만 `/internal/turns`로 보낸다. 백엔드는 재검증하지 않는다(계약 §3-2).
5. 2글자 미만 태그, 불용어(`오늘`, `진짜`, `사람`, `것`, `때`…)는 폐기. 목록은 `rules/tag_stopwords.json`.

## 6.2 동의어 병합을 하지 않는 이유 (spec F6-01 수정)

spec F6-01은 `회의가`·`미팅`·`팀장님` → `회의`를 예시로 들지만, 사용자가 "미팅"이라고 말한 턴에 `회의` 태그를 달면 **원문에 없는 태그**가 되어 FR-043·§1.4 "원문 외 태그 0건"을 어긴다. 두 조항이 충돌하면 **지표가 이긴다** — 지표는 코드로 증명 가능한 유일한 방어선이기 때문이다.

v1은 **활용형 정규화(어간 포함 대조)만** 한다. `미팅`과 `회의`는 별개 태그로 집계된다. 세션 기존 태그를 분석 호출에 넘겨(`known_tags`) 같은 표현에는 같은 기본형이 붙도록 유도하는 것까지가 v1의 정규화다. 동의어 병합이 필요해지면 **태그 ↔ 원문 표현(`surface`)을 분리 저장하는 계약 변경**이 먼저다.

---

# 7. 세션 컨텍스트 — `GET /internal/sessions/{id}` (계약 §3-4, 확정)

AI서버가 알아야 하지만 Hume이 주지 않는 것들이다. 계약 v1.3에서 신설됐고 v1.4에서 `lastTurnIndex`가 붙었다.

| 받는 값 | 쓰이는 곳 | 조회 실패 시 |
| --- | --- | --- |
| `thresholdMode`, `gapThreshold` | ④ 트리거, `/internal/turns`의 `thresholdMode` | `.env` 고정값 (**캐시 히트일 때만** — 아래) |
| `startedAt`, `usedSec`, `softWrapSec`, `hardCutSec` | 5분 마무리 유도(F2-03 B 측) | Hume `time.end`로 근사 |
| `status` + 세션 존재 여부 | **CLM 인증** | **401 (fail-closed)** |
| `lastTurnIndex` (v1.4) | `turnIndex` 채번 시드 | — |
| `recentObservations[]` (문장+태그) | F8-02 근거 기반 제안 (P1) | 제안 경로 비활성 |
| `demoMode` | 로깅 상세도 | 무시 |

## 7.1 인증 — fail-closed

`language_model_api_key`(앱이 `session_settings`로 보내야 해서 웹 번들에 노출)는 쓰지 않는다. 대신 이 조회가 인증을 겸한다. `sessionId`는 백엔드가 **UUIDv4(122비트)** 로 발급한다.

| 상황 | Hume에 돌려주는 것 |
| --- | --- |
| 200 `status: "open"` | 정상 처리 |
| 200 `status: "ended"` | **401** — 종료된 세션으로 들어오는 요청이다 |
| 404 | **401** |
| 캐시 히트 | **통과** (백엔드 상태와 무관) |
| 캐시 미스 + 5xx·타임아웃 | **401 (fail-closed)** |

**마지막 줄이 요청서에서 제안한 것과 반대 방향이다.** 처음엔 가용성을 위해 fail-open(고정 임계값으로 통과)을 제안했으나, 백엔드가 지적한 대로 그러면 "백엔드 장애 시간 = 인증 무방비 시간"이 된다. **fail-closed로 잃는 가용성이 없다** — 백엔드가 죽어 있으면 `POST /api/session/start`도 죽어 있어 새 세션 자체가 생기지 않고, 진행 중인 대화는 캐시가 지킨다. F5-04(백엔드 다운에도 대화 계속)의 목적은 캐시가 달성한다.

## 7.2 캐시와 재조회

세션당 **1회** 조회 후 메모리 캐시(TTL = `hardCutSec` + 30분 이어하기 창). 실시간 경로에 매 턴 홉을 더하지 않기 위함이다. **다만 아래 두 경우에는 캐시를 버리고 다시 조회한다.**

| 재조회 방아쇠 | 이유 |
| --- | --- |
| 같은 `sid`의 직전 턴에서 `AI_SESSION_REFETCH_IDLE_SEC`(초기 60초) 이상 경과 | **이어하기 감지.** 재연결은 AI서버에 보이지 않으므로(Hume은 매 턴 상태 없는 요청에 `custom_session_id`만 실어 보낸다) 유휴 간격으로 간접 감지한다 |
| 들어온 이력의 user 메시지 수 > 내 카운터 | 보조 신호. 이어하기 때 Hume이 복원 이력을 싣는지는 미실측이라 주 신호로 쓰지 않는다 |

**거짓 양성이 싸고 거짓 음성이 비싸므로** 느슨하게 잡았다. 대화 중 60초 침묵도 방아쇠에 걸리지만, 그때 드는 비용은 불필요한 조회 1회이고 결과는 같은 값이다.

## 7.3 `turnIndex` 채번 (계약 §3-2 v1.4, `response/backend/turn-index-numbering.md`)

```
turnIndex = lastTurnIndex(조회 시점 값) + 그 조회 이후 발급한 개수
```

카운터는 **세션 캐시 엔트리 안에** 산다. 그래서 캐시가 죽으면 카운터도 같이 죽고, 캐시가 죽으면 다음 요청이 재조회를 하므로 **재시작이 곧 재시드**다. **0에서 시작하는 경로가 설계상 없다** — 0은 백엔드가 `lastTurnIndex: 0`을 준 경우, 즉 실제로 적재된 턴이 없을 때뿐이다.

user 턴과 assistant 턴의 번호는 **user 턴 처리 시점에 둘 다 미리 잡는다**(user = n+1, assistant = n+2). assistant 적재는 스트림 종료 후라 지연되는데, 미리 잡아두면 순서가 뒤집히지 않는다.

**`occurredAt`은 발화 시각이고 재시도에서 불변이다** (계약 §3-2 v1.5). 페이로드를 만들 때 밀리초 정밀도로 한 번 찍고 재시도에 같은 문자열을 다시 보낸다. 같은 세션 직전 턴과 값이 같으면 1ms를 더한다 — 백엔드의 중복 판별이 이 필드로 재시도와 충돌을 가르기 때문이다.

---

# 8. 배치 경로

## 8.1 관찰 문장화 (`POST /internal/observations`, F7-04)

| 항목 | 내용 |
| --- | --- |
| 입력 | 계약 §3-3 그대로 — `tag, occurrences, tagAvgGap, userAvgGap, ratio`. 원본 대화 없음 |
| 모델 | `AI_MODEL_OBSERVE` (초기 `gemini-2.5-pro`), `reasoning_effort: medium` |
| 프롬프트 요지 | 숫자를 문장으로. **숫자를 쓰지 않는다**("7번"·"1.8배" 금지 — 정확한 수치는 evidence 카드가 보여준다). 없는 사실·원인 추정·조언 금지. 1문장 |
| 사후 검사 (`observe_guard`) | ① 문장에 아라비아 숫자가 있으면 폐기 ② `tag` 문자열이 없으면 폐기 ③ 금칙어(진단명·약물) 있으면 폐기 ④ 2문장 이상이면 폐기 |
| 실패 | **관찰을 만들지 않는다.** 템플릿 대체 없음(계약 §3-3). 200 대신 `422 SENTENCE_REJECTED` |

숫자를 문장에 넣지 않는 것이 "문장 ↔ evidence 불일치 0건"을 가장 싸게 지키는 방법이다. 불일치가 날 숫자가 문장에 없다.

## 8.2 세션 요약 (`POST /internal/summaries`, F2-05 — 계약 §3-5, 확정)

| 항목 | 내용 |
| --- | --- |
| 입력 | 계약 §3-5 그대로 — `sessionId`, `turns[].{role, transcript}`. **valence·갭·태그는 오지 않는다** |
| 호출 조건 | `endReason`이 `user_end`·`soft_wrap`·`hard_cut`일 때만. `timeout`(F2-06 스케줄러)은 백엔드가 호출하지 않고 `summary: null`로 닫는다 |
| 모델 | `AI_MODEL_SUMMARY` (초기 `gemini-3.5-flash-lite`), 동기 · 타임아웃 `AI_SUMMARY_TIMEOUT_MS`(초기 2500 — 계약의 3초 안쪽에서 끝내기 위해 여유를 둔다) |
| 프롬프트 | `prompts/summary.system.md` |
| 실패 | `422 SUMMARY_REJECTED`(사후 검사 실패) 또는 5xx. 백엔드는 재시도 없이 `summary: null` |

LLM 호출 지점을 AI서버 하나로 모으는 쪽을 택했다. 백엔드가 직접 부르는 대안도 가능했지만, 그러면 금칙어 검사·로깅 정책을 두 곳에서 지켜야 한다.

## 8.3 요약 사후 검사 (`summary_guard`)

| 폐기 조건 | 이유 |
| --- | --- |
| 아라비아 숫자 포함 | 회의 3개·2시간 같은 수치가 목록에 남는다 |
| 2문장 이상 · 물음표 | 목록의 라벨이지 편지가 아니다 |
| 금칙어(진단명·약물·치료) | `rules/guard` 공용 |
| 감정 단정 표현 | "힘든 하루"·"괜찮은 하루" 모두 폐기. **요약에 목소리 정보가 오지 않으므로 단정할 근거 자체가 없다** |

**갭이 요약으로 새지 않는 것이 이 검사의 핵심이다.** S02는 수치를 숨기는데(FR-031) 요약이 "말과 달리 지쳐 보이는 대화였습니다"라고 적으면 화면이 숨긴 것을 문장이 흘린다.

---

# 9. 실패 처리 (PRD §9.4 대체)

| 상황 | 동작 | 대화 |
| --- | --- | :---: |
| 분석 호출 실패·타임아웃 | `text_valence=null, tags=[], crisis_llm=null`. 갭 미산출, 되묻기 생략 | **계속** |
| 프로소디 점수 누락 | `voice_valence=null`. 갭 미산출 | 계속 |
| 응답 호출 실패·refusal | 정형 응답 1문장. 위기 플래그면 109 포함. `ops_error_log` | 계속 |
| 응답 스트림 중 끊김(끼어들기) | 스트림 취소, 보낸 만큼 assistant 턴 적재 | 계속 |
| 태그 원문 대조 실패 | 해당 태그 폐기. 0개면 F7 집계 제외(valence 통계는 포함) | 계속 |
| 세션 컨텍스트 조회 실패 — **캐시 히트** | `.env` 고정 임계값으로 진행, 경고 로그 | 계속 |
| 세션 컨텍스트 조회 실패 — **캐시 미스** | **401을 Hume에 반환 (fail-closed, §7.1)** | **중단** |
| `/internal/turns` 실패 | 5xx·타임아웃만 `AI_TURN_POST_RETRIES`회(계약 v1.3 기준 **3회**, 지수 백오프) 후 포기. 4xx는 재시도 없음. `ops_error_log` | 계속 |
| 요약 사후 검사 실패 | `422 SUMMARY_REJECTED`. 백엔드가 `summary: null` | — |
| **위기 LLM 판정 실패** | **Tier A 규칙이 단독 동작** | 계속 |
| 관찰 문장 검사 실패 | 관찰 미생성. 템플릿 없음 | — |

실시간 경로에서 **대화를 멈추는 실패는 인증 실패 하나뿐이다.** 나머지는 전부 기능을 줄이면서 대화를 계속한다. 인증만 예외인 이유는 §7.1에 있다 — 그 경로는 애초에 정상 사용자에게 열리지 않는다.

---

# 10. 관측·로깅 (NFR-07, FR-092)

턴마다 구조화 로그 1건: `sessionRef, turnIndex, latency{ctx, analyze, respond_ttft, respond_total, post}, analyze_hit(cache), gapTriggered, crisisBy, tagsKept, tagsDropped, model{analyze, respond}, tokens{in,out}`.

**절대 넣지 않는 것**: `transcript`, 응답 텍스트, 매칭된 위기 표현, 폐기된 태그 문자열, **`sessionId` 원본**.

`sessionId`는 §4 CLM 인증 수단이라 계약 §1-1이 "비밀과 동급"으로 규정한다 — 로그를 본 사람이 그 세션인 척 CLM을 부를 수 있다. 대신 **`sessionRef` = `SHA-256(sessionId)[:8]`** 을 쓴다(백엔드와 같은 방식이라 양쪽 로그를 한 세션으로 맞춰 볼 수 있다). 화이트리스트에서 빼는 것만으로는 다음에 다른 이름으로 넘기면 다시 새므로, **`sid`·`sessionId`·`session_id`·`customSessionId`·`custom_session_id`를 이름 단위로 거부**한다 (2026-09-05, `request/ai/integration-round-1.md` 2번). 로그 필드명 화이트리스트로 강제하고, 테스트가 로그 출력에 한글 문장이 섞이지 않는지 검사한다.

---

# 11. 평가 (F11-04)

| 세트 | 위치 | 지표 | 목표 |
| --- | --- | --- | --- |
| 갭 20쌍 | `eval/gap_pairs/` (전사 + prosody 스냅샷 JSON — 음성 파일은 저장하지 않는다) | 갭 방향 일치율 | ≥ 90% |
| 재현성 | 같은 스냅샷 3회 | 갭 편차 | ±0.1 |
| 위기 합성 세트 | `eval/crisis_set.jsonl` | 재현율 (전체 / Tier A 단독) | ≥ 95% / 100% |
| 태그 대조 | `eval/tag_cases.jsonl` | 원문 외 태그 | 0건 |
| 관찰 문장 | `eval/observe_cases.jsonl` | 숫자 포함·태그 누락 | 0건 |
| 채널 독립성 | 코드 검사 | 분석·응답 호출 payload에 `prosody` 키 | 0건 (TC-24) |

`make eval` 한 번에 전부 출력. **음성 파일은 어디에도 저장하지 않는다** — 20쌍은 Hume이 준 전사·prosody 점수 스냅샷으로 재생한다. 녹음은 도그푸딩 중 팀원이 직접 말하고, 그때 서버가 받은 요청 body를 익명화해 스냅샷으로 남긴다.

---

# 12. 레포 구조 (`ai-server/`)

```
ai-server/
├─ README.md
├─ pyproject.toml
├─ .env.example
├─ app/
│  ├─ main.py               FastAPI — POST /chat/completions · POST /internal/observations · GET /healthz
│  ├─ clm/                  요청 파싱(마지막 user 턴·이력·system 제거), SSE 청크 변환
│  ├─ rules/                ★ 순수 함수 + 단위 테스트. 네트워크 호출 금지
│  │  ├─ loader.py          rules/*.json 로딩 + 불변식 검사(48종·극성 겹침·Tiredness)
│  │  ├─ valence.py         48종 → voice_valence
│  │  ├─ gap.py             gap · gapTriggered · 임계값 우선순위
│  │  ├─ crisis.py          Tier A 정규식 · 두 계층 합산
│  │  ├─ tags.py            원문 대조 · 불용어
│  │  ├─ sentence.py        숫자·문장 수·물음표 검사 (관찰·요약 공용)
│  │  ├─ guard.py           금칙어(진단·약물·치료)
│  │  ├─ observe_guard.py   관찰 문장 검사
│  │  ├─ summary_guard.py   요약 검사 (갭 누출 차단)
│  │  └─ turns.py           채번 · occurredAt · 재조회 판단
│  ├─ llm/                  LLM 호출은 여기에만
│  │  ├─ client.py          클라이언트 · 프롬프트 로딩 · 모델별 파라미터 · assert_no_prosody
│  │  ├─ analyze.py         분석 호출 (전사만, 400ms, 실패는 빈 결과)
│  │  ├─ respond.py         응답 스트리밍 (플래그만, 메타 태그 없음)
│  │  └─ batch.py           observe · summary + 사후 검사 연결
│  ├─ session.py            세션 컨텍스트 캐시 · 백엔드 조회
│  ├─ backend_client.py     /internal/turns 적재 (fire-and-forget, 재시도)
│  └─ telemetry.py          구조화 로그 (필드 화이트리스트)
├─ prompts/                 ★ 프롬프트 전문의 단일 출처
│  ├─ analyze.system.md
│  ├─ respond.system.md
│  ├─ observe.system.md
│  └─ summary.system.md     세션 요약 (계약 §3-5)
├─ rules/                   ★ 데이터로서의 규칙
│  ├─ valence_mapping.json
│  ├─ crisis_keywords.json
│  └─ tag_stopwords.json
├─ eval/                    20쌍 스냅샷 · 합성 세트 · run_eval.py · reports/(gitignore)
│  └─ fixtures/internal/     ★ 내부 API 고정 JSON — 백엔드와 같은 파일로 검증한다
└─ tests/
```

- `app/rules/`에 네트워크 호출이 생기면 리뷰에서 반려한다. 이 폴더가 §1 경계의 구현체다.
- `app/llm/` 밖에서 LLM SDK를 import하면 반려한다.

---

# 13. 환경변수

```
# 서버
AI_PORT=8100
AI_PUBLIC_URL=                      # Hume Config에 등록한 https://…/chat/completions 의 origin

# 백엔드 연동
BACKEND_BASE_URL=                   # 백엔드 로컬 포트는 8080
INTERNAL_SHARED_SECRET=             # X-Internal-Secret
AI_TURN_POST_RETRIES=3              # 계약 §3-2 (v1.3). 5xx·타임아웃만, 지수 백오프
AI_SESSION_LOOKUP_TIMEOUT_MS=800    # 통합 테스트(양쪽 터널) 기간에는 2000
AI_SESSION_LOOKUP_CONNECT_RETRY=1   # 연결 단계 실패에만. 4xx·5xx 응답은 재시도하지 않는다
AI_SESSION_REFETCH_IDLE_SEC=60      # 이 시간 이상 유휴면 세션 컨텍스트 재조회 (§7.2 이어하기 감지)

# LLM
GOOGLE_API_KEY=
AI_LLM_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai/
AI_MODEL_ANALYZE=gemini-3.5-flash-lite
AI_MODEL_RESPOND=gemini-3.8-flash
AI_MODEL_OBSERVE=gemini-2.5-pro
AI_MODEL_SUMMARY=gemini-3.5-flash-lite
AI_ANALYZE_TIMEOUT_MS=400
AI_SUMMARY_TIMEOUT_MS=2500          # 계약 §3-5의 3초 안쪽에서 끝낸다
AI_SPECULATIVE_RESPOND=false

# 규칙
AI_GAP_THRESHOLD_FIXED=0.85         # 임시. 20쌍 측정 후 교체 (§4.3). 백엔드 조회값이 있으면 그것이 우선
AI_VOICE_VALENCE_MIN_MASS=0.05      # P+N 이 이 값 미만이면 voice_valence=null
```

---

# 14. 결정 기록

| # | 결정 | 사유 | 일자 |
| --- | --- | --- | --- |
| AI-01~11 | §0 표 | — | 2026-09-03 |
| AI-12 | `decisions.md`가 저장소에 없어 AI 결정은 이 표에 둔다 | 파일이 올라오면 #16부터 이관 | 2026-09-03 |
| AI-13 | 응답 스트림 메타 태그 전면 폐지 (`<v>`·`<m>` 모두) | TTFT + 누출 실패 모드 제거. §2.2 | 2026-09-03 |
| AI-14 | 관찰 문장에 숫자 금지 | 불일치 0건을 가장 싸게 지키는 방법. §8.1 | 2026-09-03 |
| AI-15 | `turnIndex` 카운터를 세션 캐시 엔트리 안에 둔다 | 캐시가 죽으면 카운터도 죽고, 캐시가 죽으면 재조회가 돈다 — 재시작이 곧 재시드가 되어 "0부터 시작" 경로가 사라진다. §7.3 | 2026-09-04 |
| AI-16 | 이어하기를 **유휴 간격**으로 감지한다 | 재연결은 AI서버에 보이지 않는다. 거짓 양성 비용은 조회 1회, 거짓 음성 비용은 인덱스 어긋남. §7.2 | 2026-09-04 |
| AI-17 | 세션 조회 실패 시 **fail-closed**(요청서의 fail-open 철회) | fail-open은 "백엔드 장애 시간 = 인증 무방비 시간". 백엔드가 죽으면 새 세션도 안 생기므로 잃는 가용성이 없다. §7.1 | 2026-09-04 |
| AI-18 | 통합 테스트에 **fail-open 개발 스위치를 만들지 않는다** | 개발 편의 스위치는 배포까지 따라간다. 타임아웃 상향(`.env`)으로 대신한다. `response/backend/integration-test-path.md` | 2026-09-04 |
| AI-19 | 요약 모델은 저비용 모델 | 입력이 짧고 출력이 1문장이며 비실시간이다. 3초 예산 안에서 여유를 확보하는 쪽이 품질보다 이득이 크다. §8.2 | 2026-09-04 |
| AI-20 | **LLM 벤더 교체 (Anthropic → OpenAI → Google)** | 팀 결정(2026-09-05, 크레딧 소진으로 Gemini 무료 티어). 설계·프롬프트·가드는 벤더 중립이라 두 번 다 바뀌지 않았고, 고친 범위는 `app/llm/`과 환경변수뿐이다 — LLM 호출을 한 계층에 가둔 §12 경계가 실제로 값을 했다 | 2026-09-05 |
| AI-23 | Gemini의 **OpenAI 호환 엔드포인트**를 쓴다 (`base_url` 교체) | 네이티브 SDK로 갈아타면 네 호출부를 다시 쓰고 스트리밍을 다시 검증해야 한다. 호환 계층은 chat completions·스트리밍·`response_format`·`reasoning_effort`를 모두 지원하므로 **환경변수 세 줄**로 끝난다. 베타라는 점은 감수한다 — 안 되면 그때 네이티브로 간다 | 2026-09-05 |
| AI-24 | **무료 티어의 제약은 분당 요청 수다** | 턴마다 LLM 호출이 2건(분석+응답)이라 대화 1개가 분당 6~8건을 쓴다. 3인 동시 도그푸딩은 한 키로 감당이 안 된다 — §2.9 | 2026-09-05 |
| AI-22 | 로그의 세션 식별자를 **해시(`sessionRef`)로** 바꾼다 | 화이트리스트에 `sid`를 넣어 둔 탓에 인증 수단이 로그로 샜다(통합 1차에서 백엔드가 30분에 7건 발견). 이름 단위로 거부해 재발을 막는다. §10 | 2026-09-05 |
| AI-21 | 파라미터 거부를 **런타임에 학습**한다 | 모델마다 받는 파라미터가 다르고 문서에 다 적혀 있지 않다. 400을 맞으면 그 파라미터를 빼고 한 번 다시 시도하고 기억한다 — 라인업 변경이 서비스 중단으로 번지지 않게 | 2026-09-05 |
