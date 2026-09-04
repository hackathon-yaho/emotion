import '../config/env.dart';

/// 카카오 인가 URL 조립 (계약 v1.6 §2-1).
///
/// **SDK를 쓰지 않는다.** `kakao_flutter_sdk` 2.0.1은 웹에서 로그인 API가 전부
/// `notSupported`를 던지고 `authorize()`도 페이지를 넘긴 뒤 빈 문자열을
/// 돌려준다 (`response/backend/kakao-web-login.md`). 웹에서 SDK가 하는 일은
/// URL 조립뿐이라 직접 만든다.
///
/// **`client_id`는 REST API 키다.** 서버의 토큰 교환도 REST 키 + 시크릿으로
/// 하므로 인가와 교환의 `client_id`가 같아야 한다
/// (`response/backend/kakao-rest-key-switch.md`).
abstract final class KakaoLogin {
  static const _authorizeHost = 'kauth.kakao.com';
  static const _authorizePath = '/oauth/authorize';

  /// 인가 페이지 주소. 키가 없으면 null — 화면이 문구로 안내한다.
  static Uri? authorizeUrl({required Uri redirectUri}) {
    final key = Env.kakaoRestKey;
    if (key == null) return null;
    return Uri(
      scheme: 'https',
      host: _authorizeHost,
      path: _authorizePath,
      queryParameters: {
        'client_id': key,
        'redirect_uri': redirectUri.toString(),
        'response_type': 'code',
      },
    );
  }

  /// 이 실행 환경의 Redirect URI.
  ///
  /// **카카오 콘솔에 등록된 값과 문자열이 정확히 같아야 한다.** 등록값은
  /// `https://hackathon-yaho.github.io/emotion/`과 `http://localhost:3000/`
  /// 둘이고, 둘 다 **디렉터리로 끝난다** — 그래서 `index.html` 같은 파일명과
  /// 쿼리·프래그먼트를 떼어낸다. 이 값을 서버에도 그대로 보내야 교환이 된다
  /// (§2-1).
  static Uri redirectUriFrom(Uri current) {
    // **빈 조각을 먼저 버린다.** `/emotion/`처럼 슬래시로 끝나는 주소는
    // 마지막 조각이 빈 문자열이라, 그대로 이어 붙이면 `/emotion//`이 되어
    // 등록값과 어긋난다 — 그러면 로그인만 400으로 실패하고 원인이 보이지
    // 않는다.
    final segments = current.pathSegments.where((s) => s.isNotEmpty).toList();
    // 마지막 조각이 파일명이면(점이 있으면) 버린다.
    if (segments.isNotEmpty && segments.last.contains('.')) {
      segments.removeLast();
    }
    final path = segments.isEmpty ? '/' : '/${segments.join('/')}/';
    return Uri(
      scheme: current.scheme,
      host: current.host,
      port: current.hasPort ? current.port : null,
      path: path,
    );
  }

  /// 돌아온 주소에서 인가 코드를 꺼낸다.
  ///
  /// **1회용이고 10분 만료다** (§2-1). 쓴 뒤에는 주소창에서 지워야 새로고침이
  /// 같은 코드를 다시 보내 400이 되는 일을 막는다.
  static String? codeFrom(Uri current) {
    final code = current.queryParameters['code'];
    return code == null || code.isEmpty ? null : code;
  }

  /// 카카오가 거절하고 돌려보낸 경우 (`?error=...`).
  static bool deniedIn(Uri current) =>
      current.queryParameters['error'] != null;
}
