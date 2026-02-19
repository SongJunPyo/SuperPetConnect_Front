import 'package:flutter/material.dart';
import '../models/applied_donation_model.dart';

/// 헌혈 신청 상태를 표시하는 위젯
class ApplicationStatusWidget extends StatelessWidget {
  final int status;

  const ApplicationStatusWidget({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    // AppliedDonationStatus 사용
    final statusText = AppliedDonationStatus.getStatusText(status);
    final statusColor = AppliedDonationStatus.getStatusColorValue(status);
    final statusIcon = _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 14),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 상태에 따른 아이콘 반환
  static IconData _getStatusIcon(int status) {
    switch (status) {
      case AppliedDonationStatus.pending:
        return Icons.schedule;
      case AppliedDonationStatus.approved:
        return Icons.check_circle;
      case AppliedDonationStatus.rejected:
        return Icons.cancel;
      case AppliedDonationStatus.completed:
        return Icons.done_all;
      case AppliedDonationStatus.cancelled:
        return Icons.close;
      case AppliedDonationStatus.pendingCompletion:
        return Icons.hourglass_empty;
      case AppliedDonationStatus.pendingCancellation:
        return Icons.pending;
      case AppliedDonationStatus.finalCompleted:
        return Icons.verified;
      default:
        return Icons.help;
    }
  }

  /// 상태 코드를 문자열로 변환 (하위 호환성)
  @Deprecated('Use AppliedDonationStatus.getStatusText() instead')
  static String getStatusText(int status) {
    return AppliedDonationStatus.getStatusText(status);
  }

  /// 상태 코드에 따른 색상을 반환 (하위 호환성)
  @Deprecated('Use AppliedDonationStatus.getStatusColorValue() instead')
  static Color getStatusColor(int status) {
    return AppliedDonationStatus.getStatusColorValue(status);
  }
}
