import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import 'fcm_handler.dart';
import 'websocket_handler.dart';

/// 알림 연결 상태
enum NotificationConnectionStatus { disconnected, connecting, connected, error }

/// FCM과 WebSocket을 통합하여 단일 인터페이스로 제공하는 관리자
///
/// 플랫폼(모바일/웹)에 따라 적절한 알림 소스를 자동으로 선택하고,
/// 단일 스트림으로 알림을 제공합니다.
class UnifiedNotificationManager {
  static UnifiedNotificationManager? _instance;
  static UnifiedNotificationManager get instance =>
      _instance ??= UnifiedNotificationManager._internal();

  UnifiedNotificationManager._internal();
  factory UnifiedNotificationManager() => instance;

  // 내부 핸들러
  FCMHandler? _fcmHandler;
  WebSocketHandler? _webSocketHandler;

  // 통합 스트림 컨트롤러
  final StreamController<NotificationModel> _notificationController =
      StreamController<NotificationModel>.broadcast();
  final StreamController<NotificationConnectionStatus> _connectionController =
      StreamController<NotificationConnectionStatus>.broadcast();

  // 구독
  StreamSubscription? _fcmSubscription;
  StreamSubscription? _webSocketSubscription;
  StreamSubscription? _webSocketConnectionSubscription;

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

  /// 플랫폼에 따라 적절한 알림 소스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    _connectionController.add(NotificationConnectionStatus.connecting);

    try {
      if (kIsWeb) {
        // 웹: WebSocket 사용
        await _initializeWebSocket();
      } else {
        // 모바일: FCM 사용
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

    // FCM 알림을 통합 스트림으로 전달
    _fcmSubscription = _fcmHandler!.notificationStream.listen(
      (notification) {
        _notificationController.add(notification);
      },
      onError: (error) {
        _connectionController.add(NotificationConnectionStatus.error);
      },
    );

    // FCM은 연결 관리가 Firebase에 의해 자동 처리됨
    _connectionController.add(NotificationConnectionStatus.connected);
  }

  /// WebSocket 초기화 (웹)
  Future<void> _initializeWebSocket() async {
    _webSocketHandler = WebSocketHandler.instance;
    await _webSocketHandler!.initialize();

    // WebSocket 알림을 통합 스트림으로 전달
    _webSocketSubscription = _webSocketHandler!.notificationStream.listen(
      (notification) {
        _notificationController.add(notification);
      },
      onError: (error) {
        _connectionController.add(NotificationConnectionStatus.error);
      },
    );

    // WebSocket 연결 상태 전달
    _webSocketConnectionSubscription = _webSocketHandler!.connectionStatusStream
        .listen((isConnected) {
          _connectionController.add(
            isConnected
                ? NotificationConnectionStatus.connected
                : NotificationConnectionStatus.disconnected,
          );
        });
  }

  /// 외부에서 알림 추가 (FCM 포그라운드 알림 등)
  void addNotification(NotificationModel notification) {
    _notificationController.add(notification);
  }

  /// 로그인 후 FCM 토큰 업데이트 (모바일)
  Future<void> updateTokenAfterLogin() async {
    if (!kIsWeb && _fcmHandler != null) {
      await _fcmHandler!.updateTokenAfterLogin();
    }
  }

  /// WebSocket 재연결 (웹)
  Future<void> reconnectWebSocket() async {
    if (kIsWeb && _webSocketHandler != null) {
      await _webSocketHandler!.reconnect();
    }
  }

  /// 리소스 정리
  void dispose() {
    _fcmSubscription?.cancel();
    _webSocketSubscription?.cancel();
    _webSocketConnectionSubscription?.cancel();
    _fcmHandler?.dispose();
    _webSocketHandler?.dispose();
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
