import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import 'app_search_bar.dart';

/// 검색 바 + 선택된 날짜 범위 칩을 묶은 공용 필터 영역.
///
/// 공지/칼럼 리스트 7개 화면에서 반복되던 `AppSearchBar` + 날짜 범위 칩
/// 마크업을 단일 위젯으로 통합. 날짜 범위 자체를 고르는 다이얼로그
/// (`showDateRangePicker`)는 화면별로 AppBar 액션에 따로 두므로 이 위젯은
/// **표시 + 검색 입력**만 담당한다.
///
/// `startDate`와 `endDate`가 모두 non-null일 때만 칩이 노출된다.
class SearchAndDateFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String hintText;
  final ValueChanged<String> onSearchChanged;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onClearDateRange;

  const SearchAndDateFilterBar({
    super.key,
    required this.searchController,
    required this.hintText,
    required this.onSearchChanged,
    required this.startDate,
    required this.endDate,
    required this.onClearDateRange,
  });

  @override
  Widget build(BuildContext context) {
    final dateChip = (startDate != null && endDate != null)
        ? Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.date_range,
                    size: 16,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${DateFormat('yyyy.MM.dd').format(startDate!)} - ${DateFormat('yyyy.MM.dd').format(endDate!)}',
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppTheme.primaryBlue,
                    ),
                    onPressed: onClearDateRange,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          AppSearchBar(
            controller: searchController,
            hintText: hintText,
            onChanged: onSearchChanged,
            onClear: () => onSearchChanged(''),
          ),
          if (dateChip != null) dateChip,
        ],
      ),
    );
  }
}
