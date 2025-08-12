import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../services/dashboard_service.dart';
import '../widgets/marquee_text.dart';
import '../utils/number_format_util.dart';
import 'package:intl/intl.dart';

class UserDonationPostsListScreen extends StatefulWidget {
  final DonationPost? initialPost; // 초기에 표시할 게시글
  final bool autoShowBottomSheet; // 자동으로 바텀 시트 표시 여부
  
  const UserDonationPostsListScreen({
    super.key,
    this.initialPost,
    this.autoShowBottomSheet = false,
  });

  @override
  State<UserDonationPostsListScreen> createState() => _UserDonationPostsListScreenState();
}

class _UserDonationPostsListScreenState extends State<UserDonationPostsListScreen>
    with TickerProviderStateMixin {
  List<DonationPost> allPosts = [];
  List<DonationPost> filteredPosts = [];
  bool isLoading = true;
  String errorMessage = '';
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  
  // 탭 컨트롤러
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    
    // initialPost가 있으면 해당 탭으로 자동 이동
    if (widget.initialPost != null) {
      _currentTabIndex = widget.initialPost!.isUrgent ? 0 : 1; // 0=긴급, 1=정기
    }
    
    _tabController = TabController(length: 2, vsync: this, initialIndex: _currentTabIndex);
    _tabController.addListener(_handleTabChange);
    
    _loadDonationPosts();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging || _tabController.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController.index;
        _filterPosts();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDonationPosts() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      print('DEBUG: 헌혈 게시글 로딩 시작');
      // 모든 헌혈 모집글을 가져옵니다 (limit을 크게 설정)
      final posts = await DashboardService.getPublicPosts(limit: 100);
      print('DEBUG: API 응답 - 로딩된 헌혈 게시글 수: ${posts.length}');
      
      if (posts.isNotEmpty) {
        print('DEBUG: 첫 번째 게시글 샘플:');
        print('  - 제목: ${posts.first.title}');
        print('  - 병원명: ${posts.first.hospitalName}');
        print('  - 병원닉네임: ${posts.first.hospitalNickname}');
        print('  - 위치: ${posts.first.location}');
        print('  - 타입: ${posts.first.typeText}');
        print('  - 상태: ${posts.first.status}');
        print('  - postIdx: ${posts.first.postIdx}');
      } else {
        print('WARNING: API에서 헌혈 게시글이 없습니다.');
      }
      
      setState(() {
        allPosts = posts;
        _filterPosts();
        isLoading = false;
      });
      
      // 초기 게시글이 있더라도 자동으로 바텀 시트는 표시하지 않음
      // 사용자가 직접 클릭해야만 상세보기가 열림
    } catch (e) {
      setState(() {
        errorMessage = '헌혈 모집글을 불러오는데 실패했습니다: $e';
        isLoading = false;
      });
    }
  }


  void _filterPosts() {
    List<DonationPost> filtered = allPosts;
    print('DEBUG: _filterPosts 시작 - 전체 게시글: ${allPosts.length}개');

    // 탭에 따른 필터링
    if (_currentTabIndex == 0) {
      // 긴급 탭: 긴급 게시글만 표시 (types == 0)
      filtered = filtered.where((post) => post.types == 0).toList();
      print('DEBUG: 긴급 탭 필터링 후: ${filtered.length}개');
    } else {
      // 정기 탭: 정기 게시글만 표시 (types == 1)
      filtered = filtered.where((post) => post.types == 1).toList();
      print('DEBUG: 정기 탭 필터링 후: ${filtered.length}개');
    }

    // 검색어 필터링
    if (searchQuery.isNotEmpty) {
      final beforeSearch = filtered.length;
      filtered = filtered.where((post) {
        return post.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            post.hospitalName.toLowerCase().contains(searchQuery.toLowerCase()) ||
            post.location.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
      print('DEBUG: 검색 필터링 ("$searchQuery") - $beforeSearch개 → ${filtered.length}개');
    }

    // 긴급 게시글을 상단에, 그 다음 최신 순으로 정렬
    filtered.sort((a, b) {
      // 긴급도 우선 정렬
      if (a.isUrgent && !b.isUrgent) return -1;
      if (!a.isUrgent && b.isUrgent) return 1;
      // 같은 긴급도면 최신 순
      return b.createdAt.compareTo(a.createdAt);
    });

    setState(() {
      filteredPosts = filtered;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });
    _filterPosts();
  }

  // 시간 선택 다이얼로그 표시 (새로운 API 구조용)
  void _showTimeSelectionDialog(BuildContext context, DonationPost post, String selectedDate) {
    // 새로운 availableDates 구조 사용
    final List<TimeSlot>? timeSlots = post.availableDates?[selectedDate];
    
    if (timeSlots == null || timeSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('해당 날짜의 시간 정보를 불러올 수 없습니다.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.access_time, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                '시간 선택',
                style: AppTheme.h3Style.copyWith(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '선택한 날짜',
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedDate,
                      style: AppTheme.bodyLargeStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '시간을 선택하세요:',
                style: AppTheme.bodyMediumStyle,
              ),
              const SizedBox(height: 12),
              // 실제 API에서 가져온 시간대 정보 표시
              ...timeSlots.map((timeSlot) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.lightGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    _showDonationApplicationDialog(context, post, selectedDate, timeSlot);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      timeSlot.formattedTime,
                      style: AppTheme.bodyMediumStyle.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )).toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                '취소',
                style: AppTheme.bodyMediumStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 헌혈 신청 다이얼로그 표시 (새로운 API 구조용)
  void _showDonationApplicationDialog(BuildContext context, DonationPost post, String selectedDate, TimeSlot selectedTimeSlot) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.volunteer_activism, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                '헌혈 신청',
                style: AppTheme.h3Style.copyWith(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '선택한 시간대',
                      style: AppTheme.bodySmallStyle.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$selectedDate ${selectedTimeSlot.formattedTime}',
                      style: AppTheme.bodyLargeStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '신청을 진행하시겠습니까?',
                style: AppTheme.bodyMediumStyle,
              ),
              const SizedBox(height: 8),
              Text(
                '신청 후 병원에서 연락을 드릴 예정입니다.',
                style: AppTheme.bodySmallStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                '취소',
                style: AppTheme.bodyMediumStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _submitDonationApplication(post, selectedDate, selectedTimeSlot);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '신청하기',
                style: AppTheme.bodyMediumStyle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  // 헌혈 신청 제출 (실제 API 호출)
  Future<void> _submitDonationApplication(DonationPost post, String selectedDate, TimeSlot selectedTimeSlot) async {
    try {
      print('헌혈 신청 시작: post_times_idx=${selectedTimeSlot.postTimesIdx}, 날짜=$selectedDate, 시간=${selectedTimeSlot.formattedTime}');
      
      // SharedPreferences에서 JWT 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token == null) {
        throw Exception('로그인이 필요합니다. 다시 로그인해주세요.');
      }
      
      // TODO: 실제 반려동물 선택 UI 구현 필요
      // 현재는 임시로 하드코딩된 값 사용
      final petIdx = 14; // 나중에 반려동물 선택 다이얼로그에서 가져올 값
      
      final response = await http.post(
        Uri.parse('${Config.serverUrl}/api/donation/apply'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // 실제 JWT 토큰 사용
        },
        body: jsonEncode({
          'post_times_idx': selectedTimeSlot.postTimesIdx,
          'pet_idx': petIdx,
          'applicant_message': '우리 반려동물이 건강하게 헌혈에 참여하고 싶습니다.',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? '헌혈 신청이 완료되었습니다. 검토 후 결과를 알려드리겠습니다.'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        } else {
          throw Exception(data['message'] ?? '신청 처리 중 오류가 발생했습니다.');
        }
      } else {
        throw Exception('서버 연결 오류 (상태코드: ${response.statusCode})');
      }
      
    } catch (e) {
      print('ERROR: 헌혈 신청 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('신청 중 오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  // 일반 헌혈 신청 다이얼로그 (availableDates가 없는 경우)
  void _showGeneralDonationApplicationDialog(BuildContext context, DonationPost post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.volunteer_activism, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                '헌혈 신청',
                style: AppTheme.h3Style.copyWith(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '이 게시글은 구체적인 시간대가 설정되지 않았습니다.\n병원에서 별도로 연락드릴 예정입니다.',
                style: AppTheme.bodyMediumStyle,
              ),
              const SizedBox(height: 16),
              Text(
                '신청하시겠습니까?',
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                '취소',
                style: AppTheme.bodyMediumStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('검토 후 결과를 알려드리겠습니다.'),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '신청하기',
                style: AppTheme.bodyMediumStyle.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPostDetail(DonationPost post) async {
    // 상세 정보 조회
    final detailPost = await DashboardService.getDonationPostDetail(post.postIdx);
    
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        final displayPost = detailPost ?? post;
        
        
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
                        // 긴급/정기 뱃지
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: displayPost.isUrgent 
                                ? Colors.red.withOpacity(0.15)
                                : Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            displayPost.typeText,
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: displayPost.isUrgent ? Colors.red : Colors.blue,
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
                                displayPost.title,
                                style: AppTheme.h3Style.copyWith(
                                  color: displayPost.isUrgent ? Colors.red : AppTheme.textPrimary,
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
                  
                  // 메타 정보 (닉네임, 주소, 설명글 순서)
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 닉네임과 등록일
                        Row(
                          children: [
                            Icon(Icons.business, size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              displayPost.hospitalNickname ?? displayPost.hospitalName ?? '병원',
                              style: AppTheme.bodyMediumStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat('yy.MM.dd').format(displayPost.createdAt),
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
                                displayPost.location,
                                style: AppTheme.bodyMediumStyle,
                              ),
                            ),
                          ],
                        ),
                        // 설명글 (있는 경우만)
                        if (displayPost.description.isNotEmpty) ...[
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
                              displayPost.description,
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
                  
                  // 헌혈 정보
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 혈액형 정보
                          if (displayPost.emergencyBloodType != null && displayPost.emergencyBloodType!.isNotEmpty) ...[
                            Text('필요 혈액형', style: AppTheme.h4Style),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: displayPost.isUrgent ? Colors.red.shade50 : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: displayPost.isUrgent ? Colors.red.shade200 : Colors.blue.shade200,
                                ),
                              ),
                              child: Text(
                                displayPost.displayBloodType,
                                style: AppTheme.h3Style.copyWith(
                                  color: displayPost.isUrgent ? Colors.red : Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          
                          // 헌혈 날짜 정보
                          Text('헌혈 예정일', style: AppTheme.h4Style),
                          const SizedBox(height: 12),
                          if (displayPost.availableDates != null && displayPost.availableDates!.isNotEmpty) ...[
                            ...displayPost.availableDates!.entries.map((entry) {
                              final dateStr = entry.key;
                              final timeSlots = entry.value;
                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      _showTimeSelectionDialog(context, displayPost, dateStr);
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              dateStr,
                                              style: AppTheme.bodyLargeStyle.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryBlue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${timeSlots.length}개 시간대',
                                              style: AppTheme.bodySmallStyle.copyWith(
                                                color: AppTheme.primaryBlue,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.keyboard_arrow_right,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ] else if (displayPost.donationDate != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                DateFormat('yyyy년 MM월 dd일 EEEE', 'ko').format(displayPost.donationDate!),
                                style: AppTheme.bodyLargeStyle.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Text(
                                '헌혈 날짜가 아직 확정되지 않았습니다',
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                          
                          // 헌혈 신청 버튼 (검은색)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(vertical: 16),
                            child: ElevatedButton(
                              onPressed: () {
                                // 일반적인 헌혈 신청 (시간대별 신청이 아닌 경우)
                                _showGeneralDonationApplicationDialog(context, displayPost);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                  horizontal: 24,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                '헌혈 신청하기',
                                style: AppTheme.bodyLargeStyle.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "헌혈 모집 게시글",
          style: AppTheme.h2Style.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Colors.black87),
            tooltip: '새로고침',
            onPressed: _loadDonationPosts,
          ),
          const SizedBox(width: 8),
        ],
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
                hintText: '게시글 제목, 병원명, 위치로 검색...',
                prefixIcon: const Icon(Icons.search, color: Colors.black),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
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


          // 탭 바
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('긴급'),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('정기'),
                  ),
                ),
              ],
              indicatorColor: Colors.black,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              indicatorWeight: 3.0,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 8.0),
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
            Text('헌혈 모집글을 불러오고 있습니다...'),
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
                style: AppTheme.h3Style.copyWith(color: Colors.red[500]),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: AppTheme.bodyMediumStyle.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDonationPosts,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredPosts.isEmpty) {
      String emptyMessage = _currentTabIndex == 0 
          ? '긴급 헌혈 모집글이 없습니다.' 
          : '정기 헌혈 모집글이 없습니다.';

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pets_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: AppTheme.h4Style.copyWith(color: Colors.grey[500]),
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade400, width: 2),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
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
                  width: 60,
                  child: Text(
                    '병원',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    '등록일',
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
        final post = filteredPosts[index - 1];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildPostListItem(post),
        );
      },
    );
  }

  Widget _buildPostListItem(DonationPost post) {
    return InkWell(
      onTap: () => _showPostDetail(post),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 구분 (긴급/정기 뱃지)
            Container(
              width: 50,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: post.isUrgent
                      ? Colors.red.withOpacity(0.15)
                      : Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  post.typeText,
                  style: AppTheme.bodySmallStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: post.isUrgent ? Colors.red : Colors.blue,
                    fontSize: 10,
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
                  text: post.title,
                  style: AppTheme.bodyMediumStyle.copyWith(
                    fontWeight: FontWeight.w500,
                    color: post.isUrgent ? Colors.red.shade700 : AppTheme.textPrimary,
                  ),
                  animationDuration: const Duration(milliseconds: 5000),
                  pauseDuration: const Duration(milliseconds: 2000),
                ),
              ),
            ),
            
            // 병원 이름 (닉네임 우선, 전체 표시)
            Container(
              width: 80,
              alignment: Alignment.center,
              child: Text(
                post.hospitalNickname ?? (post.hospitalName.isNotEmpty ? post.hospitalName : '병원'),
                style: AppTheme.bodySmallStyle.copyWith(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            
            // 등록날짜
            Container(
              width: 70,
              alignment: Alignment.center,
              child: Text(
                DateFormat('yy.MM.dd').format(post.createdAt),
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

}