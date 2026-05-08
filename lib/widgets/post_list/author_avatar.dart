import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../utils/config.dart';
import '../../utils/pet_field_icons.dart';

/// 게시판 상세(공지/칼럼)의 작성자 영역 좌측 아바타 + 대시보드 인사말 영역
/// 본인 프로필 아바타로 공통 사용. 폴백 아이콘은 호출자가 지정 (게시판은
/// hospital, 대시보드 본인은 person).
class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({
    super.key,
    required this.profileImage,
    this.radius = 12,
    this.fallbackIcon,
  });

  final String? profileImage;
  final double radius;

  /// 이미지가 없을 때 표시할 폴백 아이콘. null이면 [PetFieldIcons.hospital].
  final IconData? fallbackIcon;

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
        fallbackIcon ?? PetFieldIcons.hospital,
        size: radius * 1.1,
        color: AppTheme.textTertiary,
      ),
    );
  }
}
