import 'package:flutter/material.dart';

import '../models/unified_post_model.dart';
import '../services/hospital_post_service.dart';
import '../utils/app_constants.dart';
import '../utils/app_theme.dart';
import '../utils/time_format_util.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/post_list/post_list_header.dart';
import '../widgets/post_list/post_list_row.dart';
import '../widgets/state_view.dart';

/// 병원 게시글 현황의 Tab 0(모집대기) 전용 위젯.
///
/// 본인 병원의 게시글 중 `status == 0`(WAIT)만 표시. 백엔드는 단일 엔드포인트
/// (`getUnifiedPostModelsForCurrentUser`)에서 전체 status를 한 번에 반환하므로
/// 클라이언트에서 status / 검색어 / 날짜로 필터한 뒤 페이지네이션.
///
/// 부모와의 인터페이스:
/// - `searchQuery` / `startDate` / `endDate`는 props. 변경 시 1페이지로 리셋 후
///   재필터(서버 호출 X — 동일 데이터 재사용).
/// - `onTapPost(post)` — 행 탭 시 부모의 게시글 상세 시트 호출.
/// - 부모는 GlobalKey&lt;HospitalPendingPostsTabState&gt;로 [refresh]를 호출해
///   삭제/승인 등 액션 후 목록을 갱신.
class HospitalPendingPostsTab extends StatefulWidget {
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(UnifiedPostModel post) onTapPost;

  const HospitalPendingPostsTab({
    super.key,
    required this.searchQuery,
    required this.startDate,
    required this.endDate,
    required this.onTapPost,
  });

  @override
  State<HospitalPendingPostsTab> createState() =>
      HospitalPendingPostsTabState();
}

class HospitalPendingPostsTabState extends State<HospitalPendingPostsTab> {
  List<UnifiedPostModel> _allPosts = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  @override
  void didUpdateWidget(covariant HospitalPendingPostsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery ||
        widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      setState(() {
        _currentPage = 1;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> refresh() => _fetchPosts();

  Future<void> _fetchPosts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final posts =
          await HospitalPostService.getUnifiedPostModelsForCurrentUser();
      if (!mounted) return;
      setState(() {
        _allPosts = posts;
        _isLoading = false;
        _currentPage = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  bool _isInDateRange(DateTime date) {
    if (widget.startDate == null || widget.endDate == null) return true;
    final dateOnly = DateTime(date.year, date.month, date.day);
    final start = DateTime(
      widget.startDate!.year,
      widget.startDate!.month,
      widget.startDate!.day,
    );
    final end = DateTime(
      widget.endDate!.year,
      widget.endDate!.month,
      widget.endDate!.day,
    );
    return !dateOnly.isBefore(start) && !dateOnly.isAfter(end);
  }

  /// status==0 + 검색어 + 날짜 적용 후 결과.
  List<UnifiedPostModel> get _filteredPosts {
    var filtered = _allPosts.where((post) => post.status == 0).toList();

    if (widget.searchQuery.isNotEmpty) {
      final q = widget.searchQuery.toLowerCase();
      filtered =
          filtered.where((post) => post.title.toLowerCase().contains(q)).toList();
    }

    if (widget.startDate != null && widget.endDate != null) {
      filtered =
          filtered.where((post) => _isInDateRange(post.createdDate)).toList();
    }

    return filtered;
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const StateView.loading();
    }

    if (_errorMessage != null) {
      return StateView.error(message: _errorMessage!, onRetry: _fetchPosts);
    }

    final filtered = _filteredPosts;
    if (filtered.isEmpty) {
      return const StateView.empty(
        icon: Icons.post_add_outlined,
        message: '승인 대기 중인 게시글이 없습니다.',
      );
    }

    const pageSize = AppConstants.detailListPageSize;
    final totalPages = (filtered.length / pageSize).ceil();
    final safePage = _currentPage.clamp(1, totalPages > 0 ? totalPages : 1);
    final start = (safePage - 1) * pageSize;
    final end = (start + pageSize).clamp(0, filtered.length);
    final pageItems = filtered.sublist(start, end);

    final paginationBarCount = totalPages > 1 ? 1 : 0;
    final itemCount = pageItems.length;

    return RefreshIndicator(
      onRefresh: refresh,
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: itemCount + 1 + paginationBarCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const PostListHeader();
          }
          if (index > itemCount) {
            return PaginationBar(
              currentPage: safePage,
              totalPages: totalPages,
              onPageChanged: _onPageChanged,
            );
          }
          final post = pageItems[index - 1];
          return PostListRow(
            badgeType: post.isUrgent ? '긴급' : '정기',
            title: post.title,
            dateText: TimeFormatUtils.formatShortDate(post.createdDate),
            hospitalProfileImage: post.hospitalProfileImage,
            onTap: () => widget.onTapPost(post),
          );
        },
      ),
    );
  }
}
