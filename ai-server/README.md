# ai-server — Hume CLM 엔드포인트 · 갭 계산 · 프롬프트

담당: **AI**. 언어·프레임워크는 담당자 결정 (Hume CLM 공식 예제는 Python/FastAPI).

- `POST /chat/completions` (Hume CLM 외부 계약, 변경 불가) — [`../docs/02-architecture/api-contract.md`](../docs/02-architecture/api-contract.md) §4
- 음성 valence(규칙)·텍스트 valence·갭 계산·되묻기·위기 감지(규칙+LLM)·태깅·관찰 문장화 — [`../docs/00-context/prd.md`](../docs/00-context/prd.md) §9
- **프롬프트 전문의 단일 출처는 이 폴더의 프롬프트 파일이다** (PRD §9.3). 문서에는 조항 요지만 둔다
- 20쌍 평가 세트와 실행 스크립트(F11-04)도 여기에 둔다
- 착수 전 확정 항목: 48종 → valence 매핑표(PRD §14-1), 위기 키워드 목록(§14-2), 고정 임계값(§14-5)

이 폴더에 대한 요청은 `../docs/request/ai/`, AI가 보낸 요청의 회신은 `../docs/response/ai/`.
