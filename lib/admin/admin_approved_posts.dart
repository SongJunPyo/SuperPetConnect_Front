import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/config.dart';
import '../services/auth_http_client.dart';
import '../utils/app_theme.dart';
import '../widgets/marquee_text.dart';
import '../widgets/rich_text_viewer.dart';
import 'package:intl/intl.dart';

class AdminApprovedPostsScreen extends StatefulWidget {
  const AdminApprovedPostsScreen({super.key});

  @override
  State<AdminApprovedPostsScreen> createState() =>
      _AdminApprovedPostsScreenState();
}

class _AdminApprovedPostsScreenState extends State<AdminApprovedPostsScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> posts = [];
  bool isLoading = true;
  String errorMessage = '';
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
    fetchPosts();
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
    if (_currentTabIndex == 0) {
      // 모집진행 탭: status가 1인 게시글만 표시
      filtered = posts.where((post) => post['status'] == 1).toList();
    } else {
      // 모집마감 탭: status가 3인 게시글만 표시
      filtered = posts.where((post) => post['status'] == 3).toList();
    }

    return filtered;
  }

  Future<void> fetchPosts() async {
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


      final response = await AuthHttpClient.get(url);


      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            posts = data is List ? data : [];
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

  void _showApplicantList(int? postTimesIdx, String donationDateTime) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('신청자 목록', style: AppTheme.h3Style),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              // 날짜 시간 정보
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '헌혈 일시: ${_formatDateTime(donationDateTime)}',
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 신청자 목록
              Expanded(
                child:
                    postTimesIdx == null
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '시간대 ID가 없어 신청자 목록을 불러올 수 없습니다.',
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                        : FutureBuilder<List<dynamic>>(
                          future: _fetchApplicants(postTimesIdx),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 64,
                                      color: Colors.red[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '신청자 목록을 불러오는데 실패했습니다.\n${snapshot.error}',
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        color: Colors.red[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            }

                            final applicants = snapshot.data ?? [];

                            if (applicants.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '아직 신청한 사용자가 없습니다.',
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: applicants.length,
                              itemBuilder: (context, index) {
                                final applicant = applicants[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8.0),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.primaryBlue
                                          .withValues(alpha: 0.1),
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: AppTheme.primaryBlue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      applicant['user_name'] ?? '이름 없음',
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '반려동물: ${applicant['pet_name'] ?? 'N/A'}',
                                        ),
                                        Text(
                                          '연락처: ${applicant['phone'] ?? 'N/A'}',
                                        ),
                                      ],
                                    ),
                                    trailing: Icon(
                                      Icons.pets,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<dynamic>> _fetchApplicants(int postTimesIdx) async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse(
          '${Config.serverUrl}/api/applied_donation/time-slot/$postTimesIdx/applications',
        ),
      );


      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        // 새로운 API 응답 구조에 맞게 수정 - applications 배열 반환
        if (data is Map && data.containsKey('applications')) {
          return data['applications'] is List ? data['applications'] : [];
        }
        return [];
      } else if (response.statusCode == 404) {
        throw Exception('해당 시간대에 신청자가 없습니다.');
      } else {
        throw Exception('API 오류: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('신청자 목록을 불러올 수 없습니다: $e');
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

  String _formatDate(String dateTime) {
    try {
      if (dateTime.isEmpty) return '-';

      // YYYY-MM-DD HH:mm:ss 또는 YYYY-MM-DD 형식 처리
      final datePart = dateTime.split(' ')[0];
      final parts = datePart.split('-');

      if (parts.length == 3) {
        // YY.MM.DD 형식으로 반환 (2024 → 24)
        final year = parts[0].length >= 2 ? parts[0].substring(2) : parts[0];
        return '$year.${parts[1]}.${parts[2]}';
      }

      return dateTime;
    } catch (e) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "게시글 현황 관리",
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
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(height: 50, child: Text('모집진행')),
                        Tab(height: 50, child: Text('모집마감')),
                      ],
                      indicator: UnderlineTabIndicator(
                        borderSide: const BorderSide(
                          color: Colors.black,
                          width: 4.0,
                        ),
                        insets: const EdgeInsets.symmetric(horizontal: 5.0),
                      ),
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 16,
                      ),
                      overlayColor: WidgetStateProperty.all(
                        Colors.transparent,
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
      String emptyMessage;
      if (_currentTabIndex == 0) {
        emptyMessage = '모집 진행 중인 게시글이 없습니다.';
      } else {
        emptyMessage = '모집 마감된 게시글이 없습니다.';
      }

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

    return Column(
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
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
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '작성날짜',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 게시글 목록
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await fetchPosts();
            },
            color: AppTheme.primaryBlue,
            backgroundColor: Colors.white,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: filteredPosts.length,
              itemBuilder: (context, index) {
                final post = filteredPosts[index];
                String postStatus = _getPostStatus(post['status']);
                String postType = post['types'] == 0 ? '긴급' : '정기';

                return _buildPostListItem(post, index, postStatus, postType);
              },
            ),
          ),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 구분 (뱃지)
            Container(
              width: 60,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6.0,
                  vertical: 3.0,
                ),
                decoration: BoxDecoration(
                  color:
                      postType == '긴급'
                          ? Colors.red.withAlpha(38)
                          : Colors.blue.withAlpha(38),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  postType,
                  style: AppTheme.bodySmallStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: postType == '긴급' ? Colors.red : Colors.blue,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // 제목 - 왼쪽 정렬
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
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
            // 작성날짜
            Container(
              width: 80,
              alignment: Alignment.center,
              child: Text(
                _formatDate(post['created_date'] ?? ''),
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
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
                      color: _getStatusColor(postStatus).withValues(alpha: 0.15),
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
                        post['created_date'] ?? 'N/A',
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
                        '${post['applicantCount'] ?? 0}명',
                      ),
                      if ((post['content_delta'] != null &&
                              post['content_delta'].toString().isNotEmpty) ||
                          (post['description'] != null &&
                              post['description'].toString().isNotEmpty)) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.description_outlined,
                                size: 20, color: AppTheme.textSecondary),
                            const SizedBox(width: 12),
                            const Text('설명',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.veryLightGray,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.lightGray.withValues(alpha: 0.5),
                            ),
                          ),
                          child: RichTextViewer(
                            contentDelta: post['content_delta']?.toString(),
                            plainText: post['description']?.toString(),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      Text("헌혈 날짜 및 시간", style: AppTheme.h4Style),
                      const SizedBox(height: 12),
                      // 시간대 정보 표시
                      () {
                        final timeRanges =
                            post['timeRanges'] as List<dynamic>? ?? [];

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

                        // 중복 제거를 위한 Set 사용
                        final Set<String> seenTimeSlots = {};
                        final List<Map<String, dynamic>> uniqueTimeRanges = [];
                        
                        for (final timeRange in timeRanges) {
                          final donationDate = timeRange['donation_date'] ?? timeRange['date'] ?? '';
                          final time = timeRange['time'] ?? '';
                          final team = timeRange['team'] ?? 0;
                          
                          // 날짜+시간+팀으로 고유키 생성하여 중복 체크
                          final uniqueKey = '$donationDate-$time-$team';
                          
                          if (!seenTimeSlots.contains(uniqueKey)) {
                            seenTimeSlots.add(uniqueKey);
                            uniqueTimeRanges.add(timeRange as Map<String, dynamic>);
                          }
                        }
                        
                        return Column(
                          children:
                              uniqueTimeRanges.map<Widget>((timeRange) {
                                final donationDate =
                                    timeRange['donation_date'] ??
                                    timeRange['time'] ??
                                    'N/A';
                                final postTimesIdx = timeRange['id'];

                                return InkWell(
                                  onTap: () {
                                    _showApplicantList(
                                      postTimesIdx,
                                      donationDate.toString(),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8.0),
                                    padding: const EdgeInsets.all(12.0),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _formatDateTime(
                                              donationDate.toString(),
                                            ),
                                            style: AppTheme.bodyLargeStyle
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        Icon(
                                          Icons.people_outline,
                                          color: Colors.grey[600],
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                        );
                      }(),
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
