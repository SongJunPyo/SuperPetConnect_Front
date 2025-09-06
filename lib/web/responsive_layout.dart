import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1200 && desktop != null) {
            return desktop!;
          } else if (constraints.maxWidth >= 768 && tablet != null) {
            return tablet!;
          } else {
            return mobile;
          }
        },
      );
    }
    return mobile;
  }
}

class ResponsiveBreakpoints {
  static const double mobile = 480;
  static const double tablet = 768;
  static const double desktop = 1200;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobile;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= mobile &&
        MediaQuery.of(context).size.width < desktop;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktop;
  }
}

class WebAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;

  const WebAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return AppBar(
        title: Text(title),
        actions: actions,
        automaticallyImplyLeading: showBackButton,
      );
    }

    return AppBar(
      title: Row(
        children: [
          const Text('🩸 Super Pet Connect'),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (actions != null) ...actions!,
        if (ResponsiveBreakpoints.isDesktop(context))
          _buildDesktopNavigation(context),
      ],
      elevation: 1,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    );
  }

  Widget _buildDesktopNavigation(BuildContext context) {
    return Row(
      children: [
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/'),
          child: const Text('홈'),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/admin'),
          child: const Text('관리자'),
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}

class WebContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  const WebContainer({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth = 1200,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return child;
    }

    return Center(
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
        child: child,
      ),
    );
  }
}

class WebCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const WebCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Container(
        padding: padding,
        margin: margin,
        child: child,
      );
    }

    return Container(
      margin: margin ?? const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

extension WebContext on BuildContext {
  bool get isWeb => kIsWeb;
  bool get isMobile => ResponsiveBreakpoints.isMobile(this);
  bool get isTablet => ResponsiveBreakpoints.isTablet(this);
  bool get isDesktop => ResponsiveBreakpoints.isDesktop(this);
}