/// 게시글 리스트(슬라이딩 탭 화면)에서 공통으로 쓰는 컬럼 너비.
///
/// admin / hospital / user 세 화면이 모두 같은 값을 참조하여
/// 헤더와 행이 어긋나지 않도록 보장.
class PostListLayout {
  PostListLayout._();

  /// 구분(뱃지) 컬럼 너비.
  /// PostTypeBadge 최대 폭(약 40-50px)에 시각적 여유를 둔 값.
  static const double typeWidth = 70;

  /// 작성일 컬럼 너비. "MM.dd"(예: "12.25") 표시용.
  static const double dateWidth = 70;
}
