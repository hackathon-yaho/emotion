# `custom_session_id`가 CLM까지 오지 않습니다 — 대화가 1.5초 만에 끊기는 원인

> **상태: ✅ 회신 완료** — [`../../response/ai/custom-session-id-not-reaching-clm.md`](../../response/ai/custom-session-id-not-reaching-clm.md)
> **막고 있는 작업**: **실제 대화 전부.** Hume 소켓은 붙는데 **모든 CLM 호출이 401**로 떨어지고, 그래서 EVI가 즉시 연결을 끊습니다. 화면에 보이는 "연결이 끊겼습니다"가 이것입니다.
> **고칠 곳은 한 줄입니다** — `evi_service.dart`의 `session_settings` 메시지.
> **먼저 말씀드립니다 — 앱이 틀린 게 아닙니다.** 계약서 §1-1이 이 값을 **"EVI 소켓 URL"**로 보내는 것처럼 적어 두었고, 앱은 그대로 구현했습니다(코드 주석도 계약 §4를 인용하고 있습니다). **계약서가 틀렸습니다.** §4는 "Hume이 정한 규격"이라 우리 판단이 아니라 사실 확인의 문제였고, **그 확인이 AI 쪽에서 빠졌습니다.** 계약서를 **v1.10**으로 고쳤습니다.

- 요청자: AI
- 대상: 앱
- 관련 문서: `app/lib/core/voice/evi_service.dart` · `../../02-architecture/api-contract.md` §4 · `../../00-context/spec.md` F2-02

---

## 무슨 일이 일어났나

2026-09-07 01:19~01:28 KST에 대화를 열 번 시도했고, **열 번 다 같은 모양으로 끊겼습니다.**

Cloud Run 요청 로그입니다.

```
16:19:53Z  POST 401  0.0027s  .../chat/completions
16:20:08Z  POST 401  0.0019s  .../chat/completions
16:20:29Z  POST 401  0.0026s  .../chat/completions
16:21:12Z  POST 401  0.0020s  .../chat/completions
16:24:19Z  POST 401  0.0025s  .../chat/completions
   … 같은 것 5건 더 …
```

**주소에 물음표가 없습니다.** 계약 §4가 요구하는 `?custom_session_id={sessionId}`가 **아예 붙어 있지 않습니다.** 값이 틀린 게 아니라 없습니다.

AI서버는 그 값으로만 세션을 인증하므로(계약 §4, v1.3) 없으면 **401 말고 낼 수 있는 답이 없습니다.** 2ms 만에 끊긴 것은 그래서입니다 — 백엔드에 물어보러 가지도 못했습니다.

Hume 쪽 채팅 길이가 **1.5초로 일곱 번 반복**된 것(백엔드 `blocked.md`)과 정확히 같은 사건입니다. EVI는 CLM이 401을 주면 그 자리에서 대화를 접습니다.

## 원인 — 값은 맞는데 전달 경로가 다릅니다

지금 코드는 **소켓 URL의 쿼리 파라미터**로 넘기고 있습니다. **계약서가 그렇게 적어 두었기 때문입니다** — §1-1의 이 문장입니다.

> ~~**EVI 소켓 URL의 `custom_session_id` 노출은 불가피하다** — §4가 요구하는 값이고…~~

**이 문장이 틀렸습니다.** v1.10에서 정정했고, §4에 「세션 식별자 설정」 행과 경고를 신설했습니다.

```dart
// evi_service.dart:80~87
final channel = connect(_endpoint({
  'access_token': accessToken,
  'config_id': configId,
  'custom_session_id': sessionId,   // ← 여기
  'resumed_chat_group_id': ?resumedChatGroupId,
}));
```

**Hume은 이 값을 CLM으로 넘겨주지 않습니다.** Hume 문서(Custom Language Model 가이드)가 설정 경로로 드는 것은 두 가지이고, **소켓 URL 쿼리는 그중에 없습니다.**

> "you can either send it **from the client** via a `session_settings` message over WebSocket, or **from the CLM endpoint** by setting it as a `system_fingerprint`(SSE)"

그리고 값이 설정된 **뒤에야** SSE 엔드포인트로 쿼리 파라미터가 붙습니다.

> "For SSE endpoints, the `custom_session_id` will be sent as a query parameter to your endpoint. For example `POST https://api.example.com/chat/completions?custom_session_id=123`"

Hume이 모르는 쿼리 파라미터는 조용히 무시합니다. 그래서 **소켓은 정상으로 붙고**, `chat_group_id`도 오고, `voice_session` 행도 생깁니다 — CLM 호출에서만 값이 비어 있습니다. 겉으로는 "잘 붙었다가 끊긴다"로 보이는 이유입니다.

## 부탁드리는 것 — `session_settings`에 한 줄

앱은 **이미 `session_settings`를 보내고 있습니다.** 거기에 값을 얹기만 하면 됩니다.

```dart
// evi_service.dart:98~106
_send({
  'type': 'session_settings',
  'custom_session_id': sessionId,   // ← 추가
  'audio': {
    'encoding': 'linear16',
    'sample_rate': Mic.sampleRate,
    'channels': Mic.channels,
  },
});
```

**소켓 URL의 `custom_session_id`는 그대로 두셔도 됩니다.** 지우는 것이 깔끔하지만, 남아 있어도 Hume이 무시할 뿐이라 해가 없습니다. 판단에 맡기겠습니다.

**보내는 시점은 지금 그대로가 맞습니다** — 소켓이 열리자마자, 오디오보다 먼저입니다. 첫 발화의 CLM 호출부터 값이 실려야 하니까요.

## 확인은 이렇게 갈립니다

고친 빌드가 올라간 뒤 **한 번만** 대화를 걸어 주시면, 제가 로그로 판정합니다.

| 로그에 나오는 것 | 뜻 |
| --- | --- |
| `clm_unauthorized:missing_custom_session_id` | **아직 안 실렸다.** 같은 문제 |
| `clm_unauthorized:session_not_found` | **실렸다.** 값이 백엔드에 없는 세션일 뿐 — 다른 문제로 넘어간 것 |
| `turn` | **통과.** 대화가 도는 것 |

이 세 줄을 구별하려고 방금 AI서버를 고쳐 배포했습니다. **종전에는 이 401이 로그를 한 줄도 안 남겼습니다** — 그래서 열 번의 실패를 우리 로그가 아니라 Cloud Run 요청 로그에서야 찾았습니다. 지금은 남습니다. 요청 본문의 **모양**도 401보다 먼저 남기므로, 또 실패하더라도 Hume이 실제로 보내는 요청이 어떻게 생겼는지는 건집니다.

## 왜 급한가

**Hume 무료 티어가 월 5분이고, 약 1.3분을 이미 썼습니다.** 남은 것은 약 3.7분입니다.

지금 상태로는 몇 번을 걸어도 1.5초씩 태우기만 하고 아무것도 확인되지 않습니다. **한 줄 고친 뒤에 한 번 거는 것이, 지금 열 번 거는 것보다 훨씬 많이 알려 줍니다.**

## 요청자 후속 작업

**없습니다.** 빌드가 올라가면 알려만 주세요. 제가 대화를 걸어 보고 결과를 `docs/response/` 아래에 정리하겠습니다.

## 곁다리 — 확인해 주시면 좋을 것 하나

배포본 `GET /` 가 404를 여러 번 받고 있습니다(16:06·16:09 4건·16:24). AI서버로 오는 요청이니 앱이나 브라우저가 루트를 찌르는 것으로 보이는데, **동작에는 영향이 없습니다.** 의도한 것이면 그대로 두셔도 됩니다.
