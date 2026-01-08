import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../models/notification_types.dart';
import '../services/notification_api_service.dart';
import '../services/unified_notification_manager.dart';
import '../services/notification_service.dart';
import '../widgets/unified_notification_page.dart';

/// 알림 연결 상태
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// NotificationConnectionStatus를 ConnectionStatus로 변환
ConnectionStatus _convertConnectionStatus(NotificationConnectionStatus status) {
  switch (status) {
    case NotificationConnectionStatus.disconnected:
      return ConnectionStatus.disconnected;
    case NotificationConnectionStatus.connecting:
      return ConnectionStatus.connecting;
    case NotificationConnectionStatus.connected:
      return ConnectionStatus.connected;
    case NotificationConnectionStatus.error:
      return ConnectionStatus.error;
  }
}

/// 알림 상태 관리 Provider
///
/// FCM(모바일)과 WebSocket(웹) 알림을 통합 관리하고,
/// 알림 목록, 읽지 않은 개수 등의 상태를 전역적으로 관리합니다.
class NotificationProvider extends ChangeNotifier {
  // === 상태 ===
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _isInitialized = false;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  UserType? _currentUserType;
  String? _errorMessage;

  // 페이징 관련
  int _currentPage = 1;
  bool _hasMore = true;
  static const int _pageSize = 20;

  // 스트림 구독
  StreamSubscription<NotificationModel>? _notificationSubscription;
  StreamSubscription<NotificationConnectionStatus>? _connectionSubscription;

  // 통합 알림 관리자
  UnifiedNotificationManager? _notificationManager;

  // === Getters ===
  List<NotificationModel> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  ConnectionStatus get connectionStatus => _connectionStatus;
  UserType? get currentUserType => _currentUserType;
  String? get errorMessage => _errorMessage;
  bool get hasUnread => _unreadCount > 0;
  bool get hasMore => _hasMore;

  // === 초기화 ===

  /// Provider 초기화
  /// 앱 시작 시 또는 로그인 후 호출됩니다.
  Future<void> initialize() async {
    debugPrint('[NotificationProvider] initialize() 호출 - isInitialized: $_isInitialized');
    if (_isInitialized) {
      debugPrint('[NotificationProvider] 이미 초기화됨, 건너뜀');
      return;
    }

    _setLoading(true);
    _connectionStatus = ConnectionStatus.connecting;
    notifyListeners();

    try {
      // 사용자 타입 확인
      final prefs = await SharedPreferences.getInstance();
      final accountType = prefs.getInt('account_type');

      if (accountType == null) {
        _connectionStatus = ConnectionStatus.disconnected;
        _setLoading(false);
        return;
      }

      _currentUserType = UserTypeMapper.fromDbType(accountType);

      // 통합 알림 관리자 초기화 (플랫폼별 FCM/WebSocket 자동 선택)
      _notificationManager = UnifiedNotificationManager.instance;
      await _notificationManager!.initialize();

      // 실시간 알림 스트림 구독
      _setupRealtimeSubscription();

      // 초기 알림 목록 로드 (로딩 상태 해제 후 호출)
      debugPrint('[NotificationProvider] loadNotifications 호출 전');
      _isLoading = false;
      await loadNotifications(refresh: true);
      debugPrint('[NotificationProvider] loadNotifications 완료 - 알림 수: ${_notifications.length}');

      _isInitialized = true;
      _connectionStatus = ConnectionStatus.connected;
      _isLoading = false;
      debugPrint('[NotificationProvider] 초기화 완료 - isInitialized: $_isInitialized, connectionStatus: $_connectionStatus');
      notifyListeners(); // 초기화 완료 후 UI 갱신
    } catch (e) {
      _errorMessage = '알림 시스템 초기화 실패: $e';
      _connectionStatus = ConnectionStatus.error;
      _isLoading = false;
      debugPrint('[NotificationProvider] 초기화 실패: $e');
      notifyListeners(); // 에러 상태 UI 갱신
    }
  }

  /// 실시간 알림 스트림 구독 설정
  void _setupRealtimeSubscription() {
    if (_notificationManager == null) return;

    // 통합 알림 관리자 스트림 구독
    _notificationSubscription?.cancel();
    _notificationSubscription = _notificationManager!.notificationStream.listen(
      _onNewNotification,
      onError: (error) {
        debugPrint('[NotificationProvider] 실시간 알림 스트림 오류: $error');
        _connectionStatus = ConnectionStatus.error;
        notifyListeners();
      },
    );

    // 연결 상태 스트림 구독
    _connectionSubscription?.cancel();
    _connectionSubscription = _notificationManager!.connectionStatusStream.listen(
      (status) {
        _connectionStatus = _convertConnectionStatus(status);
        notifyListeners();
      },
    );
  }

  // === 알림 목록 관리 ===

  /// 알림 목록 로드
  /// [refresh]가 true이면 처음부터 다시 로드, false이면 다음 페이지 로드
  Future<void> loadNotifications({bool refresh = false}) async {
    if (_currentUserType == null) return;
    if (_isLoading) return;
    if (!refresh && !_hasMore) return;

    _setLoading(true);

    try {
      if (refresh) {
        _currentPage = 1;
        _hasMore = true;
      }

      final response = await _getNotificationsByUserType(
        page: _currentPage,
        limit: _pageSize,
      );

      if (refresh) {
        _notifications = response.notifications;
      } else {
        _notifications.addAll(response.notifications);
      }

      _unreadCount = response.unreadCount;
      _hasMore = response.hasMore;
      _currentPage++;

      _clearError();
    } catch (e) {
      _errorMessage = '알림 목록 로드 실패: $e';
      debugPrint('[NotificationProvider] 알림 목록 로드 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 사용자 타입별 알림 조회
  Future<NotificationListResponse> _getNotificationsByUserType({
    required int page,
    required int limit,
  }) async {
    switch (_currentUserType!) {
      case UserType.admin:
        return NotificationApiService.getAdminNotifications(
          page: page,
          limit: limit,
        );
      case UserType.hospital:
        return NotificationApiService.getHospitalNotifications(
          page: page,
          limit: limit,
        );
      case UserType.user:
        return NotificationApiService.getUserNotifications(
          page: page,
          limit: limit,
        );
    }
  }

  /// 알림 목록 새로고침
  Future<void> refresh() async {
    debugPrint('[NotificationProvider] refresh() 호출');
    await loadNotifications(refresh: true);
    debugPrint('[NotificationProvider] refresh() 완료 - 알림 수: ${_notifications.length}');
  }

  /// 다음 페이지 로드
  Future<void> loadMore() async {
    await loadNotifications(refresh: false);
  }

  // === 새 알림 처리 ===

  /// 실시간 알림 수신 처리
  void _onNewNotification(NotificationModel notification) {
    // 중복 체크
    final exists = _notifications.any(
      (n) => n.notificationId == notification.notificationId,
    );

    if (!exists) {
      // 목록 맨 앞에 추가
      _notifications.insert(0, notification);
      _unreadCount++;
      notifyListeners();

      debugPrint('[NotificationProvider] 새 알림 수신: ${notification.title}');

      // 웹에서 토스트 알림 표시
      if (kIsWeb) {
        _showToastNotification(notification);
      }
    }
  }

  /// 웹에서 토스트 알림 표시
  void _showToastNotification(NotificationModel notification) {
    final context = NotificationService.navigatorKey.currentContext;
    if (context == null) return;

    // ScaffoldMessenger를 통해 SnackBar 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.content,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3182F6),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '보기',
          textColor: Colors.white,
          onPressed: () {
            // 알림 페이지로 이동
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const UnifiedNotificationPage(),
              ),
            );
          },
        ),
      ),
    );
  }

  /// FCM 알림을 Provider에 추가 (모바일에서 FCM 수신 시 호출)
  void addNotificationFromFCM(NotificationModel notification) {
    _onNewNotification(notification);
  }

  // === 읽음 처리 ===

  /// 개별 알림 읽음 처리
  Future<bool> markAsRead(int notificationId) async {
    try {
      final success = await NotificationApiService.markAsRead(notificationId);

      if (success) {
        final index = _notifications.indexWhere(
          (n) => n.notificationId == notificationId,
        );

        if (index != -1 && !_notifications[index].isRead) {
          _notifications[index] = _notifications[index].markAsRead();
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      debugPrint('[NotificationProvider] 읽음 처리 실패: $e');
      return false;
    }
  }

  /// 전체 알림 읽음 처리
  Future<bool> markAllAsRead() async {
    try {
      final success = await NotificationApiService.markAllAsRead();

      if (success) {
        _notifications = _notifications.map((n) => n.markAsRead()).toList();
        _unreadCount = 0;
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('[NotificationProvider] 전체 읽음 처리 실패: $e');
      return false;
    }
  }

  // === 읽지 않은 알림 개수 ===

  /// 읽지 않은 알림 개수 갱신
  Future<void> refreshUnreadCount() async {
    try {
      final count = await NotificationApiService.getUnreadCount();
      if (_unreadCount != count) {
        _unreadCount = count;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[NotificationProvider] 읽지 않은 개수 조회 실패: $e');
    }
  }

  // === 유틸리티 ===

  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// 에러 메시지 초기화
  void clearError() {
    _clearError();
  }

  /// 로그아웃 시 상태 초기화
  void reset() {
    _notificationSubscription?.cancel();
    _connectionSubscription?.cancel();

    _notifications = [];
    _unreadCount = 0;
    _isLoading = false;
    _isInitialized = false;
    _connectionStatus = ConnectionStatus.disconnected;
    _currentUserType = null;
    _errorMessage = null;
    _currentPage = 1;
    _hasMore = true;

    notifyListeners();
  }

  // === 정리 ===

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
}
