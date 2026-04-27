import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';
import '../../utils/config.dart';
import '../marquee_text.dart';

/// 공지/칼럼 등 게시판형 리스트 행 [번호 / 제목 / 작성자 / 작성일].
///
/// 카테고리/중요도는 별도 뱃지가 아닌 [titleColor]로 표현.
/// 예: 공지=빨강, 관리자=파랑, 병원=초록, 일반=null(기본 검정).
class BoardListRow extends StatelessWidget {
  const BoardListRow({
    super.key,
    required this.index,
    required this.title,
    required this.authorName,
    required this.createdAt,
    this.titleColor,
    this.authorProfileImage,
    this.onTap,
  });

  /// 리스트 순서 번호 (1부터 시작).
  final int index;

  final String title;

  /// 제목 글씨 색. null이면 기본(textPrimary).
  final Color? titleColor;

  /// 작성자 표시 이름. nickname/name fallback은 호출 측에서 처리.
  final String authorName;

  /// 작성자 프로필 이미지 URL(절대/상대). 없으면 기본 아이콘.
  final String? authorProfileImage;

  final DateTime createdAt;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final displayAuthor =
        authorName.length > 15 ? '${authorName.substring(0, 15)}..' : authorName;
    final hasImage =
        authorProfileImage != null && authorProfileImage!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              child: Text(
                '$index',
                style: AppTheme.bodySmallStyle.copyWith(
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarqueeText(
                    text: title,
                    style: AppTheme.bodyMediumStyle.copyWith(
                      color: titleColor ?? AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    animationDuration: const Duration(milliseconds: 4000),
                    pauseDuration: const Duration(milliseconds: 1000),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: AppTheme.veryLightGray,
                        foregroundImage: hasImage
                            ? NetworkImage(
                                authorProfileImage!.startsWith('http')
                                    ? authorProfileImage!
                                    : '${Config.serverUrl}$authorProfileImage',
                              )
                            : null,
                        onForegroundImageError: hasImage ? (_, __) {} : null,
                        child: Icon(
                          Icons.business,
                          size: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          displayAuthor,
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              DateFormat('yy.MM.dd').format(createdAt),
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.textTertiary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
