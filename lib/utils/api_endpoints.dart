/// API 엔드포인트 중앙 관리 클래스
/// 모든 API 경로는 이 클래스를 통해 접근
class ApiEndpoints {
  // Base URLs
  static const String api = '/api';

  // ===== Auth =====
  static const String authLogin = '$api/auth/login';
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
  static const String adminNotices = '$admin/notices';
  static const String adminSignups = '$admin/signups';
  static const String adminUsers = '$admin/users';
  static const String adminHospitals = '$admin/hospitals';

  // ===== Public (인증 불필요) =====
  static const String publicPosts = '$api/posts';
  static const String publicColumns = '$api/public/columns';
  static const String publicNotices = '$api/public/notices';
  static const String columns = '$api/columns';
  static const String mainDashboard = '$api/main/dashboard';

  // ===== Notices =====
  static const String notices = '$api/notices';

  // ===== Applied Donation =====
  static const String appliedDonation = '$api/applied_donation';

  // ===== Helper methods =====

  /// 병원 게시물 상세: /api/hospital/posts/{postIdx}
  static String hospitalPost(int postIdx) => '$hospitalPosts/$postIdx';

  /// 병원 게시물 삭제 (단수형 post 사용): /api/hospital/post/{postIdx}
  static String hospitalPostDelete(int postIdx) => '$hospital/post/$postIdx';

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

  /// 신청 상태 업데이트: /api/applied_donation/{idx}/status
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

  /// 공개 게시물 상세: /api/public/posts/{postIdx}
  static String publicPostDetail(int postIdx) => '$publicPosts/$postIdx';

  // ===== Donation Dates =====
  static const String donationDates = '$api/donation-dates';
  static const String donationDatesBulk = '$donationDates/bulk';

  /// 특정 게시물의 헌혈 날짜: /api/donation-dates/post/{postIdx}
  static String donationDatesByPost(int postIdx) =>
      '$donationDates/post/$postIdx';

  /// 특정 헌혈 날짜: /api/donation-dates/{dateIdx}
  static String donationDate(int dateIdx) => '$donationDates/$dateIdx';

  // ===== Donation Post Times =====
  static const String donationPostTimes = '$api/donation_post_times';
  static const String donationPostTimesBulk = '$donationPostTimes/bulk';
  static const String donationPostTimesDateTime =
      '$donationPostTimes/date-time';

  /// 특정 날짜의 시간대: /api/donation_post_times/date/{dateIdx}
  static String donationPostTimesByDate(int dateIdx) =>
      '$donationPostTimes/date/$dateIdx';

  /// 특정 시간대: /api/donation_post_times/{timeIdx}
  static String donationPostTime(int timeIdx) =>
      '$donationPostTimes/$timeIdx';

  /// 게시물별 날짜-시간 조합: /api/donation_post_times/post/{postIdx}/dates-with-times
  static String donationPostTimesDatesWithTimes(int postIdx) =>
      '$donationPostTimes/post/$postIdx/dates-with-times';

  // ===== Completed Donation =====
  static const String completedDonation = '$api/completed_donation';
  static const String completedDonationHospitalComplete =
      '$completedDonation/hospital_complete';
  static const String completedDonationHospitalStats =
      '$completedDonation/hospital/stats';
  static const String completedDonationMyPetsHistory =
      '$completedDonation/my-pets/history';

  /// 게시물별 완료 목록: /api/completed_donation/post/{postIdx}/completions
  static String completedDonationByPost(int postIdx) =>
      '$completedDonation/post/$postIdx/completions';

  /// 완료 헌혈 상세: /api/completed_donation/{idx}
  static String completedDonationDetail(int idx) =>
      '$completedDonation/$idx';

  /// 반려동물별 완료 이력: /api/completed_donation/pet/{petIdx}/history
  static String completedDonationByPet(int petIdx) =>
      '$completedDonation/pet/$petIdx/history';

  /// 월별 통계: /api/completed_donation/stats/monthly/{year}/{month}
  static String completedDonationMonthlyStats(int year, int month) =>
      '$completedDonation/stats/monthly/$year/$month';

  // ===== Cancelled Donation =====
  static const String cancelledDonation = '$api/cancelled_donation';
  static const String cancelledDonationHospitalCancel =
      '$cancelledDonation/hospital_cancel';
  static const String cancelledDonationReasons =
      '$cancelledDonation/templates/reasons';
  static const String cancelledDonationMyPetsHistory =
      '$cancelledDonation/my-pets/history';
  static const String cancelledDonationHospitalStats =
      '$cancelledDonation/hospital/stats';

  /// 취소 헌혈 상세: /api/cancelled_donation/{idx}
  static String cancelledDonationDetail(int idx) =>
      '$cancelledDonation/$idx';

  /// 게시물별 취소 목록: /api/cancelled_donation/post/{postIdx}/cancellations
  static String cancelledDonationByPost(int postIdx) =>
      '$cancelledDonation/post/$postIdx/cancellations';

  /// 월별 취소 통계: /api/cancelled_donation/stats/monthly/{year}/{month}
  static String cancelledDonationMonthlyStats(int year, int month) =>
      '$cancelledDonation/stats/monthly/$year/$month';

  // ===== Applied Donation (확장) =====
  static const String appliedDonationMyPets =
      '$appliedDonation/my-pets/applications';

  /// 신청 상세: /api/applied_donation/{idx}
  static String appliedDonationDetail(int idx) => '$appliedDonation/$idx';

  /// 게시물별 신청 목록: /api/applied_donation/post/{postIdx}/applications
  static String appliedDonationByPost(int postIdx) =>
      '$appliedDonation/post/$postIdx/applications';

  /// 시간대별 신청 목록: /api/applied_donation/time-slot/{postTimesIdx}/applications
  static String appliedDonationByTimeSlot(int postTimesIdx) =>
      '$appliedDonation/time-slot/$postTimesIdx/applications';

  /// 게시물별 신청 통계: /api/applied_donation/post/{postIdx}/stats
  static String appliedDonationPostStats(int postIdx) =>
      '$appliedDonation/post/$postIdx/stats';

  /// 관리자 상태별 신청 조회: /api/applied_donation/admin/by-status/{status}
  static String appliedDonationAdminByStatus(int status) =>
      '$appliedDonation/admin/by-status/$status';

  // ===== Donation (사용자용) =====
  static const String donationApply = '$api/donation/apply';
  static const String donationMyApplications =
      '$api/donation/my-applications';

  /// 헌혈 신청 상세: /api/donation/applications/{applicationId}
  static String donationApplication(int applicationId) =>
      '$api/donation/applications/$applicationId';

  // ===== Black List =====
  static const String blackList = '$admin/black-list';

  /// 블랙리스트 상세: /api/admin/black-list/{idx}
  static String blackListDetail(int idx) => '$blackList/$idx';

  /// 블랙리스트 해제: /api/admin/black-list/{idx}/release
  static String blackListRelease(int idx) => '$blackList/$idx/release';

  /// 사용자 블랙리스트 상태: /api/admin/user/{accountIdx}/black-list-status
  static String adminUserBlackListStatus(int accountIdx) =>
      '$admin/user/$accountIdx/black-list-status';

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
      '$admin/completed_donation';
  static const String adminCompletedDonationPending =
      '$adminCompletedDonation/pending';
  static const String adminCompletedDonationCompleted =
      '$adminCompletedDonation/completed';

  /// 완료 승인: /api/admin/completed_donation/approve-completion/{applicationId}
  static String adminCompletedDonationApprove(int applicationId) =>
      '$adminCompletedDonation/approve-completion/$applicationId';

  /// 취소 승인: /api/admin/completed_donation/approve-cancellation/{applicationId}
  static String adminCompletedDonationApproveCancellation(
    int applicationId,
  ) => '$adminCompletedDonation/approve-cancellation/$applicationId';

  /// 취소 최종 승인: /api/admin/cancelled_donation/final_approve
  static const String adminCancelledDonationFinalApprove =
      '$admin/cancelled_donation/final_approve';

  // ===== Admin Donation Approval =====
  static const String adminDonationFinalApproval =
      '$admin/donation_final_approval';
  static const String adminDonationBatchApproval =
      '$admin/donation_batch_approval';
  static const String adminPendingDonations = '$admin/pending_donations';
  static const String adminDonationApprovalStats =
      '$admin/donation_approval_stats';

  /// 대기중인 신청 조회: /api/admin/pending_applications/{postTimesIdx}
  static String adminPendingApplications(int postTimesIdx) =>
      '$admin/pending_applications/$postTimesIdx';

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
  static const String hospitalPostImage = '$hospital/post/image';
  static const String hospitalPostImageOrder = '$hospitalPostImage/order';

  /// 게시물 이미지 상세: /api/hospital/post/image/{imageId}
  static String hospitalPostImageDetail(int imageId) =>
      '$hospitalPostImage/$imageId';

  /// 게시물별 이미지 목록: /api/hospital/post/images/{postIdx}
  static String hospitalPostImagesByPost(int postIdx) =>
      '$hospital/post/images/$postIdx';

  // ===== Pet Detail =====
  /// 반려동물 상세: /api/pets/{petIdx}
  static String petDetail(int petIdx) => '$userPets/$petIdx';

  // ===== Admin Hospital (확장) =====
  static const String adminHospitalsList = '$adminHospitals/list';
  static const String adminHospitalsSearch = '$adminHospitals/search';
  static const String adminHospitalsStatistics =
      '$adminHospitals/statistics/summary';

  /// 관리자 병원 상세: /api/admin/hospitals/{accountIdx}
  static String adminHospital(int accountIdx) =>
      '$adminHospitals/$accountIdx';
}
