import '../models/applied_donation_model.dart';

/// 애플리케이션 전역 상수 정의
class AppConstants {
  // ===== 계정 타입 (Account Type) =====
  // DB/API 기준: 1=관리자, 2=병원, 3=사용자
  static const int accountTypeAdmin = 1;
  static const int accountTypeHospital = 2;
  static const int accountTypeUser = 3;

  // ===== 계정 상태 (Account Status) =====
  static const int accountStatusWaiting = 0;
  static const int accountStatusActive = 1;
  static const int accountStatusInactive = 2;
  static const int accountStatusBlocked = 3;

  // ===== 헌혈 게시글 상태 (Post Status) =====
  static const int postStatusRecruiting = 0;  // 모집대기
  static const int postStatusApproved = 1;    // 헌혈모집 (승인)
  static const int postStatusCancelled = 2;   // 헌혈취소 (거절)
  static const int postStatusClosed = 3;      // 모집마감
  static const int postStatusCompleted = 4;   // 헌혈완료
  static const int postStatusSuspended = 5;  // 대기상태 (관리자가 모집중→대기로 변경)

  // ===== 신청자 상태 (Applicant Status, applied_donation.status) =====
  // 단일 원천: AppliedDonationStatus 클래스 (lib/models/applied_donation_model.dart)
  // 0=PENDING, 1=APPROVED, 2=PENDING_COMPLETION, 3=COMPLETED, 4=CLOSED
  static const int applicantStatusWaiting = 0;
  static const int applicantStatusApproved = 1;
  static const int applicantStatusPendingCompletion = 2;
  static const int applicantStatusCompleted = 3;
  static const int applicantStatusClosed = 4;

  // ===== 시간대 상태 (Time Slot Status) =====
  static const int timeSlotOpen = 0;
  static const int timeSlotClosed = 1;

  // ===== 긴급도 (Post Type / Urgency) =====
  // 0=긴급, 1=정기
  static const int postTypeUrgent = 0;
  static const int postTypeRegular = 1;

  // ===== 동물 타입 (Animal Type) =====
  // 숫자 형식 (API 요청/응답)
  static const int animalTypeDogNum = 0;
  static const int animalTypeCatNum = 1;
  // 문자열 형식 (API 응답 일부)
  static const String animalTypeDog = 'dog';
  static const String animalTypeCat = 'cat';
  // 한국어 표시용
  static const String animalTypeDogKr = '강아지';
  static const String animalTypeCatKr = '고양이';

  // ===== 공지사항 대상 (Notice Target Audience) =====
  // 서버 enums.py: ALL=0, ADMIN_ONLY=1, HOSPITAL_ONLY=2, USER_ONLY=3(deprecated)
  static const int noticeTargetAll = 0;
  static const int noticeTargetAdmin = 1;
  static const int noticeTargetHospital = 2;

  /// 사용자 전용 공지 (deprecated 2026-04-28). 신규 입력 차단(400). DB 0건.
  /// enum 미러링 계약(백엔드와 동일 번호 유지) 보존을 위해 자리만 점유.
  @Deprecated('2026-04-28: 사용자 전용 공지 정책 폐기. 신규 입력 차단됨')
  static const int noticeTargetUser = 3;

  // ===== 공지사항 중요도 (Notice Importance) =====
  // 0=일반(뱃지 OFF), 1=긴급(뱃지 ON)
  static const int noticeNormal = 0;
  static const int noticeImportant = 1;

  // ===== 채혈 부위 (Blood Collection Site) — 2026-05 PR-2 =====
  // 백엔드 constants/enums.py::BloodCollectionSite와 1:1 동기화. 값 변경 금지.
  // 카페 설문지 18-6번 (직전 외부 헌혈 채혈 부위)에서 사용.
  static const int bloodCollectionSiteJugular = 0; // 경정맥
  static const int bloodCollectionSiteLimb = 1; // 사지
  static const int bloodCollectionSiteBoth = 2; // 둘 다
  /// OTHER 선택 시 `prev_blood_collection_site_etc` 컬럼에 자유 텍스트 입력 필수.
  static const int bloodCollectionSiteOther = 3;

  // ===== 직전 외부 헌혈 출처 (Prev Donation Source) — 2026-05 PR-2 =====
  // GET /api/applied-donations/{id}/survey/template 응답의 prev_donation_source 필드.
  // 백엔드는 string 그대로 emit. 프론트는 분기 안전성을 위해 상수로 박제.
  /// 시스템 헌혈 이력 있음 → 직전 헌혈 정보 자동 채움 (수정 불가).
  static const String prevDonationSourceSystem = 'system';
  /// `prior_last_donation_date`만 있음 → 사용자가 prev_* 필드 직접 입력.
  static const String prevDonationSourceExternal = 'external';
  /// 첫 헌혈 → 직전 헌혈 섹션 숨김 또는 비활성.
  static const String prevDonationSourceNone = 'none';

  // ===== 대시보드 페이지 크기 =====
  static const int dashboardItemLimit = 10;
  static const int detailListPageSize = 15;

  // ===== 유틸리티 메서드 =====

  /// 계정 타입 텍스트 반환
  static String getAccountTypeText(int type) {
    switch (type) {
      case accountTypeAdmin:
        return '관리자';
      case accountTypeHospital:
        return '병원';
      case accountTypeUser:
        return '일반 사용자';
      default:
        return '알 수 없음';
    }
  }

  /// 계정 상태 텍스트 반환
  static String getAccountStatusText(int status) {
    switch (status) {
      case accountStatusWaiting:
        return '대기 중';
      case accountStatusActive:
        return '활성화';
      case accountStatusInactive:
        return '비활성화';
      case accountStatusBlocked:
        return '차단됨';
      default:
        return '알 수 없음';
    }
  }

  /// 게시글 상태 텍스트 반환
  static String getPostStatusText(int status) {
    switch (status) {
      case postStatusRecruiting:
        return '대기';
      case postStatusApproved:
        return '승인';
      case postStatusCancelled:
        return '거절';
      case postStatusClosed:
        return '마감';
      case postStatusCompleted:
        return '완료';
      case postStatusSuspended:
        return '대기';
      default:
        return '알 수 없음';
    }
  }

  /// 신청자 상태 텍스트 반환 (AppliedDonationStatus로 위임)
  static String getApplicantStatusText(int status) =>
      AppliedDonationStatus.getStatusText(status);

  /// 긴급도 텍스트 반환
  static String getPostTypeText(int type) {
    switch (type) {
      case postTypeUrgent:
        return '긴급';
      case postTypeRegular:
        return '정기';
      default:
        return '알 수 없음';
    }
  }

  /// 동물 타입 텍스트 반환 (숫자 -> 한국어)
  static String getAnimalTypeText(int type) {
    switch (type) {
      case animalTypeDogNum:
        return animalTypeDogKr;
      case animalTypeCatNum:
        return animalTypeCatKr;
      default:
        return '알 수 없음';
    }
  }

  /// 동물 타입 문자열 반환 (숫자 -> 영어)
  static String getAnimalTypeString(int type) {
    switch (type) {
      case animalTypeDogNum:
        return animalTypeDog;
      case animalTypeCatNum:
        return animalTypeCat;
      default:
        return 'unknown';
    }
  }

  /// 동물 타입 한국어 반환 (문자열 -> 한국어)
  static String getAnimalTypeTextFromString(String type) {
    switch (type) {
      case animalTypeDog:
        return animalTypeDogKr;
      case animalTypeCat:
        return animalTypeCatKr;
      default:
        return '알 수 없음';
    }
  }

  /// 채혈 부위 텍스트 반환 (BloodCollectionSite enum 값 → 한국어).
  /// `bloodCollectionSiteOther`는 `prev_blood_collection_site_etc`에 자유 텍스트가 별도 입력됨.
  static String getBloodCollectionSiteText(int? value) {
    switch (value) {
      case bloodCollectionSiteJugular:
        return '경정맥';
      case bloodCollectionSiteLimb:
        return '사지';
      case bloodCollectionSiteBoth:
        return '둘 다';
      case bloodCollectionSiteOther:
        return '기타';
      default:
        return '미입력';
    }
  }
}
