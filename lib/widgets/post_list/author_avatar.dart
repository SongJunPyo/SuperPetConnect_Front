import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../utils/config.dart';
import '../../utils/pet_field_icons.dart';

/// 게시판 상세(공지/칼럼)의 작성자 영역 좌측 아바타.
///
/// 8+ 화면(welcome / 3 dashboards / notice_list 2종 / column_list 2종 /
/// hospital_column_management_list / admin_column_management 등)에서 공통.
/// 이전에는 '공지'/'알림'/'칼럼' 텍스트 뱃지였으나 작성자 식별을 위해
/// 프로필 이미지 + 폴백 hospital 아이콘 형태로 통일.
class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({
    super.key,
    required this.profileImage,
    this.radius = 12,
  });

  final String? profileImage;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasImage = profileImage != null && profileImage!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.veryLightGray,
      foregroundImage: hasImage
          ? NetworkImage(
              profileImage!.startsWith('http')
                  ? profileImage!
                  : '${Config.serverUrl}$profileImage',
            )
          : null,
      onForegroundImageError: hasImage ? (_, __) {} : null,
      child: Icon(
        PetFieldIcons.hospital,
        size: radius * 1.1,
        color: AppTheme.textTertiary,
      ),
    );
  }
}
