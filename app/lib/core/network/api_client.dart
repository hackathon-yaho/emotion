import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// 앱 ↔ 백엔드 클라이언트. 계약서 §2.
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

  /// 본문 없는 204 응답용 (예: `DELETE /api/account`).
  Future<void> deleteNoContent(String path) =>
      _send<void>(() => _dio.delete<dynamic>(path), (_) {});

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
