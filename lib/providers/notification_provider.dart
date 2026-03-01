import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../models/notification_types.dart';
import '../services/notification_api_service.dart';
import '../services/unified_notification_manager.dart';
import '../services/notification_service.dart';
import '../utils/preferences_manager.dart';
import '../widgets/unified_notification_page.dart';
// 웹 브라우저 알림 (조건부 import)
import '../services/web_notification_helper_stub.dart'
    if (dart.library.html) '../services/web_notification_helper.dart';

/// 알림 연결 상태
enum ConnectionStatus { disconnected, connecting, connected, error }

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
  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);
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
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;
    _setLoading(true);
    _connectionStatus = ConnectionStatus.connecting;
    notifyListeners();

    try {
      // 사용자 타입 및 인증 토큰 확인
      final accountType = await PreferencesManager.getAccountType();
      final token = await PreferencesManager.getAuthToken();

      if (accountType == null || token == null || token.isEmpty) {
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

      // 초기 알림 목록 로드 (로딩 상태 해제 후 호출)
      _isLoading = false;
      await loadNotifications(refresh: true);

      _isInitialized = true;
      _isInitializing = false;
      _connectionStatus = ConnectionStatus.connected;
      _isLoading = false;
      notifyListeners();

      // 웹에서 브라우저 알림 권한이 아직 미요청 상태면 다이얼로그 표시
      if (kIsWeb) {
        final permission = WebNotificationHelper.checkCurrentPermission();
        if (permission == 'default') {
          // 잠시 지연 후 다이얼로그 표시 (화면 렌더링 완료 대기)
          Future.delayed(const Duration(milliseconds: 500), () {
            _showNotificationPermissionDialog();
          });
        }
      }
    } catch (e) {
      _errorMessage = '알림 시스템 초기화 실패: $e';
      _connectionStatus = ConnectionStatus.error;
      _isInitialized = true;
      _isInitializing = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 실시간 알림 스트림 구독 설정
  void _setupRealtimeSubscription() {
    if (_notificationManager == null) return;

    _notificationSubscription?.cancel();
    _notificationSubscription = _notificationManager!.notificationStream.listen(
      (notification) {
        _onNewNotification(notification);
      },
      onError: (error) {
        _connectionStatus = ConnectionStatus.error;
        notifyListeners();
      },
    );

    // 연결 상태 스트림 구독
    _connectionSubscription?.cancel();
    _connectionSubscription = _notificationManager!.connectionStatusStream
        .listen((status) {
          _connectionStatus = _convertConnectionStatus(status);
          notifyListeners();
        });
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
    await loadNotifications(refresh: true);
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

      // 웹에서 알림 표시
      if (kIsWeb) {
        // 브라우저 알림 (윈도우 우측 하단)
        _showBrowserNotification(notification);
        // 인앱 토스트 알림
        _showToastNotification(notification);
      }
    }
  }

  /// 웹 브라우저 알림 권한 요청 다이얼로그
  /// 사용자 클릭 이벤트 내에서 requestPermission()을 호출해야 브라우저가 허용합니다.
  void _showNotificationPermissionDialog() {
    final context = NotificationService.navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF3182F6).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: Color(0xFF3182F6),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '알림 허용',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '긴급 헌혈 요청, 지원 승인 등\n중요한 알림을 실시간으로 받을 수 있습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4E5968),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                '나중에',
                style: TextStyle(color: Color(0xFF8B95A1)),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                // 사용자 클릭 이벤트 내에서 권한 요청 (브라우저 정책 충족)
                await WebNotificationHelper.requestPermission();
              },
              child: const Text(
                '허용',
                style: TextStyle(
                  color: Color(0xFF3182F6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 웹 브라우저 알림 표시 (윈도우 우측 하단)
  void _showBrowserNotification(NotificationModel notification) {
    WebNotificationHelper.showNotification(
      title: notification.title,
      body: notification.content,
    );
  }

  /// 웹에서 토스트 알림 표시
  void _showToastNotification(NotificationModel notification) {
    final context = NotificationService.navigatorKey.currentContext;
    if (context == null) return;

    try {
      final messenger = ScaffoldMessenger.of(context);
      // 이전 알림 토스트가 있으면 즉시 제거
      messenger.hideCurrentSnackBar();

      final controller = messenger.showSnackBar(
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

      // 웹에서 action이 있는 SnackBar가 자동 dismiss 안 되는 문제 대응
      if (kIsWeb) {
        Timer(const Duration(seconds: 4), () {
          try {
            controller.close();
          } catch (_) {}
        });
      }
    } catch (_) {}
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
      return false;
    }
  }

  // === 알림 삭제 ===

  /// 개별 알림 삭제
  Future<bool> deleteNotification(int notificationId) async {
    try {
      final success = await NotificationApiService.deleteNotification(
        notificationId,
      );

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
      return false;
    }
  }

  /// 다건 알림 삭제
  Future<bool> deleteNotifications(List<int> notificationIds) async {
    try {
      final success = await NotificationApiService.deleteNotifications(
        notificationIds,
      );

      if (success) {
        // 삭제된 알림 중 읽지 않은 개수 계산
        int unreadDeletedCount = 0;
        for (final id in notificationIds) {
          final notification = _notifications.firstWhere(
            (n) => n.notificationId == id,
            orElse:
                () => NotificationModel(
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
        _notifications.removeWhere(
          (n) => notificationIds.contains(n.notificationId),
        );
        _unreadCount = (_unreadCount - unreadDeletedCount).clamp(
          0,
          _unreadCount,
        );
        notifyListeners();
      }

      return success;
    } catch (e) {
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
    } catch (_) {}
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

    // WebSocket 연결 해제 (재연결 타이머 포함)
    _notificationManager?.disconnect();

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
