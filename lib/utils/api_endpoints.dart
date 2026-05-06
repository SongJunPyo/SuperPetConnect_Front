/// API 엔드포인트 중앙 관리 클래스
/// 모든 API 경로는 이 클래스를 통해 접근
class ApiEndpoints {
  // Base URLs
  static const String api = '/api';

  // ===== Auth =====
  // 로그인은 /api/login 레거시 경로를 그대로 사용합니다 ( /api/auth/login 은 존재하지 않음 ).
  // 호출 위치: lib/auth/login.dart
  static const String authSignup = '$api/auth/signup';
  static const String authProfile = '$api/auth/profile';
  static const String authRefresh = '$api/auth/refresh';

  // ===== User =====
  static const String userPets = '$api/pets';
  static const String userApplications = '$api/user/applications';
  static const String fcmToken = '$api/user/fcm-token';
  static const String userDonations = '$api/user/donations';

  // ===== Hospital =====
  static const String hospital = '$api/hospital';
  static const String hospitalPosts = '$hospital/posts';
  static const String hospitalPostTimes = '$hospital/post-times';
  static const String hospitalColumns = '$hospital/columns';
  static const String hospitalApplicants = '$hospital/applicants';
  static const String hospitalPostsRejected = '$hospitalPosts/rejected';

  // ===== Admin =====
  static const String admin = '$api/admin';
  static const String adminPosts = '$admin/posts';
  static const String adminNotices = '$admin/notices';
  static const String adminSignups = '$admin/signups';
  static const String adminUsers = '$admin/users';
  static const String adminHospitals = '$admin/hospitals';

  /// 게시글 대기상태로 변경: PATCH /api/admin/posts/{postIdx}/suspend
  static String adminPostSuspend(int postIdx) => '$adminPosts/$postIdx/suspend';

  /// 대기상태 게시글 모집중으로 변경: PATCH /api/admin/posts/{postIdx}/resume
  static String adminPostResume(int postIdx) => '$adminPosts/$postIdx/resume';

  /// 게시글 삭제: DELETE /api/admin/posts/{postIdx}
  static String adminPostDelete(int postIdx) => '$adminPosts/$postIdx';

  // ===== Auth (확장) =====
  static const String notificationSettings =
      '$api/auth/notification-settings';

  // ===== Settings =====
  static const String surveyLinks = '$api/settings/survey-links';
  static const String termsOfService = '$api/settings/terms-of-service';

  // ===== Public (인증 불필요) =====
  static const String publicPosts = '$api/posts';
  static const String publicColumns = '$api/public/columns';
  static const String publicNotices = '$api/public/notices';
  static const String columns = '$api/columns';
  static const String mainDashboard = '$api/main/dashboard';

  // ===== Notices =====
  static const String notices = '$api/notices';

  // ===== Applied Donation =====
  static const String appliedDonation = '$api/applied-donations';

  // ===== Donation Survey (2026-05 PR-2) =====
  /// 동의 텍스트 + 5개 동의 항목: GET /api/donation-consent/items
  /// 신청 시점/설문 시점 모두 동일 endpoint 사용 (UI에서 분기).
  static const String donationConsentItems = '$api/donation-consent/items';

  /// 설문 작성용 자동 채움 데이터: GET /api/applied-donations/{id}/survey/template
  static String donationSurveyTemplate(int applicationId) =>
      '$appliedDonation/$applicationId/survey/template';

  /// 설문 본문 CRUD: /api/applied-donations/{id}/survey
  /// - GET: 본인 설문 조회 (잠금 후에도 read-only로 200)
  /// - POST: 신규 작성 (status==APPROVED, 1신청당 1설문, 409 SURVEY_ALREADY_EXISTS 가드)
  /// - PATCH: 수정 (잠금 시 400 SURVEY_LOCKED, admin 열람 후엔 admin_reviewed_at NULL 복귀 옵션 A+C)
  static String donationSurvey(int applicationId) =>
      '$appliedDonation/$applicationId/survey';

  // ===== Donation Survey — Admin (2026-05 PR-3) =====
  /// 관리자 설문 목록: GET /api/admin/donation-surveys
  /// query: review_status, post_idx, hospital_code, donation_date_from/to,
  ///        application_status, sort, page, page_size
  static const String adminDonationSurveys = '$admin/donation-surveys';

  /// 검토 대기 카운트 (배지 전용 경량): GET /api/admin/donation-surveys/pending-count
  static const String adminDonationSurveysPendingCount =
      '$admin/donation-surveys/pending-count';

  /// 관리자 설문 단건 (옵션 a 자동 PATCH): GET /api/admin/donation-surveys/{idx}
  /// 첫 GET 시 admin_reviewed_at = NOW + admin_reviewed_by 설정. 두 번째 이후 read-only.
  static String adminDonationSurvey(int surveyIdx) =>
      '$admin/donation-surveys/$surveyIdx';

  /// 게시글별 설문 일괄 (admin): GET /api/admin/posts/{post_idx}/donation-surveys
  static String adminPostDonationSurveys(int postIdx) =>
      '$admin/posts/$postIdx/donation-surveys';

  // ===== Donation Survey — Hospital (2026-05 PR-3) =====
  /// 병원 게시글의 신청자 설문 일괄: GET /api/hospital/posts/{post_idx}/donation-surveys
  /// 자동 권한 필터 (post.hospital_idx 검증). 다른 병원 → 403.
  static String hospitalPostDonationSurveys(int postIdx) =>
      '$hospitalPosts/$postIdx/donation-surveys';

  /// 병원 설문 단건: GET /api/hospital/donation-surveys/{idx}
  /// assert_hospital_owns_application 가드 (다른 병원 설문 → 403).
  static String hospitalDonationSurvey(int surveyIdx) =>
      '$hospital/donation-surveys/$surveyIdx';

  // ===== Donation Survey — Downloads (2026-05 PR-4) =====
  /// 관리자 단건 PDF: GET /api/admin/donation-surveys/{idx}/pdf
  /// 응답: application/pdf + Content-Disposition: attachment; filename*=UTF-8''<%encoded>
  static String adminDonationSurveyPdf(int surveyIdx) =>
      '$admin/donation-surveys/$surveyIdx/pdf';

  /// 관리자 게시글 일괄 Excel: GET /api/admin/posts/{post_idx}/donation-surveys.xlsx
  static String adminPostDonationSurveysXlsx(int postIdx) =>
      '$admin/posts/$postIdx/donation-surveys.xlsx';

  /// 병원 단건 PDF: GET /api/hospital/donation-surveys/{idx}/pdf
  /// assert_hospital_owns_application 가드.
  static String hospitalDonationSurveyPdf(int surveyIdx) =>
      '$hospital/donation-surveys/$surveyIdx/pdf';

  /// 병원 게시글 일괄 Excel: GET /api/hospital/posts/{post_idx}/donation-surveys.xlsx
  /// assert_hospital_owns_post 가드.
  static String hospitalPostDonationSurveysXlsx(int postIdx) =>
      '$hospitalPosts/$postIdx/donation-surveys.xlsx';

  // ===== Helper methods =====

  /// 병원 게시물 상세: /api/hospital/posts/{postIdx}
  static String hospitalPost(int postIdx) => '$hospitalPosts/$postIdx';

  /// 병원 게시물 삭제: /api/hospital/posts/{postIdx}
  /// (2026-05-02 백엔드 경로 정규화로 단수→복수 통일)
  static String hospitalPostDelete(int postIdx) => '$hospitalPosts/$postIdx';

  /// 병원 게시물 상태 변경: /api/hospital/posts/{postIdx}/status
  static String hospitalPostStatus(int postIdx) =>
      '$hospitalPosts/$postIdx/status';

  /// 병원 게시물의 신청자 목록: /api/hospital/posts/{postIdx}/applicants
  static String hospitalPostApplicants(int postIdx) =>
      '$hospitalPosts/$postIdx/applicants';

  /// 병원 게시물의 특정 신청자: /api/hospital/posts/{postIdx}/applicants/{applicationId}
  static String hospitalApplicantDetail(int postIdx, int applicationId) =>
      '$hospitalPosts/$postIdx/applicants/$applicationId';

  /// 사용자의 헌혈 신청: /api/hospital/posts/{postIdx}/applications
  static String hospitalPostApplications(int postIdx) =>
      '$hospitalPosts/$postIdx/applications';

  /// 신청 상태 업데이트: /api/applied-donations/{idx}/status
  static String appliedDonationStatus(int idx) =>
      '$appliedDonation/$idx/status';

  /// 반려동물 헌혈 이력: /api/pets/{petId}/donation-history
  static String petDonationHistory(int petId) =>
      '$api/pets/$petId/donation-history';

  /// 공지사항 상세: /api/notices/{noticeIdx}
  static String noticeDetail(int noticeIdx) => '$notices/$noticeIdx';

  /// 공개 공지사항 상세: /api/public/notices/{noticeIdx}
  static String publicNoticeDetail(int noticeIdx) =>
      '$publicNotices/$noticeIdx';

  /// 칼럼 상세: /api/public/columns/{columnIdx}
  static String columnDetail(int columnIdx) => '$publicColumns/$columnIdx';

  /// 헌혈 게시물 상세: /api/public/posts/{postIdx}
  static String publicPostDetail(int postIdx) => '$api/public/posts/$postIdx';

  // ===== Donation Dates =====
  static const String donationDates = '$api/donation-dates';
  static const String donationDatesBulk = '$donationDates/bulk';

  /// 특정 게시물의 헌혈 날짜: /api/donation-dates/post/{postIdx}
  static String donationDatesByPost(int postIdx) =>
      '$donationDates/post/$postIdx';

  /// 특정 헌혈 날짜: /api/donation-dates/{dateIdx}
  static String donationDate(int dateIdx) => '$donationDates/$dateIdx';

  // ===== Donation Post Times =====
  static const String donationPostTimes = '$api/donation-post-times';
  static const String donationPostTimesBulk = '$donationPostTimes/bulk';
  static const String donationPostTimesDateTime =
      '$donationPostTimes/date-time';

  /// 특정 날짜의 시간대: /api/donation-post-times/date/{dateIdx}
  static String donationPostTimesByDate(int dateIdx) =>
      '$donationPostTimes/date/$dateIdx';

  /// 특정 시간대: /api/donation-post-times/{timeIdx}
  static String donationPostTime(int timeIdx) =>
      '$donationPostTimes/$timeIdx';

  /// 게시물별 날짜-시간 조합: /api/donation-post-times/post/{postIdx}/dates-with-times
  static String donationPostTimesDatesWithTimes(int postIdx) =>
      '$donationPostTimes/post/$postIdx/dates-with-times';

  // ===== Completed Donation =====
  static const String completedDonation = '$api/completed-donations';
  static const String completedDonationHospitalComplete =
      '$completedDonation/hospital-complete';
  static const String completedDonationHospitalStats =
      '$completedDonation/hospital/stats';
  static const String completedDonationMyPetsHistory =
      '$completedDonation/my-pets/history';

  /// 게시물별 완료 목록: /api/completed-donations/post/{postIdx}/completions
  static String completedDonationByPost(int postIdx) =>
      '$completedDonation/post/$postIdx/completions';

  /// 완료 헌혈 상세: /api/completed-donations/{idx}
  static String completedDonationDetail(int idx) =>
      '$completedDonation/$idx';

  /// 반려동물별 완료 이력: /api/completed-donations/pet/{petIdx}/history
  static String completedDonationByPet(int petIdx) =>
      '$completedDonation/pet/$petIdx/history';

  /// 월별 통계: /api/completed-donations/stats/monthly/{year}/{month}
  static String completedDonationMonthlyStats(int year, int month) =>
      '$completedDonation/stats/monthly/$year/$month';

  // ===== Applied Donation (확장) =====
  static const String appliedDonationMyPets =
      '$appliedDonation/my-pets/applications';

  /// 신청 상세: /api/applied-donations/{idx}
  static String appliedDonationDetail(int idx) => '$appliedDonation/$idx';

  /// 게시물별 신청 목록: /api/applied-donations/post/{postIdx}/applications
  static String appliedDonationByPost(int postIdx) =>
      '$appliedDonation/post/$postIdx/applications';

  /// 시간대별 신청 목록: /api/applied-donations/time-slot/{postTimesIdx}/applications
  static String appliedDonationByTimeSlot(int postTimesIdx) =>
      '$appliedDonation/time-slot/$postTimesIdx/applications';

  /// 게시물별 신청 통계: /api/applied-donations/post/{postIdx}/stats
  static String appliedDonationPostStats(int postIdx) =>
      '$appliedDonation/post/$postIdx/stats';

  /// 관리자 상태별 신청 조회: /api/applied-donations/admin/by-status/{status}
  static String appliedDonationAdminByStatus(int status) =>
      '$appliedDonation/admin/by-status/$status';

  // ===== Donation (사용자용) =====
  static const String donationApply = '$api/donation/apply';
  static const String donationMyApplications =
      '$api/donation/my-applications';

  /// 헌혈 신청 상세: /api/donation/applications/{applicationId}
  static String donationApplication(int applicationId) =>
      '$api/donation/applications/$applicationId';

  /// 헌혈 자료 요청: POST /api/donation/request-documents
  static const String donationRequestDocuments =
      '$api/donation/request-documents';

  // ===== Black List =====
  static const String blackList = '$admin/black-list';

  /// 블랙리스트 상세: /api/admin/black-list/{idx}
  static String blackListDetail(int idx) => '$blackList/$idx';

  /// 블랙리스트 해제: /api/admin/black-list/{idx}/release
  static String blackListRelease(int idx) => '$blackList/$idx/release';

  /// 사용자 블랙리스트 상태: /api/admin/users/{accountIdx}/black-list-status
  /// (2026-05-02 백엔드 경로 정규화로 단수→복수 통일)
  static String adminUserBlackListStatus(int accountIdx) =>
      '$adminUsers/$accountIdx/black-list-status';

  // ===== Pet Donation History =====
  static const String petDonationHistoryBase = '$api/pet-donation-history';

  /// 반려동물별 이력: /api/pet-donation-history/{petIdx}
  static String petDonationHistoryByPet(int petIdx) =>
      '$petDonationHistoryBase/$petIdx';

  /// 반려동물 이력 일괄 추가: /api/pet-donation-history/{petIdx}/bulk
  static String petDonationHistoryBulk(int petIdx) =>
      '$petDonationHistoryBase/$petIdx/bulk';

  /// 이력 상세 (수정/삭제): /api/pet-donation-history/{historyIdx}
  static String petDonationHistoryItem(int historyIdx) =>
      '$petDonationHistoryBase/$historyIdx';

  // ===== Admin Completed Donation =====
  static const String adminCompletedDonation =
      '$admin/completed-donations';
  static const String adminCompletedDonationPending =
      '$adminCompletedDonation/pending';
  static const String adminCompletedDonationCompleted =
      '$adminCompletedDonation/completed';

  /// 완료 승인: /api/admin/completed-donations/approve-completion/{applicationId}
  static String adminCompletedDonationApprove(int applicationId) =>
      '$adminCompletedDonation/approve-completion/$applicationId';

  // ===== Admin Donation Approval =====
  static const String adminDonationFinalApproval =
      '$admin/donation-final-approval';
  static const String adminPendingDonations = '$admin/pending-donations';
  static const String adminDonationApprovalStats =
      '$admin/donation-approval-stats';

  // 2026-05-02 dead route 정리: /donation_batch_approval, /pending_applications/{idx}
  // 상수와 헬퍼 함수 모두 호출자 0건이라 백엔드 경로 정규화와 함께 제거됨.

  // ===== Notifications =====
  static const String notifications = '$api/notifications';
  static const String notificationsAdmin = '$notifications/admin';
  static const String notificationsHospital = '$notifications/hospital';
  static const String notificationsUser = '$notifications/user';
  static const String notificationReadAll = '$notifications/read-all';
  static const String notificationUnreadCount =
      '$notifications/unread-count';
  static const String notificationBatch = '$notifications/batch';
  static const String notificationAll = '$notifications/all';

  /// 알림 상세: /api/notifications/{idx}
  static String notificationDetail(int idx) => '$notifications/$idx';

  /// 알림 읽음: /api/notifications/{idx}/read
  static String notificationRead(int idx) => '$notifications/$idx/read';

  // ===== Hospital Columns (확장) =====
  static const String hospitalPublicColumns = '$hospital/public/columns';
  static const String hospitalColumnsMy = '$hospitalColumns/my';

  /// 칼럼 상세 (병원): /api/hospital/columns/{columnIdx}
  static String hospitalColumn(int columnIdx) =>
      '$hospitalColumns/$columnIdx';

  /// 칼럼 조회수: /api/hospital/columns/{columnIdx}/view
  static String hospitalColumnView(int columnIdx) =>
      '$hospitalColumns/$columnIdx/view';

  /// 공개 칼럼 상세: /api/hospital/public/columns/{columnIdx}
  static String hospitalPublicColumn(int columnIdx) =>
      '$hospitalPublicColumns/$columnIdx';

  // ===== Admin Columns =====
  static const String adminColumns = '$admin/columns';

  /// 관리자 칼럼 상세: /api/admin/columns/{columnIdx}
  static String adminColumn(int columnIdx) => '$adminColumns/$columnIdx';

  /// 관리자 칼럼 발행: /api/admin/columns/{columnIdx}/publish
  static String adminColumnPublish(int columnIdx) =>
      '$adminColumns/$columnIdx/publish';

  // ===== Column Images =====
  static const String hospitalColumnImages = '$hospitalColumns/images';
  static const String hospitalColumnImageUpload =
      '$hospitalColumnImages/upload';

  /// 칼럼 이미지 상세: /api/hospital/columns/images/{imageId}
  static String hospitalColumnImage(int imageId) =>
      '$hospitalColumnImages/$imageId';

  /// 칼럼별 이미지 목록: /api/hospital/columns/{columnIdx}/images
  static String hospitalColumnImagesByColumn(int columnIdx) =>
      '$hospitalColumns/$columnIdx/images';

  // ===== Post Images =====
  // (2026-05-02 백엔드 경로 정규화로 단수→복수 통일: hospital/post → hospital/posts)
  static const String hospitalPostImage = '$hospital/posts/image';
  static const String hospitalPostImageOrder = '$hospitalPostImage/order';

  /// 게시물 이미지 상세: /api/hospital/posts/image/{imageId}
  static String hospitalPostImageDetail(int imageId) =>
      '$hospitalPostImage/$imageId';

  /// 게시물별 이미지 목록: /api/hospital/posts/images/{postIdx}
  static String hospitalPostImagesByPost(int postIdx) =>
      '$hospital/posts/images/$postIdx';

  // ===== Pet Detail =====
  /// 반려동물 상세: /api/pets/{petIdx}
  static String petDetail(int petIdx) => '$userPets/$petIdx';

  /// 대표 반려동물 설정: PUT /api/pets/{petIdx}/set-primary
  static String petSetPrimary(int petIdx) => '$userPets/$petIdx/set-primary';

  /// 반려동물 프로필 사진 업로드: POST /api/pets/{petIdx}/profile-image
  /// 반려동물 프로필 사진 삭제: DELETE /api/pets/{petIdx}/profile-image
  static String petProfileImage(int petIdx) =>
      '$userPets/$petIdx/profile-image';

  /// 병원/관리자 프로필 사진 업로드: POST /api/auth/profile-image
  /// 병원/관리자 프로필 사진 삭제: DELETE /api/auth/profile-image
  static const String authProfileImage = '$api/auth/profile-image';

  // ===== Admin Pets (반려동물 승인 관리) =====
  static const String adminPets = '$admin/pets';

  /// 관리자 반려동물 목록: GET /api/admin/pets?status=0&page=1&page_size=10
  /// 반려동물 승인: POST /api/admin/pets/{petIdx}/approve
  static String adminPetApprove(int petIdx) => '$adminPets/$petIdx/approve';

  /// 반려동물 거절: POST /api/admin/pets/{petIdx}/reject
  static String adminPetReject(int petIdx) => '$adminPets/$petIdx/reject';

  /// 반려동물 승인 대기로 변경: POST /api/admin/pets/{petIdx}/reset-pending
  static String adminPetResetPending(int petIdx) => '$adminPets/$petIdx/reset-pending';

  /// 사진 검토 대기 목록: GET /api/admin/pets/profile-images/pending
  /// query: page (≥1, default 1), page_size (1~50, default 20). search 미지원, 정렬 pet_idx desc.
  static const String adminPetsProfileImagesPending =
      '$adminPets/profile-images/pending';

  /// 사진 검토 승인: POST /api/admin/pets/{petIdx}/profile-image/approve
  static String adminPetProfileImageApprove(int petIdx) =>
      '$adminPets/$petIdx/profile-image/approve';

  /// 사진 검토 거절: POST /api/admin/pets/{petIdx}/profile-image/reject
  /// body: { rejection_reason?: string } (optional)
  static String adminPetProfileImageReject(int petIdx) =>
      '$adminPets/$petIdx/profile-image/reject';

  /// 관리자 - 사용자별 헌혈 신청내역: GET /api/admin/users/{accountIdx}/applications
  static String adminUserApplications(int accountIdx) =>
      '$adminUsers/$accountIdx/applications';

  // ===== Admin Hospital (확장) =====
  static const String adminHospitalsList = '$adminHospitals/list';
  static const String adminHospitalsSearch = '$adminHospitals/search';
  static const String adminHospitalsStatistics =
      '$adminHospitals/statistics/summary';

  /// 관리자 병원 상세: /api/admin/hospitals/{accountIdx}
  static String adminHospital(int accountIdx) =>
      '$adminHospitals/$accountIdx';

  // ===== Hospital Master (병원 마스터 데이터) =====
  static const String adminHospitalsMaster = '$adminHospitals/master';
  static const String adminHospitalsMasterRegister =
      '$adminHospitalsMaster/register';

  /// 병원 마스터 상세: /api/admin/hospitals/master/{hospitalCode}
  static String adminHospitalMaster(String hospitalCode) =>
      '$adminHospitalsMaster/$hospitalCode';
}
