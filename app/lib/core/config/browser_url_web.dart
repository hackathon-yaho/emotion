import 'package:web/web.dart' as web;

/// 주소창의 쿼리만 지운다. **경로와 해시는 건드리지 않는다** — 해시가
/// 라우터의 현재 화면이므로 지우면 화면이 튄다.
void clearQuery() {
  final url = Uri.parse(web.window.location.href);
  if (url.query.isEmpty) return;
  final cleaned = url.replace(queryParameters: const {}).toString();
  // `replaceState`라서 히스토리에 남지 않는다 — 뒤로 가기로 인가 코드가
  // 돌아오면 다시 400이다.
  web.window.history.replaceState(null, '', cleaned.replaceFirst('?', ''));
}
