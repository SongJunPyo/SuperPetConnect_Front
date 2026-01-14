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
// 웹 브라우저 알림 (조건부 import)
import '../services/web_notification_helper_stub.dart'
    if (dart.library.html) '../services/web_notification_helper.dart';

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
  bool _isInitializing = false; // 초기화 중복 호출 방지
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
    debugPrint('[NotificationProvider] initialize() 호출 - isInitialized: $_isInitialized, isInitializing: $_isInitializing');
    if (_isInitialized) {
      debugPrint('[NotificationProvider] 이미 초기화됨, 건너뜀');
      return;
    }
    if (_isInitializing) {
      debugPrint('[NotificationProvider] 초기화 진행 중, 건너뜀');
      return;
    }

    _isInitializing = true;
    _setLoading(true);
    _connectionStatus = ConnectionStatus.connecting;
    notifyListeners();

    try {
      // 사용자 타입 확인
      final prefs = await SharedPreferences.getInstance();
      final accountType = prefs.getInt('account_type');

      if (accountType == null) {
        _connectionStatus = ConnectionStatus.disconnected;
        _isInitialized = true; // 로그인되지 않은 상태도 초기화 완료로 처리
        _isInitializing = false;
        _setLoading(false);
        return;
      }

      _currentUserType = UserTypeMapper.fromDbType(accountType);

      // 통합 알림 관리자 초기화 (플랫폼별 FCM/WebSocket 자동 선택)
      _notificationManager = UnifiedNotificationManager.instance;
      await _notificationManager!.initialize();

      // 실시간 알림 스트림 구독 (먼저 설정해야 알림 수신 가능)
      _setupRealtimeSubscription();

      // 웹에서 브라우저 알림 권한 요청 (비동기로 실행, 기다리지 않음)
      if (kIsWeb) {
        // 권한 요청은 백그라운드에서 실행 (사용자 응답 대기하지 않음)
        WebNotificationHelper.requestPermission().catchError((e) {
          debugPrint('[NotificationProvider] 브라우저 알림 권한 요청 실패: $e');
          return false;
        });
      }

      // 초기 알림 목록 로드 (로딩 상태 해제 후 호출)
      debugPrint('[NotificationProvider] loadNotifications 호출 전');
      _isLoading = false;
      await loadNotifications(refresh: true);
      debugPrint('[NotificationProvider] loadNotifications 완료 - 알림 수: ${_notifications.length}');

      _isInitialized = true;
      _isInitializing = false;
      _connectionStatus = ConnectionStatus.connected;
      _isLoading = false;
      debugPrint('[NotificationProvider] 초기화 완료 - isInitialized: $_isInitialized, connectionStatus: $_connectionStatus');
      notifyListeners(); // 초기화 완료 후 UI 갱신
    } catch (e) {
      _errorMessage = '알림 시스템 초기화 실패: $e';
      _connectionStatus = ConnectionStatus.error;
      _isInitialized = true; // 에러 발생해도 초기화 완료로 처리 (무한 로딩 방지)
      _isInitializing = false;
      _isLoading = false;
      debugPrint('[NotificationProvider] 초기화 실패: $e');
      notifyListeners(); // 에러 상태 UI 갱신
    }
  }

  /// 실시간 알림 스트림 구독 설정
  void _setupRealtimeSubscription() {
    debugPrint('[NotificationProvider] _setupRealtimeSubscription 호출');
    if (_notificationManager == null) {
      debugPrint('[NotificationProvider] _notificationManager가 null');
      return;
    }

    // 통합 알림 관리자 스트림 구독
    _notificationSubscription?.cancel();
    debugPrint('[NotificationProvider] 알림 스트림 구독 시작');
    _notificationSubscription = _notificationManager!.notificationStream.listen(
      (notification) {
        debugPrint('[NotificationProvider] 스트림에서 알림 수신: ${notification.title}');
        _onNewNotification(notification);
      },
      onError: (error) {
        debugPrint('[NotificationProvider] 실시간 알림 스트림 오류: $error');
        _connectionStatus = ConnectionStatus.error;
        notifyListeners();
      },
    );
    debugPrint('[NotificationProvider] 알림 스트림 구독 완료');

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

      // 웹에서 알림 표시
      if (kIsWeb) {
        // 브라우저 알림 (윈도우 우측 하단)
        _showBrowserNotification(notification);
        // 인앱 토스트 알림
        _showToastNotification(notification);
      }
    }
  }

  /// 웹 브라우저 알림 표시 (윈도우 우측 하단)
  void _showBrowserNotification(NotificationModel notification) {
    debugPrint('[NotificationProvider] 브라우저 알림 표시 시도: ${notification.title}');
    WebNotificationHelper.showNotification(
      title: notification.title,
      body: notification.content,
    );
  }

  /// 웹에서 토스트 알림 표시
  void _showToastNotification(NotificationModel notification) {
    debugPrint('[NotificationProvider] 토스트 알림 표시 시도: ${notification.title}');
    final context = NotificationService.navigatorKey.currentContext;
    if (context == null) {
      debugPrint('[NotificationProvider] 토스트 알림 실패: context가 null');
      return;
    }
    debugPrint('[NotificationProvider] context 확인됨, ScaffoldMessenger 호출');

    try {
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
      debugPrint('[NotificationProvider] 토스트 알림 표시 완료');
    } catch (e) {
      debugPrint('[NotificationProvider] 토스트 알림 표시 실패: $e');
    }
  }

  /// FCM 알림을 Provider에 추가 (모바일에서 FCM 수신 시 호출)
  void addNotificationFromFCM(NotificationModel notification) {
    _onNewNotification(notification);
  }

  // === 읽음 처리 ===

  /// 개별 알림 읽음 처리
  Future<bool> markAsRead(int notificationId) async {
    debugPrint('[NotificationProvider] markAsRead 호출 - notificationId: $notificationId');
    try {
      final success = await NotificationApiService.markAsRead(notificationId);
      debugPrint('[NotificationProvider] markAsRead API 결과: $success');

      if (success) {
        final index = _notifications.indexWhere(
          (n) => n.notificationId == notificationId,
        );
        debugPrint('[NotificationProvider] 알림 인덱스: $index');

        if (index != -1 && !_notifications[index].isRead) {
          final oldNotification = _notifications[index];
          _notifications[index] = _notifications[index].markAsRead();
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
          debugPrint('[NotificationProvider] 읽음 처리 완료 - 이전 isRead: ${oldNotification.isRead}, 현재 isRead: ${_notifications[index].isRead}');
          notifyListeners();
        } else {
          debugPrint('[NotificationProvider] 읽음 처리 스킵 - 이미 읽음 상태');
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

  // === 알림 삭제 ===

  /// 개별 알림 삭제
  Future<bool> deleteNotification(int notificationId) async {
    try {
      final success = await NotificationApiService.deleteNotification(notificationId);

      if (success) {
        final index = _notifications.indexWhere(
          (n) => n.notificationId == notificationId,
        );

        if (index != -1) {
          final notification = _notifications[index];
          _notifications.removeAt(index);
          if (!notification.isRead) {
            _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
          }
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      debugPrint('[NotificationProvider] 알림 삭제 실패: $e');
      return false;
    }
  }

  /// 다건 알림 삭제
  Future<bool> deleteNotifications(List<int> notificationIds) async {
    try {
      final success = await NotificationApiService.deleteNotifications(notificationIds);

      if (success) {
        // 삭제된 알림 중 읽지 않은 개수 계산
        int unreadDeletedCount = 0;
        for (final id in notificationIds) {
          final notification = _notifications.firstWhere(
            (n) => n.notificationId == id,
            orElse: () => NotificationModel(
              notificationId: 0,
              userId: 0,
              typeId: 0,
              title: '',
              content: '',
              createdAt: DateTime.now(),
              isRead: true,
            ),
          );
          if (!notification.isRead && notification.notificationId != 0) {
            unreadDeletedCount++;
          }
        }

        // 목록에서 삭제된 알림 제거
        _notifications.removeWhere((n) => notificationIds.contains(n.notificationId));
        _unreadCount = (_unreadCount - unreadDeletedCount).clamp(0, _unreadCount);
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('[NotificationProvider] 다건 알림 삭제 실패: $e');
      return false;
    }
  }

  /// 전체 알림 삭제
  Future<bool> deleteAllNotifications() async {
    try {
      final success = await NotificationApiService.deleteAllNotifications();

      if (success) {
        _notifications.clear();
        _unreadCount = 0;
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('[NotificationProvider] 전체 알림 삭제 실패: $e');
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
    _isInitializing = false;
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
