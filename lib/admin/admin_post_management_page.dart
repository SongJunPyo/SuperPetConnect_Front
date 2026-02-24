import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import '../utils/config.dart';
import '../services/auth_http_client.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';
import '../widgets/app_app_bar.dart';
import '../models/unified_post_model.dart';
import '../services/dashboard_service.dart';
import '../widgets/pagination_bar.dart';

class AdminPostManagementPage extends StatefulWidget {
  final String? postId;
  final String? initialTab;
  final String? highlightPostId;

  const AdminPostManagementPage({
    super.key,
    this.postId,
    this.initialTab,
    this.highlightPostId,
  });

  @override
  State<AdminPostManagementPage> createState() =>
      _AdminPostManagementPageState();
}

class _AdminPostManagementPageState extends State<AdminPostManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // 탭별 status 키
  static const List<String> _statusKeys = ['approved', 'pending', 'rejected', 'completed'];

  // 탭별 독립 페이지네이션 상태
  final Map<String, List<UnifiedPostModel>> _postsByStatus = {};
  final Map<String, int> _pageByStatus = {};
  final Map<String, int> _totalPagesByStatus = {};
  final Map<String, ScrollController> _scrollControllerByStatus = {};

  @override
  void initState() {
    super.initState();

    // 페이징 상태 초기화
    for (final key in _statusKeys) {
      _postsByStatus[key] = [];
      _pageByStatus[key] = 1;
      _totalPagesByStatus[key] = 1;
      _scrollControllerByStatus[key] = ScrollController();
    }

    // 초기 탭 설정
    int initialTabIndex = 0;
    if (widget.initialTab == 'approved') {
      initialTabIndex = 0;
    } else if (widget.initialTab == 'pending_approval') {
      initialTabIndex = 1;
    } else if (widget.initialTab == 'rejected') {
      initialTabIndex = 2;
    } else if (widget.initialTab == 'completed') {
      initialTabIndex = 3;
    }

    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialTabIndex,
    );

    _loadPosts();
  }

  @override
  void dispose() {
    for (final controller in _scrollControllerByStatus.values) {
      controller.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    // 모든 탭 상태 초기화
    for (final key in _statusKeys) {
      _postsByStatus[key] = [];
      _pageByStatus[key] = 1;
      _totalPagesByStatus[key] = 1;
    }

    try {
      // 병렬로 첫 페이지 로드
      await Future.wait(
        _statusKeys.map((status) => _fetchPosts(status, page: 1, isInitial: true)),
      );
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPosts(String status, {int page = 1, bool isInitial = false}) async {
    try {
      final response = await DashboardService.fetchAdminPostsPage(
        page: page,
        pageSize: AppConstants.detailListPageSize,
        status: status,
      );

      final pagination = response.pagination;

      if (mounted) {
        setState(() {
          _postsByStatus[status] = response.posts;
          _pageByStatus[status] = pagination.currentPage;
          _totalPagesByStatus[status] = pagination.totalPages;
        });

        // 스크롤 맨 위로 (초기 로드가 아닌 경우)
        if (!isInitial) {
          final controller = _scrollControllerByStatus[status];
          if (controller != null && controller.hasClients) {
            controller.jumpTo(0);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _postsByStatus[status] = _postsByStatus[status] ?? [];
        });
      }
    }
  }

  void _showApproveBottomSheet(UnifiedPostModel post) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 핸들바
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 제목
                Text(
                  '게시글 승인',
                  style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // 내용
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGray.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: AppTheme.bodyLargeStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '병원: ${post.hospitalName}',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  '이 게시글을 승인하시겠습니까?',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // 버튼들
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: BorderSide(color: AppTheme.lightGray),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _approvePost(post.id);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('승인'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _approvePost(int postIdx) async {
    try {
      final response = await AuthHttpClient.put(
        Uri.parse('${Config.serverUrl}/api/admin/posts/$postIdx/approval'),
        body: jsonEncode({'status': 'approved'}),
      );

      if (response.statusCode == 200) {
        _loadPosts(); // 목록 새로고침
      } else {
        throw Exception('승인 처리 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('승인 처리 중 오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRejectBottomSheet(UnifiedPostModel post) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 핸들바
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 제목
                Text(
                  '게시글 거절',
                  style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // 내용
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGray.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: AppTheme.bodyLargeStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '병원: ${post.hospitalName}',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  '이 게시글을 거절하시겠습니까?',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // 버튼들
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: BorderSide(color: AppTheme.lightGray),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _rejectPost(post.id);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('거절'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _rejectPost(int postIdx) async {
    try {
      final response = await AuthHttpClient.put(
        Uri.parse('${Config.serverUrl}/api/admin/posts/$postIdx/approval'),
        body: jsonEncode({'status': 'rejected'}),
      );

      if (response.statusCode == 200) {
        _loadPosts(); // 목록 새로고침
      } else {
        throw Exception('거절 처리 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('거절 처리 중 오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppSimpleAppBar(
        title: '헌혈 게시글 관리',
        onBackPressed: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryBlue,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primaryBlue,
              tabs: [
                Tab(text: '승인됨 (${(_postsByStatus['approved'] ?? []).length})'),
                Tab(text: '승인 대기 (${(_postsByStatus['pending'] ?? []).length})'),
                Tab(text: '거절됨 (${(_postsByStatus['rejected'] ?? []).length})'),
                Tab(text: '헌혈완료 (${(_postsByStatus['completed'] ?? []).length})'),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPostList('approved'),
                        _buildPostList('pending'),
                        _buildPostList('rejected'),
                        _buildPostList('completed'),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostList(String status) {
    final posts = _postsByStatus[status] ?? [];

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(
              '${_getStatusText(status)} 게시글이 없습니다.',
              style: AppTheme.bodyLargeStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final currentPage = _pageByStatus[status] ?? 1;
    final totalPages = _totalPagesByStatus[status] ?? 1;

    return RefreshIndicator(
      onRefresh: () => _fetchPosts(status, page: 1),
      child: ListView.builder(
        controller: _scrollControllerByStatus[status],
        padding: const EdgeInsets.all(16),
        itemCount: posts.length + 1,
        itemBuilder: (context, index) {
          if (index >= posts.length) {
            // 마지막: PaginationBar
            return PaginationBar(
              currentPage: currentPage,
              totalPages: totalPages,
              onPageChanged: (page) {
                _fetchPosts(status, page: page);
              },
            );
          }

          final post = posts[index];
          final isHighlighted =
              widget.highlightPostId != null &&
              post.id.toString() == widget.highlightPostId;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border:
                  isHighlighted
                      ? Border.all(color: AppTheme.primaryBlue, width: 2)
                      : null,
              borderRadius: BorderRadius.circular(12),
              boxShadow:
                  isHighlighted
                      ? [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                      : null,
            ),
            child: Card(
              color:
                  isHighlighted
                      ? AppTheme.lightBlue.withValues(alpha: 0.1)
                      : null,
              elevation: isHighlighted ? 4 : 1,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 게시글 제목과 상태
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            post.title,
                            style: AppTheme.h4Style.copyWith(
                              fontWeight:
                                  isHighlighted
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildStatusChip(status),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 병원 정보
                    Row(
                      children: [
                        Icon(
                          Icons.local_hospital_outlined,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '병원: ${post.hospitalName}',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 게시글 정보
                    Row(
                      children: [
                        Icon(
                          Icons.pets_outlined,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_getAnimalTypeText(post.animalType)} • ${_getPostTypeText(post.types)}',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 작성일
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '작성일: ${DateFormat('yyyy.MM.dd HH:mm').format(post.createdAt)}',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    // 승인 대기 상태인 경우 승인/거절 버튼 표시
                    if (status == 'pending') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _showApproveBottomSheet(post),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.success,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('승인'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _showRejectBottomSheet(post),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.error,
                                side: BorderSide(color: AppTheme.error),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('거절'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'approved':
        color = AppTheme.success;
        text = '승인됨';
        break;
      case 'pending':
        color = AppTheme.warning;
        text = '승인 대기';
        break;
      case 'rejected':
        color = AppTheme.error;
        text = '거절됨';
        break;
      case 'completed':
        color = Colors.purple;
        text = '헌혈완료';
        break;
      default:
        color = AppTheme.textSecondary;
        text = '알 수 없음';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: AppTheme.bodySmallStyle.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved':
        return '승인된';
      case 'pending':
        return '승인 대기 중인';
      case 'rejected':
        return '거절된';
      case 'completed':
        return '헌혈 완료된';
      default:
        return '알 수 없는';
    }
  }

  String _getAnimalTypeText(int animalType) {
    switch (animalType) {
      case 0:
        return '강아지';
      case 1:
        return '고양이';
      default:
        return '기타';
    }
  }

  String _getPostTypeText(int types) {
    switch (types) {
      case 0:
        return '긴급';
      case 1:
        return '정기';
      default:
        return '일반';
    }
  }
}
