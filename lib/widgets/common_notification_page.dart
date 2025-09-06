import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../models/notification_types.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';

class CommonNotificationPage extends StatefulWidget {
  final UserType userType;
  final Future<NotificationListResponse> Function() onLoadNotifications;
  final Future<bool> Function(int notificationId) onMarkAsRead;
  final Future<bool> Function() onMarkAllAsRead;
  final VoidCallback? onNotificationSettingsPressed;
  final Function(NotificationModel)? onNotificationTap;

  const CommonNotificationPage({
    super.key,
    required this.userType,
    required this.onLoadNotifications,
    required this.onMarkAsRead,
    required this.onMarkAllAsRead,
    this.onNotificationSettingsPressed,
    this.onNotificationTap,
  });

  @override
  State<CommonNotificationPage> createState() => _CommonNotificationPageState();
}

class _CommonNotificationPageState extends State<CommonNotificationPage> {
  List<NotificationModel> notifications = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  int totalCount = 0;
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await widget.onLoadNotifications();
      setState(() {
        notifications = response.notifications;
        totalCount = response.totalCount;
        unreadCount = response.unreadCount;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(int index) async {
    final notification = notifications[index];
    if (notification.isRead) return;

    try {
      final success = await widget.onMarkAsRead(notification.notificationId);
      if (success) {
        setState(() {
          notifications[index] = notification.markAsRead();
          if (unreadCount > 0) unreadCount--;
        });
      }
    } catch (e) {
      // 알림 목록 로딩 실패 시 로그 출력
      debugPrint('Failed to load notifications: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    if (unreadCount == 0) return;

    try {
      final success = await widget.onMarkAllAsRead();
      if (success) {
        setState(() {
          notifications = notifications.map((n) => n.markAsRead()).toList();
          unreadCount = 0;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('모든 알림을 읽음 처리했습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('읽음 처리에 실패했습니다.')),
        );
      }
    }
  }

  String get _pageTitle {
    switch (widget.userType) {
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
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

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
          // 읽지 않은 알림 개수 표시
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$unreadCount',
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
            onPressed: unreadCount > 0 ? _markAllAsRead : null,
          ),
          // 알림 설정 버튼
          if (widget.onNotificationSettingsPressed != null)
            IconButton(
              icon: Icon(Icons.settings_outlined, color: Colors.grey[600]),
              tooltip: '알림 설정',
              onPressed: widget.onNotificationSettingsPressed,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        color: AppTheme.primaryBlue,
        child: _buildBody(textTheme, colorScheme),
      ),
    );
  }

  Widget _buildBody(TextTheme textTheme, ColorScheme colorScheme) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              '알림을 불러오는 중...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (notifications.isEmpty) {
      return _buildEmptyState(textTheme);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: 20.0,
        vertical: 16.0,
      ),
      itemCount: notifications.length,
      itemBuilder: (context, index) => _buildNotificationItem(
        notifications[index], 
        index, 
        textTheme, 
        colorScheme,
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '새로운 알림이 없어요.',
            style: textTheme.titleMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
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
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      color: notification.isRead
          ? Colors.white
          : colorScheme.primary.withValues(alpha: 0.05),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _markAsRead(index);
          widget.onNotificationTap?.call(notification);
        },
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
                    color: isUrgent 
                        ? AppTheme.error 
                        : colorScheme.primary,
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
                                    color: isUrgent ? AppTheme.error : AppTheme.warning,
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
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 알림 내용
                    Text(
                      notification.content,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                        fontWeight: notification.isRead
                            ? FontWeight.normal
                            : FontWeight.w500,
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
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
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
    switch (widget.userType) {
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
    switch (widget.userType) {
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