import 'package:flutter/material.dart';
import '../utils/config.dart';
import '../utils/app_theme.dart';

/// 반려동물 프로필 이미지 공통 위젯
///
/// 사진이 있으면 원형 이미지, 없으면 동물 종류 아이콘 표시.
/// [profileImage] 서버 경로 (예: "/uploads/pet_profiles/2026/04/abc.jpg")
/// [species] "강아지" 또는 "고양이" (아이콘 fallback용)
/// [radius] CircleAvatar 반지름
/// [onTap] 클릭 시 원본 크게 보기
class PetProfileImage extends StatelessWidget {
  final String? profileImage;
  final String? species;
  final double radius;
  final VoidCallback? onTap;

  const PetProfileImage({
    super.key,
    this.profileImage,
    this.species,
    this.radius = 24,
    this.onTap,
  });

  String? get _fullImageUrl {
    if (profileImage == null || profileImage!.isEmpty) return null;
    if (profileImage!.startsWith('http')) return profileImage;
    return '${Config.serverUrl}$profileImage';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _fullImageUrl;

    Widget avatar;
    if (imageUrl != null) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl),
        backgroundColor: AppTheme.veryLightGray,
        onBackgroundImageError: (_, __) {},
      );
    } else {
      // 사진 없으면 동물 종류 아이콘
      final isDog = species == null || species == '강아지';
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.veryLightGray,
        child: Icon(
          isDog ? Icons.pets : Icons.pets_outlined,
          size: radius * 0.8,
          color: AppTheme.textTertiary,
        ),
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }

    // 사진이 있으면 기본적으로 클릭 시 원본 크게 보기
    if (imageUrl != null) {
      return GestureDetector(
        onTap: () => _showFullImage(context, imageUrl),
        child: avatar,
      );
    }

    return avatar;
  }

  /// 원본 이미지 전체화면 표시
  static void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 200,
                    height: 200,
                    color: AppTheme.veryLightGray,
                    child: const Icon(Icons.broken_image, size: 64,
                        color: AppTheme.textTertiary),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
