import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../utils/number_format_util.dart';

/// 대시보드 리스트 아이템의 조회수 표시 박스
///
/// 40x36 고정 크기의 박스로 조회수를 아이콘과 함께 표시합니다.
/// 모든 대시보드(User/Admin/Hospital)의 공지사항 및 칼럼 섹션에서 재사용됩니다.
class DashboardViewCountBox extends StatelessWidget {
  /// 표시할 조회수
  final int viewCount;

  const DashboardViewCountBox({
    super.key,
    required this.viewCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 40,
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.mediumGray.withValues(
          alpha: 0.2,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppTheme.lightGray.withValues(
            alpha: 0.3,
          ),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_outlined,
            size: 10,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 1),
          Text(
            NumberFormatUtil.formatViewCount(viewCount),
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
