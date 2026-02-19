import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';
import '../../utils/text_personalization_util.dart';
import '../marquee_text.dart';
import 'dashboard_badge.dart';
import 'dashboard_view_count_box.dart';

/// 대시보드 리스트 아이템의 통합 위젯 (제네릭)
///
/// NoticePost와 ColumnPost 모두에서 재사용 가능한 리스트 아이템 위젯입니다.
/// 콜백을 통해 각 타입의 데이터를 추출하여 일관된 UI를 제공합니다.
///
/// 사용 예시:
/// ```dart
/// DashboardListItem<NoticePost>(
///   item: notice,
///   index: index + 1,
///   onTap: () => _showNoticeBottomSheet(context, notice),
///   getTitle: (n) => n.title,
///   getAuthor: (n) => n.authorNickname ?? n.authorName,
///   getCreatedAt: (n) => n.createdAt,
///   getUpdatedAt: (n) => n.updatedAt,
///   getViewCount: (n) => n.viewCount ?? 0,
///   shouldShowBadge: (n) => n.showBadge,
///   getBadgeText: (n) => n.badgeText,
///   enableTextPersonalization: true,
///   userName: userName,
///   userNickname: userNickname,
/// )
/// ```
class DashboardListItem<T> extends StatelessWidget {
  /// 표시할 아이템 (NoticePost 또는 ColumnPost)
  final T item;

  /// 리스트에서의 순서 번호 (1부터 시작)
  final int index;

  /// 아이템을 탭했을 때 실행할 콜백
  final VoidCallback onTap;

  /// 제목을 추출하는 콜백
  final String Function(T) getTitle;

  /// 작성자 이름을 추출하는 콜백
  final String Function(T) getAuthor;

  /// 작성일을 추출하는 콜백
  final DateTime Function(T) getCreatedAt;

  /// 수정일을 추출하는 콜백
  final DateTime Function(T) getUpdatedAt;

  /// 조회수를 추출하는 콜백
  final int Function(T) getViewCount;

  /// 뱃지를 표시할지 여부를 판단하는 콜백
  final bool Function(T) shouldShowBadge;

  /// 뱃지 텍스트를 추출하는 콜백
  final String Function(T) getBadgeText;

  /// 텍스트 개인화 활성화 여부 (User/Hospital: true, Admin: false)
  final bool enableTextPersonalization;

  /// 사용자 이름 (텍스트 개인화용)
  final String? userName;

  /// 사용자 닉네임 (텍스트 개인화용)
  final String? userNickname;

  const DashboardListItem({
    super.key,
    required this.item,
    required this.index,
    required this.onTap,
    required this.getTitle,
    required this.getAuthor,
    required this.getCreatedAt,
    required this.getUpdatedAt,
    required this.getViewCount,
    required this.shouldShowBadge,
    required this.getBadgeText,
    this.enableTextPersonalization = false,
    this.userName,
    this.userNickname,
  });

  @override
  Widget build(BuildContext context) {
    final title = getTitle(item);
    final author = getAuthor(item);
    final createdAt = getCreatedAt(item);
    final updatedAt = getUpdatedAt(item);
    final viewCount = getViewCount(item);
    final showBadge = shouldShowBadge(item);
    final badgeText = getBadgeText(item);

    // 텍스트 개인화 적용
    final displayTitle = enableTextPersonalization
        ? TextPersonalizationUtil.personalizeTitle(
            title: title,
            userName: userName ?? '',
            userNickname: userNickname,
          )
        : title;

    // 작성자 이름 길이 제한 (15자)
    final displayAuthor = author.length > 15 ? '${author.substring(0, 15)}..' : author;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 왼쪽: 순서 번호
            SizedBox(
              width: 20,
              height: 50,
              child: Center(
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
            ),
            const SizedBox(width: 8),
            // 중앙: 메인 콘텐츠
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 첫 번째 줄: 뱃지 + 제목
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showBadge) ...[
                        DashboardBadge(text: badgeText),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: MarqueeText(
                          text: displayTitle,
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: showBadge ? AppTheme.error : AppTheme.textPrimary,
                            fontWeight: showBadge ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 14,
                          ),
                          animationDuration: const Duration(milliseconds: 4000),
                          pauseDuration: const Duration(milliseconds: 1000),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 두 번째 줄: 작성자 이름
                  Text(
                    displayAuthor,
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 오른쪽: 날짜들 + 조회수 박스
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 날짜 컬럼 (작성/수정일 세로 배치)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '작성: ${DateFormat('yy.MM.dd').format(createdAt)}',
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '수정: ${DateFormat('yy.MM.dd').format(updatedAt)}',
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // 조회수 박스
                DashboardViewCountBox(viewCount: viewCount),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
