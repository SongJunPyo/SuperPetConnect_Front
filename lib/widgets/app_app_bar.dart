// app_app_bar.dart: 대시보드용, 심플한 앱바 등 컴포넌트들
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'notification_badge.dart';

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool centerTitle;
  final double? elevation;
  final Widget? leading;

  const AppAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.centerTitle = false,
    this.elevation,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? Colors.white,
      foregroundColor: foregroundColor ?? AppTheme.textPrimary,
      elevation: elevation ?? 0,
      centerTitle: centerTitle,
      leading: _buildLeading(context),
      title: titleWidget ?? (title != null ? _buildTitle() : null),
      actions: _buildActions(),
      systemOverlayStyle: Theme.of(context).appBarTheme.systemOverlayStyle,
    );
  }

  Widget? _buildLeading(BuildContext context) {
    if (leading != null) return leading;

    if (showBackButton && Navigator.of(context).canPop()) {
      return IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
      );
    }

    return null;
  }

  Widget _buildTitle() {
    return Text(title!, style: AppTheme.h3Style);
  }

  List<Widget>? _buildActions() {
    if (actions == null) return null;

    return [...actions!, const SizedBox(width: AppTheme.spacing8)];
  }

  @override
  Size get preferredSize => const Size.fromHeight(AppTheme.appBarHeight);
}

// 특화된 앱바 컴포넌트들
class AppDashboardAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String? userName;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onBackPressed;
  final Widget? additionalAction;

  const AppDashboardAppBar({
    super.key,
    this.userName,
    this.onProfilePressed,
    this.onNotificationPressed,
    this.onBackPressed,
    this.additionalAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppAppBar(
      onBackPressed: onBackPressed,
      showBackButton: onBackPressed != null,
      actions: [
        // 알림 버튼 (Provider 기반 자동 뱃지 표시)
        NotificationBadge(onPressed: onNotificationPressed),

        // 추가 액션 버튼 (있는 경우)
        if (additionalAction != null) additionalAction!,

        // 프로필 버튼
        IconButton(
          icon: const Icon(Icons.person, color: Colors.black87, size: 24),
          onPressed: onProfilePressed,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(AppTheme.appBarHeight);
}

class AppSimpleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;

  const AppSimpleAppBar({
    super.key,
    required this.title,
    this.onBackPressed,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppAppBar(
      title: title,
      centerTitle: true,
      onBackPressed: onBackPressed,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(AppTheme.appBarHeight);
}
