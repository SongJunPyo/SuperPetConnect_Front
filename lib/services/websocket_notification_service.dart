import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import '../models/notification_mapping.dart';
import '../models/notification_model.dart';
import '../models/notification_types.dart';
import '../utils/config.dart';

/// WebSocket을 통한 실시간 알림 서비스
class WebSocketNotificationService {
  static WebSocketNotificationService? _instance;
  static WebSocketNotificationService get instance => _instance ??= WebSocketNotificationService._();
  
  WebSocketNotificationService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  // 알림 스트림 컨트롤러
  final StreamController<NotificationModel> _notificationController = 
      StreamController<NotificationModel>.broadcast();
  
  /// 새 알림 스트림
  Stream<NotificationModel> get notifications => _notificationController.stream;
  
  // 연결 상태 스트림 컨트롤러  
  final StreamController<bool> _connectionController = 
      StreamController<bool>.broadcast();
      
  /// 연결 상태 스트림
  Stream<bool> get connectionStatus => _connectionController.stream;

  /// WebSocket 연결 초기화
  Future<void> initialize() async {
    if (kIsWeb) {
      // 웹에서는 WebSocket 지원
      await _connect();
    } else {
      // 모바일에서는 FCM을 사용하므로 WebSocket 비활성화
      print('모바일 환경에서는 FCM을 사용합니다.');
    }
  }

  /// WebSocket 연결
  Future<void> _connect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        print('WebSocket 연결 실패: 인증 토큰이 없습니다.');
        _isConnected = false;
        _connectionController.add(false);
        return;
      }

      // WebSocket URL 구성 (서버 설정에 따라 ws 또는 wss 사용)
      String wsUrl = Config.serverUrl.replaceAll('http://', 'ws://').replaceAll('https://', 'wss://');
      if (!wsUrl.endsWith('/ws')) {
        wsUrl = '$wsUrl/ws';
      }
      print('WebSocket 연결 시도: $wsUrl');

      _channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      // 연결 리스너 등록
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _isConnected = true;
      _connectionController.add(true);
      print('WebSocket 연결 성공');
      
      // 재연결 타이머 취소
      _reconnectTimer?.cancel();
      
    } catch (e) {
      print('WebSocket 연결 오류: $e');
      _isConnected = false;
      _connectionController.add(false);
      _scheduleReconnect();
    }
  }

  /// 메시지 처리
  void _handleMessage(dynamic message) {
    try {
      if (message == null || message.toString().isEmpty) {
        print('WebSocket 빈 메시지 수신');
        return;
      }

      final data = jsonDecode(message.toString()) as Map<String, dynamic>;
      final serverNotification = ServerNotificationData.fromJson(data);
      
      print('WebSocket 알림 수신: ${serverNotification.type} - ${serverNotification.title}');
      
      // 현재 사용자 타입 확인
      _getCurrentUserType().then((userType) {
        if (userType == null) {
          print('사용자 타입을 확인할 수 없어 WebSocket 알림 무시');
          return;
        }
        
        // 서버 알림을 프론트엔드 모델로 변환
        final clientNotification = _convertServerNotificationToClient(
          serverNotification, 
          userType
        );
        
        if (clientNotification != null) {
          print('WebSocket 알림 변환 성공: ${clientNotification.title} (사용자: $userType)');
          _notificationController.add(clientNotification);
        } else {
          print('WebSocket 알림 변환 실패 - "${serverNotification.type}" 타입이 사용자 타입 "$userType"에 맞지 않음');
        }
      });
      
    } catch (e) {
      print('WebSocket 메시지 파싱 오류: $e');
      print('받은 메시지: $message');
    }
  }

  /// 연결 오류 처리
  void _handleError(dynamic error) {
    print('WebSocket 오류: $error');
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }

  /// 연결 종료 처리
  void _handleDisconnect() {
    print('WebSocket 연결이 종료되었습니다.');
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }

  /// 재연결 스케줄링
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        print('WebSocket 재연결 시도...');
        _connect();
      }
    });
  }

  /// 현재 사용자 타입 가져오기
  Future<UserType?> _getCurrentUserType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountType = prefs.getInt('account_type');
      return accountType != null ? UserTypeMapper.fromDbType(accountType) : null;
    } catch (e) {
      print('사용자 타입 로드 실패: $e');
      return null;
    }
  }

  /// 서버 알림을 클라이언트 알림으로 변환
  NotificationModel? _convertServerNotificationToClient(
    ServerNotificationData serverNotification,
    UserType userType,
  ) {
    // 이 알림이 현재 사용자 타입에 해당하는지 확인
    if (!ServerNotificationMapping.isNotificationForUserType(
        serverNotification.type, userType)) {
      return null;
    }

    final clientType = ServerNotificationMapping.getClientNotificationType(
        serverNotification.type, userType);
    
    if (clientType == null) return null;

    final priority = ServerNotificationMapping.getNotificationPriority(
        serverNotification.type);

    // 사용자 타입별 알림 모델 생성
    switch (userType) {
      case UserType.admin:
        return NotificationFactory.createAdminNotification(
          notificationId: DateTime.now().millisecondsSinceEpoch,
          userId: 0, // WebSocket에서는 userId를 0으로 설정
          type: clientType as AdminNotificationType,
          title: serverNotification.title,
          content: serverNotification.body,
          relatedData: serverNotification.data,
        );
        
      case UserType.hospital:
        return NotificationFactory.createHospitalNotification(
          notificationId: DateTime.now().millisecondsSinceEpoch,
          userId: 0,
          type: clientType as HospitalNotificationType,
          title: serverNotification.title,
          content: serverNotification.body,
          relatedData: serverNotification.data,
        );
        
      case UserType.user:
        return NotificationFactory.createUserNotification(
          notificationId: DateTime.now().millisecondsSinceEpoch,
          userId: 0,
          type: clientType as UserNotificationType,
          title: serverNotification.title,
          content: serverNotification.body,
          relatedData: serverNotification.data,
        );
    }
  }

  /// 연결 상태 확인 API 호출
  Future<bool> checkConnectionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) return false;
      
      // TODO: 서버의 연결 상태 확인 API 호출
      // GET /api/notifications/connection/status
      
      return _isConnected;
    } catch (e) {
      print('연결 상태 확인 실패: $e');
      return false;
    }
  }

  /// FCM 알림을 실시간 스트림에 추가 (모바일 환경용)
  void addFCMNotificationToStream(NotificationModel notification) {
    print('FCM 알림을 실시간 스트림에 추가: ${notification.title}');
    _notificationController.add(notification);
  }

  /// 연결 종료
  void disconnect() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    
    _isConnected = false;
    _connectionController.add(false);
    
    print('WebSocket 연결이 종료되었습니다.');
  }

  /// 리소스 정리
  void dispose() {
    disconnect();
    _notificationController.close();
    _connectionController.close();
  }
}