import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// 공통 페이지네이션 바 위젯
/// ListView의 마지막 아이템으로 배치하여 스크롤 최하단에 표시
///
/// ```
///   [◀]  1  2  [3]  4  5  [▶]
/// ```
class PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  final int maxVisiblePages;

  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.maxVisiblePages = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    final pageNumbers = _calculatePageRange();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 좌측 화살표
          _buildArrowButton(
            icon: Icons.chevron_left,
            onPressed:
                currentPage > 1
                    ? () => onPageChanged(currentPage - 1)
                    : null,
          ),
          const SizedBox(width: 4),
          // 페이지 번호들
          ...pageNumbers.map((page) => _buildPageButton(page)),
          const SizedBox(width: 4),
          // 우측 화살표
          _buildArrowButton(
            icon: Icons.chevron_right,
            onPressed:
                currentPage < totalPages
                    ? () => onPageChanged(currentPage + 1)
                    : null,
          ),
        ],
      ),
    );
  }

  /// 현재 페이지 중심으로 최대 maxVisiblePages개 번호 계산
  List<int> _calculatePageRange() {
    final int half = maxVisiblePages ~/ 2;
    int start = currentPage - half;
    int end = currentPage + half;

    if (start < 1) {
      start = 1;
      end = maxVisiblePages.clamp(1, totalPages);
    }
    if (end > totalPages) {
      end = totalPages;
      start = (totalPages - maxVisiblePages + 1).clamp(1, totalPages);
    }

    return List.generate(end - start + 1, (i) => start + i);
  }

  Widget _buildPageButton(int page) {
    final bool isSelected = page == currentPage;
    return GestureDetector(
      onTap: isSelected ? null : () => onPageChanged(page),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          '$page',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildArrowButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        color:
            onPressed != null ? AppTheme.textPrimary : AppTheme.textDisabled,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
