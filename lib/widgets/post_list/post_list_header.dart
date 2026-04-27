import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'post_list_layout.dart';

/// 게시글 리스트 헤더 [구분 / 제목 / 작성일].
///
/// admin / hospital / user 세 화면이 공통으로 사용.
class PostListHeader extends StatelessWidget {
  const PostListHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final headerStyle = AppTheme.bodyMediumStyle.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade400, width: 2),
        ),
      ),
      child: Row(
        children: [
          // 구분 — 뱃지가 가운데 정렬되므로 라벨도 가운데 정렬
          SizedBox(
            width: PostListLayout.typeWidth,
            child: Text(
              '구분',
              style: headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text('제목', style: headerStyle),
          ),
          SizedBox(
            width: PostListLayout.dateWidth,
            child: Text(
              '작성일',
              style: headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
