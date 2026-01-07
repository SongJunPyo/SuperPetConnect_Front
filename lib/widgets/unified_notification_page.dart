import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../models/notification_types.dart';
import '../providers/notification_provider.dart';
import '../admin/admin_post_management_page.dart';
import '../admin/admin_signup_management.dart';
import '../admin/admin_column_management.dart';
import 'notification_debug_page.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';

/// Provider 기반 통합 알림 페이지
///
/// NotificationProvider를 통해 알림 목록을 관리하고,
/// 사용자 타입에 따라 적절한 UI와 네비게이션을 제공합니다.
class UnifiedNotificationPage extends StatefulWidget {
  const UnifiedNotificationPage({super.key});

  @override
  State<UnifiedNotificationPage> createState() =>
      _UnifiedNotificationPageState();
}

class _UnifiedNotificationPageState extends State<UnifiedNotificationPage> {
  @override
  void initState() {
    super.initState();
    // Provider 초기화 (이미 초기화되어 있으면 건너뜀)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationProvider>();
      if (!provider.isInitialized) {
        provider.initialize();
      } else {
        // 이미 초기화되어 있으면 새로고침
        provider.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        // 로딩 중 (초기화 전)
        if (!provider.isInitialized && provider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 사용자 타입 확인 불가
        if (provider.currentUserType == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('알림')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('사용자 타입을 확인할 수 없습니다.',
                      style: TextStyle(fontSize: 16)),
                  SizedBox(height: 8),
                  Text('다시 로그인해 주세요.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        // 정상 UI
        return _NotificationPageContent(
          provider: provider,
          onNotificationTap: _onNotificationTap,
          onNotificationSettingsPressed: _openNotificationSettings,
        );
      },
    );
  }

  // 알림 탭 시 처리
  void _onNotificationTap(
      NotificationModel notification, NotificationProvider provider) {
    // 읽음 처리
    if (!notification.isRead) {
      provider.markAsRead(notification.notificationId);
    }
    // 알림 타입에 따른 페이지 이동
    _navigateToRelevantPage(notification, provider.currentUserType!);
  }

  // 알림별 적절한 페이지로 이동
  void _navigateToRelevantPage(
      NotificationModel notification, UserType userType) {
    switch (userType) {
      case UserType.admin:
        _handleAdminNotificationTap(notification);
        break;
      case UserType.hospital:
        _handleHospitalNotificationTap(notification);
        break;
      case UserType.user:
        _handleUserNotificationTap(notification);
        break;
    }
  }

  void _handleAdminNotificationTap(NotificationModel notification) {
    if (notification is AdminNotificationModel) {
      switch (notification.adminType) {
        case AdminNotificationType.signupRequest:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminSignupManagement(),
            ),
          );
          break;
        case AdminNotificationType.postApprovalRequest:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminPostManagementPage(
                initialTab: 'pending_approval',
                highlightPostId: notification.relatedId?.toString(),
              ),
            ),
          );
          break;
        case AdminNotificationType.columnApprovalRequest:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminColumnManagement(),
            ),
          );
          break;
        case AdminNotificationType.systemNotice:
          break;
      }
    }
  }

  void _handleHospitalNotificationTap(NotificationModel notification) {
    if (notification is HospitalNotificationModel) {
      switch (notification.hospitalType) {
        case HospitalNotificationType.postApproved:
        case HospitalNotificationType.postRejected:
          Navigator.pushReplacementNamed(context, '/hospital/dashboard');
          break;
        case HospitalNotificationType.recruitmentDeadline:
          Navigator.pushReplacementNamed(
            context,
            '/hospital/dashboard',
            arguments: {'highlightPostId': notification.relatedId},
          );
          break;
        case HospitalNotificationType.columnApproved:
        case HospitalNotificationType.columnRejected:
          Navigator.pushReplacementNamed(context, '/hospital/dashboard');
          break;
        case HospitalNotificationType.systemNotice:
          Navigator.pushReplacementNamed(context, '/hospital/dashboard');
          break;
      }
    }
  }

  void _handleUserNotificationTap(NotificationModel notification) {
    if (notification is UserNotificationModel) {
      switch (notification.userType) {
        case UserNotificationType.systemNotice:
          Navigator.pushReplacementNamed(
            context,
            '/user/dashboard',
            arguments: {'highlightNotificationId': notification.notificationId},
          );
          break;
      }
    }
  }

  // 알림 설정 페이지로 이동
  void _openNotificationSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('디버그 페이지'),
              subtitle: const Text('알림 시스템 연결 상태 확인'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationDebugPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('알림 설정'),
              subtitle: const Text('구현 예정'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('알림 설정 기능 구현 예정')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 알림 페이지 콘텐츠 위젯
class _NotificationPageContent extends StatelessWidget {
  final NotificationProvider provider;
  final void Function(NotificationModel, NotificationProvider) onNotificationTap;
  final VoidCallback onNotificationSettingsPressed;

  const _NotificationPageContent({
    required this.provider,
    required this.onNotificationTap,
    required this.onNotificationSettingsPressed,
  });

  String get _pageTitle {
    switch (provider.currentUserType!) {
      case UserType.admin:
        return '관리자 알림';
      case UserType.hospital:
        return '병원 알림';
      case UserType.user:
        return '사용자 알림';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _pageTitle,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
        actions: [
          // 연결 상태 표시
          _buildConnectionIndicator(),
          // 읽지 않은 알림 개수 표시
          if (provider.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${provider.unreadCount}',
                style: AppTheme.bodySmallStyle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          // 모두 읽음 버튼
          IconButton(
            icon: Icon(Icons.check_circle_outline, color: Colors.grey[600]),
            tooltip: '모두 읽음 표시',
            onPressed: provider.unreadCount > 0
                ? () => _markAllAsRead(context)
                : null,
          ),
          // 알림 설정 버튼
          IconButton(
            icon: Icon(Icons.settings_outlined, color: Colors.grey[600]),
            tooltip: '알림 설정',
            onPressed: onNotificationSettingsPressed,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.refresh(),
        color: AppTheme.primaryBlue,
        child: _buildBody(context, textTheme, colorScheme),
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    IconData icon;
    Color color;

    switch (provider.connectionStatus) {
      case ConnectionStatus.connected:
        icon = Icons.cloud_done;
        color = Colors.green;
        break;
      case ConnectionStatus.connecting:
        icon = Icons.cloud_sync;
        color = Colors.orange;
        break;
      case ConnectionStatus.error:
        icon = Icons.cloud_off;
        color = Colors.red;
        break;
      case ConnectionStatus.disconnected:
        icon = Icons.cloud_outlined;
        color = Colors.grey;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(icon, size: 20, color: color),
    );
  }

  Future<void> _markAllAsRead(BuildContext context) async {
    final success = await provider.markAllAsRead();
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 알림을 읽음 처리했습니다.')),
      );
    } else if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('읽음 처리에 실패했습니다.')),
      );
    }
  }

  Widget _buildBody(
      BuildContext context, TextTheme textTheme, ColorScheme colorScheme) {
    // 로딩 중
    if (provider.isLoading && provider.notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              '알림을 불러오는 중...',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // 에러
    if (provider.errorMessage != null && provider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(provider.errorMessage!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.refresh(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    // 빈 상태
    if (provider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              '새로운 알림이 없어요.',
              style: textTheme.titleMedium?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // 알림 목록
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      itemCount: provider.notifications.length + (provider.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 더 불러오기 인디케이터
        if (index == provider.notifications.length) {
          // 자동으로 다음 페이지 로드
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.loadMore();
          });
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return _buildNotificationItem(
          context,
          provider.notifications[index],
          index,
          textTheme,
          colorScheme,
        );
      },
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    NotificationModel notification,
    int index,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final isUrgent = notification.priority >= NotificationPriority.urgent;
    final isImportant = notification.priority >= NotificationPriority.high;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: notification.isRead
          ? Colors.white
          : colorScheme.primary.withValues(alpha: 0.05),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onNotificationTap(notification, provider),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 읽지 않은 알림 표시점
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 12, top: 4),
                  decoration: BoxDecoration(
                    color: isUrgent ? AppTheme.error : colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(width: 20),

              // 메인 콘텐츠
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목과 우선순위 뱃지
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              // 우선순위 뱃지
                              if (isUrgent || isImportant) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUrgent
                                        ? AppTheme.error
                                        : AppTheme.warning,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isUrgent ? '긴급' : '중요',
                                    style: AppTheme.bodySmallStyle.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              // 알림 아이콘
                              Text(
                                _getNotificationIcon(notification),
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              // 제목
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: notification.isRead
                                        ? Colors.black87
                                        : (isUrgent
                                            ? AppTheme.error
                                            : colorScheme.primary),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 날짜
                        Text(
                          DateFormat('MM.dd').format(notification.createdAt),
                          style: textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 알림 내용
                    Text(
                      notification.content,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                        fontWeight:
                            notification.isRead ? FontWeight.normal : FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 알림 타입과 시간
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getNotificationTypeName(notification),
                          style: textTheme.bodySmall?.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm').format(notification.createdAt),
                          style: textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getNotificationIcon(NotificationModel notification) {
    switch (provider.currentUserType!) {
      case UserType.admin:
        if (notification is AdminNotificationModel) {
          return notification.typeIcon;
        }
        break;
      case UserType.hospital:
        if (notification is HospitalNotificationModel) {
          return notification.typeIcon;
        }
        break;
      case UserType.user:
        if (notification is UserNotificationModel) {
          return notification.typeIcon;
        }
        break;
    }
    return '🔔';
  }

  String _getNotificationTypeName(NotificationModel notification) {
    switch (provider.currentUserType!) {
      case UserType.admin:
        if (notification is AdminNotificationModel) {
          return notification.typeName;
        }
        break;
      case UserType.hospital:
        if (notification is HospitalNotificationModel) {
          return notification.typeName;
        }
        break;
      case UserType.user:
        if (notification is UserNotificationModel) {
          return notification.typeName;
        }
        break;
    }
    return '알림';
  }
}

// 알림 페이지 간편 사용을 위한 헬퍼 위젯
class NotificationPageRoute {
  static MaterialPageRoute<void> get route {
    return MaterialPageRoute<void>(
      builder: (context) => const UnifiedNotificationPage(),
    );
  }
}
