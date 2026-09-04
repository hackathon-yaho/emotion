import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// 앱 ↔ 백엔드 클라이언트. 계약서 §2.
///
/// **웹에서 자격증명(쿠키)을 켜지 않는다** — `docs/response/app/cors-origin.md`.
/// 백엔드는 로컬 개발용으로 `http://localhost:*` 와일드카드 오리진을 열어
/// 두었고, `Access-Control-Allow-Credentials`는 와일드카드와 **함께 쓸 수
/// 없다.** dio의 브라우저 어댑터는 기본이 `withCredentials = false`이므로
/// 지금은 맞다 — 켜는 순간 로컬 개발이 전부 CORS로 막힌다. 인증은 쿠키가
/// 아니라 아래 `Authorization` 헤더 하나로 한다.
///
/// **CORS 차단은 브라우저에서 그냥 네트워크 오류로 보인다.** 배포 URL에서
/// 모든 호출이 한꺼번에 [ApiException.network]로 떨어지면 오프라인이 아니라
/// **허용 오리진 목록**을 먼저 의심한다 (백엔드 환경변수
/// `CORS_ALLOWED_ORIGINS`). 앱 코드로는 둘을 구분할 방법이 없다.
class ApiClient {
  ApiClient({required this.tokens, Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = Env.apiBaseUrl
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 15)
      ..contentType = 'application/json; charset=utf-8'
      // 오류 본문을 우리가 직접 해석한다.
      ..validateStatus = (_) => true;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra[_noAuth] != true) {
            final jwt = await tokens.readJwt();
            if (jwt != null) {
              options.headers['Authorization'] = 'Bearer $jwt';
            }
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage tokens;

  static const _noAuth = 'noAuth';

  /// JWT 만료 시 호출되는 콜백.
  ///
  /// **대화 중이면 대화를 끊지 않는다** (F1-02). 여기서 곧바로 로그인 화면으로
  /// 보내지 않고, 이 신호를 받은 쪽이 "대화 중인가"를 보고 판단한다.
  void Function()? onTokenExpired;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = true,
    required T Function(Map<String, dynamic> json) parse,
  }) =>
      _send(
        () => _dio.get<dynamic>(
          path,
          queryParameters: query,
          options: Options(extra: {_noAuth: !authenticated}),
        ),
        parse,
      );

  Future<T> post<T>(
    String path, {
    Object? body,
    bool authenticated = true,
    required T Function(Map<String, dynamic> json) parse,
  }) =>
      _send(
        () => _dio.post<dynamic>(
          path,
          data: body,
          options: Options(extra: {_noAuth: !authenticated}),
        ),
        parse,
      );

  Future<T> delete<T>(
    String path, {
    required T Function(Map<String, dynamic> json) parse,
  }) =>
      _send(() => _dio.delete<dynamic>(path), parse);

  /// 204(본문 없음) 응답용.
  ///
  /// `body`는 `DELETE /api/account`처럼 **본문이 선택인** 경우에만 쓴다
  /// (계약 v1.6 §2-3 — 카카오 연결 해제용 인가 코드).
  Future<void> deleteNoContent(String path, {Object? body}) =>
      _send<void>(() => _dio.delete<dynamic>(path, data: body), (_) {});

  Future<T> _send<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Map<String, dynamic> json) parse,
  ) async {
    final Response<dynamic> res;
    try {
      res = await call();
    } on DioException catch (e) {
      throw e.type == DioExceptionType.badResponse
          ? ApiException.unexpected(e.response?.statusCode)
          : ApiException.network();
    }

    final status = res.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      final data = res.data;
      return parse(data is Map<String, dynamic> ? data : const {});
    }

    final err = _parseError(res);
    if (err.isTokenExpired) onTokenExpired?.call();
    throw err;
  }

  ApiException _parseError(Response<dynamic> res) {
    final data = res.data;
    if (data is Map<String, dynamic>) {
      final e = data['error'];
      if (e is Map<String, dynamic> && e['code'] is String) {
        return ApiException(
          code: e['code'] as String,
          message: e['message'] as String? ?? '문제가 생겼습니다.',
          statusCode: res.statusCode,
          traceId: e['traceId'] as String?,
        );
      }
    }
    return ApiException.unexpected(res.statusCode);
  }
}
