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
  static const int postStatusRecruiting = 0;
  static const int postStatusApproved = 1;
  static const int postStatusCancelled = 2;
  static const int postStatusClosed = 3;

  // ===== 신청자 상태 (Applicant Status) =====
  static const int applicantStatusWaiting = 0;
  static const int applicantStatusApproved = 1;
  static const int applicantStatusRejected = 2;
  static const int applicantStatusCancelled = 3;

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
  // 서버 enums.py: ALL=0, ADMIN_ONLY=1, HOSPITAL_ONLY=2, USER_ONLY=3
  static const int noticeTargetAll = 0;
  static const int noticeTargetAdmin = 1;
  static const int noticeTargetHospital = 2;
  static const int noticeTargetUser = 3;

  // ===== 공지사항 중요도 (Notice Importance) =====
  // 0=일반(뱃지 OFF), 1=긴급(뱃지 ON)
  static const int noticeNormal = 0;
  static const int noticeImportant = 1;

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
      default:
        return '알 수 없음';
    }
  }

  /// 신청자 상태 텍스트 반환
  static String getApplicantStatusText(int status) {
    switch (status) {
      case applicantStatusWaiting:
        return '대기';
      case applicantStatusApproved:
        return '승인';
      case applicantStatusRejected:
        return '거절';
      case applicantStatusCancelled:
        return '취소';
      default:
        return '알 수 없음';
    }
  }

  // ===== 신청자 확장 상태 (0~7) =====
  static const int applicantStatusPendingCompletion = 5;
  static const int applicantStatusPendingCancellation = 6;
  static const int applicantStatusFinalCompleted = 7;

  /// 신청자 상태 텍스트 반환 (확장 버전, 0~7)
  /// @Deprecated - AppliedDonationStatus.getStatusText() 사용 권장
  static String getApplicantStatusTextExtended(int status) {
    // AppliedDonationStatus로 통합됨 - 하위 호환성을 위해 유지
    return AppliedDonationStatus.getStatusText(status);
  }

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
}
