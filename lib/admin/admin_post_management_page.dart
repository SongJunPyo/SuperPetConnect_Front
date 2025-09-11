import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/config.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../services/dashboard_service.dart';

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
  State<AdminPostManagementPage> createState() => _AdminPostManagementPageState();
}

class _AdminPostManagementPageState extends State<AdminPostManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<DonationPost> _pendingPosts = [];
  List<DonationPost> _approvedPosts = [];
  List<DonationPost> _rejectedPosts = [];
  List<DonationPost> _completedPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
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
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }

      // 병렬로 데이터 로드
      final futures = await Future.wait([
        _fetchPostsByStatus('pending', token),
        _fetchPostsByStatus('approved', token),
        _fetchPostsByStatus('rejected', token),
        _fetchPostsByStatus('completed', token),
      ]);

      setState(() {
        _pendingPosts = futures[0];
        _approvedPosts = futures[1];
        _rejectedPosts = futures[2];
        _completedPosts = futures[3];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<DonationPost>> _fetchPostsByStatus(String status, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${Config.serverUrl}/api/admin/posts?status=$status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['posts'] != null) {
          return (data['posts'] as List)
              .map((post) => DonationPost.fromJson(post))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> _approvePost(int postIdx) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) throw Exception('인증 토큰이 없습니다.');

      final response = await http.put(
        Uri.parse('${Config.serverUrl}/api/admin/posts/$postIdx/approval'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': 'approved'}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('게시글이 승인되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
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

  Future<void> _rejectPost(int postIdx) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) throw Exception('인증 토큰이 없습니다.');

      final response = await http.put(
        Uri.parse('${Config.serverUrl}/api/admin/posts/$postIdx/approval'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': 'rejected'}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('게시글이 거절되었습니다.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
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
                Tab(text: '승인됨 (${_approvedPosts.length})'),
                Tab(text: '승인 대기 (${_pendingPosts.length})'),
                Tab(text: '거절됨 (${_rejectedPosts.length})'),
                Tab(text: '헌혈완료 (${_completedPosts.length})'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPostList(_approvedPosts, 'approved'),
                      _buildPostList(_pendingPosts, 'pending'),
                      _buildPostList(_rejectedPosts, 'rejected'),
                      _buildPostList(_completedPosts, 'completed'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostList(List<DonationPost> posts, String status) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppTheme.textTertiary,
            ),
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

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final isHighlighted = widget.highlightPostId != null &&
              post.postIdx.toString() == widget.highlightPostId;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: isHighlighted
                  ? Border.all(color: AppTheme.primaryBlue, width: 2)
                  : null,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isHighlighted
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
              color: isHighlighted ? AppTheme.lightBlue.withValues(alpha: 0.1) : null,
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
                              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
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
                              onPressed: () => _approvePost(post.postIdx),
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
                              onPressed: () => _rejectPost(post.postIdx),
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