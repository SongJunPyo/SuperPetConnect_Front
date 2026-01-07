import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../utils/app_theme.dart';

/// 읽지 않은 알림 개수를 표시하는 뱃지 위젯
///
/// Provider를 통해 실시간으로 읽지 않은 알림 개수를 표시합니다.
class NotificationBadge extends StatelessWidget {
  /// 아이콘
  final IconData icon;

  /// 아이콘 색상
  final Color? iconColor;

  /// 아이콘 크기
  final double iconSize;

  /// 알림 아이콘 클릭 시 콜백
  final VoidCallback? onPressed;

  /// 뱃지 배경색
  final Color? badgeColor;

  /// 뱃지 텍스트 색상
  final Color? badgeTextColor;

  const NotificationBadge({
    super.key,
    this.icon = Icons.notifications,
    this.iconColor,
    this.iconSize = 24,
    this.onPressed,
    this.badgeColor,
    this.badgeTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final unreadCount = provider.unreadCount;
        final hasUnread = unreadCount > 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                icon,
                color: iconColor ?? Colors.black87,
                size: iconSize,
              ),
              onPressed: onPressed,
            ),
            if (hasUnread)
              Positioned(
                right: 6,
                top: 6,
                child: _buildBadge(unreadCount),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBadge(int count) {
    final displayCount = count > 99 ? '99+' : count.toString();
    final isSmall = count < 10;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 4 : 6,
        vertical: 2,
      ),
      constraints: const BoxConstraints(
        minWidth: 16,
        minHeight: 16,
      ),
      decoration: BoxDecoration(
        color: badgeColor ?? AppTheme.error,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          displayCount,
          style: TextStyle(
            color: badgeTextColor ?? Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// 간단한 점 형태의 알림 뱃지
///
/// 읽지 않은 알림이 있을 때 작은 점으로 표시합니다.
class NotificationDotBadge extends StatelessWidget {
  /// 아이콘
  final IconData icon;

  /// 아이콘 색상
  final Color? iconColor;

  /// 아이콘 크기
  final double iconSize;

  /// 알림 아이콘 클릭 시 콜백
  final VoidCallback? onPressed;

  /// 점 색상
  final Color? dotColor;

  /// 점 크기
  final double dotSize;

  const NotificationDotBadge({
    super.key,
    this.icon = Icons.notifications,
    this.iconColor,
    this.iconSize = 24,
    this.onPressed,
    this.dotColor,
    this.dotSize = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final hasUnread = provider.hasUnread;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                icon,
                color: iconColor ?? Colors.black87,
                size: iconSize,
              ),
              onPressed: onPressed,
            ),
            if (hasUnread)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: dotColor ?? AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Provider 없이 사용 가능한 정적 뱃지
///
/// 외부에서 unreadCount를 직접 전달받아 표시합니다.
class StaticNotificationBadge extends StatelessWidget {
  /// 읽지 않은 알림 개수
  final int unreadCount;

  /// 아이콘
  final IconData icon;

  /// 아이콘 색상
  final Color? iconColor;

  /// 아이콘 크기
  final double iconSize;

  /// 알림 아이콘 클릭 시 콜백
  final VoidCallback? onPressed;

  const StaticNotificationBadge({
    super.key,
    required this.unreadCount,
    this.icon = Icons.notifications,
    this.iconColor,
    this.iconSize = 24,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            icon,
            color: iconColor ?? Colors.black87,
            size: iconSize,
          ),
          onPressed: onPressed,
        ),
        if (hasUnread)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
