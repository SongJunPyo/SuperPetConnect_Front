import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import '../utils/config.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';

class AdminPostCheck extends StatefulWidget {
  const AdminPostCheck({super.key});

  @override
  _AdminPostCheckState createState() => _AdminPostCheckState();
}

class _AdminPostCheckState extends State<AdminPostCheck> with TickerProviderStateMixin {
  List<dynamic> posts = [];
  bool isLoading = true;
  String errorMessage = '';
  String? token;
  String? statusFilter; // null = 전체, 'wait_to_approved' = 공개안함, 'approved' = 공개
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  late TabController _tabController;
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    // 초기 필터 설정: 0번 탭 = 전체 (null)
    statusFilter = null;
    _loadToken().then((_) => fetchPosts());
  }

  @override
  void dispose() {
    searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {
      // 0: 전체 (null), 1: 공개안함 (wait_to_approved), 2: 공개 (approved)
      if (_tabController.index == 0) {
        statusFilter = null;
      } else if (_tabController.index == 1) {
        statusFilter = 'wait_to_approved';
      } else {
        statusFilter = 'approved';
      }
    });
    fetchPosts();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('auth_token');
    
    if (storedToken != null && storedToken.isNotEmpty) {
      print("토큰 로드 성공: ${storedToken.substring(0, math.min(20, storedToken.length))}...");
      print("토큰 길이: ${storedToken.length}");
    } else {
      print("토큰이 없거나 비어있음");
      print("저장된 사용자 이메일: ${prefs.getString('user_email') ?? '없음'}");
      print("저장된 사용자 이름: ${prefs.getString('user_name') ?? '없음'}");
    }
    
    setState(() {
      token = storedToken;
    });
  }

  Future<void> fetchPosts() async {
    if (token == null || token!.isEmpty) {
      setState(() {
        errorMessage = '로그인이 필요합니다. (토큰 없음)';
        isLoading = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    try {
      // 상태에 따른 URL 구성
      String apiUrl = '${Config.serverUrl}/api/admin/posts';
      List<String> queryParams = [];
      
      if (statusFilter != null) {
        queryParams.add('status=$statusFilter');
      }
      
      if (startDate != null) {
        queryParams.add('start_date=${DateFormat('yyyy-MM-dd').format(startDate!)}');
      }
      
      if (endDate != null) {
        queryParams.add('end_date=${DateFormat('yyyy-MM-dd').format(endDate!)}');
      }
      
      if (searchQuery.isNotEmpty) {
        queryParams.add('search=${Uri.encodeComponent(searchQuery)}');
      }
      
      if (queryParams.isNotEmpty) {
        apiUrl += '?${queryParams.join('&')}';
      }
      
      final url = Uri.parse(apiUrl);
      
      print('API 요청 URL: $url');
      print('요청 헤더 - Authorization: Bearer ${token?.substring(0, math.min(20, token?.length ?? 0))}...');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('API 응답 상태: ${response.statusCode}');
      print('API 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('게시글 목록 조회 성공: ${data.length}개의 게시글');
        if (mounted) {
          setState(() {
            posts = data is List ? data : [];
            isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          setState(() {
            errorMessage = '인증이 만료되었습니다. 다시 로그인해주세요.';
            isLoading = false;
          });
        }
        print('401 인증 오류 - 토큰: ${token?.substring(0, math.min(10, token?.length ?? 0))}...');
      } else {
        if (mounted) {
          setState(() {
            errorMessage = '게시물 목록을 불러오는데 실패했습니다: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = '오류가 발생했습니다: $e';
          isLoading = false;
        });
      }
      print('fetchPosts Error: $e');
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });
    fetchPosts();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      fetchPosts();
    }
  }

  void _clearDateRange() {
    setState(() {
      startDate = null;
      endDate = null;
    });
    fetchPosts();
  }

  Future<void> _showConfirmDialog(int postId, bool approve, String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            approve ? '게시글 승인' : '게시글 거절',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: approve ? Colors.green : Colors.red,
            ),
          ),
          content: Text(
            '정말로 "$title" 게시글을 ${approve ? '승인' : '거절'}하시겠습니까?',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: approve ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(approve ? '승인' : '거절'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      approvePost(postId, approve);
    }
  }

  Future<void> approvePost(int postId, bool approve) async {
    if (token == null || token!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("로그인 토큰이 없어 처리할 수 없습니다."))
      );
      return;
    }

    try {
      final url = Uri.parse('${Config.serverUrl}/api/admin/posts/$postId/approval');
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'approved': approve}),
      );

      print('승인 API 응답 상태: ${response.statusCode}');
      print('승인 API 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        fetchPosts();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? "게시글이 승인되었습니다." : "게시글이 거절되었습니다."),
            backgroundColor: approve ? Colors.green : Colors.orange,
          ),
        );
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("인증이 만료되었습니다. 다시 로그인해주세요."),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("처리 실패: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("오류 발생: $e"))
      );
      print('approvePost Error: $e');
    }
  }

  String _getPostStatus(String? status) {
    switch (status) {
      case 'wait_to_approved':
      case '대기':
        return '승인 대기';
      case 'approved':
      case '승인':
        return '승인 완료';
      case '거절':
        return '거절됨';
      case '모집중':
        return '모집중';
      case '모집마감':
        return '모집마감';
      default:
        return '알 수 없음';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '승인 완료':
        return Colors.green;
      case '승인 대기':
        return Colors.orange;
      case '거절됨':
        return Colors.red;
      case '모집중':
        return Colors.blue;
      case '모집마감':
        return Colors.grey;
      case '대기':
        return Colors.orange;
      case '거절':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "게시물 승인 관리",
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: '날짜 범위 선택',
          ),
          if (startDate != null || endDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearDateRange,
              tooltip: '날짜 범위 초기화',
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Colors.black87),
            tooltip: '새로고침',
            onPressed: fetchPosts,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt, size: 20),
                  SizedBox(width: 8),
                  Text('전체'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pending_actions, size: 20),
                  SizedBox(width: 8),
                  Text('공개안함'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 20),
                  SizedBox(width: 8),
                  Text('공개'),
                ],
              ),
            ),
          ],
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryBlue,
        ),
      ),
      body: Column(
        children: [
          // 검색창
          Container(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '게시글 제목, 병원명, 내용으로 검색...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryBlue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          
          // 날짜 범위 표시
          if (startDate != null || endDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: AppTheme.primaryBlue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '기간: ${startDate != null ? DateFormat('yyyy-MM-dd').format(startDate!) : '시작일 미지정'} ~ ${endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : '종료일 미지정'}',
                        style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.primaryBlue, size: 18),
                      onPressed: _clearDateRange,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          
          // 콘텐츠
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
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
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                '오류가 발생했습니다',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.red[500],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: fetchPosts,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (posts.isEmpty) {
      String emptyMessage = statusFilter == null 
          ? '게시글이 없습니다.'
          : statusFilter == 'approved'
              ? '승인된 게시글이 없습니다.'
              : '승인 대기 중인 게시글이 없습니다.';
              
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.article_outlined,
                size: 64,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        print('🚨 디버그: 게시글 데이터 - ${post.toString()}');
        String postStatus = _getPostStatus(post['status']);
        
        // 동물 종류 표시를 위한 변환
        String animalTypeKorean = '';
        if (post['animalType'] == 'dog') {
          animalTypeKorean = '강아지';
        } else if (post['animalType'] == 'cat') {
          animalTypeKorean = '고양이';
        }
        
        // 게시글 타입 표시를 위한 변환
        String postType = post['types'] == 1 ? '긴급' : '정기';

        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 게시물 번호와 기본 정보
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withAlpha(38),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        post['title'] ?? '제목 없음',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: _getStatusColor(postStatus).withAlpha(38),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        postStatus,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(postStatus),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 기타 상세 정보
                _buildDetailRow(context, Icons.business_outlined, '병원명', post['hospital_name'] ?? 'N/A'),
                _buildDetailRow(context, Icons.location_on_outlined, '위치', post['location'] ?? 'N/A'),
                _buildDetailRow(context, Icons.calendar_today_outlined, '요청일', post['created_at'] ?? 'N/A'),
                _buildDetailRow(context, Icons.pets_outlined, '동물 종류', animalTypeKorean.isNotEmpty ? animalTypeKorean : 'N/A'),
                _buildDetailRow(context, Icons.category_outlined, '게시글 타입', postType),
                if (post['blood_type'] != null && post['blood_type'].toString().isNotEmpty)
                  _buildDetailRow(context, Icons.bloodtype_outlined, '혈액형', post['blood_type'] ?? 'N/A'),
                _buildDetailRow(context, Icons.group_outlined, '신청자 수', '${post['applicant_count'] ?? 0}명'),
                if (post['description'] != null && post['description'].toString().isNotEmpty)
                  _buildDetailRow(context, Icons.description_outlined, '설명', post['description'] ?? 'N/A'),

                const SizedBox(height: 24),
                Text(
                  "시간대 정보",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                // 시간대 정보 표시
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List<Widget>.from(
                    (post['timeRanges'] as List<dynamic>? ?? []).map((timeRange) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "시간: ${timeRange['time'] ?? 'N/A'}",
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "필요 팀 수: ${timeRange['team'] ?? 'N/A'}팀",
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                
                // 게시글 승인/거절 버튼 (대기 중인 게시글만 표시)
                if (post['status'] == 'wait_to_approved' || post['status'] == '대기') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final postId = post['id'];
                            if (postId != null) {
                              _showConfirmDialog(
                                postId is int ? postId : int.tryParse(postId.toString()) ?? 0,
                                true,
                                post['title'] ?? '제목 없음'
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('게시글 ID가 올바르지 않습니다.')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            "게시글 승인",
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final postId = post['id'];
                            if (postId != null) {
                              _showConfirmDialog(
                                postId is int ? postId : int.tryParse(postId.toString()) ?? 0,
                                false,
                                post['title'] ?? '제목 없음'
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('게시글 ID가 올바르지 않습니다.')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            "게시글 거절",
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}