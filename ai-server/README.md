# ai-server — Hume CLM 엔드포인트 · valence · 갭 · 위기 규칙 · 프롬프트

담당: **AI**. 스택 **Python 3.12 · FastAPI · uvicorn** (2026-09-03 확정 — Hume CLM 공식 예제 `evi-python-clm-sse`와 같은 형태).

**LLM은 Google Gemini 무료 티어**다(2026-09-05). Gemini의 OpenAI 호환 엔드포인트를 쓰므로 SDK는 `openai` 그대로이고, 벤더를 또 바꾸려면 `.env`의 `GOOGLE_API_KEY`·`AI_LLM_BASE_URL`·모델 이름만 갈면 된다.

**설계의 단일 출처는 [`../docs/02-architecture/ai-pipeline.md`](../docs/02-architecture/ai-pipeline.md)다.** 이 README는 실행 안내와 이 폴더의 규칙만 둔다.

## 이 서버가 하는 일

| 경로 | 방향 | 내용 | 계약 |
| --- | --- | --- | --- |
| `POST /chat/completions?custom_session_id=` | Hume → 여기 | 턴 처리: 음성 valence(규칙) · 분석 호출(텍스트 valence·태그·위기) · 갭 판정(규칙) · 응답 호출 → SSE | 계약 §4 (외부·변경 불가) |
| `POST /internal/observations` | 백엔드 → 여기 | 집계 숫자 → 관찰 문장 1개 | 계약 §3-3 |
| `POST /internal/turns` | 여기 → 백엔드 | 턴 적재 (fire-and-forget) | 계약 §3-2 |
| `POST /internal/summaries` | 백엔드 → 여기 | 세션 턴 텍스트 → 요약 1문장 (동기, 3초) | 계약 §3-5 |
| `GET /internal/sessions/{id}` | 여기 → 백엔드 | 세션 컨텍스트 조회. **CLM 인증을 겸한다** — 캐시 미스 + 조회 실패는 401 | 계약 §3-4 |
| `GET /healthz` | — | 헬스체크 | — |

## 이 폴더의 단일 출처

| 경로 | 내용 | 바꾸면 |
| --- | --- | --- |
| `prompts/*.system.md` | **프롬프트 전문** 4종 — analyze · respond · observe · summary (PRD §9.3 — 문서에는 요지만) | `make eval` 재실행 |
| `rules/valence_mapping.json` | 48종 → ±1 매핑표 (PRD §14-1) | 20쌍 갭 방향 일치율 재측정 |
| `rules/crisis_keywords.json` | 위기 키워드 Tier A(규칙)·Tier B(LLM 힌트) + 출처 (PRD §14-2) | 합성 세트 재현율 재측정 |
| `rules/tag_stopwords.json` | 태그 불용어 | 태그 케이스 재실행 |
| `rules/guard_terms.json` | 금칙어(진단·약물·치료) + 요약 감정 단정 표현 | `make test` 재실행 |
| `eval/` | 20쌍 스냅샷 · 합성 세트 · 실행 스크립트 (F11-04) | — |

## 지켜야 하는 것 (경계 — `CLAUDE.md` 경계 감시와 동일)

- **`app/rules/`에 네트워크 호출·LLM 호출이 없다.** 순수 함수 + 단위 테스트만. 위반은 반려.
- **`app/llm/` 밖에서 LLM SDK를 import하지 않는다.**
- **분석·응답 호출의 payload에 `prosody` 키가 없다** (FR-025, TC-24). 테스트가 payload를 검사한다.
- **응답 SSE 스트림에 메타 태그·JSON이 없다.** 파싱·제거 로직 자체가 존재하지 않아야 한다.
- **위기 Tier A 규칙은 LLM 호출 실패 경로에서도 돈다** (FR-032). 테스트가 LLM을 죽인 상태에서 검증한다.
- **로그·오류·`/internal/turns` 실패 로그에 발화 내용·매칭 표현·폐기 태그 문자열이 없다** (FR-092). 로그 필드는 화이트리스트.
- **음성 파일을 쓰지 않는다.** `.wav`·`.mp3`·`audio/*` 저장·전송 코드가 없다 (FR-041). 20쌍 평가도 전사+prosody **스냅샷 JSON**으로 한다.
- 매핑표·임계값·키워드를 **코드 상수로 박지 않는다.** `rules/`와 `.env`에서 읽는다.

## 실행

```bash
cd ai-server
uv sync --extra dev          # 또는 pip install -e ".[dev]"
cp .env.example .env         # 값 채우기 (GOOGLE_API_KEY, INTERNAL_SHARED_SECRET)
python -m app.envcheck       # 들어갔는지 확인 — 시크릿은 마스킹해서 보여준다
uv run uvicorn app.main:app --port 8100 --reload
```

Hume이 공인 HTTPS로 호출하므로 로컬은 ngrok으로 연다:

```bash
ngrok http 8100
# → https://xxxx.ngrok-free.app/chat/completions 를 Hume Config의 CLM URL로 등록
```

Hume 콘솔 Config(`https://app.hume.ai/evi/configs`)는 AI 담당이 생성·소유한다. 언어 한국어, 언어 모델 "Custom language model", URL 위 값, 프롬프트는 비운다(시스템 프롬프트는 이 서버가 쓴다). 발급된 `config_id`는 백엔드 환경변수로 전달한다(`docs/request/backend/hume-config-id.md`).

```bash
make test     # 단위 테스트 (rules/ 전부 + 경계 검사)
make lint     # ruff
make eval     # 20쌍 · 위기 합성 세트 · 태그 · 관찰 문장 → eval/reports/
```

**시크릿은 스크립트로 넣는다.** 값이 화면에도 명령 기록에도 남지 않는다.

```powershell
.\scripts\set-secret.ps1 INTERNAL_SHARED_SECRET
.\scripts\set-secret.ps1 GOOGLE_API_KEY
```

`make help`가 전체 명령을 보여준다. **README의 명령과 `Makefile`이 다르면 `Makefile`이 맞다.**

## 지금 있는 것 (2026-09-05)

**엔드포인트 4종이 전부 서 있다. 테스트 182건 통과.** 통합 테스트 준비 목표였던 9/6보다 하루 빠르다.

`uvicorn app.main:app --port 8100`으로 실제 기동해 `/healthz` 200과 인증 없는 요청 401을 확인했다.

| 계층 | 상태 |
| --- | --- |
| `app/rules/` — valence · gap · crisis · tags · guard · observe_guard · summary_guard · turns · sentence · loader | 완료 |
| `app/clm/` — Hume 요청 파싱 · SSE 청크 | 완료 |
| `app/session.py` — 세션 캐시 · CLM 인증(fail-closed) · 채번 · 발화 시각 | 완료 |
| `app/backend_client.py` — `/internal/turns` 적재(재시도 3회, 4xx 제외) | 완료 |
| `app/llm/` — analyze · respond(스트리밍) · observe · summary | 완료 (**실제 API 키로는 미검증** — 키가 들어오면 확인) |
| `app/telemetry.py` — 필드 화이트리스트 로그 | 완료 |
| `app/capture.py` — 요청 뼈대 캡처(기본 켜짐) · 갭 스냅샷(기본 꺼짐) | 완료 |
| `app/main.py` — `/chat/completions` · `/internal/observations` · `/internal/summaries` · `/healthz` | 완료 |
| `eval/fixtures/internal/` — 내부 API 고정 JSON 10건 | 완료 (백엔드와 공유) |
| `eval/run_eval.py` — 평가 실행기 | 미착수 (20쌍 수집 후) |

**첫 Hume 연결에서 요청 뼈대가 `eval/capture/shape/`에 남는다.** 문서만 보고 짠 파서라 실제 모양을 한 번은 봐야 하고, 안 남기면 무료 할당량(월 5분)을 한 번 더 써야 한다. 발화·점수 값은 담기지 않으므로(키 이름과 타입만) 기본으로 켜 둔다.

**아직 못 한 검증**: Hume 실제 연결(Config가 없다), Gemini 실제 호출(키가 없다),
백엔드 실제 연결(터널 전). 이 셋은 목으로만 검증돼 있다.

## 구조

```
ai-server/
├─ app/
│  ├─ main.py            FastAPI 엔트리
│  ├─ clm/               Hume 요청 파싱 · SSE 청크
│  ├─ rules/             ★ 순수 함수 (valence · gap · crisis · tags · guard · observe_guard · summary_guard · turns)
│  ├─ llm/               ★ analyze · respond · observe · summary — LLM 호출은 여기에만
│  ├─ session.py         세션 컨텍스트 캐시 · 백엔드 조회
│  ├─ backend_client.py  /internal/turns 적재
│  └─ telemetry.py       구조화 로그 (필드 화이트리스트)
├─ prompts/              ★ 프롬프트 단일 출처 (analyze · respond · observe · summary)
├─ rules/                ★ 규칙 데이터 단일 출처
├─ eval/                 평가 세트 · run_eval.py · reports/ (gitignore)
│  └─ fixtures/internal/ ★ 내부 API 고정 JSON — 백엔드와 같은 파일로 검증한다
└─ tests/
```

---

이 폴더에 대한 요청은 `../docs/request/ai/`, AI가 보낸 요청의 회신은 `../docs/response/ai/`.
