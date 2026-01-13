import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class CustomTabBar extends StatelessWidget {
  final TabController? controller;
  final List<Tab> tabs;
  final Color? indicatorColor;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final double indicatorWeight;
  final EdgeInsetsGeometry? indicatorPadding;
  final TabBarIndicatorSize? indicatorSize;
  final bool isScrollable;
  final Function(int)? onTap;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Decoration? indicator;
  final BorderRadius? borderRadius;
  
  const CustomTabBar({
    super.key,
    this.controller,
    required this.tabs,
    this.indicatorColor,
    this.labelColor,
    this.unselectedLabelColor,
    this.labelStyle,
    this.unselectedLabelStyle,
    this.indicatorWeight = 3.0,
    this.indicatorPadding,
    this.indicatorSize,
    this.isScrollable = false,
    this.onTap,
    this.height,
    this.padding,
    this.indicator,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
      ),
      child: TabBar(
        controller: controller,
        tabs: tabs,
        indicatorColor: indicatorColor ?? AppTheme.primaryBlue,
        labelColor: labelColor ?? AppTheme.primaryBlue,
        unselectedLabelColor: unselectedLabelColor ?? AppTheme.mediumGray,
        labelStyle: labelStyle ?? AppTheme.bodyMediumStyle.copyWith(
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: unselectedLabelStyle ?? AppTheme.bodyMediumStyle,
        indicatorWeight: indicatorWeight,
        indicatorPadding: indicatorPadding ?? const EdgeInsets.symmetric(horizontal: 16.0),
        indicatorSize: indicatorSize ?? TabBarIndicatorSize.tab,
        isScrollable: isScrollable,
        onTap: onTap,
        indicator: indicator ?? UnderlineTabIndicator(
          borderSide: BorderSide(
            width: indicatorWeight,
            color: indicatorColor ?? AppTheme.primaryBlue,
          ),
          insets: indicatorPadding ?? const EdgeInsets.symmetric(horizontal: 16.0),
        ),
      ),
    );
  }
}

// 프리셋 스타일을 위한 팩토리 메서드들
class CustomTabBar2 extends CustomTabBar {
  // 기본 스타일 (가장 일반적으로 사용)
  CustomTabBar2.standard({
    super.key,
    TabController? controller,
    required List<Tab> tabs,
    Function(int)? onTap,
  }) : super(
    controller: controller,
    tabs: tabs,
    indicatorColor: Colors.black,
    labelColor: Colors.black,
    unselectedLabelColor: Colors.grey,
    indicatorWeight: 3.0,
    indicatorPadding: const EdgeInsets.symmetric(horizontal: 20.0),
    onTap: onTap,
  );
  
  // 컴팩트 스타일 (좁은 공간용)
  CustomTabBar2.compact({
    super.key,
    TabController? controller,
    required List<Tab> tabs,
    Function(int)? onTap,
  }) : super(
    controller: controller,
    tabs: tabs,
    indicatorColor: Colors.black,
    labelColor: Colors.black,
    unselectedLabelColor: Colors.grey,
    indicatorWeight: 2.0,
    indicatorPadding: const EdgeInsets.symmetric(horizontal: 8.0),
    indicatorSize: TabBarIndicatorSize.label,
    onTap: onTap,
  );
  
  // 아이콘이 포함된 탭용
  CustomTabBar2.withIcons({
    super.key,
    TabController? controller,
    required List<Tab> tabs,
    Function(int)? onTap,
  }) : super(
    controller: controller,
    tabs: tabs,
    indicatorColor: Colors.black,
    labelColor: Colors.black,
    unselectedLabelColor: Colors.grey.shade600,
    indicatorWeight: 3.0,
    indicatorPadding: const EdgeInsets.symmetric(horizontal: 12.0),
    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
    onTap: onTap,
  );
  
  // 스크롤 가능한 탭 (많은 탭이 있을 때)
  CustomTabBar2.scrollable({
    super.key,
    TabController? controller,
    required List<Tab> tabs,
    Function(int)? onTap,
  }) : super(
    controller: controller,
    tabs: tabs,
    indicatorColor: Colors.black,
    labelColor: Colors.black,
    unselectedLabelColor: Colors.grey,
    indicatorWeight: 3.0,
    indicatorPadding: const EdgeInsets.symmetric(horizontal: 16.0),
    isScrollable: true,
    onTap: onTap,
  );
  
  // 둥근 모서리 스타일
  CustomTabBar2.rounded({
    super.key,
    TabController? controller,
    required List<Tab> tabs,
    Function(int)? onTap,
  }) : super(
    controller: controller,
    tabs: tabs,
    indicatorColor: Colors.transparent,
    labelColor: Colors.white,
    unselectedLabelColor: Colors.black,
    indicator: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(25.0),
    ),
    onTap: onTap,
  );
}

// 탭 아이템 빌더 헬퍼
class TabItemBuilder {
  static Tab textOnly(String text) {
    return Tab(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Text(text),
      ),
    );
  }
  
  static Tab withIcon(IconData icon, String text) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
  
  static Tab withBadge(String text, int count) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}