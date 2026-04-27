import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// 아이콘 + 라벨 + 값으로 구성된 정보 행.
/// 게시글 상세/신청자 정보 바텀시트에서 사용.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: AppTheme.bodyMediumStyle.copyWith(fontWeight: FontWeight.w600),
        ),
        Expanded(child: Text(value, style: AppTheme.bodyMediumStyle)),
      ],
    );
  }
}
