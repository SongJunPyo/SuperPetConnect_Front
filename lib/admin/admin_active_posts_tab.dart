import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_http_client.dart';
import '../utils/app_constants.dart';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../utils/time_format_util.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/post_list/post_list_header.dart';
import '../widgets/post_list/post_list_row.dart';

/// 관리자 게시글 관리의 Tab 1(헌혈모집) 전용 위젯.
///
/// 백엔드 `/api/admin/posts?status=모집중`으로 donation_posts.status IN (1, 3)
/// 게시글을 fetch — 서버에서 search/start_date/end_date를 query로 적용해 받은 뒤
/// 클라이언트에서 다시 한 번 검색/날짜 필터를 거치고(기존 동작 호환) 페이지네이션.
/// page_size=100 고정이라 100건 초과 시점에는 추후 서버 페이지네이션 도입 필요.
///
/// 부모와의 인터페이스:
/// - `searchQuery` / `startDate` / `endDate`는 props. 변경 시 1페이지로 리셋 후
///   refetch (서버 필터가 달라지므로 didUpdateWidget이 fetch까지 트리거).
/// - `onTapPost(post)` — 행 탭 시 부모의 `_openPostDetailSheet`로 위임. 시트 안의
///   시간대 마감 / 재오픈 / 신청자 관리 등은 부모가 보유한 shared 로직 그대로.
/// - 부모는 GlobalKey&lt;AdminActivePostsTabState&gt;로 [refresh]를 호출해
///   시간대 마감 / 게시글 재오픈 / 대기 변경 / 삭제 후 목록을 갱신.
class AdminActivePostsTab extends StatefulWidget {
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(Map<String, dynamic> post) onTapPost;

  const AdminActivePostsTab({
    super.key,
    required this.searchQuery,
    required this.startDate,
    required this.endDate,
    required this.onTapPost,
  });

  @override
  State<AdminActivePostsTab> createState() => AdminActivePostsTabState();
}

class AdminActivePostsTabState extends State<AdminActivePostsTab> {
  /// 서버에서 받은 게시글 전체. 검색/날짜는 [filteredPosts]에서 한 번 더 필터.
  List<dynamic> _allPosts = [];
  bool isLoading = true;
  String errorMessage = '';

  int _currentPage = 1;
  int _totalPages = 1;

  final ScrollController _scrollController = ScrollController();

  /// 부모가 알림 진입(initialPostIdx) 시 단건 매칭에 쓰는 read-only 접근자.
  /// 검색/날짜 필터를 거치지 않은 raw fetched 리스트.
  List<dynamic> get allPosts => _allPosts;

  @override
  void initState() {
    super.initState();
    _fetchAppliedDonations();
  }

  @override
  void didUpdateWidget(covariant AdminActivePostsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery ||
        widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      _currentPage = 1;
      _fetchAppliedDonations();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> refresh() => _fetchAppliedDonations();

  Future<void> _fetchAppliedDonations() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      final queryParams = <String>['status=모집중', 'page_size=100'];
      if (widget.startDate != null) {
        queryParams.add(
          'start_date=${DateFormat('yyyy-MM-dd').format(widget.startDate!)}',
        );
      }
      if (widget.endDate != null) {
        queryParams.add(
          'end_date=${DateFormat('yyyy-MM-dd').format(widget.endDate!)}',
        );
      }
      if (widget.searchQuery.isNotEmpty) {
        queryParams.add('search=${Uri.encodeComponent(widget.searchQuery)}');
      }

      final apiUrl =
          '${Config.serverUrl}/api/admin/posts?${queryParams.join('&')}';
      final response = await AuthHttpClient.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> fetched;
        if (data is Map) {
          fetched = (data['items'] ?? data['posts'] ?? []) as List;
        } else if (data is List) {
          fetched = data;
        } else {
          fetched = [];
        }

        if (!mounted) return;
        setState(() {
          _allPosts = fetched;
          isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          errorMessage = '헌혈모집 목록을 불러오는데 실패했습니다: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = '오류가 발생했습니다: $e';
        isLoading = false;
      });
    }
  }

  /// 검색/날짜 클라이언트 측 필터(서버 필터와 이중 적용 — 기존 동작 보존) +
  /// 클라이언트 페이지네이션.
  List<dynamic> get filteredPosts {
    var filtered = _allPosts;

    if (widget.searchQuery.isNotEmpty) {
      final query = widget.searchQuery.toLowerCase();
      filtered = filtered.where((post) {
        final title = post['title']?.toString().toLowerCase() ?? '';
        final content = post['content']?.toString().toLowerCase() ?? '';
        final hospitalName =
            post['hospital_name']?.toString().toLowerCase() ?? '';
        return title.contains(query) ||
            content.contains(query) ||
            hospitalName.contains(query);
      }).toList();
    }

    if (widget.startDate != null && widget.endDate != null) {
      filtered = filtered.where((post) {
        final createdAt = DateTime.tryParse(post['created_at'] ?? '');
        if (createdAt == null) return false;
        return createdAt.isAfter(widget.startDate!) &&
            createdAt.isBefore(widget.endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    const pageSize = AppConstants.detailListPageSize;
    _totalPages = filtered.isEmpty ? 1 : (filtered.length / pageSize).ceil();
    if (_currentPage > _totalPages) _currentPage = _totalPages;

    final startIndex = (_currentPage - 1) * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  /// Tab 1 전용 게시글 뱃지 라벨.
  /// CLOSED(3)이면 '마감', 아니면 긴급/정기 (PostType 미러).
  String _getPostType(Map<String, dynamic> post) {
    if (post['status'] == 3) return '마감';
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
            Text('헌혈모집 목록을 불러오고 있습니다...'),
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

    final posts = filteredPosts;
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
                '헌혈 모집 게시글이 없습니다.',
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

    final paginationBarCount = _totalPages > 1 ? 1 : 0;
    final postCount = posts.length;

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
