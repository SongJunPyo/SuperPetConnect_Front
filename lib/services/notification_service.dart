import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../admin/admin_column_management.dart';
import '../admin/admin_donation_approval_page.dart';
import '../admin/admin_pet_management.dart';
import '../admin/admin_signup_management.dart';
import '../hospital/hospital_post_check.dart';
import '../providers/notification_provider.dart';
import '../utils/config.dart';
import '../utils/preferences_manager.dart';
import '../web/web_storage_helper.dart';
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

    // 백그라운드에서 앱을 연 경우
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      try {
        // 서버에서 JSON 문자열로 전송한 데이터 파싱
        Map<String, dynamic> parsedData = {};

        if (message.data.containsKey('navigation')) {
          parsedData['navigation'] = jsonDecode(
            message.data['navigation'] ?? '{}',
          );
        }
        if (message.data.containsKey('post_info')) {
          parsedData['post_info'] = jsonDecode(
            message.data['post_info'] ?? '{}',
          );
        }

        if (message.data['type'] == 'new_post_approval') {
          _navigateToPostManagement(parsedData);
        } else if (message.data['type'] == 'donation_post_approved') {
          _navigateToHospitalPosts(parsedData);
        } else if (message.data['type'] == 'column_approved') {
          _navigateToHospitalColumns(parsedData);
        } else if (message.data['type'] == 'donation_application_approved') {
          _navigateToUserDashboard(parsedData);
        } else if (message.data['type'] == 'donation_application_rejected') {
          _navigateToUserDashboard(parsedData);
        } else if (message.data['type'] == 'recruitment_closed') {
          _navigateForRecruitmentClosed(message.data);
        } else if (message.data['type'] == 'donation_completed') {
          _navigateForDonationCompleted(message.data);
        } else if (message.data['type'] == 'new_donation_post') {
          _navigateToNewDonationPost(parsedData);
        } else if (message.data['type'] == 'new_pet_registration' ||
            message.data['type'] == 'pet_review_request') {
          _navigateToAdminPetManagement(parsedData);
        } else if (message.data['type'] == 'new_user_registration') {
          _navigateToSignupManagement(parsedData);
        } else if (message.data['type'] == 'column_approval') {
          _navigateToAdminColumnManagement(parsedData);
        } else if (message.data['type'] == 'column_rejected') {
          _navigateToHospitalColumns(parsedData);
        } else if (message.data['type'] == 'all_timeslots_filled' ||
            message.data['type'] == 'post_suspended' ||
            message.data['type'] == 'post_resumed') {
          _navigateToHospitalPosts(parsedData);
        } else if (message.data['type'] == 'account_suspended' ||
            message.data['type'] == 'account_status_changed') {
          _navigateForAccountStatus(message.data);
        }
      } catch (e) {
        // 파싱 실패 시 기본 데이터로 처리
      }
    });

    // 앱이 완전히 종료된 상태에서 알림으로 앱을 연 경우
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          try {
            // 서버에서 JSON 문자열로 전송한 데이터 파싱
            Map<String, dynamic> parsedData = {};

            if (message.data.containsKey('navigation')) {
              parsedData['navigation'] = jsonDecode(
                message.data['navigation'] ?? '{}',
              );
            }
            if (message.data.containsKey('post_info')) {
              parsedData['post_info'] = jsonDecode(
                message.data['post_info'] ?? '{}',
              );
            }

            if (message.data['type'] == 'new_post_approval') {
              _navigateToPostManagement(parsedData);
            } else if (message.data['type'] == 'donation_post_approved') {
              _navigateToHospitalPosts(parsedData);
            } else if (message.data['type'] == 'column_approved') {
              _navigateToHospitalColumns(parsedData);
            } else if (message.data['type'] ==
                'donation_application_approved') {
              _navigateToUserDashboard(parsedData);
            } else if (message.data['type'] ==
                'donation_application_rejected') {
              _navigateToUserDashboard(parsedData);
            } else if (message.data['type'] == 'recruitment_closed') {
              _navigateForRecruitmentClosed(message.data);
            } else if (message.data['type'] == 'donation_completed') {
              _navigateForDonationCompleted(message.data);
            } else if (message.data['type'] == 'new_donation_post') {
              _navigateToNewDonationPost(parsedData);
            } else if (message.data['type'] == 'new_pet_registration' ||
                message.data['type'] == 'pet_review_request') {
              _navigateToAdminPetManagement(parsedData);
            } else if (message.data['type'] == 'new_user_registration') {
              _navigateToSignupManagement(parsedData);
            } else if (message.data['type'] == 'column_approval') {
              _navigateToAdminColumnManagement(parsedData);
            } else if (message.data['type'] == 'column_rejected') {
              _navigateToHospitalColumns(parsedData);
            } else if (message.data['type'] == 'all_timeslots_filled' ||
                message.data['type'] == 'post_suspended' ||
                message.data['type'] == 'post_resumed') {
              _navigateToHospitalPosts(parsedData);
            } else if (message.data['type'] == 'account_suspended' ||
                message.data['type'] == 'account_status_changed') {
              _navigateForAccountStatus(message.data);
            }
          } catch (e) {
            // 파싱 실패 시 기본 데이터로 처리
          }
        });
      }
    });
  }

  // 로컬 알림 탭 처리 (public으로 변경)
  static void handleLocalNotificationTap(String? payload) {
    if (payload == null) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final notificationType = data['type'] as String?;

      // 알림 타입별로 적절한 페이지로 이동
      switch (notificationType) {
        case 'new_post_approval':
          final parsedData = _parseNotificationData(data);
          _navigateToPostManagement(parsedData);
          break;
        case 'donation_application':
          final parsedData = _parseNotificationData(data);
          _navigateToDonationManagement(parsedData);
          break;
        case 'donation_post_approved':
          final parsedData = _parseNotificationData(data);
          _navigateToHospitalPosts(parsedData);
          break;
        case 'column_approved':
          final parsedData = _parseNotificationData(data);
          _navigateToHospitalColumns(parsedData);
          break;
        case 'donation_application_approved':
        case 'donation_application_rejected':
          final parsedData = _parseNotificationData(data);
          _navigateToUserDashboard(parsedData);
          break;
        case 'recruitment_closed':
          _navigateForRecruitmentClosed(data);
          break;
        case 'donation_completed':
          _navigateForDonationCompleted(data);
          break;
        case 'new_donation_post':
          final parsedData = _parseNotificationData(data);
          _navigateToNewDonationPost(parsedData);
          break;
        case 'new_pet_registration':
        case 'pet_review_request':
          final parsedData = _parseNotificationData(data);
          _navigateToAdminPetManagement(parsedData);
          break;
        case 'new_user_registration':
          final parsedData = _parseNotificationData(data);
          _navigateToSignupManagement(parsedData);
          break;
        case 'column_approval':
          final parsedData = _parseNotificationData(data);
          _navigateToAdminColumnManagement(parsedData);
          break;
        case 'column_rejected':
          final parsedData = _parseNotificationData(data);
          _navigateToHospitalColumns(parsedData);
          break;
        case 'all_timeslots_filled':
        case 'post_suspended':
        case 'post_resumed':
          final parsedData = _parseNotificationData(data);
          _navigateToHospitalPosts(parsedData);
          break;
        case 'account_suspended':
        case 'account_status_changed':
          _navigateForAccountStatus(data);
          break;
        default:
      }
    } catch (e) {
      // 알림 처리 실패 시 로그 출력
      debugPrint('Failed to handle notification: $e');
    }
  }

  // 알림 데이터 파싱 헬퍼 메서드
  static Map<String, dynamic> _parseNotificationData(
    Map<String, dynamic> data,
  ) {
    Map<String, dynamic> parsedData = {};

    try {
      if (data.containsKey('navigation')) {
        parsedData['navigation'] = jsonDecode(data['navigation'] ?? '{}');
      }
      if (data.containsKey('post_info')) {
        parsedData['post_info'] = jsonDecode(data['post_info'] ?? '{}');
      }

      // 다른 필드들도 복사
      parsedData.addAll(data);
    } catch (e) {
      // 파싱 실패 시 원본 데이터 반환
      return data;
    }

    return parsedData;
  }

  static void _navigateToPostManagement(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      final navigation = data['navigation'];

      if (navigation != null) {
        // navigation이 JSON 문자열인 경우 파싱
        final navData =
            navigation is String ? jsonDecode(navigation) : navigation;

        final postId = navData['post_id']; // 게시글 ID
        final tab = navData['tab']; // "pending_approval"

        // 관리자 게시글 관리 페이지로 이동
        Navigator.pushNamed(
          context,
          '/admin/post-management',
          arguments: {
            'postId': postId is String ? int.tryParse(postId) : postId,
            'initialTab': tab,
            'highlightPost':
                data['post_idx'] is String
                    ? int.tryParse(data['post_idx'])
                    : data['post_idx'],
          },
        );
      } else {
        // 기본 게시글 관리 페이지로 이동
        Navigator.pushNamed(context, '/admin/post-management');
      }
    } catch (e) {
      // 오류 발생 시 기본 관리자 게시글 관리 페이지로 이동
      Navigator.pushNamed(context, '/admin/post-management');
    }
  }

  /// 로그인 직후 FCM 토큰을 서버에 재전송. [FCMHandler]로 위임.
  static Future<void> updateTokenAfterLogin() async {
    if (kIsWeb) return;
    await FCMHandler.instance.updateFCMToken();
  }

  // 헌혈 신청 관리 페이지로 이동 (병원용)
  static void _navigateToDonationManagement(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      final navigation = data['navigation'];

      if (navigation != null) {
        // navigation이 JSON 문자열인 경우 파싱
        final navData =
            navigation is String ? jsonDecode(navigation) : navigation;

        final postId = navData['post_id']; // 게시글 ID
        final tab = navData['tab']; // "applications"

        // 병원 헌혈 신청 관리 페이지로 이동
        Navigator.pushNamed(
          context,
          '/hospital/donation-management',
          arguments: {
            'postId': postId is String ? int.tryParse(postId) : postId,
            'initialTab': tab,
            'highlightApplication':
                data['application_id'] is String
                    ? int.tryParse(data['application_id'])
                    : data['application_id'],
          },
        );
      } else {
        // 기본 병원 대시보드로 이동
        Navigator.pushNamed(context, '/hospital/dashboard');
      }
    } catch (e) {
      // 오류 발생 시 기본 병원 대시보드로 이동
      Navigator.pushNamed(context, '/hospital/dashboard');
    }
  }

  // 병원 헌혈 게시글 페이지로 이동
  static void _navigateToHospitalPosts(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      final postId = data['post_id'];

      // 병원 대시보드 또는 게시글 관리 페이지로 이동
      Navigator.pushNamed(
        context,
        '/hospital/dashboard',
        arguments: {
          'highlightPostId': postId is String ? int.tryParse(postId) : postId,
          'showPostDetail': true,
        },
      );
    } catch (e) {
      // 오류 발생 시 기본 병원 대시보드로 이동
      Navigator.pushNamed(context, '/hospital/dashboard');
    }
  }

  // 병원 칼럼 페이지로 이동
  static void _navigateToHospitalColumns(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      final columnId = data['column_id'];

      // 병원 칼럼 목록 페이지로 이동
      Navigator.pushNamed(
        context,
        '/hospital/columns',
        arguments: {
          'highlightColumnId':
              columnId is String ? int.tryParse(columnId) : columnId,
        },
      );
    } catch (e) {
      // 오류 발생 시 기본 병원 대시보드로 이동
      Navigator.pushNamed(context, '/hospital/dashboard');
    }
  }

  // 사용자 대시보드로 이동 (헌혈 신청 승인/거절 알림용)
  static void _navigateToUserDashboard(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      final navigation = data['navigation'] ?? data;
      final postId = navigation['post_id'];
      final applicationId = navigation['application_id'];

      // 사용자 대시보드로 이동 (헌혈 신청 내역 탭으로)
      Navigator.pushNamed(
        context,
        '/user/dashboard',
        arguments: {
          'highlightPostId': postId is String ? int.tryParse(postId) : postId,
          'highlightApplicationId':
              applicationId is String
                  ? int.tryParse(applicationId)
                  : applicationId,
          'initialTab': 'donation_history',
        },
      );
    } catch (e) {
      // 오류 발생 시 기본 사용자 대시보드로 이동
      Navigator.pushNamed(context, '/user/dashboard');
    }
  }

  // 모집 마감 알림 클릭 시 네비게이션
  static void _navigateForRecruitmentClosed(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      final isSelected = data['is_selected'] == 'true';

      if (isSelected) {
        // 선정된 사용자 - 내 신청 내역 페이지로 이동
        Navigator.pushNamed(context, '/user/my-applications');
      } else {
        // 미선정 사용자 - 헌혈 게시글 목록으로 이동
        Navigator.pushNamed(context, '/user/donation-posts');
      }
    } catch (e) {
      debugPrint('[NotificationService] 모집 마감 네비게이션 실패: $e');
      // 오류 발생 시 사용자 대시보드로 이동
      Navigator.pushNamed(context, '/user/dashboard');
    }
  }

  /// 신규 반려동물 등록 알림 클릭 시 네비게이션 (관리자용).
  /// 서버 FCM payload 예: `navigation: { page: "admin_pet_management", pet_idx: <pk> }`
  /// 현재는 page 키와 무관하게 `AdminPetManagement` 전체 화면으로 이동 (해당 페이지에
  /// 이미 승인 대기 탭이 기본 진입 상태). pet_review_request도 같은 화면 사용.
  static void _navigateToAdminPetManagement(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminPetManagement()),
      );
    } catch (e) {
      debugPrint('[NotificationService] 반려동물 관리 네비게이션 실패: $e');
    }
  }

  /// 신규 가입 요청 알림(new_user_registration) 클릭 시 가입 관리 화면 진입.
  /// 라우트 미등록이라 직접 push.
  static void _navigateToSignupManagement(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminSignupManagement()),
      );
    } catch (e) {
      debugPrint('[NotificationService] 가입 관리 네비게이션 실패: $e');
    }
  }

  /// 칼럼 승인 요청 알림(column_approval) 클릭 시 관리자 칼럼 관리 화면 진입.
  /// 라우트 미등록이라 직접 push.
  static void _navigateToAdminColumnManagement(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminColumnManagement()),
      );
    } catch (e) {
      debugPrint('[NotificationService] 칼럼 관리 네비게이션 실패: $e');
    }
  }

  // 새 헌혈 모집 게시글 알림 클릭 시 네비게이션
  static void _navigateToNewDonationPost(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      // 알림 data에서 post_idx 추출
      final postIdx = data['post_idx'] ?? data['data']?['post_idx'];

      // 사용자 헌혈 게시물 목록으로 이동
      Navigator.pushNamed(
        context,
        '/user/donation-posts',
        arguments: {
          'highlightPostId':
              postIdx is String ? int.tryParse(postIdx) : postIdx,
        },
      );
    } catch (e) {
      debugPrint('[NotificationService] 새 헌혈 모집 네비게이션 실패: $e');
      // 오류 발생 시 헌혈 게시글 목록으로 이동
      Navigator.pushNamed(context, '/user/donation-posts');
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
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HospitalPostCheck()),
        );
      } else {
        _navigateToDonationHistory(data);
      }
    } catch (e) {
      debugPrint('[NotificationService] donation_completed 분기 실패: $e');
    }
  }

  // 헌혈 완료 알림 클릭 시 네비게이션
  static void _navigateToDonationHistory(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      // 헌혈 내역 페이지로 이동
      Navigator.pushNamed(
        context,
        '/user/donation-history',
        arguments: {
          'applicationId':
              data['application_id'] is String
                  ? int.tryParse(data['application_id'])
                  : data['application_id'],
        },
      );
    } catch (e) {
      debugPrint('[NotificationService] 헌혈 완료 네비게이션 실패: $e');
      // 오류 발생 시 사용자 대시보드로 이동
      Navigator.pushNamed(context, '/user/dashboard');
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
