import '../utils/app_constants.dart';
import 'column_post_model.dart';
import 'notice_post_model.dart';

class PaginatedColumnsResult {
  final List<ColumnPost> columns;
  final PaginationMeta pagination;

  PaginatedColumnsResult({required this.columns, required this.pagination});
}

class PaginatedNoticesResult {
  final List<NoticePost> notices;
  final PaginationMeta pagination;

  PaginatedNoticesResult({required this.notices, required this.pagination});
}

class PaginationMeta {
  final int currentPage;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;
  final bool isEnd;

  const PaginationMeta({
    required this.currentPage,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
    required this.isEnd,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    final hasNextValue = _toBool(json['has_next'] ?? json['hasNext']);
    final hasPrevValue = _toBool(json['has_prev'] ?? json['hasPrev']);
    final isEndRaw = json['is_end'] ?? json['isEnd'];
    final isEndValue = isEndRaw != null ? _toBool(isEndRaw) : !hasNextValue;
    return PaginationMeta(
      currentPage: _toInt(json['current_page'] ?? json['page'], fallback: 1),
      pageSize: _toInt(
        json['page_size'] ?? json['pageSize'],
        fallback: AppConstants.detailListPageSize,
      ),
      totalCount: _toInt(
        json['total_count'] ?? json['totalCount'],
        fallback: 0,
      ),
      totalPages: _toInt(
        json['total_pages'] ?? json['totalPages'],
        fallback: 0,
      ),
      hasNext: hasNextValue,
      hasPrev: hasPrevValue,
      isEnd: isEndValue,
    );
  }

  factory PaginationMeta.derived({
    required int currentPage,
    required int pageSize,
    required int itemCount,
  }) {
    final hasNextValue = itemCount >= pageSize;
    return PaginationMeta(
      currentPage: currentPage,
      pageSize: pageSize,
      totalCount: (currentPage - 1) * pageSize + itemCount,
      totalPages: hasNextValue ? currentPage + 1 : currentPage,
      hasNext: hasNextValue,
      hasPrev: currentPage > 1,
      isEnd: !hasNextValue,
    );
  }

  factory PaginationMeta.singlePage({
    required int currentPage,
    required int pageSize,
    required int totalCount,
  }) {
    return PaginationMeta(
      currentPage: currentPage,
      pageSize: pageSize,
      totalCount: totalCount,
      totalPages: 1,
      hasNext: false,
      hasPrev: false,
      isEnd: true,
    );
  }

  bool get noMoreData => isEnd;

  static bool _toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return false;
  }

  static int _toInt(dynamic value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }
}
