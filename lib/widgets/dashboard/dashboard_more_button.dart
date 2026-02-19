import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// 대시보드 리스트의 더보기 버튼 위젯
///
/// 리스트 맨 아래에 "..." 버튼을 표시하여 전체 목록으로 이동할 수 있게 합니다.
/// 모든 대시보드(User/Admin/Hospital)의 목록 하단에서 재사용됩니다.
class DashboardMoreButton extends StatelessWidget {
  /// 더보기 버튼을 탭했을 때 실행할 콜백
  final VoidCallback onTap;

  const DashboardMoreButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
        child: Center(
          child: Text(
            '...',
            style: AppTheme.h3Style.copyWith(
              color: AppTheme.textTertiary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
