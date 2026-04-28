/// 공지/칼럼 게시판형 리스트의 컬럼 너비 상수.
///
/// [BoardListHeader]와 [BoardListRow]가 동일 값을 참조하여
/// 헤더와 행이 어긋나지 않도록 보장.
class BoardListLayout {
  BoardListLayout._();

  /// 구분(번호) 컬럼 너비.
  /// "구분" 헤더 텍스트가 한 줄로 들어가야 하며, 페이지네이션 없는
  /// 화면(admin_notice_list)에서 4자리 인덱스도 표시될 수 있도록 확보.
  static const double indexWidth = 44;

  /// 작성일 컬럼 너비. "yy.MM.dd"(예: "26.04.28") 표시용.
  static const double dateWidth = 70;
}
