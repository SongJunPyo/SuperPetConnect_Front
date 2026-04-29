import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/dashboard_service.dart';
import '../utils/app_constants.dart';
import '../utils/app_theme.dart';
import '../utils/time_format_util.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/post_list/post_list_header.dart';
import '../widgets/post_list/post_list_row.dart';

/// 관리자 게시글 관리의 Tab 0(모집대기) 전용 위젯.
///
/// donation_posts.status = 0(WAIT) / 5(SUSPENDED) 게시글만 다룸.
/// 서버 사이드 페이지네이션(`detailListPageSize`)을 사용하며, 검색/날짜 필터는
/// 부모로부터 props로 받음.
///
/// 부모와의 인터페이스:
/// - `searchQuery` / `startDate` / `endDate` 변경 시 didUpdateWidget이 1페이지로
///   리셋하면서 자동 refetch.
/// - `onTapPost(post)`: 게시글 행 탭 시 부모가 `_openPostDetailSheet`을 호출하도록
///   delegate. 시트 내부의 승인/거절 콜백은 부모가 그대로 보유 (시트가 부모의
///   shared 로직을 다수 의존하므로 위젯 분리 1단계에서는 그 부분을 옮기지 않음).
/// - 부모는 GlobalKey&lt;AdminPendingPostsTabState&gt;로 [refresh]를 호출해 승인/거절
///   API 성공 후 목록을 갱신.
class AdminPendingPostsTab extends StatefulWidget {
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(Map<String, dynamic> post) onTapPost;

  const AdminPendingPostsTab({
    super.key,
    required this.searchQuery,
    required this.startDate,
    required this.endDate,
    required this.onTapPost,
  });

  @override
  State<AdminPendingPostsTab> createState() => AdminPendingPostsTabState();
}

class AdminPendingPostsTabState extends State<AdminPendingPostsTab> {
  List<dynamic> posts = [];
  bool isLoading = true;
  String errorMessage = '';
  int _currentPage = 1;
  int _totalPages = 1;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  @override
  void didUpdateWidget(covariant AdminPendingPostsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery ||
        widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      _currentPage = 1;
      fetchPosts();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 외부(부모)에서 승인/거절 등 액션 후 목록 새로고침에 사용.
  Future<void> refresh() => fetchPosts();

  Future<void> fetchPosts({int? page}) async {
    final targetPage = page ?? _currentPage;
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      final result = await DashboardService.fetchAdminPostsPageRaw(
        page: targetPage,
        pageSize: AppConstants.detailListPageSize,
        status: '대기',
        search: widget.searchQuery.isNotEmpty ? widget.searchQuery : null,
        startDate: widget.startDate != null
            ? DateFormat('yyyy-MM-dd').format(widget.startDate!)
            : null,
        endDate: widget.endDate != null
            ? DateFormat('yyyy-MM-dd').format(widget.endDate!)
            : null,
      );

      if (!mounted) return;
      setState(() {
        posts = List.from(result.posts);
        isLoading = false;
        _currentPage = result.pagination.currentPage;
        _totalPages = result.pagination.totalPages;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = '오류가 발생했습니다: $e';
        isLoading = false;
      });
    }
  }

  void _onPageChanged(int page) {
    _currentPage = page;
    fetchPosts();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  /// Tab 0 전용 게시글 뱃지 라벨.
  /// SUSPENDED(5)이면 '대기', 아니면 긴급/정기.
  String _getPostType(Map<String, dynamic> post) {
    if (post['status'] == 5) return '대기';
    return post['types'] == 0 ? '긴급' : '정기';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('게시글 목록을 불러오고 있습니다...'),
          ],
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                '오류가 발생했습니다',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.red[500]),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: refresh,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.article_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                '승인 대기 중인 게시글이 없습니다.',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    final int paginationBarCount = _totalPages > 1 ? 1 : 0;
    final int postCount = posts.length;

    return RefreshIndicator(
      onRefresh: refresh,
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: postCount + 1 + paginationBarCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const PostListHeader();
          }
          if (index > postCount) {
            return PaginationBar(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onPageChanged: _onPageChanged,
            );
          }

          final post = posts[index - 1] as Map<String, dynamic>;
          return PostListRow(
            badgeType: _getPostType(post),
            title: post['title'] ?? '제목 없음',
            dateText: TimeFormatUtils.formatFlexibleShortDate(
              post['createdDate'] ??
                  post['created_date'] ??
                  post['created_at'],
            ),
            hospitalProfileImage: post['hospitalProfileImage'] ??
                post['hospital_profile_image'],
            onTap: () => widget.onTapPost(post),
          );
        },
      ),
    );
  }
}
