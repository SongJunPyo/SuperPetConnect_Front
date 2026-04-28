import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// 라벨 + 값으로 구성된 정보 행. 아이콘은 옵션.
///
/// 14개 이상의 화면에서 `_buildInfoRow` / `_buildDetailRow` 변형으로
/// 흩어져 있던 패턴을 통합한 위젯.
///
/// - `icon`이 null이면 라벨만 표시 (좁은 라벨 컬럼 + 회색 라벨 스타일).
/// - `icon`이 있으면 기존 게시글 상세 스타일 (아이콘 + 굵은 라벨 + 값).
/// - `valueColor`로 강조/경고 색상 지정 가능.
/// - `padding`으로 행 간격 조정 가능 (기본 0).
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.padding = EdgeInsets.zero,
    this.labelWidth,
  });

  final IconData? icon;
  final String label;
  final String value;
  final Color? valueColor;
  final EdgeInsetsGeometry padding;

  /// 라벨 컬럼 고정 너비. 아이콘 없는 모드에서 값을 정렬할 때 사용 (기본 80).
  final double? labelWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(
              '$label: ',
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else
            SizedBox(
              width: labelWidth ?? 80,
              child: Text(
                label,
                style: AppTheme.bodyMediumStyle.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: valueColor,
                fontWeight: valueColor != null ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
