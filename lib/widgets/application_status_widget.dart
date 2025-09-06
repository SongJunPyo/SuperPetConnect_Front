import 'package:flutter/material.dart';

/// 헌혈 신청 상태를 표시하는 위젯
class ApplicationStatusWidget extends StatelessWidget {
  final int status;
  
  const ApplicationStatusWidget({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    String statusText;
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 0: // PENDING
        statusText = "대기중";
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case 1: // APPROVED
        statusText = "승인됨";
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 2: // REJECTED
        statusText = "거절됨";
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusText = "알수없음";
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }
    
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
          Icon(
            statusIcon,
            color: statusColor,
            size: 14,
          ),
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

  /// 상태 코드를 문자열로 변환하는 정적 메서드
  static String getStatusText(int status) {
    switch (status) {
      case 0:
        return "대기중";
      case 1:
        return "승인됨";
      case 2:
        return "거절됨";
      default:
        return "알수없음";
    }
  }

  /// 상태 코드에 따른 색상을 반환하는 정적 메서드
  static Color getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.green;
      case 2:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}