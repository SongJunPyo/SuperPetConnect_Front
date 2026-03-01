import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/notification_model.dart';
import '../utils/config.dart';
import '../utils/preferences_manager.dart';
import 'notification_converter.dart';

/// WebSocket 전용 핸들러 (웹 환경)
///
/// WebSocket을 통한 실시간 알림 수신을 담당합니다.
class WebSocketHandler {
  static WebSocketHandler? _instance;
  static WebSocketHandler get instance =>
      _instance ??= WebSocketHandler._internal();

  WebSocketHandler._internal();
  factory WebSocketHandler() => instance;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  bool _isConnected = false;
  bool _isDisposed = false;

  /// 연결 상태
  bool get isConnected => _isConnected;

  // 알림 스트림 컨트롤러
  final StreamController<NotificationModel> _notificationController =
      StreamController<NotificationModel>.broadcast();

  // 연결 상태 스트림 컨트롤러
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  /// 새 알림 스트림
  Stream<NotificationModel> get notificationStream =>
      _notificationController.stream;

  /// 연결 상태 스트림
  Stream<bool> get connectionStatusStream => _connectionController.stream;

  /// WebSocket 초기화 및 연결
  Future<void> initialize() async {
    if (!kIsWeb) return;

    // disconnect()에서 설정된 _isDisposed 플래그를 리셋하여 연결 허용
    _isDisposed = false;
    await _connect();
  }

  /// WebSocket 연결
  Future<void> _connect() async {
    if (_isDisposed) return;

    try {
      final token = await PreferencesManager.getAuthToken();

      if (token == null || token.isEmpty) {
        _isConnected = false;
        _connectionController.add(false);
        return;
      }

      // WebSocket URL 구성 (쿼리 파라미터 방식 인증)
      String wsUrl = Config.serverUrl
          .replaceAll('http://', 'ws://')
          .replaceAll('https://', 'wss://');
      if (!wsUrl.endsWith('/ws')) {
        wsUrl = '$wsUrl/ws';
      }
      // 토큰을 쿼리 파라미터로 전달 (브라우저 WebSocket은 커스텀 헤더 미지원)
      wsUrl = '$wsUrl?token=$token';

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // 연결 리스너 등록
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _isConnected = true;
      _connectionController.add(true);

      // 재연결 타이머 취소
      _reconnectTimer?.cancel();

      // Ping 타이머 시작 (연결 유지)
      _startPingTimer();
    } catch (_) {
      _isConnected = false;
      _connectionController.add(false);
      _scheduleReconnect();
    }
  }

  /// 메시지 처리
  Future<void> _handleMessage(dynamic message) async {
    try {
      if (message == null || message.toString().isEmpty) {
        return;
      }

      final data = jsonDecode(message.toString()) as Map<String, dynamic>;

      // 현재 사용자 타입 확인
      final userType = await NotificationConverter.getCurrentUserType();
      if (userType == null) return;

      // 서버 알림을 클라이언트 모델로 변환
      final notification = NotificationConverter.fromServerData(data, userType);

      if (notification != null) {
        _notificationController.add(notification);
      }
    } catch (_) {
      // 메시지 처리 실패 시 무시
    }
  }

  /// 연결 오류 처리
  void _handleError(dynamic error) {
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }

  /// 연결 종료 처리
  void _handleDisconnect() {
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }

  /// 재연결 스케줄링
  void _scheduleReconnect() {
    if (_isDisposed) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected && !_isDisposed) {
        _connect();
      }
    });
  }

  /// Ping 타이머 시작 (연결 유지)
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {
          // Ping 전송 실패 시 무시
        }
      }
    });
  }

  /// 수동 재연결
  Future<void> reconnect() async {
    disconnect();
    await _connect();
  }

  /// 연결 종료 (로그아웃 시 사용)
  /// _isDisposed를 true로 설정하여 비동기 onClose 콜백에 의한 자동 재연결을 방지
  void disconnect() {
    _isDisposed = true; // 재연결 방지 (initialize() 호출 시 리셋됨)
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();

    _isConnected = false;
    _connectionController.add(false);
  }

  /// 리소스 정리
  void dispose() {
    _isDisposed = true;
    disconnect();
    _notificationController.close();
    _connectionController.close();
  }
}
