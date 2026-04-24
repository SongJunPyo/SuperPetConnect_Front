import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../utils/config.dart';

/// 팝업 메뉴 항목 데이터
class PostDetailMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const PostDetailMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// 게시글 상세 바텀시트 헤더
/// - 프로필 사진 + 제목
/// - 더보기(...) 메뉴
/// - 닫기 버튼
class PostDetailHeader extends StatelessWidget {
  final String title;
  final bool isUrgent;
  final String typeText;
  final VoidCallback onClose;
  final VoidCallback? onEdit;
  final List<PostDetailMenuItem>? menuItems;
  final String? profileImage;

  const PostDetailHeader({
    super.key,
    required this.title,
    required this.isUrgent,
    required this.typeText,
    required this.onClose,
    this.onEdit,
    this.menuItems,
    this.profileImage,
  });

  String? get _fullImageUrl {
    if (profileImage == null || profileImage!.isEmpty) return null;
    if (profileImage!.startsWith('http')) return profileImage;
    return '${Config.serverUrl}$profileImage';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          // 프로필 사진
          if (_fullImageUrl != null) ...[
            CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(_fullImageUrl!),
              backgroundColor: AppTheme.veryLightGray,
              onBackgroundImageError: (_, __) {},
            ),
            const SizedBox(width: 12),
          ],
          // 제목
          Expanded(
            child: Text(
              title,
              style: AppTheme.h3Style.copyWith(
                color: isUrgent ? Colors.red : AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 더보기 메뉴
          if (menuItems != null && menuItems!.isNotEmpty)
            PopupMenuButton<int>(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              tooltip: '더보기',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onSelected: (index) {
                menuItems![index].onTap();
              },
              itemBuilder: (context) => menuItems!.asMap().entries.map((entry) {
                return PopupMenuItem<int>(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(entry.value.icon, size: 20, color: Colors.black87),
                      const SizedBox(width: 12),
                      Text(entry.value.label),
                    ],
                  ),
                );
              }).toList(),
            )
          else if (onEdit != null)
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
                tooltip: '게시글 수정',
                padding: EdgeInsets.zero,
              ),
            ),
          // 닫기 버튼
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
