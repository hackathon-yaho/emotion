/// 주소창을 다시 쓰는 일 — 웹에서만 의미가 있다.
///
/// 인가 코드를 쓴 뒤 `?code=`를 지워야 한다. 안 지우면 **새로고침이 같은
/// 코드를 다시 보내 400**이 된다 (계약 §2-1).
library;

export 'browser_url_stub.dart'
    if (dart.library.js_interop) 'browser_url_web.dart';
