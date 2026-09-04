import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'outline_button.dart';

/// 비동기 데이터 한 덩어리를 그리는 공통 처리 — 로딩·빈 상태·오류.
///
/// 세 상태를 화면마다 따로 쓰면 문구와 모양이 갈린다. **빈 상태는 오류가
/// 아니다** — 관찰이 없는 것은 정상이므로 조건을 정직하게 말한다
/// (design-system §7 결정 11).
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    required this.loading,
    this.isEmpty,
    this.empty,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// 스켈레톤. 화면마다 골격이 달라 호출하는 쪽이 준다.
  final Widget loading;

  /// 값이 비었는지 판정 — 주면 [empty]를 그린다.
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => loading,
      error: (e, _) => AsyncErrorBlock(error: e, onRetry: onRetry),
      data: (d) {
        if (isEmpty != null && empty != null && isEmpty!(d)) return empty!;
        return data(d);
      },
    );
  }
}

/// 오류 문구 — 원인별로 갈린다 (design-system §7-1).
///
/// **원인을 사용자 말로 옮긴다.** 상태 코드·`traceId`를 화면에 쓰지 않는다.
/// [AsyncView]를 쓰지 않는 화면(홈)도 같은 문구를 쓰도록 공개해 둔다.
class AsyncErrorBlock extends StatelessWidget {
  const AsyncErrorBlock({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  String get _message {
    final e = error;
    if (e is! ApiException) return '문제가 생겼습니다. 잠시 후 다시 시도해 주세요.';
    if (e.isNetwork) {
      return '연결이 되지 않습니다. 네트워크를 확인해 주세요.';
    }
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _message,
          style: AppType.sans(size: AppType.bodySize, color: t.muted, height: 1.75),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: Space.xl),
          ActionLink(label: '다시 시도', onPressed: onRetry!),
        ],
      ],
    );
  }
}
