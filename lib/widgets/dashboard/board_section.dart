import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../post_list/board_list_header.dart';
import 'dashboard_empty_state.dart';
import 'dashboard_more_button.dart';

/// 대시보드 게시판 섹션 (공지사항/칼럼 공용)
///
/// 4개 화면(user/admin/hospital/welcome)이 동일하게 사용하던 board 패턴을 통합.
/// 로딩/빈 상태 처리, 헤더, 리스트, 하단 "더보기" 버튼까지 한 번에 처리.
///
/// 호출부는 `itemBuilder`로 행 위젯(보통 [BoardListRow])을 직접 만들고,
/// `onMoreTap`으로 전체 목록 화면으로 이동할 동작을 제공.
class BoardSection<T> extends StatelessWidget {
  final bool isLoading;
  final List<T> items;
  final IconData emptyIcon;
  final String emptyMessage;
  final VoidCallback onMoreTap;
  final Widget Function(BuildContext context, int index, T item) itemBuilder;

  const BoardSection({
    super.key,
    required this.isLoading,
    required this.items,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.onMoreTap,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return DashboardEmptyState(icon: emptyIcon, message: emptyMessage);
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const BoardListHeader(),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: items.length + 1,
              separatorBuilder: (context, index) => Container(
                height: 1,
                color: AppTheme.lightGray.withValues(alpha: 0.2),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              itemBuilder: (context, index) {
                if (index == items.length) {
                  return DashboardMoreButton(onTap: onMoreTap);
                }
                return itemBuilder(context, index, items[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
