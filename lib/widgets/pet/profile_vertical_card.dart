import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../pet_profile_image.dart';

/// 시트 내부에서 펫 프로필을 가운데 정렬로 표시하는 헤더 카드.
///
/// 패턴: [큰 원형 사진] → [이름] → [subtitle] (모두 가운데 정렬).
/// 시트 안 펫 정보 섹션의 헤더에서만 사용. 목록 행은 좌측 아바타 + Row 패턴 그대로 유지.
class ProfileVerticalCard extends StatelessWidget {
  final String? profileImage;
  final Uint8List? localImageBytes;
  final String? species;
  final String name;
  final String? subtitle;
  final double avatarRadius;
  final EdgeInsetsGeometry padding;
  final int? cacheBuster;

  /// 카드 우측 상단에 겹쳐 표시할 위젯 (예: PopupMenuButton).
  /// Stack 패턴으로 가운데 사진 정렬은 유지된 상태에서 우측 상단에 absolute 배치.
  final Widget? trailing;

  /// 사진의 오른쪽 같은 행에 배치할 위젯 (예: 사진 다운로드 IconButton).
  /// 사진+위젯 묶음을 가운데 정렬 — 시각적으로 사진은 살짝 좌측, 버튼은 사진 옆.
  final Widget? imageTrailing;

  const ProfileVerticalCard({
    super.key,
    this.profileImage,
    this.localImageBytes,
    this.species,
    required this.name,
    this.subtitle,
    this.avatarRadius = 40,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
    this.cacheBuster,
    this.trailing,
    this.imageTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final image = PetProfileImage(
      profileImage: profileImage,
      localImageBytes: localImageBytes,
      species: species,
      radius: avatarRadius,
      cacheBuster: cacheBuster,
    );
    final imageBlock = imageTrailing == null
        ? image
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              image,
              const SizedBox(width: 8),
              imageTrailing!,
            ],
          );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        imageBlock,
        const SizedBox(height: 12),
        Text(
          name,
          textAlign: TextAlign.center,
          style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: padding,
      child: trailing == null
          ? body
          : Stack(
              children: [
                body,
                Positioned(top: 0, right: 0, child: trailing!),
              ],
            ),
    );
  }
}
