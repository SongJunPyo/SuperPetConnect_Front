import 'package:flutter/material.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_theme.dart';

/// 공지 색상/정렬 헬퍼.
///
/// 색 매핑 (audience가 importance보다 우선):
/// - audience=관리자 → 파랑
/// - audience=병원 → 초록
/// - audience=전체 + importance=중요 → 빨강
/// - audience=전체 + importance=일반 → null (기본 검정)
///
/// 차원 충돌(audience=관리자/병원 + importance=중요)은
/// admin_notice_create UI에서 양방향 비활성화로 차단.
class NoticeStyling {
  NoticeStyling._();

  /// 공지 제목 색상. null 반환 = 기본 검정 사용.
  static Color? titleColor({
    required int targetAudience,
    required int noticeImportant,
  }) {
    if (targetAudience == AppConstants.noticeTargetAdmin) {
      return AppTheme.primaryBlue;
    }
    if (targetAudience == AppConstants.noticeTargetHospital) {
      return AppTheme.success;
    }
    if (noticeImportant == AppConstants.noticeImportant) {
      return AppTheme.error;
    }
    return null;
  }

  /// 공지 정렬 우선순위 (낮을수록 위에 표시).
  /// 0=빨강(중요), 1=파랑(관리자), 2=초록(병원), 3=검정(일반).
  static int priorityRank({
    required int targetAudience,
    required int noticeImportant,
  }) {
    if (targetAudience == AppConstants.noticeTargetAdmin) return 1;
    if (targetAudience == AppConstants.noticeTargetHospital) return 2;
    if (noticeImportant == AppConstants.noticeImportant) return 0;
    return 3;
  }
}
