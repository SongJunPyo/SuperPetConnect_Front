import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// 게시글 상세 환자 정보 섹션 (긴급 헌혈 전용)
/// 긴급 헌혈(types == 0)일 때만 표시되며, 병원과 관리자만 볼 수 있습니다.
///
/// 표시 정보:
/// - 환자 이름 (patientName)
/// - 품종 (breed)
/// - 나이 (age)
/// - 병명/증상 (diagnosis)
class PostDetailPatientInfo extends StatelessWidget {
  final bool isUrgent; // types == 0 여부
  final String? patientName;
  final String? breed;
  final int? age;
  final String? diagnosis;

  const PostDetailPatientInfo({
    super.key,
    required this.isUrgent,
    this.patientName,
    this.breed,
    this.age,
    this.diagnosis,
  });

  /// 환자 정보가 하나라도 있는지 확인
  bool get _hasPatientInfo {
    if (!isUrgent) return false;
    return (patientName != null && patientName!.isNotEmpty) ||
           (breed != null && breed!.isNotEmpty) ||
           (age != null && age! > 0) ||
           (diagnosis != null && diagnosis!.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPatientInfo) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // 섹션 제목
        Row(
          children: [
            Icon(
              Icons.medical_information,
              size: 18,
              color: Colors.red.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              '수혈 환자 정보',
              style: AppTheme.h4Style.copyWith(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 환자 정보 카드
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.red.shade200,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 환자 이름
              if (patientName != null && patientName!.isNotEmpty) ...[
                _buildInfoRow(
                  icon: Icons.pets,
                  label: '환자 이름',
                  value: patientName!,
                ),
              ],

              // 품종
              if (breed != null && breed!.isNotEmpty) ...[
                if (patientName != null && patientName!.isNotEmpty)
                  const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.category,
                  label: '품종',
                  value: breed!,
                ),
              ],

              // 나이
              if (age != null && age! > 0) ...[
                if ((patientName != null && patientName!.isNotEmpty) ||
                    (breed != null && breed!.isNotEmpty))
                  const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.cake,
                  label: '나이',
                  value: '$age세',
                ),
              ],

              // 병명/증상
              if (diagnosis != null && diagnosis!.isNotEmpty) ...[
                if ((patientName != null && patientName!.isNotEmpty) ||
                    (breed != null && breed!.isNotEmpty) ||
                    (age != null && age! > 0))
                  const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.local_hospital,
                  label: '병명/증상',
                  value: diagnosis!,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: AppTheme.bodyMediumStyle.copyWith(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTheme.bodyMediumStyle.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
