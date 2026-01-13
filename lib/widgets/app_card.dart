// app_card.dart: 게시글, 정보, 기능 카드 등 다양한 카드 컴포넌트들
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

enum AppCardType { elevated, outlined, filled }

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final AppCardType type;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final VoidCallback? onTap;
  final bool showShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.type = AppCardType.elevated,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.onTap,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? AppTheme.cardMargin,
      child: Material(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(borderRadius ?? AppTheme.radius12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppTheme.radius12,
          ),
          child: Container(
            padding: padding ?? AppTheme.cardPadding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                borderRadius ?? AppTheme.radius12,
              ),
              border: _getBorder(),
              boxShadow: _getShadow(),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (backgroundColor != null) return backgroundColor!;

    switch (type) {
      case AppCardType.elevated:
        return Colors.white;
      case AppCardType.outlined:
        return Colors.white;
      case AppCardType.filled:
        return AppTheme.veryLightGray;
    }
  }

  Border? _getBorder() {
    if (type == AppCardType.outlined) {
      return Border.all(color: borderColor ?? AppTheme.lightGray, width: 1);
    }
    return null;
  }

  List<BoxShadow>? _getShadow() {
    if (!showShadow || type != AppCardType.elevated) return null;
    return AppTheme.shadowSmall;
  }
}

// 특화된 카드 컴포넌트들
class AppPostCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? date;
  final String? status;
  final Color? statusColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const AppPostCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.date,
    this.status,
    this.statusColor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              border: Border.all(
                color: AppTheme.lightGray.withValues(alpha: 0.8),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.h4Style.copyWith(
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.spacing12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                if (date != null || status != null) ...[
                  const SizedBox(height: AppTheme.spacing16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (date != null)
                        Text(
                          date!,
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      if (status != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing8,
                            vertical: AppTheme.spacing4,
                          ),
                          decoration: BoxDecoration(
                            color: (statusColor ?? AppTheme.primaryBlue).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radius8),
                            border: Border.all(
                              color: statusColor ?? AppTheme.primaryBlue,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            status!,
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: statusColor ?? AppTheme.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const AppInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      type: AppCardType.filled,
      backgroundColor: backgroundColor ?? AppTheme.lightBlue,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? AppTheme.primaryBlue, size: 24),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: iconColor ?? AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  description,
                  style: AppTheme.bodySmallStyle.copyWith(
                    color: iconColor ?? AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: iconColor ?? AppTheme.primaryBlue,
            ),
        ],
      ),
    );
  }
}

class AppFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const AppFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      backgroundColor: backgroundColor ?? AppTheme.lightBlue,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: iconColor ?? AppTheme.primaryBlue),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTheme.bodyMediumStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
