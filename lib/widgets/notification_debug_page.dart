import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/unified_notification_manager.dart';
import '../services/websocket_handler.dart';
import '../services/notification_list_service.dart';
import '../models/notification_model.dart';
import '../utils/app_theme.dart';

/// 알림 시스템 디버그 및 테스트 페이지
class NotificationDebugPage extends StatefulWidget {
  const NotificationDebugPage({super.key});

  @override
  State<NotificationDebugPage> createState() => _NotificationDebugPageState();
}

class _NotificationDebugPageState extends State<NotificationDebugPage> {
  bool _isConnected = false;
  final List<String> _debugLogs = [];
  StreamSubscription<NotificationConnectionStatus>? _connectionSubscription;
  StreamSubscription<NotificationModel>? _notificationSubscription;
  int _receivedNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _setupDebugListeners();
    _checkConnectionStatus();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _setupDebugListeners() {
    final manager = UnifiedNotificationManager.instance;

    // 연결 상태 리스너
    _connectionSubscription = manager.connectionStatusStream.listen((status) {
      setState(() {
        _isConnected = status == NotificationConnectionStatus.connected;
      });
      _addDebugLog('연결 상태: ${_getStatusText(status)}');
    });

    // 실시간 알림 리스너
    _notificationSubscription = manager.notificationStream.listen((notification) {
      setState(() {
        _receivedNotificationCount++;
      });
      _addDebugLog('실시간 알림 수신: ${notification.title}');
    });
  }

  String _getStatusText(NotificationConnectionStatus status) {
    switch (status) {
      case NotificationConnectionStatus.connected:
        return '연결됨';
      case NotificationConnectionStatus.connecting:
        return '연결 중...';
      case NotificationConnectionStatus.disconnected:
        return '연결끊김';
      case NotificationConnectionStatus.error:
        return '오류';
    }
  }

  void _checkConnectionStatus() {
    if (kIsWeb) {
      final wsHandler = WebSocketHandler.instance;
      setState(() {
        _isConnected = wsHandler.isConnected;
      });
      _addDebugLog('초기 WebSocket 연결 상태: ${_isConnected ? "연결됨" : "연결끊김"}');
    } else {
      // 모바일에서는 FCM 사용 (항상 연결된 것으로 간주)
      setState(() {
        _isConnected = true;
      });
      _addDebugLog('FCM 알림 시스템 활성화됨 (모바일)');
    }
  }

  void _addDebugLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _debugLogs.insert(0, '[$timestamp] $message');
      if (_debugLogs.length > 50) {
        _debugLogs.removeLast();
      }
    });
  }

  Future<void> _testApiConnection() async {
    _addDebugLog('API 연결 테스트 시작...');

    try {
      // 관리자 알림 조회 테스트
      final adminResponse = await NotificationListService.getAdminNotifications(limit: 1);
      _addDebugLog('관리자 API 테스트: ${adminResponse.notifications.length}개 알림');

      // 병원 알림 조회 테스트
      final hospitalResponse = await NotificationListService.getHospitalNotifications(limit: 1);
      _addDebugLog('병원 API 테스트: ${hospitalResponse.notifications.length}개 알림');

      // 사용자 알림 조회 테스트
      final userResponse = await NotificationListService.getUserNotifications(limit: 1);
      _addDebugLog('사용자 API 테스트: ${userResponse.notifications.length}개 알림');

      // 읽지 않은 알림 수 조회 테스트
      final unreadCount = await NotificationListService.getUnreadCount();
      _addDebugLog('읽지 않은 알림 수: $unreadCount개');

      _addDebugLog('모든 API 연결 테스트 완료');
    } catch (e) {
      _addDebugLog('API 테스트 오류: $e');
    }
  }

  Future<void> _reconnect() async {
    if (kIsWeb) {
      _addDebugLog('WebSocket 재연결 시도...');
      await UnifiedNotificationManager.instance.reconnectWebSocket();
    } else {
      _addDebugLog('FCM 토큰 갱신 시도...');
      await UnifiedNotificationManager.instance.updateTokenAfterLogin();
    }
  }

  void _clearLogs() {
    setState(() {
      _debugLogs.clear();
      _receivedNotificationCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림 시스템 디버그'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상태 표시 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '연결 상태',
                      style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.wifi : Icons.wifi_off,
                          color: _isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          kIsWeb
                              ? 'WebSocket: ${_isConnected ? "연결됨" : "연결끊김"}'
                              : 'FCM: ${_isConnected ? "활성화" : "비활성화"}',
                          style: TextStyle(
                            color: _isConnected ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.notifications_active, color: AppTheme.primaryBlue),
                        const SizedBox(width: 8),
                        Text('수신된 실시간 알림: $_receivedNotificationCount개'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.phone_android, color: AppTheme.primaryBlue),
                        const SizedBox(width: 8),
                        Text('플랫폼: ${kIsWeb ? "웹 (WebSocket)" : "모바일 (FCM)"}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 테스트 버튼들
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testApiConnection,
                    icon: const Icon(Icons.api),
                    label: const Text('API 테스트'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _reconnect,
                    icon: const Icon(Icons.refresh),
                    label: Text(kIsWeb ? 'WS 재연결' : 'FCM 갱신'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 로그 섹션
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '디버그 로그',
                  style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _clearLogs,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('로그 지우기'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 로그 리스트
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _debugLogs.isEmpty
                    ? const Center(
                        child: Text(
                          '로그가 없습니다.\n상단 버튼을 눌러 테스트를 시작하세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _debugLogs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              _debugLogs[index],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
