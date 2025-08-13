import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import '../utils/config.dart';
import '../utils/app_theme.dart';
import '../widgets/marquee_text.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
    _tabController = TabController(length: 4, vsync: this);
    _tabController!.addListener(_handleTabChange);
    _loadToken().then((_) => fetchPosts());
  }

  void _handleTabChange() {
    if (_tabController!.indexIsChanging ||
        _tabController!.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController!.index;
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
    List<dynamic> filtered;
    switch (_currentTabIndex) {
      case 0:
        // 모집대기 탭: status가 0인 게시글만 표시
        filtered = posts.where((post) => post['status'] == 0).toList();
        break;
      case 1:
        // 모집진행 탭: status가 1인 게시글만 표시
        filtered = posts.where((post) => post['status'] == 1).toList();
        break;
      case 2:
        // 모집마감 탭: status가 3인 게시글만 표시
        filtered = posts.where((post) => post['status'] == 3).toList();
        break;
      case 3:
        // 모집거절 탭: status가 2인 게시글만 표시
        filtered = posts.where((post) => post['status'] == 2).toList();
        break;
      default:
        filtered = [];
    }

    // 검색어 필터링
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((post) {
        final title = post['title']?.toString().toLowerCase() ?? '';
        final content = post['content']?.toString().toLowerCase() ?? '';
        final hospitalName = post['hospital_name']?.toString().toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();
        
        return title.contains(query) || 
               content.contains(query) || 
               hospitalName.contains(query);
      }).toList();
    }

    // 날짜 필터링
    if (startDate != null && endDate != null) {
      filtered = filtered.where((post) {
        final createdAt = DateTime.tryParse(post['created_at'] ?? '');
        if (createdAt == null) return false;
        
        return createdAt.isAfter(startDate!) && 
               createdAt.isBefore(endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    return filtered;
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('auth_token');


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


      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );


      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
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
          "헌혈 게시글 관리",
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.hourglass_empty, size: 16),
                              SizedBox(width: 4),
                              Text('모집대기', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow, size: 16),
                              SizedBox(width: 4),
                              Text('모집진행', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stop, size: 16),
                              SizedBox(width: 4),
                              Text('모집마감', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close, size: 16),
                              SizedBox(width: 4),
                              Text('모집거절', style: TextStyle(fontSize: 12)),
                            ],
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
                  width: 80,
                  child: Text(
                    '작성일',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '신청자',
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
            // 작성일
            Container(
              width: 80,
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
            // 신청자
            Container(
              width: 60,
              alignment: Alignment.center,
              child: Text(
                '${post['applicantCount'] ?? post['applicant_count'] ?? 0}',
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
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // 핸들 바
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // 헤더
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        // 게시글 타입 뱃지
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: postType == '긴급' 
                                ? Colors.red.withOpacity(0.15)
                                : Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            postType,
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: postType == '긴급' ? Colors.red : Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post['title'] ?? '제목 없음',
                                style: AppTheme.h3Style.copyWith(
                                  color: postType == '긴급' ? Colors.red : AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(height: 1),
                  
                  // 메타 정보
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 닉네임과 작성일
                        Row(
                          children: [
                            Icon(Icons.business, size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              post['hospital_nickname'] ?? post['accounts']?['nickname'] ?? post['hospital_name'] ?? '병원',
                              style: AppTheme.bodyMediumStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat('yy.MM.dd').format(DateTime.tryParse(post['created_date'] ?? post['created_at'] ?? '') ?? DateTime.now()),
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 주소
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                post['location'] ?? '주소 정보 없음',
                                style: AppTheme.bodyMediumStyle,
                              ),
                            ),
                          ],
                        ),
                        // 설명글 (있는 경우만)
                        if (post['description'] != null && post['description'].toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.veryLightGray,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.lightGray.withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              post['description'],
                              style: AppTheme.bodyMediumStyle.copyWith(
                                color: AppTheme.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // 상세 정보
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 혈액형 정보
                          if (post['blood_type'] != null && post['blood_type'].toString().isNotEmpty) ...[
                            Text('필요 혈액형', style: AppTheme.h4Style),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: postType == '긴급' ? Colors.red.shade50 : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: postType == '긴급' ? Colors.red.shade200 : Colors.blue.shade200,
                                ),
                              ),
                              child: Text(
                                post['blood_type'],
                                style: AppTheme.h3Style.copyWith(
                                  color: postType == '긴급' ? Colors.red : Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          
                          // 동물 종류
                          if (animalTypeKorean.isNotEmpty) ...[
                            _buildDetailRow(
                              context,
                              post['animalType'] == 'dog' 
                                  ? FontAwesomeIcons.dog
                                  : FontAwesomeIcons.cat,
                              '동물 종류',
                              animalTypeKorean,
                            ),
                            const SizedBox(height: 12),
                          ],
                          
                          // 신청자 수
                          _buildDetailRow(
                            context,
                            Icons.group_outlined,
                            '신청자 수',
                            '${post['applicantCount'] ?? post['applicant_count'] ?? 0}명',
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // 헌혈 예정일
                          Text("헌혈 예정일", style: AppTheme.h4Style),
                          const SizedBox(height: 12),
                          
                          // 드롭다운 형태의 날짜/시간 선택 UI
                          _buildDateTimeDropdown(post),

                          const SizedBox(height: 24),
                          
                          // 승인/거절 버튼 (대기 상태일 때만 표시)
                          if (postStatus == '승인 대기') ...[
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
                                      side: const BorderSide(color: Colors.green),
                                      backgroundColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text('승인'),
                                  ),
                                ),
                                const SizedBox(width: 12),
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
                                          false,
                                          post['title'] ?? '제목 없음',
                                        );
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      backgroundColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                ],
              ),
            );
          },
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

  // 날짜를 요일로 변환하는 함수
  String _getWeekday(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      return weekdays[date.weekday - 1];
    } catch (e) {
      return '';
    }
  }

  // 날짜를 "YYYY년 MM월 DD일 O요일" 형태로 포맷팅
  String _formatDateWithWeekday(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final weekday = _getWeekday(dateStr);
      return '${date.year}년 ${date.month}월 ${date.day}일 ${weekday}요일';
    } catch (e) {
      return dateStr;
    }
  }

  // 시간 포맷팅 메서드
  String _formatTime(String time24) {
    if (time24.isEmpty) return '시간 미정';
    
    try {
      final parts = time24.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        if (hour == 0) {
          return '오전 12:$minute';
        } else if (hour < 12) {
          return '오전 ${hour.toString().padLeft(2, '0')}:$minute';
        } else if (hour == 12) {
          return '오후 12:$minute';
        } else {
          return '오후 ${(hour - 12).toString().padLeft(2, '0')}:$minute';
        }
      }
    } catch (e) {
      return time24;
    }
    return '시간 미정';
  }

  Widget _buildDateTimeDropdown(Map<String, dynamic> post) {
    final timeRanges = post['timeRanges'] as List<dynamic>? ?? [];

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
            style: AppTheme.bodyMediumStyle.copyWith(
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // timeRanges를 날짜별로 그룹화
    final Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    
    for (final timeRange in timeRanges) {
      final dateStr = timeRange['donation_date'] ?? timeRange['date'] ?? 'N/A';
      if (!groupedByDate.containsKey(dateStr)) {
        groupedByDate[dateStr] = [];
      }
      groupedByDate[dateStr]!.add(timeRange);
    }

    return Column(
      children: groupedByDate.entries.map((entry) {
        final dateStr = entry.key;
        final timeSlots = entry.value;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              leading: Icon(
                Icons.calendar_month,
                color: Colors.black,
                size: 24,
              ),
              title: Text(
                _formatDateWithWeekday(dateStr),
                style: AppTheme.h4Style.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              trailing: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.black,
                size: 24,
              ),
              children: timeSlots.map<Widget>((timeSlot) {
                final timeStr = timeSlot['time'] ?? timeSlot['donation_time'] ?? 'N/A';
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: Colors.black,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _formatTime(timeStr),
                            style: AppTheme.bodyLargeStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      }).toList(),
    );
  }
}
