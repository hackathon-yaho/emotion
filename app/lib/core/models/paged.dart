/// 계약서 §1-4 목록 페이징 봉투.
///
/// | 파라미터 | 기본 | 최대 |
/// | --- | --- | --- |
/// | `limit` | 20 | 100 |
/// | `offset` | 0 | — |
///
/// 응답에 `total`이 포함되고 **정렬은 항상 최신순이며 클라이언트가 바꾸지
/// 않는다**.
class Paged<T> {
  const Paged({required this.total, required this.items});

  final int total;
  final List<T> items;

  bool get isEmpty => items.isEmpty;

  /// 다음 페이지가 남아 있는지. `offset`은 호출한 쪽이 관리한다.
  bool hasMore(int offset) => offset + items.length < total;

  /// `{ "total": n, "<key>": [ ... ] }` 모양을 푼다.
  factory Paged.fromJson(
    Map<String, dynamic> json, {
    required String key,
    required T Function(Map<String, dynamic>) itemFromJson,
  }) {
    final raw = json[key] as List<dynamic>? ?? const [];
    return Paged(
      total: json['total'] as int? ?? raw.length,
      items: raw
          .map((e) => itemFromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// 목록 요청의 페이징 파라미터.
class PageQuery {
  const PageQuery({this.limit = defaultLimit, this.offset = 0});

  static const defaultLimit = 20;
  static const maxLimit = 100;

  final int limit;
  final int offset;

  Map<String, dynamic> toQuery() => {
        'limit': limit.clamp(1, maxLimit),
        'offset': offset,
      };

  PageQuery next(int received) =>
      PageQuery(limit: limit, offset: offset + received);
}
