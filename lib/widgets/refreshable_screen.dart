import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// 모든 페이지에서 일관된 pull-to-refresh 기능을 제공하는 공통 위젯
class RefreshableScreen extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final bool enableRefresh;
  final Color? indicatorColor;
  final EdgeInsets? padding;

  const RefreshableScreen({
    super.key,
    required this.child,
    required this.onRefresh,
    this.enableRefresh = true,
    this.indicatorColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableRefresh) {
      return child;
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: indicatorColor ?? AppTheme.primaryBlue,
      backgroundColor: Colors.white,
      displacement: 50.0, // 표시기가 나타나는 거리
      strokeWidth: 3.0,   // 표시기 두께
      child: _buildScrollableChild(context),
    );
  }

  /// child 위젯을 스크롤 가능하게 만들어 RefreshIndicator가 작동하도록 함
  Widget _buildScrollableChild(BuildContext context) {
    // child가 이미 스크롤 가능한 위젯인지 확인
    if (child is ScrollView ||
        child is ListView ||
        child is GridView ||
        child is SingleChildScrollView ||
        child is PageView ||
        child is TabBarView) {
      return child;
    }

    // 스크롤 불가능한 위젯인 경우 ListView로 감싸기
    return ListView(
      padding: padding,
      physics: const AlwaysScrollableScrollPhysics(), // 항상 스크롤 가능
      children: [
        Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - 200,
          ),
          child: child,
        ),
      ],
    );
  }
}

/// TabBar가 있는 페이지를 위한 특별한 RefreshableScreen
class RefreshableTabScreen extends StatelessWidget {
  final TabController tabController;
  final List<Tab> tabs;
  final List<Widget> children;
  final Future<void> Function() onRefresh;
  final Color? indicatorColor;
  final Widget? appBar;

  const RefreshableTabScreen({
    super.key,
    required this.tabController,
    required this.tabs,
    required this.children,
    required this.onRefresh,
    this.indicatorColor,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (appBar != null) appBar!,
        // 탭바
        TabBar(
          controller: tabController,
          tabs: tabs,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryBlue,
          dividerColor: Colors.transparent,
        ),
        // 탭 내용들 (각각 RefreshIndicator로 감쌈)
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: children.map((child) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                color: indicatorColor ?? AppTheme.primaryBlue,
                backgroundColor: Colors.white,
                displacement: 50.0,
                strokeWidth: 3.0,
                child: _makeScrollable(context, child),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 위젯을 스크롤 가능하게 만드는 헬퍼 메서드
  Widget _makeScrollable(BuildContext context, Widget child) {
    if (child is ScrollView ||
        child is ListView ||
        child is GridView ||
        child is SingleChildScrollView) {
      return child;
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - 300,
          ),
          child: child,
        ),
      ],
    );
  }
}