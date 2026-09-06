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
      // **Render 무료는 유휴 15분이면 잠들고 깨는 데 오래 걸린다.**
      // 2026-09-06 통합에서 실측 **17.7초**(두 번째 요청은 0.5초). 종전
      // 10초/15초로는 깨어나는 동안 반드시 실패했고, 화면에는 "네트워크를
      // 확인해 주세요"가 떴다 — **사용자 잘못이 아닌데 그렇게 말했다.**
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 45)
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

  /// 설정값을 밖에서 확인할 수 있게 열어 둔다 — 콜드 스타트를 견디는지
  /// 테스트가 본다.
  Duration get connectTimeout => _dio.options.connectTimeout!;
  Duration get receiveTimeout => _dio.options.receiveTimeout!;

  static const _noAuth = 'noAuth';

  /// JWT 만료 시 호출되는 콜백.
  ///
  /// **대화 중이면 대화를 끊지 않는다** (F1-02). 여기서 곧바로 로그인 화면으로
  /// 보내지 않고, 이 신호를 받은 쪽이 "대화 중인가"를 보고 판단한다.
  void Function()? onTokenExpired;

  /// GET은 **네트워크 실패에서 한 번만 다시 시도한다.**
  ///
  /// 서버가 잠에서 깨는 동안 첫 요청이 죽는데(위 타임아웃 주석), 그 뒤에는
  /// 대개 살아 있다. **GET에만 건다** — `session/start` 같은 POST를 다시
  /// 보내면 세션이 둘 생긴다.
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = true,
    required T Function(Map<String, dynamic> json) parse,
  }) async {
    Future<Response<dynamic>> call() => _dio.get<dynamic>(
          path,
          queryParameters: query,
          options: Options(extra: {_noAuth: !authenticated}),
        );
    try {
      return await _send(call, parse);
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      return _send(call, parse);
    }
  }

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

  /// 204(본문 없음) 응답용 POST — 예: `POST /api/session/{id}/chat-group`.
  Future<void> postNoContent(String path, {Object? body}) =>
      _send<void>(() => _dio.post<dynamic>(path, data: body), (_) {});

  /// 204(본문 없음) 응답용.
  ///
  /// `body`는 `DELETE /api/account`처럼 **본문이 선택인** 경우에만 쓴다
  /// (계약 v1.6 §2-3 — 카카오 연결 해제용 인가 코드).
  Future<void> deleteNoContent(String path, {Object? body}) =>
      _send<void>(() => _dio.delete<dynamic>(path, data: body), (_) {});

  /// 상태 코드까지 보고 파싱해야 하는 경우 (예: `POST /api/session/start`가
  /// **200이면 세션, 202면 대기 티켓**이다 — 계약 §2-4·§2-14).
  ///
  /// 본문 모양으로 짐작하지 않는다. 모양이 겹치는 날 조용히 틀린다.
  Future<T> postByStatus<T>(
    String path, {
    Object? body,
    bool authenticated = true,
    required T Function(Map<String, dynamic> json, int status) parse,
  }) =>
      _send(
        () => _dio.post<dynamic>(
          path,
          data: body,
          options: Options(extra: {_noAuth: !authenticated}),
        ),
        // 실제로는 아래 `withStatus`가 쓰인다. 이 자리는 도달하지 않는다.
        (json) => parse(json, 200),
        withStatus: parse,
      );

  Future<T> _send<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Map<String, dynamic> json) parse, {
    T Function(Map<String, dynamic> json, int status)? withStatus,
  }) async {
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
      final json = data is Map<String, dynamic> ? data : const <String, dynamic>{};
      return withStatus == null ? parse(json) : withStatus(json, status);
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
