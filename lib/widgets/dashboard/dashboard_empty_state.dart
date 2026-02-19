import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// 대시보드 리스트의 빈 상태 표시 위젯
///
/// 데이터가 없을 때 아이콘과 메시지를 중앙에 표시합니다.
/// 모든 대시보드(User/Admin/Hospital)의 빈 상태에서 재사용됩니다.
class DashboardEmptyState extends StatelessWidget {
  /// 표시할 아이콘
  final IconData icon;

  /// 표시할 메시지
  final String message;

  const DashboardEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppTheme.mediumGray,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTheme.h4Style,
          ),
        ],
      ),
    );
  }
}
