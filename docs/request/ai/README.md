# AI Request

AI 개발자에게 요청할 사항을 문서로 정리하는 폴더입니다.

- 모델/프롬프트 관련 요청, valence·갭 계산 변경, CLM 응답 포맷 조정, 평가 세트 등을 이 폴더에 문서로 작성합니다.
- 요청 하나당 파일 하나로 작성하는 것을 권장합니다. (예: `valence-mapping-table.md`, `crisis-keyword-list.md`)

## 회신 상태 표시 규칙

요청 문서 맨 위에 상태 배너를 답니다. 형식은 [`../app/README.md`](../app/README.md) "회신 상태 표시 규칙"과 동일합니다.

## 현재 요청 목록

| 문서 | 상태 | 막고 있던 작업 |
| --- | --- | --- |
| [clm-turn-pipeline-review.md](clm-turn-pipeline-review.md) | ⏳ **회신 대기** (2026-09-03) | PRD §9.1 실시간 턴 처리 — 텍스트 valence **순환 의존**(같은 호출의 출력을 입력으로 씀) + **채널 독립성**(CLM이 프로소디를 LLM에 노출). 회신 전 §9.1·FR-021·F3-02 구현 보류 |
