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
class UnifiedNotificationPage extends StatefulWidget {
  const UnifiedNotificationPage({super.key});

  @override
  State<UnifiedNotificationPage> createState() =>
      _UnifiedNotificationPageState();
}

class _UnifiedNotificationPageState extends State<UnifiedNotificationPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationProvider>();
      if (!provider.isInitialized) {
        provider.initialize();
      }
    });

    // 무한 스크롤
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<NotificationProvider>();
      if (!provider.isLoading && provider.hasMore) {
        provider.loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        if (!provider.isInitialized) {
          return Scaffold(
            appBar: _buildAppBar(provider),
            body: const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            ),
          );
        }

        if (provider.currentUserType == null) {
          return Scaffold(
            appBar: _buildAppBar(provider),
            body: _buildErrorState('사용자 정보를 확인할 수 없습니다.\n다시 로그인해 주세요.'),
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(provider),
          body: RefreshIndicator(
            onRefresh: () => provider.refresh(),
            color: AppTheme.primaryBlue,
            child: _buildBody(provider),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(NotificationProvider provider) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Text(
            '알림',
            style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
          ),
          if (provider.unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                provider.unreadCount > 99 ? '99+' : '${provider.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        // 모두 읽음 버튼
        if (provider.unreadCount > 0)
          TextButton(
            onPressed: () => _markAllAsRead(provider),
            child: Text(
              '모두 읽음',
              style: AppTheme.bodySmallStyle.copyWith(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        // 더보기 메뉴
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
          onSelected: (value) {
            if (value == 'debug') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationDebugPage(),
                ),
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'debug',
              child: Row(
                children: [
                  Icon(Icons.bug_report, size: 20),
                  SizedBox(width: 8),
                  Text('연결 상태 확인'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBody(NotificationProvider provider) {
    // 로딩 중
    if (provider.isLoading && provider.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryBlue),
            const SizedBox(height: 16),
            Text(
              '알림을 불러오는 중...',
              style: AppTheme.bodyMediumStyle.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    // 에러 상태
    if (provider.errorMessage != null && provider.notifications.isEmpty) {
      return _buildErrorState(provider.errorMessage!);
    }

    // 빈 상태
    if (provider.notifications.isEmpty) {
      return _buildEmptyState();
    }

    // 알림 목록
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: provider.notifications.length + (provider.hasMore ? 1 : 0),
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        color: AppTheme.lightGray.withValues(alpha: 0.3),
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        if (index == provider.notifications.length) {
          return _buildLoadingMore();
        }
        return _buildNotificationItem(provider.notifications[index], provider);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: AppTheme.mediumGray,
          ),
          const SizedBox(height: 16),
          Text(
            '알림이 없습니다',
            style: AppTheme.h4Style.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 알림이 오면 여기에 표시됩니다',
            style: AppTheme.bodySmallStyle.copyWith(color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTheme.bodyMediumStyle.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.read<NotificationProvider>().refresh(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMore() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification, NotificationProvider provider) {
    final isRead = notification.isRead;
    final timeAgo = _getTimeAgo(notification.createdAt);

    return InkWell(
      onTap: () => _onNotificationTap(notification, provider),
      child: Container(
        color: isRead ? Colors.white : AppTheme.primaryBlue.withValues(alpha: 0.03),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 읽음 표시 점
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, right: 12),
              decoration: BoxDecoration(
                color: isRead ? Colors.transparent : AppTheme.primaryBlue,
                shape: BoxShape.circle,
              ),
            ),
            // 아이콘
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: _getIconBackgroundColor(notification).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  _getNotificationIcon(notification, provider),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            // 내용
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Text(
                    notification.title,
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 내용
                  Text(
                    notification.content,
                    style: AppTheme.bodySmallStyle.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // 타입 & 시간
                  Row(
                    children: [
                      Text(
                        _getNotificationTypeName(notification, provider),
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                      Container(
                        width: 3,
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 화살표
            Icon(
              Icons.chevron_right,
              color: AppTheme.lightGray,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Color _getIconBackgroundColor(NotificationModel notification) {
    if (notification is AdminNotificationModel) {
      return AppTheme.primaryBlue;
    } else if (notification is HospitalNotificationModel) {
      return AppTheme.success;
    } else {
      return AppTheme.warning;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return DateFormat('MM.dd').format(dateTime);
    }
  }

  Future<void> _markAllAsRead(NotificationProvider provider) async {
    final success = await provider.markAllAsRead();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '모든 알림을 읽음 처리했습니다' : '읽음 처리에 실패했습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onNotificationTap(NotificationModel notification, NotificationProvider provider) {
    // 읽음 처리
    if (!notification.isRead) {
      provider.markAsRead(notification.notificationId);
    }
    // 알림 타입에 따른 페이지 이동
    _navigateToRelevantPage(notification, provider.currentUserType!);
  }

  void _navigateToRelevantPage(NotificationModel notification, UserType userType) {
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
            MaterialPageRoute(builder: (context) => const AdminSignupManagement()),
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
        case AdminNotificationType.donationApplicationRequest:
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
            MaterialPageRoute(builder: (context) => const AdminColumnManagement()),
          );
          break;
        case AdminNotificationType.donationCompleted:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminPostManagementPage(
                initialTab: 'completed',
                highlightPostId: notification.relatedId?.toString(),
              ),
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
        case HospitalNotificationType.recruitmentDeadline:
        case HospitalNotificationType.timeslotFilled:
        case HospitalNotificationType.allTimeslotsFilled:
        case HospitalNotificationType.donationApplication:
        case HospitalNotificationType.columnApproved:
        case HospitalNotificationType.columnRejected:
        case HospitalNotificationType.systemNotice:
          Navigator.pushReplacementNamed(context, '/hospital/dashboard');
          break;
      }
    }
  }

  void _handleUserNotificationTap(NotificationModel notification) {
    if (notification is UserNotificationModel) {
      Navigator.pushReplacementNamed(context, '/user/dashboard');
    }
  }

  String _getNotificationIcon(NotificationModel notification, NotificationProvider provider) {
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

  String _getNotificationTypeName(NotificationModel notification, NotificationProvider provider) {
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

/// 알림 페이지 라우트 헬퍼
class NotificationPageRoute {
  static MaterialPageRoute<void> get route {
    return MaterialPageRoute<void>(
      builder: (context) => const UnifiedNotificationPage(),
    );
  }
}
