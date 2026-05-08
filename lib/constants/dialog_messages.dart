// lib/constants/dialog_messages.dart
//
// FE 화면 팝업 다이얼로그 메시지 — UI 단일 원천.
//
// 백엔드 `constants/messages.py::DialogMsg`를 미러링. 변경 시 BE/FE 동시 갱신 필수.
// 키 컨벤션은 dart 표준(lowerCamelCase) 사용 — 각 상수에 BE 원본 키를 주석으로 표기.
//
// 사용처:
// - register.dart / onboarding_screen.dart  → 가입 완료
// - login.dart / naver_callback.dart        → 승인 대기
// - admin_signup_management.dart            → 회원가입 거절 확인
// - admin_post_check.dart                   → 게시글 마감 완료

class DialogMsg {
  DialogMsg._();

  // ===== 회원가입 완료 (이메일 + 네이버 통일) =====

  // BE: SIGNUP_COMPLETE_TITLE
  static const String signupCompleteTitle = '회원가입 완료';

  // BE: SIGNUP_COMPLETE_BODY
  static const String signupCompleteBody =
      '회원가입이 완료되었습니다.\n관리자 승인까지 기다려주세요.';

  // ===== 승인 대기 중 (재로그인 시) =====

  // BE: PENDING_APPROVAL_TITLE
  static const String pendingApprovalTitle = '승인 대기 중';

  // BE: PENDING_APPROVAL_BODY
  static const String pendingApprovalBody =
      '관리자의 승인을 기다리고 있습니다.\n승인 후 로그인이 가능합니다.';

  // ===== 회원가입 거절 확인 팝업 (관리자) =====

  // BE: SIGNUP_REJECT_CONFIRM_TITLE
  static const String signupRejectConfirmTitle = '회원가입 거절';

  // BE: SIGNUP_REJECT_CONFIRM_BODY (placeholder {user_name})
  static String signupRejectConfirmBody(String userName) =>
      "'$userName' 님의 가입 신청을 거절하시겠습니까?\n"
      '거절 시 신청 정보가 영구 제거되며, 사용자가 다시 가입 신청해야 합니다.';

  // BE: SIGNUP_REJECT_CONFIRM_BUTTON_CONFIRM (빨간색 강조)
  static const String signupRejectConfirmButtonConfirm = '거절';

  // BE: SIGNUP_REJECT_CONFIRM_BUTTON_CANCEL
  static const String signupRejectConfirmButtonCancel = '취소';

  // ===== 헌혈 게시글 마감 완료 팝업 (SnackBar 대체) =====

  // BE: POST_CLOSE_COMPLETE_TITLE
  static const String postCloseCompleteTitle = '헌혈 마감 완료';

  // BE: POST_CLOSE_NO_APPLICANT_BODY (new_status == 4 COMPLETED 직행)
  static const String postCloseNoApplicantBody =
      '신청자가 없는 게시글이 마감 처리되었습니다.\n[헌혈완료] 탭에서 확인할 수 있습니다.';

  // BE: POST_CLOSE_WITH_APPLICANT_BODY (new_status == 3 CLOSED)
  static const String postCloseWithApplicantBody =
      '헌혈 모집이 마감되었습니다.\n[헌혈마감] 탭에서 확인할 수 있습니다.';

  // BE: POST_CLOSE_BUTTON
  static const String postCloseButton = '확인';
}
