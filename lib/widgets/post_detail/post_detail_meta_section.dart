import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../utils/app_theme.dart';
import '../../utils/time_format_util.dart';

/// 게시글 상세 메타 정보 섹션
/// 통일된 순서로 메타 정보 표시:
/// 1. 병원명/닉네임 + 작성일
/// 2. 주소
/// 3. 동물 종류
/// 4. 신청자 수
class PostDetailMetaSection extends StatelessWidget {
  final String hospitalName;
  final String? hospitalNickname;
  final String location;
  final int animalType; // 0: 강아지, 1: 고양이
  final int applicantCount;
  final DateTime createdAt;

  const PostDetailMetaSection({
    super.key,
    required this.hospitalName,
    this.hospitalNickname,
    required this.location,
    required this.animalType,
    required this.applicantCount,
    required this.createdAt,
  });

  String get _displayHospitalName {
    if (hospitalNickname != null && hospitalNickname!.isNotEmpty) {
      return hospitalNickname!;
    }
    return hospitalName.isNotEmpty ? hospitalName : '병원';
  }

  String get _animalTypeText {
    return animalType == 0 ? '강아지' : '고양이';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 병원명/닉네임 + 작성일
        Row(
          children: [
            Icon(
              Icons.business,
              size: 16,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _displayHospitalName,
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              TimeFormatUtils.formatPostDate(createdAt),
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // 2. 주소
        Row(
          children: [
            Icon(
              Icons.location_on,
              size: 16,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                location.isNotEmpty ? location : '주소 정보 없음',
                style: AppTheme.bodyMediumStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 3. 동물 종류
        Row(
          children: [
            Icon(
              animalType == 0 ? FontAwesomeIcons.dog : FontAwesomeIcons.cat,
              size: 16,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              '동물 종류: ',
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            Expanded(
              child: Text(
                _animalTypeText,
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 4. 신청자 수
        Row(
          children: [
            Icon(
              Icons.group_outlined,
              size: 16,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              '신청자 수: ',
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            Expanded(
              child: Text(
                '$applicantCount명',
                style: AppTheme.bodyMediumStyle.copyWith(
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
