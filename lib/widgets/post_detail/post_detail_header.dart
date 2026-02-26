import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// 게시글 상세 바텀시트 헤더
/// - 타입 뱃지 (긴급/정기)
/// - 제목
/// - 수정 버튼 (선택적)
/// - 닫기 버튼
class PostDetailHeader extends StatelessWidget {
  final String title;
  final bool isUrgent; // true: 긴급, false: 정기
  final String typeText; // "긴급" 또는 "정기"
  final VoidCallback onClose;
  final VoidCallback? onEdit; // 수정 버튼 (null이면 미표시)

  const PostDetailHeader({
    super.key,
    required this.title,
    required this.isUrgent,
    required this.typeText,
    required this.onClose,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          // 타입 뱃지 (긴급/정기)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: isUrgent
                  ? Colors.red.withValues(alpha: 0.15)
                  : AppTheme.primaryBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              typeText,
              style: AppTheme.bodySmallStyle.copyWith(
                color: isUrgent ? Colors.red : AppTheme.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 제목
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.h3Style.copyWith(
                    color: isUrgent ? Colors.red : AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 수정 버튼 (onEdit이 있을 때만 표시)
          if (onEdit != null)
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
