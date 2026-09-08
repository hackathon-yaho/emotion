# 답변 음성이 안 오는 원인 — 응답 모델이 죽었습니다 (TTFT 188초)

- 회신자: AI
- 회신일: 2026-09-08
- 관련: `backend/docs/blocked.md` · `../../request/ai/respond-fallback.md`

---

## 결론

**`gemini-3.8-flash`가 응답하지 않습니다.** 우리 응답 호출이 쓰던 모델입니다.

같은 키·같은 시각에 세 모델을 재봤습니다.

| 모델 | 쓰는 곳 | 첫 글자까지 |
| --- | --- | --- |
| `gemini-3.8-flash` | **응답·관찰** | **188초** · 재시도에서는 25초 읽기 타임아웃 |
| `gemini-3.5-flash` | — | 2.8초 |
| `gemini-3.5-flash-lite` | 분석·요약 | **1.4초** |

**Hume은 188초를 기다리지 않습니다.** 끊고 나가므로 사용자에게는 **답변 음성이 아예 안 들립니다.** "답변 음성이 오질 않네요"가 이것입니다.

## 로그가 같은 이야기를 합니다

```
13:15:50  respond  respondTtftMs=12302  turnIndex=2
13:18:16  error    reason=respond_failed:InternalServerError:503
13:18:16  respond  respondTtftMs=47438  turnIndex=4
13:18:55  error    reason=respond_failed:InternalServerError:503
13:19:13  respond  respondTtftMs=36867  turnIndex=8
```

**같은 요청 안에서 분석은 1.0~1.2초에 끝났습니다**(`analyzeMs=1145`·`1017`·`1195`). 세션 조회도 1.5~1.7초입니다. **느린 것은 응답 호출 하나뿐**이고, 그것만 다른 모델을 씁니다. 키·쿼터·네트워크 문제였다면 분석도 같이 죽습니다.

`503 InternalServerError`는 모델 과부하 신호입니다.

## 고친 것

**① 응답 모델을 `gemini-3.5-flash-lite`로 바꿨습니다.**

분석이 매 턴 이 모델로 **1초 안에** 돌아오고 있었습니다 — 실적이 이미 증명된 자리입니다. 관찰(`observe`)도 같은 죽은 모델을 쓰고 있어 함께 옮겼습니다.

**② 첫 글자에 시한을 걸었습니다** (`AI_RESPOND_TTFT_TIMEOUT_MS=5000`).

**이쪽이 더 중요한 수정입니다.** 모델이 무엇이든, **5초 안에 첫 글자가 안 오면 포기하고 다음 (키·모델) 칸으로 넘어갑니다.** 종전에는 188초를 그대로 매달려 있었고, 그동안 Hume은 이미 끊긴 뒤였습니다 — **늦게 오는 답은 안 온 답입니다.**

**말을 시작한 뒤에는 자르지 않습니다.** 중간에 끊긴 문장이 TTS로 나가면 사용자는 말이 잘리는 것을 듣습니다.

**③ 갈아타는 조건을 넓혔습니다.** 종전에는 429만 갈아탔습니다. 이번 건은 **503**이라 그대로 정형 문장으로 떨어졌습니다. 이제 429·5xx·타임아웃·연결 실패·시한 초과가 모두 다음 칸으로 넘어갑니다.

**④ 기동 워밍업이 `reasoning_effort`까지 얹어서 깨웁니다.** `flash-lite`는 이 파라미터를 거부하는데, 그 400을 **사용자의 첫 턴이 아니라 기동 때** 맞고 학습하도록 했습니다.

테스트 261건 통과, 배포했습니다.

## 백엔드가 확인해 주실 것 — 없습니다

**백엔드 쪽 값은 그대로입니다.** 모델 이름은 AI서버 환경변수라 Render를 건드릴 일이 없습니다.

**대화를 한 번 더 걸어 봐 주시면** 제가 로그로 판정하겠습니다. 이번에는 이렇게 갈립니다.

| 로그 | 뜻 |
| --- | --- |
| `respond  respondTtftMs=1000~2000` | **정상.** 음성이 나갑니다 |
| `respond_switched  status=rung1` | 1칸이 막혀 갈아탔지만 **답은 나갔습니다** |
| `respond_failed:RespondTimeout` | 5초 안에 첫 글자가 안 옴 — 다음 칸으로 넘어간 기록 |

## 남은 위험

**무료 티어 키가 하나입니다.** 지금은 `flash-lite`가 빠르지만, 한도(분당·일일)에 닿으면 같은 자리에서 또 막힙니다 — 어제는 12턴 중 10턴이 429였습니다.

**팀원이 각자 Google 키를 하나씩 내주시면 그대로 배가 됩니다**(`GOOGLE_API_KEY_2`·`GOOGLE_API_KEY_3`, 비면 안 씁니다). 한도는 키마다 따로 셉니다. [aistudio.google.com/apikey](https://aistudio.google.com/apikey)에서 카드 없이 발급됩니다.

## 로그 보는 법 — gcloud 없이

**말씀하신 대로 지금은 제 PC에서만 읽힙니다.** 세 가지 중 편한 것을 쓰시면 됩니다.

**① 저에게 말씀하시는 게 제일 빠릅니다.** 「로그 봐 달라」고 하시면 제가 읽고 판정해 문서로 남깁니다. 지금까지 그렇게 해 왔고, 판정에 필요한 맥락(어떤 태그가 무슨 뜻인지)이 제 쪽에 있습니다.

**② 브라우저로 직접** — gcloud 설치가 필요 없습니다. GCP 프로젝트 `emotion-voice-ai`에 접근 권한이 있어야 합니다.

```
https://console.cloud.google.com/logs/query?project=emotion-voice-ai
```

쿼리 상자에 이걸 넣으면 우리 구조화 로그만 나옵니다.

```
resource.type="cloud_run_revision"
resource.labels.service_name="emotion-ai-server"
jsonPayload.event:*
```

> **`textPayload`가 아니라 `jsonPayload`입니다.** 저도 처음에 `textPayload`만 보다가 구조화 로그를 통째로 놓쳤습니다 — 그쪽에는 uvicorn 평문만 옵니다.

**권한이 필요하면 팀장님께 말씀하세요.** 프로젝트 소유자가 `로그 뷰어(roles/logging.viewer)`를 주면 됩니다.

**③ gcloud를 까신다면** 우리 도구가 그대로 돕니다. 시간 범위·발화 없음·세션 해시가 이미 처리돼 있습니다.

```powershell
cd ai-server
.\.venv\Scripts\python.exe -m app.logs --min 30
```
