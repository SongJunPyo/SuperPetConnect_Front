import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../admin/admin_column_management.dart';
import '../admin/admin_dashboard.dart';
import '../admin/admin_donation_approval_page.dart';
import '../admin/admin_pet_management.dart';
import '../admin/admin_post_check.dart';
import '../admin/admin_signup_management.dart';
import '../hospital/hospital_column_management_list.dart';
import '../hospital/hospital_dashboard.dart';
import '../hospital/hospital_post_check.dart';
import '../providers/notification_provider.dart';
import '../user/donation_history_screen.dart';
import '../user/my_applications_screen.dart';
import '../user/pet_management.dart';
import '../user/user_dashboard.dart';
import '../user/user_donation_posts_list.dart';
import '../utils/config.dart';
import '../utils/preferences_manager.dart';
import '../web/web_storage_helper_stub.dart'
    if (dart.library.html) '../web/web_storage_helper.dart';
import 'fcm_handler.dart';

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    if (kIsWeb) return;

    // FCM 토큰 서버 전송 (앱 시작 시점 1회). onTokenRefresh 리스너 등록과
    // 포그라운드 메시지 수신/스트림 추가/상단 푸시는 전부 [FCMHandler]가 담당.
    // 이 클래스는 알림 탭 시 네비게이션만 책임.
    await FCMHandler.instance.updateFCMToken();

    // 백그라운드에서 앱을 연 경우 — dispatch 단일 진입점.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      try {
        dispatchByType(Map<String, dynamic>.from(message.data));
      } catch (e) {
        debugPrint('[NotificationService] background dispatch 실패: $e');
      }
    });

    // 앱이 완전히 종료된 상태에서 알림으로 앱을 연 경우 — dispatch 단일 진입점.
    // 1초 delay는 Navigator/Provider가 attach되기 전 dispatch 방지용 (기존 동작 보존).
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message == null) return;
      Future.delayed(const Duration(milliseconds: 1000), () {
        try {
          dispatchByType(Map<String, dynamic>.from(message.data));
        } catch (e) {
          debugPrint('[NotificationService] initial message dispatch 실패: $e');
        }
      });
    });
  }

  /// 로컬 알림 탭 처리 (포그라운드 진입점). dispatch 단일 진입점에 위임.
  static void handleLocalNotificationTap(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      dispatchByType(data);
    } catch (e) {
      debugPrint('[NotificationService] foreground dispatch 실패: $e');
    }
  }

  /// 알림 type별 화면 이동 dispatch — 포그라운드/백그라운드/킬 + 알림 목록 클릭
  /// 네 진입점이 동일한 매핑을 쓰도록 단일 진실 소스로 통합 (drift 방지).
  ///
  /// 신규 type 추가 시 백엔드 `constants/enums.py::NotificationType` +
  /// 프론트 `lib/models/notification_mapping.dart` + 본 switch 세 곳 모두
  /// 갱신해야 한다 (CLAUDE.md "알림 타입 추가 시 dual-sync contract" 참조).
  ///
  /// `data`는 raw `type` 문자열을 포함해야 하며, 그 외에 화면 highlight를 위한
  /// 식별자(post_idx / application_id / pet_idx 등)를 같이 넘긴다.
  static void dispatchByType(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == null) return;

    final parsedData = _parseNotificationData(data);

    switch (type) {
      case 'new_post_approval':
        _navigateToPostManagement(parsedData);
        break;
      case 'donation_post_approved':
        _navigateToHospitalPosts(parsedData);
        break;
      case 'column_approved':
        _navigateToHospitalColumns(parsedData);
        break;
      case 'donation_application_approved':
        _navigateToDonationHistory(parsedData);
        break;
      case 'recruitment_closed':
        _navigateForRecruitmentClosed(parsedData);
        break;
      case 'donation_completed':
        _navigateForDonationCompleted(parsedData);
        break;
      case 'new_donation_post':
        _navigateToNewDonationPost(parsedData);
        break;
      case 'new_pet_registration':
      case 'pet_review_request':
      case 'pet_profile_image_review_request':
        // 사진 검토 요청도 동일하게 관리자 반려동물 관리로 이동.
        // CLAUDE.md "펫 프로필 사진 검토 워크플로우" 참고.
        _navigateToAdminPetManagement(parsedData);
        break;
      case 'new_user_registration':
        _navigateToSignupManagement(parsedData);
        break;
      case 'new_donation_application':
        _navigateForNewDonationApplication(parsedData);
        break;
      case 'column_approval':
        _navigateToAdminColumnManagement(parsedData);
        break;
      case 'column_rejected':
        _navigateToHospitalColumns(parsedData);
        break;
      case 'all_timeslots_filled':
      case 'post_suspended':
      case 'post_resumed':
        _navigateToHospitalPosts(parsedData);
        break;
      case 'donation_post_rejected':
      case 'document_request':
        _navigateToHospitalPostCheck(parsedData);
        break;
      case 'document_request_responded':
        // 자료 요청 응답 — admin/user 양쪽 수신.
        _navigateForDocumentRequestResponded(parsedData);
        break;
      case 'pet_approved':
      case 'pet_rejected':
      case 'pet_profile_image_approved':
      case 'pet_profile_image_rejected':
        // 사진 승인/거절도 사용자 펫 관리 화면으로.
        // 거절 시 사진 옵션 시트 자동 오픈은 안 함 (수정 화면까지만 도착).
        _navigateToUserPetManagement(parsedData);
        break;
      case 'account_suspended':
      case 'account_status_changed':
        _navigateForAccountStatus(parsedData);
        break;
      case 'timeslot_filled':
        // 의도된 dead-end — 정보 알림이라 화면 이동 불필요.
        // CLAUDE.md "알림 다중 수신 라우팅" 정책.
        break;
      default:
        // 매핑 없는 type(systemNotice 류 broadcast/general/admin_alert/hospital_alert,
        // 또는 알 수 없는 신규 type)은 본인 역할 dashboard로 fallback.
        // 알림 목록 클릭 진입에서 systemNotice는 dashboard로 보내던 기존 동작 보존.
        _navigateToOwnDashboard();
        break;
    }
  }

  /// account_type에 따라 본인 역할의 대시보드로 이동.
  /// 매핑 누락 type / systemNotice 류 알림의 fallback 진입점.
  static Future<void> _navigateToOwnDashboard() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final accountType = await PreferencesManager.getAccountType();
    if (!context.mounted) return;

    try {
      Widget dashboard;
      switch (accountType) {
        case 1:
          dashboard = const AdminDashboard();
          break;
        case 2:
          dashboard = const HospitalDashboard();
          break;
        case 3:
        default:
          dashboard = const UserDashboard();
          break;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => dashboard),
      );
    } catch (e) {
      debugPrint('[NotificationService] dashboard fallback 실패: $e');
    }
  }

  // 알림 데이터 파싱 헬퍼 메서드.
  // FCM data는 모든 값이 string으로 직렬화되므로 navigation/post_info 같은
  // 중첩 객체 키는 jsonDecode로 다시 풀어야 함. WebSocket(이미 객체)에 호출해도
  // 안전 — 해당 키가 없으면 그냥 통과.
  static Map<String, dynamic> _parseNotificationData(
    Map<String, dynamic> data,
  ) {
    Map<String, dynamic> parsedData = {};

    try {
      if (data['navigation'] is String) {
        parsedData['navigation'] = jsonDecode(data['navigation'] as String);
      }
      if (data['post_info'] is String) {
        parsedData['post_info'] = jsonDecode(data['post_info'] as String);
      }

      // 다른 필드들도 복사 (위 두 키는 위에서 풀어둔 값으로 덮어씀)
      data.forEach((key, value) {
        parsedData.putIfAbsent(key, () => value);
      });
    } catch (e) {
      // 파싱 실패 시 원본 데이터 반환
      return data;
    }

    return parsedData;
  }

  /// 관리자 게시글 관리(`new_post_approval` 알림) 진입.
  ///
  /// 백엔드 4c1de27 commit 이후 `navigation` 객체 emit 중단됨.
  /// CLAUDE.md "Frontend routing branches solely on data.type" 원칙에 따라
  /// type별 default tab을 프론트가 직접 결정. `new_post_approval` 알림은
  /// 모집대기 탭(`pending_approval`) 단일 진입.
  ///
  /// post_idx 키 정책: top-level `post_idx` 우선, `post_id`는 구버전 fallback.
  static void _navigateToPostManagement(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      final raw = data['post_idx'] ?? data['post_id'];
      final postId = raw is int ? raw : int.tryParse(raw?.toString() ?? '');

      Navigator.pushNamed(
        context,
        '/admin/post-management',
        arguments: {
          'postId': postId,
          'initialTab': 'pending_approval',
          'highlightPost': postId,
        },
      );
    } catch (e) {
      Navigator.pushNamed(context, '/admin/post-management');
    }
  }

  /// 로그인 직후 FCM 토큰을 서버에 재전송. [FCMHandler]로 위임.
  static Future<void> updateTokenAfterLogin() async {
    if (kIsWeb) return;
    await FCMHandler.instance.updateFCMToken();
  }

  // donation_post_approved / all_timeslots_filled / post_suspended /
  // post_resumed 등 병원 게시글 알림을 HospitalPostCheck로 라우팅.
  // _navigateToHospitalPostCheck와 동일 동작 — 같은 함수에 위임.
  static void _navigateToHospitalPosts(Map<String, dynamic> data) {
    _navigateToHospitalPostCheck(data);
  }

  /// column_approved / column_rejected 알림 클릭 시 병원 칼럼 관리 화면 진입.
  /// column_idx가 있으면 HospitalColumnManagementScreen.initialColumnIdx로 전달해
  /// 매칭 칼럼의 상세 시트 자동 오픈
  /// (hospital_column_management_list.dart::_loadAndMaybeAutoOpen 참조).
  static void _navigateToHospitalColumns(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    try {
      final raw = data['column_idx'] ?? data['column_id'];
      final columnIdx =
          raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              HospitalColumnManagementScreen(initialColumnIdx: columnIdx),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] 병원 칼럼 관리 네비게이션 실패: $e');
    }
  }

  // 모집 마감 알림 클릭 시 네비게이션 (직접 push 단순 통일).
  // is_selected="true" → MyApplicationsScreen, 그 외 → UserDonationPostsListScreen.
  static void _navigateForRecruitmentClosed(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    try {
      final isSelected = data['is_selected'] == 'true';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => isSelected
              ? const MyApplicationsScreen()
              : const UserDonationPostsListScreen(),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] 모집 마감 네비게이션 실패: $e');
    }
  }

  /// 관리자용 펫 관련 알림(new_pet_registration / pet_review_request /
  /// pet_profile_image_review_request) 클릭 시 진입.
  /// pet_idx가 있으면 AdminPetManagement.initialPetIdx로 전달해 승인 대기 탭의
  /// fetched 리스트에서 매칭 + 상세 시트 자동 오픈
  /// (admin_pet_management.dart::_maybeAutoOpenDetailSheet 참조).
  static void _navigateToAdminPetManagement(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    try {
      final raw = data['pet_idx'] ?? data['pet_id'];
      final petIdx = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminPetManagement(initialPetIdx: petIdx),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] 반려동물 관리 네비게이션 실패: $e');
    }
  }

  /// 신규 가입 요청 알림(new_user_registration) 클릭 시 가입 관리 화면 진입.
  /// account_idx가 있으면 AdminSignupManagement.initialAccountIdx로 전달해
  /// 매칭 사용자의 승인 다이얼로그 자동 오픈
  /// (admin_signup_management.dart::_fetchAndMaybeAutoOpen 참조).
  static void _navigateToSignupManagement(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    try {
      final raw = data['account_idx'] ?? data['user_id'];
      final accountIdx =
          raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AdminSignupManagement(initialAccountIdx: accountIdx),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] 가입 관리 네비게이션 실패: $e');
    }
  }

  /// 칼럼 승인 요청 알림(column_approval) 클릭 시 관리자 칼럼 관리 화면 진입.
  /// column_idx가 있으면 AdminColumnManagement.initialColumnIdx로 전달해 매칭
  /// 칼럼의 상세 시트 자동 오픈
  /// (admin_column_management.dart::_loadAndMaybeAutoOpen 참조).
  static void _navigateToAdminColumnManagement(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    try {
      final raw = data['column_idx'] ?? data['column_id'];
      final columnIdx =
          raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AdminColumnManagement(initialColumnIdx: columnIdx),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] 칼럼 관리 네비게이션 실패: $e');
    }
  }

  /// new_donation_application(admin only) 알림 클릭 시 진입.
  /// AdminPostCheck의 헌혈모집 탭(index=1)으로 자동 이동 + post_idx 매칭으로
  /// 게시글 상세 시트 자동 오픈 (admin_post_check.dart::initState 참조).
  static void _navigateForNewDonationApplication(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    try {
      final raw = data['post_idx'] ?? data['post_id'];
      final postIdx = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminPostCheck(
            initialPostIdx: postIdx,
            initialTabIndex: 1,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] 헌혈 신청 검토 네비게이션 실패: $e');
    }
  }

  /// donation_post_rejected / document_request 알림 클릭 시 병원 게시글 관리 진입.
  /// post_idx가 있으면 HospitalPostCheck.initialPostIdx로 전달해 단건 fetch +
  /// 상세 시트 자동 오픈 (hospital_post_check.dart::initState 참조).
  static void _navigateToHospitalPostCheck(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    try {
      final raw = data['post_idx'] ?? data['post_id'];
      final postIdx = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HospitalPostCheck(initialPostIdx: postIdx),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] 병원 게시글 관리 네비게이션 실패: $e');
    }
  }

  /// pet_approved / pet_rejected / pet_profile_image_approved /
  /// pet_profile_image_rejected 알림 클릭 시 사용자 반려동물 관리 화면 진입.
  /// pet_idx가 있으면 PetManagementScreen.initialPetIdx로 전달해 매칭 펫의
  /// 상세 시트 자동 오픈 (pet_management.dart::_maybeAutoOpenDetailSheet 참조).
  static void _navigateToUserPetManagement(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    try {
      final raw = data['pet_idx'] ?? data['pet_id'];
      final petIdx = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PetManagementScreen(initialPetIdx: petIdx),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] 사용자 반려동물 관리 네비게이션 실패: $e');
    }
  }

  // 새 헌혈 모집 게시글 알림 클릭 시 네비게이션.
  // post_idx가 있으면 UserDonationPostsListScreen.initialPostIdx로 전달해
  // 단건 detail fetch + 상세 시트 자동 오픈
  // (user_donation_posts_list.dart::initState 참조).
  static void _navigateToNewDonationPost(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    try {
      final raw = data['post_idx'] ?? data['post_id'];
      final postIdx = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              UserDonationPostsListScreen(initialPostIdx: postIdx),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] 새 헌혈 모집 네비게이션 실패: $e');
    }
  }

  /// donation_completed 알림 분기 (2-3a 임시 정정).
  /// CLAUDE.md "알림 다중 수신 라우팅" 박제대로 account_type 3분기:
  /// - admin(1)    → 헌혈 최종 승인 대기 화면
  /// - hospital(2) → 게시글 신청자/완료 관리 화면 (현재 단순 push,
  ///                 백엔드 단일 게시글 fetch API 합의 후 2-3b에서 자동 오픈 보강 예정)
  /// - user(3)     → 본인 헌혈 이력 (_navigateToDonationHistory 위임)
  static Future<void> _navigateForDonationCompleted(
    Map<String, dynamic> data,
  ) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final accountType = await PreferencesManager.getAccountType();
    if (!context.mounted) return;

    try {
      if (accountType == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminDonationApprovalPage()),
        );
      } else if (accountType == 2) {
        // 2-3b: post_idx 전달하여 HospitalPostCheck initState에서 단건 fetch
        // → _showPostBottomSheet 자동 호출. 백엔드 GET /api/hospital/posts/{post_idx}
        // 가 status 제한 없어 status=4(COMPLETED)인 시점에도 정상 동작.
        final raw = data['post_idx'] ?? data['post_id'];
        final postIdx = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HospitalPostCheck(initialPostIdx: postIdx),
          ),
        );
      } else {
        _navigateToDonationHistory(data);
      }
    } catch (e) {
      debugPrint('[NotificationService] donation_completed 분기 실패: $e');
    }
  }

  // 헌혈 완료 / 신청 승인 / 신청 거절 등 신청 관련 알림 진입.
  // application_id가 있으면 DonationHistoryScreen.initialApplicationId로 전달해
  // 자동 탭 전환(완료 vs 신청중) + 카드 highlight
  // (donation_history_screen.dart::_loadDonationHistoryAndMaybeHighlight 참조).
  static void _navigateToDonationHistory(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    try {
      // FCM data는 'application_id', REST 응답은 'applied_donation_idx' 양쪽 fallback.
      final raw = data['application_id'] ?? data['applied_donation_idx'];
      final applicationId =
          raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DonationHistoryScreen(initialApplicationId: applicationId),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] 헌혈 완료 네비게이션 실패: $e');
    }
  }

  /// document_request_responded 알림 분기 (2026-05-01 신규 type).
  ///
  /// 백엔드 emit: POST /api/donation/respond-documents 처리 시 원 요청자에게 발송.
  /// USER + ADMIN 양쪽 수신. CLAUDE.md "알림 다중 수신 라우팅" 패턴 적용.
  /// data 키: document_request_id / application_id / post_idx / hospital_name / post_title.
  ///
  /// - admin(1)    → AdminPostCheck 헌혈완료 탭(index=3, 자료 요청 추적용)
  /// - user(3)     → DonationHistoryScreen (본인 헌혈 이력)
  static Future<void> _navigateForDocumentRequestResponded(
    Map<String, dynamic> data,
  ) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final accountType = await PreferencesManager.getAccountType();
    if (!context.mounted) return;

    try {
      if (accountType == 1) {
        final raw = data['post_idx'] ?? data['post_id'];
        final postIdx = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminPostCheck(
              initialPostIdx: postIdx,
              initialTabIndex: 3,
            ),
          ),
        );
      } else {
        // user(3): 본인 헌혈 이력 화면. account_type 미식별 시에도 user로 fallback.
        _navigateToDonationHistory(data);
      }
    } catch (e) {
      debugPrint('[NotificationService] document_request_responded 분기 실패: $e');
    }
  }

  /// account_suspended / account_status_changed 알림 처리.
  /// 옵션 d 분기: SUSPENDED(2)/BLOCKED(3) → 강제 모달 + 로그아웃 + welcome 이동.
  /// PENDING(0)/ACTIVE(1)는 OS 푸시만으로 안내 (인앱 화면 이동 없음, 의도된 dead-end).
  static void _navigateForAccountStatus(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // FCM data는 모든 값이 string으로 직렬화되므로 양쪽 타입 처리
    final raw = data['new_status'];
    final newStatus = raw is int ? raw : int.tryParse(raw?.toString() ?? '');

    if (newStatus == 2 || newStatus == 3) {
      _showAccountSuspendedDialog(context, isBlocked: newStatus == 3);
    }
  }

  /// 정지/차단 강제 모달. 닫기 불가, 확인 버튼만 노출.
  /// 확인 누르면 [_forceLogoutAndGoWelcome] 실행.
  static void _showAccountSuspendedDialog(
    BuildContext context, {
    required bool isBlocked,
  }) {
    final title = isBlocked ? '계정 사용이 차단되었습니다' : '계정이 정지되었습니다';
    final body = isBlocked
        ? '계정 사용이 차단되었습니다.\n자세한 사항은 관리자에게 문의해 주세요.'
        : '계정이 일시 정지되었습니다.\n자세한 사항은 관리자에게 문의해 주세요.';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _forceLogoutAndGoWelcome();
              },
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  /// 강제 로그아웃 + welcome(`/`) 이동. profile_management.dart::_logout 패턴 미러.
  /// 로컬 데이터 → Provider 초기화 → 서버 logout → 네이버 SDK 클리어 → 라우트 교체 순서.
  static Future<void> _forceLogoutAndGoWelcome() async {
    final token = await PreferencesManager.getAuthToken();
    final refreshToken = await PreferencesManager.getRefreshToken();

    await PreferencesManager.clearAll();
    if (kIsWeb) {
      WebStorageHelper.clearAll();
    }

    final providerContext = navigatorKey.currentContext;
    if (providerContext != null && providerContext.mounted) {
      try {
        providerContext.read<NotificationProvider>().reset();
      } catch (_) {
        // Provider가 위젯 트리에 없는 경우 무시
      }
    }

    try {
      await http
          .post(
            Uri.parse('${Config.serverUrl}/api/auth/logout'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // 서버 로그아웃 실패 시 무시 (로컬 데이터는 이미 삭제됨)
    }

    if (!kIsWeb) {
      try {
        await FlutterNaverLogin.logOutAndDeleteToken();
      } catch (_) {
        // 네이버 로그인 세션이 없는 경우 무시
      }
    }

    final navContext = navigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      Navigator.of(navContext).pushNamedAndRemoveUntil(
        '/',
        (Route<dynamic> route) => false,
      );
    }
  }
}
