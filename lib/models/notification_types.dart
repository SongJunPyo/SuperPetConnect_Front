// 알림 타입 및 관련 상수 정의
enum UserType {
  admin, // 관리자 (account_type = 1)
  hospital, // 병원 (account_type = 2)
  user, // 일반 사용자 (account_type = 3)
}

// DB의 account_type과 UserType 매핑
class UserTypeMapper {
  static const Map<int, UserType> fromAccountType = {
    1: UserType.admin,
    2: UserType.hospital,
    3: UserType.user,
  };

  static const Map<UserType, int> toAccountType = {
    UserType.admin: 1,
    UserType.hospital: 2,
    UserType.user: 3,
  };

  static UserType? fromDbType(int accountType) {
    return fromAccountType[accountType];
  }

  static int toDbType(UserType userType) {
    return toAccountType[userType] ?? 3;
  }
}

// 관리자 알림 타입
enum AdminNotificationType {
  signupRequest, // 회원가입 승인 요청
  postApprovalRequest, // 헌혈 게시글 승인 요청
  donationApplicationRequest, // 헌혈 신청 승인 요청
  columnApprovalRequest, // 칼럼 게시글 승인 요청
  donationCompleted, // 헌혈 완료 보고
  systemNotice, // 시스템 공지 알림
  newPetRegistration, // 신규 반려동물 등록
  petReviewRequest, // 반려동물 재심사 요청
  petPhotoReviewRequest, // 반려동물 프로필 사진 변경 검토 요청
  documentRequestResponded, // 헌혈 자료 요청 응답 수신
}

// 병원 알림 타입
enum HospitalNotificationType {
  postApproved, // 헌혈 게시글 승인
  postRejected, // 헌혈 게시글 거절
  recruitmentDeadline, // 모집 마감
  timeslotFilled, // 특정 시간대 모집 완료
  allTimeslotsFilled, // 모든 시간대 모집 완료
  donationApplication, // 새 헌혈 신청 접수
  donationCompleted, // 헌혈 완료 알림
  columnApproved, // 칼럼 게시글 승인
  columnRejected, // 칼럼 게시글 거절
  systemNotice, // 시스템 공지
  documentRequest, // 헌혈 자료 요청
}

// 사용자 알림 타입
enum UserNotificationType {
  systemNotice, // 시스템 공지 (기본)
  recruitmentClosed, // 모집 마감 알림
  donationCompleted, // 헌혈 완료 알림
  applicationApproved, // 헌혈 신청 승인
  newDonationPost, // 새 헌혈 모집 게시글 알림
  petApproved, // 반려동물 승인
  petRejected, // 반려동물 거절
  petPhotoApproved, // 반려동물 프로필 사진 승인
  petPhotoRejected, // 반려동물 프로필 사진 거절
  documentRequestResponded, // 헌혈 자료 요청 응답 수신
}

// 알림 타입 한국어 이름 매핑
class NotificationTypeNames {
  // 관리자 알림 이름
  static const Map<AdminNotificationType, String> adminNames = {
    AdminNotificationType.signupRequest: '회원가입 승인 요청',
    AdminNotificationType.postApprovalRequest: '헌혈 게시글 승인 요청',
    AdminNotificationType.donationApplicationRequest: '헌혈 신청 승인 요청',
    AdminNotificationType.columnApprovalRequest: '칼럼 게시글 승인 요청',
    AdminNotificationType.donationCompleted: '헌혈 완료 보고',
    AdminNotificationType.systemNotice: '시스템 공지',
    AdminNotificationType.newPetRegistration: '신규 반려동물 등록',
    AdminNotificationType.petReviewRequest: '반려동물 재심사 요청',
    AdminNotificationType.petPhotoReviewRequest: '반려동물 사진 변경 검토',
    AdminNotificationType.documentRequestResponded: '자료 요청 응답',
  };

  // 병원 알림 이름
  static const Map<HospitalNotificationType, String> hospitalNames = {
    HospitalNotificationType.postApproved: '헌혈 게시글 승인',
    HospitalNotificationType.postRejected: '헌혈 게시글 거절',
    HospitalNotificationType.recruitmentDeadline: '모집 마감',
    HospitalNotificationType.timeslotFilled: '시간대 모집 완료',
    HospitalNotificationType.allTimeslotsFilled: '전체 모집 완료',
    HospitalNotificationType.donationApplication: '새 헌혈 신청',
    HospitalNotificationType.donationCompleted: '헌혈 완료',
    HospitalNotificationType.columnApproved: '칼럼 게시글 승인',
    HospitalNotificationType.columnRejected: '칼럼 게시글 거절',
    HospitalNotificationType.systemNotice: '시스템 공지',
    HospitalNotificationType.documentRequest: '헌혈 자료 요청',
  };

  // 사용자 알림 이름
  static const Map<UserNotificationType, String> userNames = {
    UserNotificationType.systemNotice: '시스템 공지',
    UserNotificationType.recruitmentClosed: '모집 마감',
    UserNotificationType.donationCompleted: '헌혈 완료',
    UserNotificationType.applicationApproved: '신청 승인',
    UserNotificationType.newDonationPost: '새 헌혈 모집',
    UserNotificationType.petApproved: '반려동물 승인',
    UserNotificationType.petRejected: '반려동물 거절',
    UserNotificationType.petPhotoApproved: '반려동물 사진 승인',
    UserNotificationType.petPhotoRejected: '반려동물 사진 거절',
    UserNotificationType.documentRequestResponded: '자료 요청 응답',
  };
}

// 알림 타입 아이콘 매핑
class NotificationTypeIcons {
  // 관리자 알림 아이콘
  static const Map<AdminNotificationType, String> adminIcons = {
    AdminNotificationType.signupRequest: '👤',
    AdminNotificationType.postApprovalRequest: '📝',
    AdminNotificationType.donationApplicationRequest: '💉',
    AdminNotificationType.columnApprovalRequest: '📄',
    AdminNotificationType.donationCompleted: '✅',
    AdminNotificationType.systemNotice: '🔔',
    AdminNotificationType.newPetRegistration: '🐾',
    AdminNotificationType.petReviewRequest: '🔄',
    AdminNotificationType.petPhotoReviewRequest: '📸',
    AdminNotificationType.documentRequestResponded: '📄',
  };

  // 병원 알림 아이콘
  static const Map<HospitalNotificationType, String> hospitalIcons = {
    HospitalNotificationType.postApproved: '✅',
    HospitalNotificationType.postRejected: '❌',
    HospitalNotificationType.recruitmentDeadline: '⏰',
    HospitalNotificationType.timeslotFilled: '🕐',
    HospitalNotificationType.allTimeslotsFilled: '🎉',
    HospitalNotificationType.donationApplication: '💉',
    HospitalNotificationType.donationCompleted: '✅',
    HospitalNotificationType.columnApproved: '✅',
    HospitalNotificationType.columnRejected: '❌',
    HospitalNotificationType.systemNotice: '🔔',
    HospitalNotificationType.documentRequest: '📋',
  };

  // 사용자 알림 아이콘
  static const Map<UserNotificationType, String> userIcons = {
    UserNotificationType.systemNotice: '🔔',
    UserNotificationType.recruitmentClosed: '⏰',
    UserNotificationType.donationCompleted: '✅',
    UserNotificationType.applicationApproved: '✅',
    UserNotificationType.newDonationPost: '🩸',
    UserNotificationType.petApproved: '🐾',
    UserNotificationType.petRejected: '🚫',
    UserNotificationType.petPhotoApproved: '📸',
    UserNotificationType.petPhotoRejected: '🚫',
    UserNotificationType.documentRequestResponded: '📄',
  };
}

// 알림 우선순위 (높을수록 중요)
class NotificationPriority {
  static const int low = 1;
  static const int normal = 2;
  static const int high = 3;
  static const int urgent = 4;

  // 관리자 알림 우선순위
  static const Map<AdminNotificationType, int> adminPriorities = {
    AdminNotificationType.signupRequest: normal,
    AdminNotificationType.postApprovalRequest: high,
    AdminNotificationType.donationApplicationRequest: high,
    AdminNotificationType.columnApprovalRequest: normal,
    AdminNotificationType.donationCompleted: normal,
    AdminNotificationType.systemNotice: urgent,
    AdminNotificationType.newPetRegistration: normal,
    AdminNotificationType.petReviewRequest: normal,
    AdminNotificationType.petPhotoReviewRequest: normal,
    AdminNotificationType.documentRequestResponded: high,
  };

  // 병원 알림 우선순위
  static const Map<HospitalNotificationType, int> hospitalPriorities = {
    HospitalNotificationType.postApproved: high,
    HospitalNotificationType.postRejected: high,
    HospitalNotificationType.recruitmentDeadline: urgent,
    HospitalNotificationType.timeslotFilled: high,
    HospitalNotificationType.allTimeslotsFilled: urgent,
    HospitalNotificationType.donationApplication: high,
    HospitalNotificationType.donationCompleted: high,
    HospitalNotificationType.columnApproved: normal,
    HospitalNotificationType.columnRejected: normal,
    HospitalNotificationType.systemNotice: urgent,
    HospitalNotificationType.documentRequest: high,
  };

  // 사용자 알림 우선순위
  static const Map<UserNotificationType, int> userPriorities = {
    UserNotificationType.systemNotice: urgent,
    UserNotificationType.recruitmentClosed: high,
    UserNotificationType.donationCompleted: high,
    UserNotificationType.applicationApproved: high,
    UserNotificationType.newDonationPost: high,
    UserNotificationType.petApproved: high,
    UserNotificationType.petRejected: high,
    UserNotificationType.petPhotoApproved: normal,
    UserNotificationType.petPhotoRejected: high,
    UserNotificationType.documentRequestResponded: high,
  };
}

// 알림 타입 ID 매핑 (서버 API와 호환)
class NotificationTypeIds {
  // 관리자 알림 ID
  static const Map<AdminNotificationType, int> adminIds = {
    AdminNotificationType.signupRequest: 101,
    AdminNotificationType.postApprovalRequest: 102,
    AdminNotificationType.donationApplicationRequest: 103,
    AdminNotificationType.columnApprovalRequest: 104,
    AdminNotificationType.donationCompleted: 105,
    AdminNotificationType.systemNotice: 106,
    AdminNotificationType.newPetRegistration: 107,
    AdminNotificationType.petReviewRequest: 108,
    AdminNotificationType.petPhotoReviewRequest: 109,
    AdminNotificationType.documentRequestResponded: 110,
  };

  // 병원 알림 ID
  static const Map<HospitalNotificationType, int> hospitalIds = {
    HospitalNotificationType.postApproved: 201,
    HospitalNotificationType.postRejected: 202,
    HospitalNotificationType.recruitmentDeadline: 203,
    HospitalNotificationType.timeslotFilled: 204,
    HospitalNotificationType.allTimeslotsFilled: 205,
    HospitalNotificationType.donationApplication: 206,
    HospitalNotificationType.donationCompleted: 210,
    HospitalNotificationType.columnApproved: 207,
    HospitalNotificationType.columnRejected: 208,
    HospitalNotificationType.systemNotice: 209,
    HospitalNotificationType.documentRequest: 211,
  };

  // 사용자 알림 ID
  static const Map<UserNotificationType, int> userIds = {
    UserNotificationType.systemNotice: 301,
    UserNotificationType.recruitmentClosed: 302,
    UserNotificationType.donationCompleted: 303,
    UserNotificationType.applicationApproved: 304,
    UserNotificationType.newDonationPost: 306,
    UserNotificationType.petApproved: 307,
    UserNotificationType.petRejected: 308,
    UserNotificationType.petPhotoApproved: 309,
    UserNotificationType.petPhotoRejected: 310,
    UserNotificationType.documentRequestResponded: 311,
  };

  // ID에서 타입으로 역매핑
  static AdminNotificationType? getAdminTypeById(int id) {
    return adminIds.entries
        .where((entry) => entry.value == id)
        .map((entry) => entry.key)
        .firstOrNull;
  }

  static HospitalNotificationType? getHospitalTypeById(int id) {
    return hospitalIds.entries
        .where((entry) => entry.value == id)
        .map((entry) => entry.key)
        .firstOrNull;
  }

  static UserNotificationType? getUserTypeById(int id) {
    return userIds.entries
        .where((entry) => entry.value == id)
        .map((entry) => entry.key)
        .firstOrNull;
  }
}
