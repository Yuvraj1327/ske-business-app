/// Generic paginated response wrapper matching the backend's
/// `{items, total, page, page_size, total_pages}` envelope.
class Page<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const Page({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory Page.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJsonItem) {
    return Page<T>(
      items: (json['items'] as List).map((e) => fromJsonItem(e as Map<String, dynamic>)).toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      totalPages: json['total_pages'] as int,
    );
  }

  bool get hasNextPage => page < totalPages;
}
