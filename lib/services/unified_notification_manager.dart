import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import 'fcm_handler.dart';
// 웹 FCM (조건부 import — 모바일은 stub 사용)
import 'web_fcm_init_stub.dart'
    if (dart.library.html) 'web_fcm_init.dart';

/// 알림 연결 상태
enum NotificationConnectionStatus { disconnected, connecting, connected, error }

/// FCM 단일 채널 (모바일/웹) 통합 관리자.
///
/// 모바일은 FCMHandler, 웹은 WebFcmInit (firebase_messaging web + Service Worker)
/// 양쪽 모두 동일한 FCM 토큰 등록 → multicast 발송 흐름.
/// 2026-05-02 BE [A][B][C] sync 후 WebSocket 채널 폐기.
class UnifiedNotificationManager {
  static UnifiedNotificationManager? _instance;
  static UnifiedNotificationManager get instance =>
      _instance ??= UnifiedNotificationManager._internal();

  UnifiedNotificationManager._internal();
  factory UnifiedNotificationManager() => instance;

  // 내부 핸들러
  FCMHandler? _fcmHandler;

  // 통합 스트림 컨트롤러
  final StreamController<NotificationModel> _notificationController =
      StreamController<NotificationModel>.broadcast();
  final StreamController<NotificationConnectionStatus> _connectionController =
      StreamController<NotificationConnectionStatus>.broadcast();

  // 구독
  StreamSubscription? _fcmSubscription;
  StreamSubscription? _webFcmSubscription;

  bool _isInitialized = false;

  /// 초기화 여부
  bool get isInitialized => _isInitialized;

  /// 현재 플랫폼이 웹인지 여부
  bool get isWebPlatform => kIsWeb;

  /// 통합 알림 스트림
  Stream<NotificationModel> get notificationStream =>
      _notificationController.stream;

  /// 연결 상태 스트림
  Stream<NotificationConnectionStatus> get connectionStatusStream =>
      _connectionController.stream;

  /// 플랫폼에 따라 적절한 알림 소스 초기화 (모바일: FCMHandler, 웹: WebFcmInit)
  Future<void> initialize() async {
    if (_isInitialized) return;

    _connectionController.add(NotificationConnectionStatus.connecting);

    try {
      if (kIsWeb) {
        await _initializeWebFcm();
      } else {
        await _initializeFCM();
      }
      _isInitialized = true;
    } catch (e) {
      _connectionController.add(NotificationConnectionStatus.error);
    }
  }

  /// FCM 초기화 (모바일)
  Future<void> _initializeFCM() async {
    _fcmHandler = FCMHandler.instance;
    await _fcmHandler!.initialize();

    _fcmSubscription = _fcmHandler!.notificationStream.listen(
      (notification) {
        _notificationController.add(notification);
      },
      onError: (error) {
        _connectionController.add(NotificationConnectionStatus.error);
      },
    );

    // FCM은 Firebase가 연결 자동 관리
    _connectionController.add(NotificationConnectionStatus.connected);
  }

  /// 웹 FCM 초기화 (firebase_messaging web + Service Worker).
  /// 권한 거부 시 토큰 발급 실패하지만 FE는 정상 동작 (push 수신 안 됨).
  Future<void> _initializeWebFcm() async {
    await WebFcmInit.initialize();

    _webFcmSubscription = WebFcmInit.notificationStream.listen(
      (notification) {
        _notificationController.add(notification);
      },
      onError: (error) {
        _connectionController.add(NotificationConnectionStatus.error);
      },
    );

    // FCM Web도 Firebase가 연결 자동 관리
    _connectionController.add(NotificationConnectionStatus.connected);
  }

  /// 외부에서 알림 추가 (FCM 포그라운드 알림 등)
  void addNotification(NotificationModel notification) {
    _notificationController.add(notification);
  }

  /// 로그인 후 FCM 토큰 재등록 (모바일/웹 공통).
  Future<void> updateTokenAfterLogin() async {
    if (kIsWeb) {
      await WebFcmInit.updateTokenAfterLogin();
    } else if (_fcmHandler != null) {
      await _fcmHandler!.updateTokenAfterLogin();
    }
  }

  /// 로그아웃 직전 호출 — 현재 디바이스 토큰 백엔드에서 제거.
  Future<void> deleteCurrentDeviceToken() async {
    if (kIsWeb) {
      await WebFcmInit.deleteCurrentDeviceToken();
    }
    // 모바일: FCMHandler에 deleteCurrentDeviceToken 별도 구현 시 여기서 호출
  }

  /// 연결 해제 (로그아웃 시) — 싱글턴은 유지
  void disconnect() {
    _webFcmSubscription?.cancel();
    _webFcmSubscription = null;
    if (kIsWeb) {
      WebFcmInit.dispose();
    }
    _isInitialized = false;
  }

  /// 리소스 정리
  void dispose() {
    _fcmSubscription?.cancel();
    _webFcmSubscription?.cancel();
    _fcmHandler?.dispose();
    if (kIsWeb) {
      WebFcmInit.dispose();
    }
    _notificationController.close();
    _connectionController.close();
    _isInitialized = false;
  }

  /// 싱글톤 리셋 (테스트용)
  @visibleForTesting
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }
}
