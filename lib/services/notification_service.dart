import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/config.dart';
import '../utils/preferences_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart' as main_app;
import 'notification_converter.dart';
import 'unified_notification_manager.dart';

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    if (kIsWeb) return;

    // FCM 토큰 가져오기 및 서버 전송
    await _updateFCMToken();

    // FCM 토큰 갱신 리스너 등록 (토큰 만료/갱신 시 자동으로 서버에 전송)
    setupTokenRefreshListener();

    // 포그라운드 메시지 리스너
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // 포그라운드에서도 상단 알림 표시
      main_app.showGlobalLocalNotification(message);

      if (message.data['type'] == 'donation_application') {
        _handleDonationApplicationNotification(message);
      } else if (message.data['type'] == 'new_post_approval') {
        _handleNewPostApprovalNotification(message);
      } else if (message.data['type'] == 'donation_post_approved') {
        _handleDonationPostApprovedNotification(message);
      } else if (message.data['type'] == 'column_approved') {
        _handleColumnApprovedNotification(message);
      } else if (message.data['type'] == 'donation_application_approved') {
        _handleDonationApprovedNotification(message);
      } else if (message.data['type'] == 'donation_application_rejected') {
        _handleDonationRejectedNotification(message);
      } else if (message.data['type'] == 'recruitment_closed') {
        _handleRecruitmentClosedNotification(message);
      } else if (message.data['type'] == 'donation_completed') {
        _handleDonationCompletedNotification(message);
      } else if (message.data['type'] == 'new_donation_post') {
        _handleNewDonationPostNotification(message);
      }
    });

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
          _navigateToDonationHistory(message.data);
        } else if (message.data['type'] == 'new_donation_post') {
          _navigateToNewDonationPost(parsedData);
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
              _navigateToDonationHistory(message.data);
            } else if (message.data['type'] == 'new_donation_post') {
              _navigateToNewDonationPost(parsedData);
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
          _navigateToDonationHistory(data);
          break;
        case 'new_donation_post':
          final parsedData = _parseNotificationData(data);
          _navigateToNewDonationPost(parsedData);
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

  static Future<void> _updateFCMToken() async {
    // 웹에서는 FCM 토큰 처리 건너뜀 (WebSocket 사용)
    if (kIsWeb) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _sendTokenToServer(token);
      }
    } catch (e) {
      // 알림 처리 실패 시 로그 출력
      debugPrint('Failed to handle notification: $e');
    }
  }

  static Future<void> _sendTokenToServer(String token) async {
    try {
      final authToken = (await PreferencesManager.getAuthToken()) ?? '';

      if (authToken.isEmpty) {
        return;
      }

      final response = await http.post(
        Uri.parse('${Config.serverUrl}/api/user/fcm-token'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fcm_token': token}),
      );

      if (response.statusCode == 200) {
      } else {}
    } catch (e) {
      // 알림 처리 실패 시 로그 출력
      debugPrint('Failed to handle notification: $e');
    }
  }

  static void _handleDonationApplicationNotification(RemoteMessage message) {
    // 포그라운드에서 받은 알림을 처리 (필요시 추가 로직)

    try {
      // 서버에서 JSON 문자열로 전송한 데이터 파싱
      Map<String, dynamic> parsedData = {};

      if (message.data.containsKey('navigation')) {
        parsedData['navigation'] = jsonDecode(
          message.data['navigation'] ?? '{}',
        );
      }
      if (message.data.containsKey('post_info')) {
        parsedData['post_info'] = jsonDecode(message.data['post_info'] ?? '{}');
      }

      // FCM 알림을 실시간 스트림에 추가
      _addFCMNotificationToStream(message);

      // 상단 푸시 알림은 포그라운드 리스너에서 이미 표시됨
    } catch (e) {
      // 상단 푸시 알림은 포그라운드 리스너에서 이미 표시됨
    }
  }

  static void _handleNewPostApprovalNotification(RemoteMessage message) {
    // 병원 게시글 승인 요청 알림 처리

    // 상단 푸시 알림은 포그라운드 리스너에서 이미 표시됨
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

  /// 로그인 시 FCM 토큰 업데이트
  static Future<void> updateTokenAfterLogin() async {
    await _updateFCMToken();
  }

  /// FCM 토큰 새로고침 리스너 등록
  static void setupTokenRefreshListener() {
    if (kIsWeb) return;

    FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
      _sendTokenToServer(token);
    });
  }

  // 헌혈 게시글 승인 알림 처리 (병원용)
  static void _handleDonationPostApprovedNotification(RemoteMessage message) {
    // 상단 푸시 알림은 포그라운드 리스너에서 이미 표시됨
  }

  // 칼럼 게시글 승인 알림 처리 (병원용)
  static void _handleColumnApprovedNotification(RemoteMessage message) {
    // 상단 푸시 알림은 포그라운드 리스너에서 이미 표시됨
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

  // 헌혈 신청 승인 알림 처리 (사용자용)
  static void _handleDonationApprovedNotification(RemoteMessage message) {
    // 상단 푸시 알림만 표시됨 (다이얼로그 제거)
  }

  // 헌혈 신청 미승인 알림 처리 (사용자용)
  static void _handleDonationRejectedNotification(RemoteMessage message) {
    // 상단 푸시 알림만 표시됨 (다이얼로그 제거)
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

  /// FCM 알림을 실시간 스트림에 추가하는 헬퍼 메서드.
  ///
  /// 변환은 [NotificationConverter.fromFCM]을 단일 원천으로 사용하며,
  /// 매핑에 없는 type은 silent drop 대신 유저타입별 `systemNotice`로 fallback 승격
  /// (WebSocket 핸들러와 동일 패턴).
  static void _addFCMNotificationToStream(RemoteMessage message) async {
    try {
      final userType = await NotificationConverter.getCurrentUserType();
      if (userType == null) return;

      // 정규 매핑 시도 (ServerNotificationMapping 경유)
      final notification = await NotificationConverter.fromFCM(message);
      if (notification != null) {
        UnifiedNotificationManager.instance.addNotification(notification);
        return;
      }

      // Unknown type fallback
      final rawType = message.data['type']?.toString() ?? '';
      debugPrint(
        '[FCM] 알 수 없는 알림 타입: "$rawType" (userType=$userType). '
        'fallback으로 systemNotice 표시. constants/enums.py::NotificationType 대조 필요.',
      );
      final title = message.notification?.title ?? '알림';
      final body = message.notification?.body ?? '';
      if (title.isEmpty && body.isEmpty) return;
      final relatedData = NotificationConverter.parseRelatedData(message.data);
      final fallback = NotificationConverter.createFallbackNotification(
        userType: userType,
        notificationId: DateTime.now().millisecondsSinceEpoch,
        title: title,
        content: body,
        relatedData: relatedData,
      );
      UnifiedNotificationManager.instance.addNotification(fallback);
    } catch (e) {
      debugPrint('[FCM] 알림 스트림 처리 실패: $e');
    }
  }

  // 모집 마감 알림 처리 (사용자/병원용)
  static void _handleRecruitmentClosedNotification(RemoteMessage message) {
    debugPrint('[NotificationService] 모집 마감 알림 수신');
    // FCM 알림을 실시간 스트림에 추가
    _addFCMNotificationToStream(message);
  }

  // 헌혈 완료 알림 처리 (사용자/병원용)
  static void _handleDonationCompletedNotification(RemoteMessage message) {
    debugPrint('[NotificationService] 헌혈 완료 알림 수신');
    // FCM 알림을 실시간 스트림에 추가
    _addFCMNotificationToStream(message);
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

  // 새 헌혈 모집 게시글 알림 처리 (사용자용)
  static void _handleNewDonationPostNotification(RemoteMessage message) {
    debugPrint('[NotificationService] 새 헌혈 모집 게시글 알림 수신');
    // FCM 알림을 실시간 스트림에 추가
    _addFCMNotificationToStream(message);
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
}
