import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// 대시보드 리스트 아이템의 뱃지 표시 위젯
///
/// 공지사항이나 칼럼에서 중요 표시 또는 카테고리 뱃지를 표시합니다.
/// 기본적으로 빨간색 배경(AppTheme.error)과 흰색 텍스트를 사용합니다.
class DashboardBadge extends StatelessWidget {
  /// 뱃지에 표시할 텍스트
  final String text;

  /// 뱃지 배경색 (기본값: AppTheme.error)
  final Color? backgroundColor;

  /// 뱃지 텍스트 색상 (기본값: Colors.white)
  final Color? textColor;

  const DashboardBadge({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.error,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AppTheme.bodySmallStyle.copyWith(
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
