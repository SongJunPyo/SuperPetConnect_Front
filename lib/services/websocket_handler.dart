import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/notification_model.dart';
import '../utils/config.dart';
import 'notification_converter.dart';

/// WebSocket 전용 핸들러 (웹 환경)
///
/// WebSocket을 통한 실시간 알림 수신을 담당합니다.
class WebSocketHandler {
  static WebSocketHandler? _instance;
  static WebSocketHandler get instance => _instance ??= WebSocketHandler._internal();

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
  Stream<NotificationModel> get notificationStream => _notificationController.stream;

  /// 연결 상태 스트림
  Stream<bool> get connectionStatusStream => _connectionController.stream;

  /// WebSocket 초기화 및 연결
  Future<void> initialize() async {
    if (!kIsWeb) {
      debugPrint('[WebSocketHandler] 모바일 환경에서는 WebSocket 비활성화');
      return;
    }

    await _connect();
  }

  /// WebSocket 연결
  Future<void> _connect() async {
    if (_isDisposed) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        debugPrint('[WebSocketHandler] 인증 토큰 없음, 연결 스킵');
        _isConnected = false;
        _connectionController.add(false);
        return;
      }

      // WebSocket URL 구성
      String wsUrl = Config.serverUrl
          .replaceAll('http://', 'ws://')
          .replaceAll('https://', 'wss://');
      if (!wsUrl.endsWith('/ws')) {
        wsUrl = '$wsUrl/ws';
      }

      debugPrint('[WebSocketHandler] 연결 시도: $wsUrl');

      _channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

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

      debugPrint('[WebSocketHandler] 연결 성공');
    } catch (e) {
      debugPrint('[WebSocketHandler] 연결 실패: $e');
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

      debugPrint('[WebSocketHandler] 메시지 수신: $message');

      final data = jsonDecode(message.toString()) as Map<String, dynamic>;

      // 현재 사용자 타입 확인
      final userType = await NotificationConverter.getCurrentUserType();
      if (userType == null) {
        debugPrint('[WebSocketHandler] 사용자 타입 없음');
        return;
      }

      // 서버 알림을 클라이언트 모델로 변환
      final notification = NotificationConverter.fromServerData(data, userType);

      if (notification != null) {
        _notificationController.add(notification);
        debugPrint('[WebSocketHandler] 알림 변환 성공: ${notification.title}');
      }
    } catch (e) {
      debugPrint('[WebSocketHandler] 메시지 처리 실패: $e');
    }
  }

  /// 연결 오류 처리
  void _handleError(dynamic error) {
    debugPrint('[WebSocketHandler] 연결 오류: $error');
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }

  /// 연결 종료 처리
  void _handleDisconnect() {
    debugPrint('[WebSocketHandler] 연결 종료');
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
        debugPrint('[WebSocketHandler] 재연결 시도');
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
        } catch (e) {
          debugPrint('[WebSocketHandler] Ping 전송 실패: $e');
        }
      }
    });
  }

  /// 수동 재연결
  Future<void> reconnect() async {
    disconnect();
    await _connect();
  }

  /// 연결 종료
  void disconnect() {
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
