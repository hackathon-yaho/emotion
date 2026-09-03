# app — 모바일 앱

담당: **앱**. React Native 또는 Flutter (담당자 결정, PRD §14-4).

- EVI SDK 연동, 대화 UI(S02), 발견·트렌드·기록 화면, 설정 — 화면 정의는 [`../docs/00-context/spec.md`](../docs/00-context/spec.md) §4
- 호출하는 API는 [`../docs/02-architecture/api-contract.md`](../docs/02-architecture/api-contract.md) §2 · 화면↔엔드포인트 매핑은 §5
- **Hume API 키를 앱에 내장하지 않는다.** 백엔드가 발급하는 단기 토큰만 쓴다 (FR-013)
- RN은 네이티브 오디오 모듈 때문에 Expo Go로 동작하지 않는다 (spec F2-02 개발 주의)

이 폴더에 대한 요청은 `../docs/request/app/`, 앱이 보낸 요청의 회신은 `../docs/response/app/`.
