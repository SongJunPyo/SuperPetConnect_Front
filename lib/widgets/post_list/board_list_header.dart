import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'board_list_layout.dart';

/// 공지/칼럼 게시판형 리스트 헤더 [구분 / 제목 / 작성일].
///
/// 공지(user/hospital/admin notice_list) 및 칼럼(user/hospital column_list,
/// admin/hospital column_management) 화면이 공통으로 사용.
class BoardListHeader extends StatelessWidget {
  const BoardListHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final headerStyle = AppTheme.bodyMediumStyle.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade400, width: 2),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: BoardListLayout.indexWidth,
            child: Text(
              '구분',
              style: headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('제목', style: headerStyle)),
          const SizedBox(width: 12),
          SizedBox(
            width: BoardListLayout.dateWidth,
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
