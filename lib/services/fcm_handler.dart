import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';
import '../utils/config.dart';
import 'notification_converter.dart';

/// FCM 전용 핸들러 (모바일 환경)
///
/// Firebase Cloud Messaging을 통한 푸시 알림 수신 및 FCM 토큰 관리를 담당합니다.
class FCMHandler {
  static FCMHandler? _instance;
  static FCMHandler get instance => _instance ??= FCMHandler._internal();

  FCMHandler._internal();
  factory FCMHandler() => instance;

  // 알림 스트림 컨트롤러
  final StreamController<NotificationModel> _notificationController =
      StreamController<NotificationModel>.broadcast();

  // 초기 메시지 (앱이 종료된 상태에서 알림으로 열린 경우)
  RemoteMessage? _initialMessage;

  /// 새 알림 스트림
  Stream<NotificationModel> get notificationStream => _notificationController.stream;

  /// 초기 메시지 (앱이 종료된 상태에서 알림으로 열린 경우)
  RemoteMessage? get initialMessage => _initialMessage;

  /// FCM 초기화 및 리스너 등록
  Future<void> initialize() async {
    if (kIsWeb) return;

    // 1. FCM 토큰 갱신 리스너 등록
    _setupTokenRefreshListener();

    // 2. 초기 FCM 토큰 서버 전송
    await updateFCMToken();

    // 3. 포그라운드 메시지 리스너
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 4. 백그라운드에서 앱을 연 경우
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 5. 앱이 완전히 종료된 상태에서 알림으로 앱을 연 경우
    _initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    debugPrint('[FCMHandler] 초기화 완료');
  }

  /// FCM 토큰 갱신 리스너 설정
  void _setupTokenRefreshListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
      debugPrint('[FCMHandler] 토큰 갱신됨, 서버로 전송');
      _sendTokenToServer(token);
    });
  }

  /// FCM 토큰 업데이트
  Future<void> updateFCMToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _sendTokenToServer(token);
      }
    } catch (e) {
      debugPrint('[FCMHandler] FCM 토큰 획득 실패: $e');
    }
  }

  /// FCM 토큰 서버 전송
  Future<void> _sendTokenToServer(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token') ?? '';

      if (authToken.isEmpty) {
        debugPrint('[FCMHandler] 인증 토큰 없음, 토큰 전송 스킵');
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
        debugPrint('[FCMHandler] FCM 토큰 서버 전송 성공');
      } else {
        debugPrint('[FCMHandler] FCM 토큰 서버 전송 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FCMHandler] FCM 토큰 서버 전송 오류: $e');
    }
  }

  /// 로그인 후 토큰 업데이트 (외부 호출용)
  Future<void> updateTokenAfterLogin() async {
    await updateFCMToken();
  }

  /// 포그라운드 메시지 처리
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCMHandler] 포그라운드 메시지 수신: ${message.data['type']}');

    final notification = await NotificationConverter.fromFCM(message);
    if (notification != null) {
      _notificationController.add(notification);
    }
  }

  /// 백그라운드/종료 상태에서 앱 열림 처리
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    debugPrint('[FCMHandler] 백그라운드에서 앱 열림: ${message.data['type']}');

    final notification = await NotificationConverter.fromFCM(message);
    if (notification != null) {
      _notificationController.add(notification);
    }
  }

  /// FCM 메시지의 원본 데이터 가져오기 (네비게이션 등에 사용)
  Map<String, dynamic> getMessageData(RemoteMessage message) {
    Map<String, dynamic> parsedData = Map<String, dynamic>.from(message.data);

    // navigation 데이터 파싱
    if (message.data.containsKey('navigation')) {
      try {
        parsedData['navigation'] = jsonDecode(message.data['navigation'] ?? '{}');
      } catch (e) {
        debugPrint('[FCMHandler] navigation 파싱 실패: $e');
      }
    }

    // post_info 데이터 파싱
    if (message.data.containsKey('post_info')) {
      try {
        parsedData['post_info'] = jsonDecode(message.data['post_info'] ?? '{}');
      } catch (e) {
        debugPrint('[FCMHandler] post_info 파싱 실패: $e');
      }
    }

    return parsedData;
  }

  /// 리소스 정리
  void dispose() {
    _notificationController.close();
  }
}
