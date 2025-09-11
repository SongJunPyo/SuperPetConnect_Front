import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/config.dart';
import '../utils/app_theme.dart';
import '../widgets/marquee_text.dart';
import '../widgets/custom_tab_bar.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AdminPostCheck extends StatefulWidget {
  const AdminPostCheck({super.key});

  @override
  State createState() => _AdminPostCheckState();
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
      filtered =
          filtered.where((post) {
            final title = post['title']?.toString().toLowerCase() ?? '';
            final content = post['content']?.toString().toLowerCase() ?? '';
            final hospitalName =
                post['hospital_name']?.toString().toLowerCase() ?? '';
            final query = searchQuery.toLowerCase();

            return title.contains(query) ||
                content.contains(query) ||
                hospitalName.contains(query);
          }).toList();
    }

    // 날짜 필터링
    if (startDate != null && endDate != null) {
      filtered =
          filtered.where((post) {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(approve ? "게시글이 승인되었습니다." : "게시글이 거절되었습니다."),
              backgroundColor: approve ? Colors.green : Colors.orange,
            ),
          );
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
                '처리 실패: ${response.statusCode}\n${utf8.decode(response.bodyBytes)}';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("오류 발생: $e")));
      }
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

  // 시간대별 신청자 목록을 가져오는 메소드
  Future<List<Map<String, dynamic>>> _fetchTimeSlotApplicants(
    int postId,
    int timeSlotId,
    String date,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${Config.serverUrl}/api/admin/time-slots/$timeSlotId/applicants',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load applicants');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // 신청자 상태 업데이트 메소드
  Future<void> _updateApplicantStatus(
    int timeSlotId,
    int appliedDonationIdx,
    bool approved,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse(
          '${Config.serverUrl}/api/admin/applied-donations/$appliedDonationIdx/${approved ? "approve" : "reject"}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(approved ? '신청이 승인되었습니다.' : '신청이 거절되었습니다.'),
              backgroundColor: approved ? Colors.green : Colors.red,
            ),
          );
        }
      } else {
        throw Exception('Failed to update status');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('처리 중 오류가 발생했습니다: $e')));
      }
    }
  }

  // 신청자 상태를 '대기'로 변경하는 메소드
  Future<void> _pendApplicantStatus(int appliedDonationIdx) async {
    try {
      final response = await http.patch(
        Uri.parse(
          '${Config.serverUrl}/api/admin/applied-donations/$appliedDonationIdx/pend',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신청 상태가 \'대기\'로 변경되었습니다.'),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        String errorMessage = '상태 변경에 실패했습니다.';
        try {
          final errorData = json.decode(utf8.decode(response.bodyBytes));
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // 에러 메시지 파싱 실패 시 기본 메시지 사용
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('처리 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

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
                    child: CustomTabBar2.withIcons(
                      controller: _tabController,
                      tabs: [
                        TabItemBuilder.withIcon(Icons.hourglass_empty, '모집대기'),
                        TabItemBuilder.withIcon(Icons.play_arrow, '모집진행'),
                        TabItemBuilder.withIcon(Icons.stop, '모집마감'),
                        TabItemBuilder.withIcon(Icons.close, '모집거절'),
                      ],
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
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
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
                                color:
                                    postType == '긴급'
                                        ? Colors.red.withValues(alpha: 0.15)
                                        : Colors.blue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                postType,
                                style: AppTheme.bodySmallStyle.copyWith(
                                  color:
                                      postType == '긴급'
                                          ? Colors.red
                                          : Colors.blue,
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
                                      color:
                                          postType == '긴급'
                                              ? Colors.red
                                              : AppTheme.textPrimary,
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
                                Icon(
                                  Icons.business,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _extractHospitalName(
                                    post['title'] ?? '',
                                  ), // 제목에서 병원 이름 추출
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  DateFormat('yy.MM.dd').format(
                                    DateTime.tryParse(
                                          post['created_date'] ??
                                              post['created_at'] ??
                                              '',
                                        ) ??
                                        DateTime.now(),
                                  ),
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
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
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
                            if (post['description'] != null &&
                                post['description'].toString().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.veryLightGray,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.lightGray.withValues(alpha: 0.5),
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
                              if (post['types'] == 0 &&
                                  post['bloodType'] != null &&
                                  post['bloodType'].toString().isNotEmpty) ...[
                                Text('필요 혈액형', style: AppTheme.h4Style),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    post['bloodType'],
                                    style: AppTheme.h3Style.copyWith(
                                      color: Colors.red,
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
                              _buildDateTimeDropdown(post, setState),

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
                                                  : int.tryParse(
                                                        postId.toString(),
                                                      ) ??
                                                      0,
                                              true,
                                              post['title'] ?? '제목 없음',
                                            );
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.green,
                                          side: const BorderSide(
                                            color: Colors.green,
                                          ),
                                          backgroundColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
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
                                                  : int.tryParse(
                                                        postId.toString(),
                                                      ) ??
                                                      0,
                                              false,
                                              post['title'] ?? '제목 없음',
                                            );
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(
                                            color: Colors.red,
                                          ),
                                          backgroundColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
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
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return '연락처 없음';

    // 숫자만 추출
    String numbers = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (numbers.length != 11) return phone; // 휴대폰 번호가 아닌 경우 원본 반환

    // 000-0000-0000 형식으로 변환
    return '${numbers.substring(0, 3)}-${numbers.substring(3, 7)}-${numbers.substring(7)}';
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
      return '${date.year}년 ${date.month}월 ${date.day}일 $weekday요일';
    } catch (e) {
      return dateStr;
    }
  }

  // 시간 포맷팅 메서드
  String _formatTime(String time24) {
    if (time24.isEmpty) return '시간 미정';

    try {
      final parts = time24.split(':');
      if (parts.length >= 2) {
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

  // 제목에서 병원 이름 추출하는 메서드
  String _extractHospitalName(String title) {
    // [병원이름] 형식에서 병원 이름 추출
    final match = RegExp(r'\[(.*?)\]').firstMatch(title);
    if (match != null && match.group(1) != null) {
      return match.group(1)!;
    }
    return '병원 이름 없음';
  }

  Widget _buildDateTimeDropdown(
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) {
    final timeRanges = post['timeRanges'] as List<dynamic>? ?? [];
    final isActive = post['status'] == 1 || post['status'] == 3; // 모집 진행중이거나 마감된 게시글 모두 관리 가능

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
            style: AppTheme.bodyMediumStyle.copyWith(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // timeRanges를 날짜별로 그룹화 (중복 제거)
    final Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    final Set<String> seenTimeSlots = {}; // 중복 체크용

    for (final timeRange in timeRanges) {
      final dateStr = timeRange['donation_date'] ?? timeRange['date'] ?? 'N/A';
      final time = timeRange['time'] ?? '';
      final team = timeRange['team'] ?? 0;
      
      // 날짜+시간+팀으로 고유키 생성하여 중복 체크
      final uniqueKey = '$dateStr-$time-$team';
      
      if (!seenTimeSlots.contains(uniqueKey)) {
        seenTimeSlots.add(uniqueKey);
        if (!groupedByDate.containsKey(dateStr)) {
          groupedByDate[dateStr] = [];
        }
        groupedByDate[dateStr]!.add(timeRange);
      }
    }

    return Column(
      children:
          groupedByDate.entries.map((entry) {
            final dateStr = entry.key;
            final timeSlots = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, width: 1.5),
              ),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(
                    _formatDateWithWeekday(dateStr),
                    style: AppTheme.bodyLargeStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children:
                      timeSlots.map((timeSlot) {
                        final time = timeSlot['time'] ?? '';
                        final isSlotClosed = timeSlot['status'] == 1;

                        return InkWell(
                          onTap: isActive
                                  ? () async {
                                    await _showTimeSlotApplicants(
                                      post['id'],
                                      timeSlot['id'],
                                      dateStr,
                                      time,
                                      timeSlot['status'],
                                      post,
                                      onUpdate,
                                    );
                                  }
                                  : null, // 모집 진행 중인 게시글이면 마감된 시간대도 접근 가능
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  isSlotClosed
                                      ? Colors.grey.shade100
                                      : Colors.white,
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color:
                                      isSlotClosed ? Colors.grey : Colors.black,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTime(time),
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color:
                                        isSlotClosed
                                            ? Colors.grey
                                            : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                _buildTimeSlotStatusBadge(timeSlot['status'] ?? 0), // 기본값 0(모집중)
                                if (isActive) // 마감된 시간대도 신청자 관리 버튼 표시
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        await _showTimeSlotApplicants(
                                          post['id'],
                                          timeSlot['id'],
                                          dateStr,
                                          time,
                                          timeSlot['status'],
                                          post,
                                          onUpdate,
                                        );
                                      },
                                      icon: Icon(
                                        Icons.people_outline,
                                        size: 18,
                                        color: isSlotClosed ? Colors.grey : Colors.black, // 마감된 경우 회색으로 표시
                                      ),
                                      label: Text(
                                        '신청자 관리',
                                        style: TextStyle(
                                          color: isSlotClosed ? Colors.grey : Colors.black, // 마감된 경우 회색으로 표시
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: isSlotClosed ? Colors.grey : Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
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

  Future<void> _showTimeSlotApplicants(
    dynamic postId,
    dynamic timeSlotId,
    String date,
    String time,
    dynamic status,
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) async {
    // ID 값들을 정수형으로 변환
    final postIdInt =
        postId is int ? postId : int.tryParse(postId.toString()) ?? 0;
    final timeSlotIdInt =
        timeSlotId is int
            ? timeSlotId
            : int.tryParse(timeSlotId.toString()) ?? 0;
    final isSlotClosed = status == 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (
                BuildContext context,
                ScrollController scrollController,
              ) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '신청자 목록',
                                    style: AppTheme.h3Style.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatDateWithWeekday(date)} ${_formatTime(time)}',
                                    style: AppTheme.bodyMediumStyle.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.black,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: '닫기',
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // 신청자 목록
                      Expanded(
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: _fetchTimeSlotApplicants(
                            postIdInt,
                            timeSlotIdInt,
                            date,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  '신청자 정보를 불러오는데 실패했습니다.\n${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color: Colors.red,
                                  ),
                                ),
                              );
                            }
                            final applicants = snapshot.data ?? [];
                            if (applicants.isEmpty && isSlotClosed) {
                              return Center(
                                child: Text(
                                  '마감된 시간대입니다.',
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              );
                            }
                            if (applicants.isEmpty) {
                              return Center(
                                child: Text(
                                  '아직 신청자가 없습니다.',
                                  style: AppTheme.bodyMediumStyle.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              );
                            }
                            return Column(
                              children: [
                                Expanded(
                                  child: ListView.separated(
                                    controller: scrollController,
                                    padding: const EdgeInsets.all(16),
                                    itemCount: applicants.length,
                                    separatorBuilder:
                                        (context, index) => const Divider(),
                                    itemBuilder: (context, index) {
                                      final applicant = applicants[index];
                                      return ListTile(
                                        title: Text(
                                          '${applicant['nickname'] ?? '닉네임 없음'} (${applicant['name'] ?? '이름 없음'}) ${_formatPhoneNumber(applicant['contact'])}',
                                          style: AppTheme.bodyLargeStyle
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '반려동물: ${(applicant['pet_info'] as Map<String, dynamic>)['name'] ?? '이름 없음'} (${(applicant['pet_info'] as Map<String, dynamic>)['breed'] ?? '품종 정보 없음'})',
                                              style: AppTheme.bodySmallStyle,
                                            ),
                                            Text(
                                              '나이: ${(applicant['pet_info'] as Map<String, dynamic>)['age'] ?? '?'}세, 혈액형: ${(applicant['pet_info'] as Map<String, dynamic>)['blood_type'] ?? '정보 없음'}',
                                              style: AppTheme.bodySmallStyle,
                                            ),
                                            () {
                                              final petInfo =
                                                  applicant['pet_info']
                                                      as Map<
                                                        String,
                                                        dynamic
                                                      >? ??
                                                  {};
                                              final lastDonationDate =
                                                  petInfo['last_donation_date'];
                                              String lastDonationText;
                                              if (lastDonationDate == null ||
                                                  lastDonationDate
                                                      .toString()
                                                      .isEmpty) {
                                                lastDonationText =
                                                    '첫 헌혈을 기다리는 중';
                                              } else {
                                                lastDonationText = _formatDate(
                                                  lastDonationDate.toString(),
                                                );
                                              }
                                              return Text(
                                                '직전 헌혈일: $lastDonationText',
                                                style: AppTheme.bodySmallStyle,
                                              );
                                            }(),
                                          ],
                                        ),
                                        trailing: SizedBox(
                                          width: 150,
                                          child: ToggleButtons(
                                            isSelected: [
                                              applicant['status'] ==
                                                  1, // Approve
                                              applicant['status'] ==
                                                  0, // Pending
                                              applicant['status'] ==
                                                  2, // Reject
                                            ],
                                            onPressed: (int index) async {
                                              final appliedDonationIdx =
                                                  applicant['id'];
                                              final currentStatus =
                                                  applicant['status']; // 0: Pending, 1: Approved, 2: Rejected
                                              final targetIndex =
                                                  index; // 0: Approve, 1: Pending, 2: Reject

                                              // 승인(1) -> 거절(2)
                                              if (currentStatus == 1 &&
                                                  targetIndex == 2) {
                                                await _pendApplicantStatus(
                                                  appliedDonationIdx,
                                                );
                                                await _updateApplicantStatus(
                                                  timeSlotIdInt,
                                                  appliedDonationIdx,
                                                  false,
                                                );
                                              }
                                              // 거절(2) -> 승인(1)
                                              else if (currentStatus == 2 &&
                                                  targetIndex == 0) {
                                                await _pendApplicantStatus(
                                                  appliedDonationIdx,
                                                );
                                                await _updateApplicantStatus(
                                                  timeSlotIdInt,
                                                  appliedDonationIdx,
                                                  true,
                                                );
                                              }
                                              // 다른 모든 경우
                                              else {
                                                if (targetIndex == 1) {
                                                  // 대기
                                                  await _pendApplicantStatus(
                                                    appliedDonationIdx,
                                                  );
                                                } else {
                                                  // 승인 또는 거절
                                                  final newStatus =
                                                      targetIndex == 0;
                                                  await _updateApplicantStatus(
                                                    timeSlotIdInt,
                                                    appliedDonationIdx,
                                                    newStatus,
                                                  );
                                                }
                                              }

                                              setState(() {
                                                // 상태 변경 후 UI를 다시 그리도록 setState 호출
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(
                                              8.0,
                                            ),
                                            selectedBorderColor: Colors.black,
                                            selectedColor: Colors.white,
                                            fillColor: Colors.black,
                                            color: Colors.black,
                                            constraints: const BoxConstraints(
                                              minHeight: 32.0,
                                              minWidth: 48.0,
                                            ),
                                            children: const <Widget>[
                                              Text('승인'),
                                              Text('대기'),
                                              Text('거절'),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // 마감/마감해제 버튼 (항상 표시)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16.0,
                                    8.0,
                                    16.0,
                                    16.0,
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (!isSlotClosed) {
                                        // 마감 처리
                                        _showCloseConfirmationSheet(
                                          timeSlotIdInt,
                                          date,
                                          time,
                                          post,
                                          onUpdate,
                                        );
                                      } else {
                                        // 마감 해제 처리
                                        _showReopenConfirmationDialog(
                                          timeSlotIdInt,
                                          date,
                                          time,
                                          post,
                                          onUpdate,
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isSlotClosed ? Colors.green : Colors.black,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(
                                        double.infinity,
                                        50,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          12,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      isSlotClosed ? '마감 해제' : '마감',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Helper method to build the status badge for a time slot
  Widget _buildTimeSlotStatusBadge(dynamic status) {
    final isClosed = (status == 1);
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // 패딩 증가
      decoration: BoxDecoration(
        color: isClosed ? Colors.red : Colors.green,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isClosed ? '모집마감' : '모집진행',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1.0, // 텍스트 높이 조정
        ),
        textAlign: TextAlign.center, // 텍스트 중앙 정렬
      ),
    );
  }

  // Method to call the API to close a time slot
  Future<void> _closeTimeSlot(
    Map<String, dynamic> post,
    int timeSlotId,
    StateSetter onUpdate,
  ) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}/api/admin/time-slots/$timeSlotId/close',
      );
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // 1. 개선된 API 응답 파싱
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        final int postStatus = responseData['post_status'];
        final int postIdx = responseData['post_idx'];
        final updatedTimeSlot = responseData['updated_time_slot']; // 새로 추가된 정보

        // 2. 업데이트된 시간대 정보를 사용하여 효율적으로 상태 업데이트
        if (updatedTimeSlot != null) {
          final updatedTimeSlotId = updatedTimeSlot['post_times_idx'];
          final updatedStatus = updatedTimeSlot['status'];

          // 모달 내부 상태 업데이트
          final timeRanges = post['timeRanges'] as List<dynamic>? ?? [];
          
          // id 또는 idx 필드로 매칭 시도
          int timeSlotIndex = timeRanges.indexWhere((ts) => ts['id'] == updatedTimeSlotId);
          if (timeSlotIndex == -1) {
            timeSlotIndex = timeRanges.indexWhere((ts) => ts['idx'] == updatedTimeSlotId);
          }
          
          if (timeSlotIndex != -1) {
            onUpdate(() {
              // status 필드가 없을 수도 있으므로 추가
              timeRanges[timeSlotIndex]['status'] = updatedStatus;
            });
          } else {
            for (int i = 0; i < timeRanges.length; i++) {
            }
          }

          // 메인 화면 상태 업데이트 (전체 목록 새로고침 없이 효율적으로 처리)
          if (mounted) { // mounted 체크 추가
            setState(() {
              final mainPostIndex = posts.indexWhere((p) => p['id'] == postIdx);
              if (mainPostIndex != -1) {
                final mainTimeRanges = posts[mainPostIndex]['timeRanges'] as List<dynamic>? ?? [];
                
                // id 또는 idx 필드로 매칭 시도
                int mainTimeSlotIndex = mainTimeRanges.indexWhere((ts) => ts['id'] == updatedTimeSlotId);
                if (mainTimeSlotIndex == -1) {
                  mainTimeSlotIndex = mainTimeRanges.indexWhere((ts) => ts['idx'] == updatedTimeSlotId);
                }
                
                if (mainTimeSlotIndex != -1) {
                  mainTimeRanges[mainTimeSlotIndex]['status'] = updatedStatus;
                } else {
                }
              }
            });
          }
        } else {
        }

        // 확인 창 닫기
        if (mounted) {
          Navigator.of(context).pop();
          
          // 신청자 관리 바텀시트도 닫기
          Navigator.of(context).pop();
        }
        
        // 상세 게시글 새로고침을 위해 잠깐 닫고 다시 열기
        await _refreshAndReopenPostDetail(post, _getPostStatus(post['status']), post['types'] == 1 ? '긴급' : '정기');

        // 3. 서버에서 받은 게시글 최종 상태가 '마감'이면, 메인 목록 업데이트
        if (postStatus == 3) {
          // 응답의 postIdx를 사용하여 메인 목록에서 게시글 제거
          setState(() {
            posts.removeWhere((p) => p['id'] == postIdx);
          });
        }

        // 마감 처리 후 전체 데이터 새로고침 (신청자 수 등 최신 정보 반영)
        await Future.delayed(const Duration(milliseconds: 500)); // UI 업데이트 완료 대기
        await fetchPosts();
        
      } else {
        if (mounted) {
          Navigator.of(context).pop(); // 오류 시에도 확인 창은 닫습니다.
        }
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        if (response.statusCode == 400) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('알림'),
                content: const Text('이미 마감된 시간대입니다.'),
                actions: [
                  TextButton(
                    child: const Text('확인'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            );
          }
        } else {
          throw Exception(
            'Failed to close time slot: ${errorData['message'] ?? response.statusCode}',
          );
        }
      }
    } catch (e) {
      // 오류 발생 시 로그만 출력
    }
  }

  // Method to show the confirmation dialog for closing a time slot
  void _showCloseConfirmationSheet(
    int timeSlotId,
    String date,
    String time,
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchTimeSlotApplicants(0, timeSlotId, date).then(
            (applicants) => applicants.where((a) => a['status'] == 1).toList(),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Container(
                height: 200,
                padding: const EdgeInsets.all(20),
                child: Center(child: Text('오류: ${snapshot.error}')),
              );
            }

            final approvedApplicants = snapshot.data ?? [];
            bool isClosing = false;

            return StatefulBuilder(
              builder: (context, setState) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '마감 확인',
                        style: AppTheme.h3Style.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_formatDateWithWeekday(date)} ${_formatTime(time)}',
                        style: AppTheme.bodyLargeStyle,
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text('승인된 신청자 목록', style: AppTheme.h4Style),
                      const SizedBox(height: 8),
                      approvedApplicants.isEmpty
                          ? const Text('승인된 신청자가 없습니다.')
                          : ListView.builder(
                            shrinkWrap: true,
                            itemCount: approvedApplicants.length,
                            itemBuilder: (context, index) {
                              final applicant = approvedApplicants[index];
                              final petInfo =
                                  applicant['pet_info']
                                      as Map<String, dynamic>? ??
                                  {};
                              final lastDonationDate =
                                  petInfo['last_donation_date'];
                              String lastDonationText;
                              if (lastDonationDate == null ||
                                  lastDonationDate.toString().isEmpty) {
                                lastDonationText = '첫 헌혈';
                              } else {
                                lastDonationText = _formatDate(
                                  lastDonationDate.toString(),
                                );
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${applicant['nickname'] ?? '닉네임 없음'} (${applicant['name'] ?? '이름 없음'}) - ${_formatPhoneNumber(applicant['contact'])}',
                                        style: AppTheme.bodyLargeStyle.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      Text(
                                        '반려동물: ${petInfo['name'] ?? ''} (${petInfo['breed'] ?? ''}, ${petInfo['age'] ?? '?'}세, ${petInfo['blood_type'] ?? ''})',
                                        style: AppTheme.bodyMediumStyle,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '직전 헌혈일: $lastDonationText',
                                        style: AppTheme.bodyMediumStyle,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed:
                            isClosing
                                ? null
                                : () async {
                                  setState(() {
                                    isClosing = true;
                                  });
                                  await _closeTimeSlot(
                                    post,
                                    timeSlotId,
                                    onUpdate,
                                  );
                                  if (mounted) {
                                    setState(() {
                                      isClosing = false;
                                    });
                                  }
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child:
                            isClosing
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Text('최종 마감 확인'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // 시간대 마감 해제 확인 다이얼로그
  void _showReopenConfirmationDialog(
    int timeSlotId,
    String date,
    String time,
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '마감 해제 확인',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_formatDateWithWeekday(date)} ${_formatTime(time)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '이 시간대의 마감을 해제하시겠습니까?\n마감 해제 후 다시 신청을 받을 수 있습니다.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _reopenTimeSlot(timeSlotId, post, onUpdate);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('마감 해제'),
            ),
          ],
        );
      },
    );
  }

  // 시간대 마감 해제 API 호출
  Future<void> _reopenTimeSlot(
    int timeSlotId,
    Map<String, dynamic> post,
    StateSetter onUpdate,
  ) async {
    try {
      final url = Uri.parse(
        '${Config.serverUrl}/api/admin/time-slots/$timeSlotId/reopen',
      );
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        
        final updatedTimeSlot = responseData['updated_time_slot'];
        if (updatedTimeSlot != null) {
          final updatedTimeSlotId = updatedTimeSlot['post_times_idx'];
          final updatedStatus = updatedTimeSlot['status']; // 0: 다시 열림

          // 모달 내부 상태 업데이트
          final timeRanges = post['timeRanges'] as List<dynamic>? ?? [];
          final timeSlotIndex = timeRanges.indexWhere((ts) => ts['id'] == updatedTimeSlotId);
          if (timeSlotIndex != -1) {
            onUpdate(() {
              timeRanges[timeSlotIndex]['status'] = updatedStatus;
            });
          }

          // 메인 화면 상태 업데이트
          if (mounted) {
            setState(() {
              final mainPostIndex = posts.indexWhere((p) => p['id'] == post['id']);
              if (mainPostIndex != -1) {
                final mainTimeRanges = posts[mainPostIndex]['timeRanges'] as List<dynamic>? ?? [];
                final mainTimeSlotIndex = mainTimeRanges.indexWhere((ts) => ts['id'] == updatedTimeSlotId);
                if (mainTimeSlotIndex != -1) {
                  mainTimeRanges[mainTimeSlotIndex]['status'] = updatedStatus;
                }
              }
            });
          }
        }

        // 신청자 관리 바텀시트 닫기
        if (mounted) {
          Navigator.of(context).pop();
        }
        
        // 상세 게시글 새로고침을 위해 잠깐 닫고 다시 열기
        await _refreshAndReopenPostDetail(post, _getPostStatus(post['status']), post['types'] == 1 ? '긴급' : '정기');

        // 마감해제 처리 후 전체 데이터 새로고침 (신청자 수 등 최신 정보 반영)
        await Future.delayed(const Duration(milliseconds: 500)); // UI 업데이트 완료 대기
        await fetchPosts();
      } else {
        // 마감 해제 실패 시 로그만 출력
      }
    } catch (e) {
      // 오류 발생 시 로그만 출력
    }
  }


  // 상세 게시글을 새로고침하고 다시 여는 메서드
  Future<void> _refreshAndReopenPostDetail(Map<String, dynamic> post, String postStatus, String postType) async {
    try {
      
      // 1. 상세 게시글 모달 닫기
      Navigator.of(context).pop();
      
      // 2. 잠깐 대기 (모달 닫기 완료)
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 3. 최신 데이터 가져오기
      await fetchPosts();
      
      // 4. 업데이트된 게시글 찾기
      final postId = post['id'];
      final updatedPost = posts.firstWhere(
        (p) => p['id'] == postId,
        orElse: () => post, // 찾을 수 없으면 기존 데이터 사용
      );
      
      // 5. 업데이트된 게시글로 상세 모달 다시 열기
      _showPostDetail(updatedPost, _getPostStatus(updatedPost['status']), updatedPost['types'] == 1 ? '긴급' : '정기');
      
    } catch (e) {
      // 게시글 새로고침 실패 시 로그 출력
      debugPrint('Failed to refresh post detail: $e');
    }
  }
}
