import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../utils/config.dart';
import '../marquee_text.dart';
import '../post_type_badge.dart';
import 'post_list_layout.dart';

/// 게시글 리스트 행 [구분 뱃지 / (병원 아이콘 +) 제목 / 작성일].
///
/// admin / hospital / user 세 화면이 공통으로 사용. 병원 프로필 이미지가
/// 있으면 제목 앞에 작은 원형 아이콘으로 표시.
class PostListRow extends StatelessWidget {
  const PostListRow({
    super.key,
    required this.badgeType,
    required this.title,
    required this.dateText,
    this.titleColor,
    this.hospitalProfileImage,
    this.onTap,
  });

  /// PostTypeBadge에 전달될 타입 문자열 (긴급/정기/마감/완료대기 등).
  final String badgeType;

  /// 제목 텍스트.
  final String title;

  /// 작성일 표시 문자열 (예: "12.25").
  final String dateText;

  /// 제목 글씨 색상 override. null이면 기본(textPrimary). user 화면에서
  /// 긴급 게시글 빨강 강조용으로 사용.
  final Color? titleColor;

  /// 병원 프로필 이미지 URL(절대 또는 상대). 있으면 제목 앞에 작은 원형
  /// 이미지로 표시.
  final String? hospitalProfileImage;

  /// 행 클릭 콜백.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fontSize = AppTheme.bodyMedium;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 18.0,
          horizontal: 8.0,
        ),
        margin: const EdgeInsets.symmetric(vertical: 1.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 구분 (뱃지) — 가운데 정렬로 헤더 라벨과 시각적으로 정렬
            Container(
              width: PostListLayout.typeWidth,
              alignment: Alignment.center,
              child: PostTypeBadge(type: badgeType),
            ),
            // 제목 (병원 아이콘 + 텍스트). 좌측 패딩 없이 구분 직후에 시작.
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(right: 8.0),
                alignment: Alignment.centerLeft,
                child: MarqueeText(
                  text: title,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w500,
                    color: titleColor,
                  ),
                  leading: hospitalProfileImage != null
                      ? CircleAvatar(
                          radius: fontSize * 0.55,
                          backgroundImage: NetworkImage(
                            hospitalProfileImage!.startsWith('http')
                                ? hospitalProfileImage!
                                : '${Config.serverUrl}$hospitalProfileImage',
                          ),
                          backgroundColor: AppTheme.veryLightGray,
                          onBackgroundImageError: (_, __) {},
                        )
                      : null,
                  animationDuration: const Duration(milliseconds: 5000),
                  pauseDuration: const Duration(milliseconds: 2000),
                ),
              ),
            ),
            // 작성일 — 제목과 같은 크기, bold
            Container(
              width: PostListLayout.dateWidth,
              alignment: Alignment.center,
              child: Text(
                dateText,
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
