import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import '../utils/config.dart';
import '../utils/app_theme.dart';
import '../widgets/marquee_text.dart';
import 'package:intl/intl.dart';

class AdminPostCheck extends StatefulWidget {
  const AdminPostCheck({super.key});

  @override
  _AdminPostCheckState createState() => _AdminPostCheckState();
}

class _AdminPostCheckState extends State<AdminPostCheck>
    with SingleTickerProviderStateMixin {
  List<dynamic> posts = [];
  bool isLoading = true;
  String errorMessage = '';
  String? token;
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  // 슬라이딩 탭 관련
  TabController? _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController!.addListener(_handleTabChange);
    _loadToken().then((_) => fetchPosts());
  }

  void _handleTabChange() {
    if (_tabController!.indexIsChanging ||
        _tabController!.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController!.index;
        print('DEBUG: 탭이 변경됨 - 새 인덱스: $_currentTabIndex');
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    searchController.dispose();
    super.dispose();
  }

  // 게시글 필터링 함수
  List<dynamic> get filteredPosts {
    print('DEBUG: 현재 탭 인덱스: $_currentTabIndex');
    print('DEBUG: 전체 posts 개수: ${posts.length}');

    // 모든 posts의 status를 출력
    for (var i = 0; i < posts.length; i++) {
      print(
        'DEBUG: posts[$i] status = ${posts[i]['status']}, title = ${posts[i]['title']}',
      );
    }

    List<dynamic> filtered;
    if (_currentTabIndex == 0) {
      // 대기 탭: status가 0인 게시글만 표시
      filtered = posts.where((post) => post['status'] == 0).toList();
      print('DEBUG: 대기 탭 필터링 결과: ${filtered.length}개');
    } else {
      // 거절 탭: status가 2인 게시글만 표시
      filtered = posts.where((post) => post['status'] == 2).toList();
      print('DEBUG: 거절 탭 필터링 결과: ${filtered.length}개');
    }

    return filtered;
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('auth_token');

    if (storedToken != null && storedToken.isNotEmpty) {
      print(
        "토큰 로드 성공: ${storedToken.substring(0, math.min(20, storedToken.length))}...",
      );
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
      // API URL 구성 - 모든 게시글 조회
      String apiUrl = '${Config.serverUrl}/api/admin/posts';
      List<String> queryParams = [];

      if (startDate != null) {
        queryParams.add(
          'start_date=${DateFormat('yyyy-MM-dd').format(startDate!)}',
        );
      }

      if (endDate != null) {
        queryParams.add(
          'end_date=${DateFormat('yyyy-MM-dd').format(endDate!)}',
        );
      }

      if (searchQuery.isNotEmpty) {
        queryParams.add('search=${Uri.encodeComponent(searchQuery)}');
      }

      if (queryParams.isNotEmpty) {
        apiUrl += '?${queryParams.join('&')}';
      }

      final url = Uri.parse(apiUrl);

      print('API 요청 URL: $url');
      print(
        '요청 헤더 - Authorization: Bearer ${token?.substring(0, math.min(20, token?.length ?? 0))}...',
      );

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
        print(
          '401 인증 오류 - 토큰: ${token?.substring(0, math.min(10, token?.length ?? 0))}...',
        );
      } else {
        if (mounted) {
          setState(() {
            errorMessage =
                '게시물 목록을 불러오는데 실패했습니다: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}';
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
      initialDateRange:
          startDate != null && endDate != null
              ? DateTimeRange(start: startDate!, end: endDate!)
              : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.primaryBlue),
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

  Future<void> _showConfirmDialog(
    int postId,
    bool approve,
    String title,
  ) async {
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
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("로그인 토큰이 없어 처리할 수 없습니다.")));
      return;
    }

    try {
      final url = Uri.parse(
        '${Config.serverUrl}/api/admin/posts/$postId/approval',
      );
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
            content: Text(
              "처리 실패: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("오류 발생: $e")));
      print('approvePost Error: $e');
    }
  }

  String _getPostStatus(dynamic status) {
    // 상태값이 숫자로 전달됨: 0=대기, 1=승인/모집중, 2=거절, 3=모집마감
    int statusNum =
        status is int ? status : int.tryParse(status.toString()) ?? 0;

    switch (statusNum) {
      case 0:
        return '승인 대기';
      case 1:
        return '모집중';
      case 2:
        return '거절됨';
      case 3:
        return '모집마감';
      default:
        return '승인 대기'; // 기본값
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '승인 대기':
        return Colors.orange;
      case '모집중':
        return Colors.green;
      case '거절됨':
        return Colors.red;
      case '모집마감':
        return Colors.grey;
      default:
        return Colors.orange; // 기본값
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "헌혈 게시글 승인 관리",
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
      ),
      body:
          _tabController == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // 검색창
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: '게시글 제목, 병원명, 내용으로 검색...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.black,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.black,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        suffixIcon:
                            searchQuery.isNotEmpty
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

                  // 슬라이딩 탭
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Text('대기'),
                          ),
                        ),
                        Tab(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Text('거절'),
                          ),
                        ),
                      ],
                      indicatorColor: Colors.black,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      indicatorWeight: 3.0,
                      indicatorPadding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                      ),
                    ),
                  ),

                  // 날짜 범위 표시
                  if (startDate != null || endDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.date_range,
                              color: Colors.black,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '기간: ${startDate != null ? DateFormat('yyyy-MM-dd').format(startDate!) : '시작일 미지정'} ~ ${endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : '종료일 미지정'}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.black,
                                size: 18,
                              ),
                              onPressed: _clearDateRange,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 콘텐츠
                  Expanded(child: _buildContent()),
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
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                '오류가 발생했습니다',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.red[500]),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: fetchPosts, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }

    if (filteredPosts.isEmpty) {
      String emptyMessage =
          _currentTabIndex == 0 ? '승인 대기 중인 게시글이 없습니다.' : '거절된 게시글이 없습니다.';

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.article_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: filteredPosts.length + 1, // 헤더 포함
      itemBuilder: (context, index) {
        // 첫 번째 아이템은 헤더
        if (index == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade400, width: 2),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    '구분',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '제목',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    '등록날짜',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        // 나머지는 게시글 아이템
        final post = filteredPosts[index - 1]; // 인덱스 조정
        String postStatus = _getPostStatus(post['status']);
        String postType = post['types'] == 1 ? '긴급' : '정기';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildPostListItem(post, index - 1, postStatus, postType),
        );
      },
    );
  }

  Widget _buildPostListItem(
    Map<String, dynamic> post,
    int index,
    String postStatus,
    String postType,
  ) {
    return InkWell(
      onTap: () => _showPostDetail(post, postStatus, postType),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 14.0,
          horizontal: 0,
        ), // 패딩 증가
        margin: const EdgeInsets.symmetric(vertical: 1.0), // 마진 추가로 공간 확보
        decoration: BoxDecoration(
          color: Colors.white, // 배경색 명시
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 구분 (뱃지)
            Container(
              width: 70,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color:
                      postType == '긴급'
                          ? Colors.red.withAlpha(38)
                          : Colors.blue.withAlpha(38),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  postType,
                  style: AppTheme.bodySmallStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: postType == '긴급' ? Colors.red : Colors.blue,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // 제목
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                alignment: Alignment.centerLeft,
                child: MarqueeText(
                  text: post['title'] ?? '제목 없음',
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  animationDuration: const Duration(milliseconds: 5000),
                  pauseDuration: const Duration(milliseconds: 2000),
                ),
              ),
            ),
            // 등록날짜
            Container(
              width: 100,
              alignment: Alignment.center,
              child: Text(
                _formatDate(post['created_date'] ?? post['created_at'] ?? ''),
                style: AppTheme.bodySmallStyle.copyWith(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostDetail(
    Map<String, dynamic> post,
    String postStatus,
    String postType,
  ) {
    // 동물 종류 표시를 위한 변환
    String animalTypeKorean = '';
    if (post['animalType'] == 'dog') {
      animalTypeKorean = '강아지';
    } else if (post['animalType'] == 'cat') {
      animalTypeKorean = '고양이';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('게시글 상세정보', style: AppTheme.h3Style),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(postStatus).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      postStatus,
                      style: AppTheme.bodySmallStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(postStatus),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 기본 정보
                      _buildDetailRow(
                        context,
                        Icons.title,
                        '제목',
                        post['title'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        context,
                        Icons.business_outlined,
                        '병원명',
                        post['nickname'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        context,
                        Icons.location_on_outlined,
                        '위치',
                        post['location'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        context,
                        Icons.calendar_today_outlined,
                        '요청일',
                        post['created_date'] ?? post['created_at'] ?? 'N/A',
                      ),
                      _buildDetailRow(
                        context,
                        Icons.pets_outlined,
                        '동물 종류',
                        animalTypeKorean.isNotEmpty ? animalTypeKorean : 'N/A',
                      ),
                      _buildDetailRow(
                        context,
                        Icons.category_outlined,
                        '게시글 타입',
                        postType,
                      ),
                      if (post['blood_type'] != null &&
                          post['blood_type'].toString().isNotEmpty)
                        _buildDetailRow(
                          context,
                          Icons.bloodtype_outlined,
                          '혈액형',
                          post['blood_type'] ?? 'N/A',
                        ),
                      _buildDetailRow(
                        context,
                        Icons.group_outlined,
                        '신청자 수',
                        '${post['applicantCount'] ?? post['applicant_count'] ?? 0}명',
                      ),
                      if (post['description'] != null &&
                          post['description'].toString().isNotEmpty)
                        _buildDetailRow(
                          context,
                          Icons.description_outlined,
                          '설명',
                          post['description'] ?? 'N/A',
                        ),

                      const SizedBox(height: 24),
                      Text("헌혈 날짜 및 시간", style: AppTheme.h4Style),
                      const SizedBox(height: 12),
                      // 시간대 정보 표시 및 디버깅
                      () {
                        print('DEBUG: post 전체 데이터: $post');
                        print('DEBUG: timeRanges 데이터: ${post['timeRanges']}');
                        final timeRanges =
                            post['timeRanges'] as List<dynamic>? ?? [];
                        print('DEBUG: timeRanges 길이: ${timeRanges.length}');

                        if (timeRanges.isEmpty) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Center(
                              child: Text(
                                '헌혈 날짜 정보가 없습니다',
                                style: AppTheme.bodyLargeStyle.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        return Column(
                          children:
                              timeRanges.map<Widget>((timeRange) {
                                print('DEBUG: timeRange 개별 데이터: $timeRange');
                                final donationDate =
                                    timeRange['donation_date'] ??
                                    timeRange['time'] ??
                                    'N/A';
                                print('DEBUG: donation_date: $donationDate');

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8.0),
                                  padding: const EdgeInsets.all(12.0),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _formatDateTime(donationDate.toString()),
                                      style: AppTheme.bodyLargeStyle.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }).toList(),
                        );
                      }(),

                      // 승인/거절 버튼 (모든 게시글에 표시)
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                final postId = post['id'];
                                if (postId != null) {
                                  _showConfirmDialog(
                                    postId is int
                                        ? postId
                                        : int.tryParse(postId.toString()) ?? 0,
                                    true,
                                    post['title'] ?? '제목 없음',
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green,
                                side: BorderSide(color: Colors.green.shade300),
                                backgroundColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('승인'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                final postId = post['id'];
                                if (postId != null) {
                                  _showConfirmDialog(
                                    postId is int
                                        ? postId
                                        : int.tryParse(postId.toString()) ?? 0,
                                    false,
                                    post['title'] ?? '제목 없음',
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
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
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateTime(String dateTime) {
    try {
      if (dateTime == 'N/A' || dateTime.isEmpty) return dateTime;

      // YYYY-MM-DD HH:mm:ss 형식으로 가정
      final parts = dateTime.split(' ');
      if (parts.length >= 2) {
        final dateParts = parts[0].split('-');
        final timePart = parts[1].split(':');
        if (dateParts.length == 3 && timePart.length >= 2) {
          return '${dateParts[0]}.${dateParts[1]}.${dateParts[2]} : ${timePart[0]}:${timePart[1]}';
        }
      }

      // 단순 시간 형식 (HH:mm)
      if (dateTime.contains(':') && !dateTime.contains('-')) {
        return '시간: $dateTime';
      }

      // 파싱에 실패하면 원본 반환
      return dateTime;
    } catch (e) {
      return dateTime;
    }
  }

  String _formatDate(String dateTime) {
    try {
      if (dateTime.isEmpty) return '-';

      // YYYY-MM-DD HH:mm:ss 또는 YYYY-MM-DD 형식 처리
      final datePart = dateTime.split(' ')[0];
      final parts = datePart.split('-');

      if (parts.length == 3) {
        return '${parts[1]}.${parts[2]}'; // MM.DD 형식으로 반환
      }

      return dateTime;
    } catch (e) {
      return '-';
    }
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
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
