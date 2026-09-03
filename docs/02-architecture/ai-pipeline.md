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
| AI-06 | LLM 모델 (초기값, 전부 환경변수) | 분석 `claude-haiku-4-5` · 응답 `claude-sonnet-5` · 문장화·요약 `claude-opus-5` | 분석은 지연 예산 400ms, 응답은 한국어 품질과 TTFT의 균형, 배치는 지연이 없으니 최상위. §2.6 |
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
| 모델 | `AI_MODEL_ANALYZE` (초기 `claude-haiku-4-5`), temperature 0 |
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
| 모델 | `AI_MODEL_RESPOND` (초기 `claude-sonnet-5`), adaptive thinking, `effort: low`, 스트리밍 |
| 입력 | 시스템 프롬프트 + 대화 이력(텍스트만, Hume이 준 전체 이력에서 `system` role 제거) + **플래그 블록** |
| 플래그 블록 | `gapTriggered`, `crisis`(+`crisisBy`), `softWrap`, `adviceRequested`, `elapsedMin`. **수치는 없다** |
| 출력 | 대화 텍스트. 1~3문장, 구어체. 메타 태그·JSON·마크다운 없음 |
| 프롬프트 요지 | PRD §9.3 조항 2~5. 되묻기는 "감정을 단정하지 않고 묻는다". 위기면 톤 전환 + 109 안내 + 대화 계속. 조언은 `adviceRequested`일 때만, 그것도 관찰 근거가 있을 때만(F8-02 — 근거 관찰은 §7 세션 컨텍스트에 실어 받는다) |
| 실패 | 호출 실패·`stop_reason: refusal` → 정형 응답 1문장으로 대체, `ops_error_log`. 위기 플래그가 켜져 있으면 정형 응답에도 109 안내 포함 |
| 전문 | `ai-server/prompts/respond.system.md` |

**주의 — 모델 파라미터**: `claude-sonnet-5`·`claude-opus-5`는 `temperature` 등 샘플링 파라미터를 받지 않는다(400). 응답의 일관성은 프롬프트로 잡는다. `claude-haiku-4-5`는 temperature 0을 받는다.

## 2.6 지연 예산 (NFR-01 p95 2초)

```
[발화 종료] → Hume STT·프로소디 확정 → CLM 요청 → ② (첫 턴만 ~20ms)
           → ③(c) analyze  ≤ 400ms
           → ⑤ respond TTFT ≤ 600ms 목표
           → Hume TTS 첫 오디오
```

- 우리가 통제하는 구간은 ②③⑤이고 목표 합계 **≤ 1.0초**. Hume 양단(STT 확정·TTS 첫 바이트)이 나머지를 쓴다.
- 턴마다 구간별 지연을 계측해 로그(발화 내용 없이)로 남긴다. TC-12의 수치는 여기서 나온다.
- **p95가 깨지면** 순서대로: ① `AI_MODEL_RESPOND`를 `claude-haiku-4-5`로 ② 추측 실행 ON(§2.7) ③ 분석 타임아웃 축소(300ms). 세 개를 한 번에 바꾸지 않는다.

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

# 7. 세션 컨텍스트 — 백엔드 내부 조회 (요청 중)

AI서버가 알아야 하지만 Hume이 주지 않는 것들이다. `request/backend/session-context-lookup.md`로 요청했다.

| 필요한 값 | 쓰이는 곳 | 없으면 |
| --- | --- | --- |
| `thresholdMode`, `gapThreshold` | ④ 트리거, `/internal/turns`의 `thresholdMode` | `.env` 고정값으로 대화 계속 |
| `startedAt`, `softWrapSec`, `hardCutSec` | 5분 마무리 유도(F2-03 B 측) | Hume `time.end`로 근사 |
| 세션 존재 여부 | **CLM 인증** — 모르는 `custom_session_id`는 401 | 조회 실패 시 인증 통과(가용성 우선) + 경고 로그 |
| `recentObservations[]` (문장+태그) | F8-02 근거 기반 제안 (P1) | 제안 경로 비활성 |
| `demoMode` | 로깅 상세도 | 무시 |

- 세션당 **1회** 조회 후 메모리 캐시 (TTL = hardCutSec + 30분 이어하기 창). 실시간 경로에 매 턴 홉을 더하지 않는다.
- 이 조회가 곧 인증이므로 `sessionId`는 추측 불가능해야 한다 — 백엔드에 128비트 이상 엔트로피를 요청했다. `language_model_api_key`(앱이 `session_settings`로 보내야 함)는 웹 번들에 노출되므로 쓰지 않는다.

---

# 8. 배치 경로

## 8.1 관찰 문장화 (`POST /internal/observations`, F7-04)

| 항목 | 내용 |
| --- | --- |
| 입력 | 계약 §3-3 그대로 — `tag, occurrences, tagAvgGap, userAvgGap, ratio`. 원본 대화 없음 |
| 모델 | `AI_MODEL_OBSERVE` (초기 `claude-opus-5`), `effort: medium` |
| 프롬프트 요지 | 숫자를 문장으로. **숫자를 쓰지 않는다**("7번"·"1.8배" 금지 — 정확한 수치는 evidence 카드가 보여준다). 없는 사실·원인 추정·조언 금지. 1문장 |
| 사후 검사 (`observe_guard`) | ① 문장에 아라비아 숫자가 있으면 폐기 ② `tag` 문자열이 없으면 폐기 ③ 금칙어(진단명·약물) 있으면 폐기 ④ 2문장 이상이면 폐기 |
| 실패 | **관찰을 만들지 않는다.** 템플릿 대체 없음(계약 §3-3). 200 대신 `422 SENTENCE_REJECTED` |

숫자를 문장에 넣지 않는 것이 "문장 ↔ evidence 불일치 0건"을 가장 싸게 지키는 방법이다. 불일치가 날 숫자가 문장에 없다.

## 8.2 세션 요약 (F2-05) — 경로 미정, 요청 중

spec F2-05는 요약 생성을 A/B 담당으로 두지만 계약에 AI서버 경로가 없다. `request/backend/session-summary-endpoint.md`로 `POST /internal/summaries`(백엔드 → AI서버, 턴 텍스트 → 1문장) 신설을 제안했다. 백엔드가 직접 LLM을 호출하는 대안도 가능하나, LLM 호출 지점을 AI서버 하나로 유지하는 쪽이 금칙어 검사·로깅 정책을 한 곳에서 지킨다.

---

# 9. 실패 처리 (PRD §9.4 대체)

| 상황 | 동작 | 대화 |
| --- | --- | :---: |
| 분석 호출 실패·타임아웃 | `text_valence=null, tags=[], crisis_llm=null`. 갭 미산출, 되묻기 생략 | **계속** |
| 프로소디 점수 누락 | `voice_valence=null`. 갭 미산출 | 계속 |
| 응답 호출 실패·refusal | 정형 응답 1문장. 위기 플래그면 109 포함. `ops_error_log` | 계속 |
| 응답 스트림 중 끊김(끼어들기) | 스트림 취소, 보낸 만큼 assistant 턴 적재 | 계속 |
| 태그 원문 대조 실패 | 해당 태그 폐기. 0개면 F7 집계 제외(valence 통계는 포함) | 계속 |
| 세션 컨텍스트 조회 실패 | `.env` 고정 임계값, 인증 통과, 경고 로그 | 계속 |
| `/internal/turns` 실패 | 재시도 `AI_TURN_POST_RETRIES`회(초기 1, 계약 준수) 후 포기. `ops_error_log` | 계속 |
| **위기 LLM 판정 실패** | **Tier A 규칙이 단독 동작** | 계속 |
| 관찰 문장 검사 실패 | 관찰 미생성. 템플릿 없음 | — |

"대화" 열이 전부 "계속"인 것이 이 표의 요점이다. 실시간 경로에서 **대화를 멈추는 실패는 없다.**

---

# 10. 관측·로깅 (NFR-07, FR-092)

턴마다 구조화 로그 1건: `sid, turnIndex, latency{ctx, analyze, respond_ttft, respond_total, post}, analyze_hit(cache), gapTriggered, crisisBy, tagsKept, tagsDropped, model{analyze, respond}, tokens{in,out}`.

**절대 넣지 않는 것**: `transcript`, 응답 텍스트, 매칭된 위기 표현, 폐기된 태그 문자열. 로그 필드명 화이트리스트로 강제하고, 테스트가 로그 출력에 한글 문장이 섞이지 않는지 검사한다.

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
│  │  ├─ valence.py         48종 → voice_valence
│  │  ├─ gap.py             gap · gapTriggered
│  │  ├─ crisis.py          Tier A 정규식
│  │  ├─ tags.py            원문 대조 · 불용어
│  │  ├─ guard.py           금칙어(진단·약물·치료)
│  │  └─ observe_guard.py   관찰 문장 검사
│  ├─ llm/                  analyze · respond · observe — LLM 호출은 여기에만
│  ├─ session.py            세션 컨텍스트 캐시 · 백엔드 조회
│  ├─ backend_client.py     /internal/turns 적재 (fire-and-forget, 재시도)
│  └─ telemetry.py          구조화 로그 (필드 화이트리스트)
├─ prompts/                 ★ 프롬프트 전문의 단일 출처
│  ├─ analyze.system.md
│  ├─ respond.system.md
│  ├─ observe.system.md
│  └─ summary.system.md     (경로 확정 시)
├─ rules/                   ★ 데이터로서의 규칙
│  ├─ valence_mapping.json
│  ├─ crisis_keywords.json
│  └─ tag_stopwords.json
├─ eval/                    20쌍 스냅샷 · 합성 세트 · run_eval.py · reports/(gitignore)
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
BACKEND_BASE_URL=
INTERNAL_SHARED_SECRET=             # X-Internal-Secret
AI_TURN_POST_RETRIES=1              # 계약 §3-2 기본값. 데모 세션 신뢰도 이슈 시 상향

# LLM
ANTHROPIC_API_KEY=
AI_MODEL_ANALYZE=claude-haiku-4-5
AI_MODEL_RESPOND=claude-sonnet-5
AI_MODEL_OBSERVE=claude-opus-5
AI_ANALYZE_TIMEOUT_MS=400
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
