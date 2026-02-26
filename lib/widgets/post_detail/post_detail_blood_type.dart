import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// 게시글 상세 혈액형 정보 섹션
/// 혈액형이 있는 경우에만 표시
class PostDetailBloodType extends StatelessWidget {
  final String? bloodType;
  final bool isUrgent; // 긴급/정기에 따라 색상 변경

  const PostDetailBloodType({
    super.key,
    this.bloodType,
    required this.isUrgent,
  });

  bool get _shouldDisplay {
    if (bloodType == null || bloodType!.isEmpty) return false;
    if (bloodType == '상관없음' || bloodType == '혈액형 무관') return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldDisplay) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('필요 혈액형', style: AppTheme.h4Style),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUrgent ? Colors.red.shade50 : AppTheme.lightBlue,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUrgent ? Colors.red.shade200 : AppTheme.lightGray,
            ),
          ),
          child: Text(
            bloodType!,
            style: AppTheme.h3Style.copyWith(
              color: isUrgent ? Colors.red : AppTheme.primaryBlue,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
