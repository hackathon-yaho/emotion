import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paged.dart';

/// 목록 한 장씩 이어 붙이는 공통 처리 (design-system §7 결정 22).
///
/// **"더 보기" 버튼을 두지 않는다** — 조용한 언어에 버튼이 하나 더 붙을 이유가
/// 없다. 바닥에 닿으면 이어 불러오고, 마지막에 닿으면 조용히 끝난다. 남은
/// 개수도 표시하지 않는다.
abstract class PagedNotifier<T> extends AsyncNotifier<Paged<T>> {
  /// 한 장 불러온다. 호출하는 쪽이 `offset`을 관리한다 (§1-4).
  Future<Paged<T>> fetch(PageQuery page);

  bool _loadingMore = false;

  @override
  Future<Paged<T>> build() => fetch(const PageQuery());

  /// 다음 장. **이미 불러오는 중이거나 끝이면 아무것도 하지 않는다** —
  /// 스크롤 알림은 연달아 오므로 방어가 없으면 같은 장을 여러 번 부른다.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || _loadingMore) return;
    if (!current.hasMore(0)) return;

    _loadingMore = true;
    try {
      final next = await fetch(PageQuery(offset: current.items.length));
      state = AsyncData(Paged(
        // **`total`은 새 응답의 것을 쓴다.** 사이에 삭제가 있었으면 값이
        // 달라지고, 옛 값을 유지하면 끝나지 않는 목록이 된다.
        total: next.total,
        items: [...current.items, ...next.items],
      ));
    } on Object {
      // **이미 보여준 목록을 오류로 바꾸지 않는다.** 다음 장을 못 불러온
      // 것이지 목록이 사라진 것이 아니다. 바닥에 다시 닿으면 또 시도한다.
      state = AsyncData(current);
    } finally {
      _loadingMore = false;
    }
  }
}
