# ai-server — Hume CLM 엔드포인트 · valence · 갭 · 위기 규칙 · 프롬프트

담당: **AI**. 스택 **Python 3.12 · FastAPI · uvicorn · Anthropic SDK** (2026-09-03 확정 — Hume CLM 공식 예제 `evi-python-clm-sse`와 같은 형태).

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
cp .env.example .env         # 값 채우기 (ANTHROPIC_API_KEY, INTERNAL_SHARED_SECRET, BACKEND_BASE_URL)
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

`make help`가 전체 명령을 보여준다. **README의 명령과 `Makefile`이 다르면 `Makefile`이 맞다.**

## 지금 있는 것 (2026-09-04)

| 계층 | 상태 |
| --- | --- |
| `app/rules/` — valence · gap · crisis · tags · guard · observe_guard · summary_guard · turns · sentence | **구현 완료, 테스트 111건 통과** |
| `app/config.py` — 환경변수 | 완료 |
| `eval/fixtures/internal/` — 내부 API 고정 JSON 10건 | 완료 (백엔드와 공유) |
| `app/clm/` · `app/llm/` · `app/session.py` · `app/backend_client.py` · `app/main.py` | 미착수 — 목표 9/6 |

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
