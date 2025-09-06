// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'pet_management.dart';
import '../utils/app_theme.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/unified_notification_page.dart';
import '../auth/profile_management.dart';
import 'user_notice_list.dart';
import 'user_donation_posts_list.dart';
import 'user_column_list.dart';
import 'donation_history_screen.dart';
import '../services/dashboard_service.dart';
import '../models/hospital_column_model.dart';
import '../models/notice_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import '../widgets/marquee_text.dart';
import '../utils/number_format_util.dart';
import '../utils/config.dart';
import '../widgets/region_selection_sheet.dart';
import '../models/region_model.dart';
import '../utils/text_personalization_util.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String userName = "사용자"; // 실제 사용자 이름
  String userNickname = "사용자"; // 사용자 닉네임
  String currentDateTime = "";
  Timer? _timer;

  // 서버 데이터
  List<HospitalColumn> columns = [];
  List<Notice> notices = [];
  List<DonationPost> donations = [];
  bool isLoadingColumns = false;
  bool isLoadingNotices = false;
  bool isLoadingDonations = false;
  bool isLoadingDashboard = false;

  // 지역 선택 관련 변수들 - 다중 선택 지원
  List<Region> selectedLargeRegions = []; // 선택된 시/도 목록
  Map<Region, List<Region>> selectedMediumRegions = {}; // 시/도별 선택된 시/군/구 목록

  String get selectedRegionText {
    if (selectedLargeRegions.isEmpty) return '전체 지역';

    if (selectedLargeRegions.length == 1) {
      final largeRegion = selectedLargeRegions.first;
      final mediumRegions = selectedMediumRegions[largeRegion] ?? [];

      if (mediumRegions.isEmpty) {
        return '${largeRegion.name} 전체';
      } else if (mediumRegions.length == 1) {
        return '${largeRegion.name} ${mediumRegions.first.name}';
      } else {
        return '${largeRegion.name} ${mediumRegions.first.name} 외 ${mediumRegions.length - 1}곳';
      }
    } else {
      if (selectedLargeRegions.length <= 3) {
        return selectedLargeRegions.map((r) => r.name).join(', ');
      } else {
        return '${selectedLargeRegions.take(2).map((r) => r.name).join(', ')} 외 ${selectedLargeRegions.length - 2}곳';
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
    ); // 3개의 탭 (헌혈 모집, 칼럼, 공지사항)
    _tabController.addListener(() {
      setState(() {}); // 탭이 변경될 때 UI를 다시 그리도록 강제
    });
    _loadUserName();
    _updateDateTime();
    _startTimer();
    _loadDashboardData();
  }

  void _updateDateTime() {
    if (!mounted) return;
    final now = DateTime.now();
    final formatter = DateFormat('yyyy년 M월 d일 (EEEE) HH:mm', 'ko_KR');
    setState(() {
      currentDateTime = formatter.format(now);
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateDateTime();
    });
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    // 서버에서 최신 이름을 먼저 시도
    if (token != null) {
      try {
        final response = await http.get(
          Uri.parse('${Config.serverUrl}/api/auth/profile'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json; charset=UTF-8',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final userRealName = data['name'] ?? '사용자';
          final userRealNickname = data['nickname'] ?? userRealName;

          if (!mounted) return;
          setState(() {
            userName = userRealName;
            userNickname = userRealNickname;
          });

          // 로컬 저장소에도 업데이트
          await prefs.setString('user_name', userRealName);
          await prefs.setString('user_nickname', userRealNickname);
          return;
        }
      } catch (e) {
        // 웹 환경에서는 CORS 문제로 인해 로컬 데이터 사용
      }
    }

    // 서버 실패 시 로컬에 저장된 이름과 닉네임 사용
    final savedName = prefs.getString('user_name');
    final savedNickname = prefs.getString('user_nickname');
    if (savedName != null && savedName.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        userName = savedName;
        userNickname = savedNickname ?? savedName;
      });
    } else {
      if (!mounted) return;
      setState(() {
        userName = '사용자';
        userNickname = '사용자';
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadUserName();
    _updateDateTime();
    await _loadDashboardData();
  }

  // 정식명칭을 간단명칭으로 변환하는 헬퍼 함수 (서버 권장사항)
  String _getSimpleRegionName(String fullName) {
    const regionMapping = {
      '서울특별시': '서울',
      '부산광역시': '부산',
      '대구광역시': '대구',
      '인천광역시': '인천',
      '광주광역시': '광주',
      '대전광역시': '대전',
      '울산광역시': '울산',
      '세종특별자치시': '세종',
      '경기도': '경기',
      '강원도': '강원',
      '강원특별자치도': '강원',
      '충청북도': '충북',
      '충청남도': '충남',
      '전라북도': '전북',
      '전북특별자치도': '전북',
      '전라남도': '전남',
      '경상북도': '경북',
      '경상남도': '경남',
      '제주특별자치도': '제주',
    };

    final mapped = regionMapping[fullName];
    return mapped ?? fullName;
  }

  // 헌혈 모집 데이터만 새로고침 (지역 필터링용)
  Future<void> _refreshDonationPosts() async {
    setState(() {
      isLoadingDonations = true;
    });

    try {
      List<DonationPost> allDonationPosts = [];

      if (selectedLargeRegions.isEmpty) {
        // 전체 지역 선택인 경우
        final posts = await DashboardService.getPublicPosts(limit: 50);
        allDonationPosts.addAll(posts);
      } else {
        // 선택된 지역들에서 데이터 가져오기
        for (final largeRegion in selectedLargeRegions) {
          final mediumRegions = selectedMediumRegions[largeRegion] ?? [];

          if (mediumRegions.isEmpty) {
            // 시/도 전체 선택인 경우 - 서버 권장 간단명칭 사용
            final posts = await DashboardService.getPublicPosts(
              limit: 20,
              region: _getSimpleRegionName(largeRegion.name),
            );
            allDonationPosts.addAll(posts);
          } else {
            // 구체적인 시/군/구 선택인 경우 - 서버 권장 간단명칭 사용
            for (final mediumRegion in mediumRegions) {
              final posts = await DashboardService.getPublicPosts(
                limit: 20,
                region: _getSimpleRegionName(largeRegion.name),
                subRegion: mediumRegion.name,
              );
              allDonationPosts.addAll(posts);
            }
          }
        }
      }

      // 중복 제거 (postIdx 기준)
      final uniquePosts = <int, DonationPost>{};
      for (final post in allDonationPosts) {
        uniquePosts[post.postIdx] = post;
      }
      final donationPosts = uniquePosts.values.toList();

      // 헌혈 모집글 정렬 (긴급 우선, 그 다음 최신순)
      final sortedDonations = List<DonationPost>.from(donationPosts);
      sortedDonations.sort((a, b) {
        if (a.isUrgent && !b.isUrgent) return -1;
        if (!a.isUrgent && b.isUrgent) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      if (!mounted) return;
      setState(() {
        donations = sortedDonations.take(10).toList();
        isLoadingDonations = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingDonations = false;
      });
    }
  }

  // 통합 대시보드 데이터 로드
  Future<void> _loadDashboardData() async {
    setState(() {
      isLoadingDashboard = true;
      isLoadingDonations = true;
      isLoadingColumns = true;
      isLoadingNotices = true;
    });

    try {
      // 다중 지역 선택에 따른 헌혈 모집글 로딩
      List<DonationPost> allDonationPosts = [];

      if (selectedLargeRegions.isEmpty) {
        // 전체 지역 선택인 경우
        final posts = await DashboardService.getPublicPosts(limit: 10);
        allDonationPosts.addAll(posts);
      } else {
        // 선택된 지역들에서 데이터 가져오기 (초기 로딩이므로 제한적으로)
        for (final largeRegion in selectedLargeRegions.take(3)) {
          // 처음 3개 지역만
          final mediumRegions = selectedMediumRegions[largeRegion] ?? [];

          if (mediumRegions.isEmpty) {
            // 시/도 전체 선택인 경우 - 서버 권장 간단명칭 사용
            final posts = await DashboardService.getPublicPosts(
              limit: 5,
              region: _getSimpleRegionName(largeRegion.name),
            );
            allDonationPosts.addAll(posts);
          } else {
            // 구체적인 시/군/구 선택인 경우 (첫 번째만) - 서버 권장 간단명칭 사용
            final posts = await DashboardService.getPublicPosts(
              limit: 5,
              region: _getSimpleRegionName(largeRegion.name),
              subRegion: mediumRegions.first.name,
            );
            allDonationPosts.addAll(posts);
          }
        }
      }

      // 중복 제거
      final uniquePosts = <int, DonationPost>{};
      for (final post in allDonationPosts) {
        uniquePosts[post.postIdx] = post;
      }
      final donationPosts = uniquePosts.values.take(10).toList();

      // 칼럼과 공지사항은 별도로 로딩
      final futures = await Future.wait([
        DashboardService.getPublicColumns(limit: 10),
        DashboardService.getPublicNotices(limit: 10),
      ]);

      final columnPosts = futures[0] as List<ColumnPost>;
      final noticePosts = futures[1] as List<NoticePost>;

      // 헌혈 모집글 정렬 (긴급 우선, 그 다음 최신순)
      final sortedDonations = List<DonationPost>.from(donationPosts);
      sortedDonations.sort((a, b) {
        if (a.isUrgent && !b.isUrgent) return -1;
        if (!a.isUrgent && b.isUrgent) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      // 칼럼 정렬 (중요 공지 우선, 그 다음 최신순)
      final sortedColumns =
          columnPosts.map((column) {
            return HospitalColumn(
              columnIdx: column.columnIdx,
              title: column.title,
              content: column.contentPreview,
              hospitalName: column.authorName, // 병원 실명
              hospitalIdx: 0,
              isPublished: true,
              viewCount: column.viewCount,
              createdAt: column.createdAt,
              updatedAt: column.updatedAt,
              authorNickname: column.authorNickname, // 병원 닉네임
            );
          }).toList();

      sortedColumns.sort((a, b) {
        final aImportant = a.title.contains('[중요]') || a.title.contains('[공지]');
        final bImportant = b.title.contains('[중요]') || b.title.contains('[공지]');
        if (aImportant && !bImportant) return -1;
        if (!aImportant && bImportant) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      // 공지사항 필터링 및 정렬 (청중 타겟이 전체(0) 또는 사용자(3)만)
      final sortedNotices =
          noticePosts
              .where(
                (notice) =>
                    notice.targetAudience == 0 || notice.targetAudience == 3,
              )
              .map((notice) {
                return Notice(
                  noticeIdx: notice.noticeIdx,
                  accountIdx: 0, // DashboardService에서 제공하지 않는 필드
                  title: notice.title,
                  content: notice.contentPreview,
                  noticeImportant: notice.noticeImportant, // 1=뱃지 표시, 0=뱃지 숨김
                  noticeActive: true,
                  createdAt: notice.createdAt,
                  updatedAt: notice.updatedAt,
                  authorEmail: notice.authorEmail,
                  authorName: notice.authorName,
                  authorNickname: notice.authorNickname, // 작성자 닉네임
                  viewCount: notice.viewCount,
                  targetAudience: notice.targetAudience,
                );
              })
              .toList();

      sortedNotices.sort((a, b) {
        if (a.showBadge && !b.showBadge) return -1;
        if (!a.showBadge && b.showBadge) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      if (!mounted) return;
      setState(() {
        donations = sortedDonations.take(10).toList();
        columns = sortedColumns.take(10).toList();
        notices = sortedNotices.take(10).toList();
        isLoadingDashboard = false;
        isLoadingDonations = false;
        isLoadingColumns = false;
        isLoadingNotices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingDashboard = false;
        isLoadingDonations = false;
        isLoadingColumns = false;
        isLoadingNotices = false;
      });
    }
  }

  // 날짜/시간 표시 로직

  // 지역 선택 바텀 시트 표시
  void _showRegionSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => RegionSelectionSheet(
            initialSelectedLargeRegions: List.from(selectedLargeRegions),
            initialSelectedMediumRegions: Map.from(selectedMediumRegions),
            onRegionSelected: (selectedLarges, selectedMediums) {
              setState(() {
                selectedLargeRegions = selectedLarges;
                selectedMediumRegions = selectedMediums;
              });
              // 지역이 변경되면 헌혈 모집 데이터만 새로고침
              _refreshDonationPosts();
            },
          ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose(); // TabController 리소스 해제
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 뒤로가기 방지
      child: Scaffold(
        appBar: AppDashboardAppBar(
          onProfilePressed: () async {
            // 프로필 관리 페이지로 이동 후 돌아올 때 사용자 이름 새로고침
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProfileManagement(),
              ),
            );
            // 프로필 페이지에서 돌아온 후 사용자 정보 새로고침
            _loadUserName();
          },
          onNotificationPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UnifiedNotificationPage(),
              ),
            );
          },
          additionalAction: IconButton(
            icon: const Icon(Icons.pets, color: AppTheme.textPrimary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PetManagementScreen(),
                ),
              );
            },
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppTheme.primaryBlue,
          child: _buildDashboardContent(),
        ),
      ),
    );
  }

  // 사용자 대시보드의 메인 내용을 구성하는 위젯
  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 고정 컨텐츠
          Padding(
            padding: AppTheme.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('안녕하세요, $userNickname 님!', style: AppTheme.h2Style),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  currentDateTime,
                  style: AppTheme.bodyLargeStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing20),

                // 퀵 액세스 메뉴
                Text('내 헌혈 관리', style: AppTheme.h3Style),
                const SizedBox(height: AppTheme.spacing12),
                _buildLongActionCard(
                  icon: Icons.bloodtype,
                  title: '헌혈 이력',
                  subtitle: '헌혈 신청 및 완료 내역',
                  color: Colors.red.shade600,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DonationHistoryScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // 탭바
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bloodtype, size: 20),
                      SizedBox(width: 8),
                      Text('헌혈 모집'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article, size: 20),
                      SizedBox(width: 8),
                      Text('칼럼'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.announcement, size: 20),
                      SizedBox(width: 8),
                      Text('공지사항'),
                    ],
                  ),
                ),
              ],
              labelColor: Colors.black87,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.black87,
              dividerColor: Colors.transparent,
            ),
          ),
          // 탭 뷰
          Container(
            margin: const EdgeInsets.only(
              left: AppTheme.spacing16,
              right: AppTheme.spacing16,
              bottom: AppTheme.spacing16, // 하단 여백
            ),
            height: 400, // 고정 높이
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightGray.withValues(alpha: 0.3),
              ),
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBloodDonationBoard(), // 헌혈 모집 게시판 내용
                _buildColumnBoard(), // 칼럼 게시판 내용
                _buildNoticeBoard(), // 공지사항 게시판 내용
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 헌혈 모집 게시판 위젯을 생성합니다.
  Widget _buildBloodDonationBoard() {
    if (isLoadingDonations) {
      return const Center(child: CircularProgressIndicator());
    }

    // 게시글이 없어도 지역 선택 버튼은 항상 표시

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 지역 필터 버튼
          Container(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: _showRegionSelectionSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.veryLightGray,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  border: Border.all(
                    color: AppTheme.lightGray.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          selectedRegionText,
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 헌혈 모집 목록
          Expanded(
            child:
                donations.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bloodtype_outlined,
                            size: 48,
                            color: AppTheme.mediumGray,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '선택한 지역에 헌혈 모집이 없습니다',
                            style: AppTheme.bodyMediumStyle.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const UserDonationPostsListScreen(),
                                ),
                              );
                            },
                            child: Text(
                              '전체 헌혈 모집 보기',
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: donations.length + 1, // ... 아이템 추가를 위해 +1
                      separatorBuilder:
                          (context, index) => Container(
                            height: 1,
                            color: AppTheme.lightGray.withValues(alpha: 0.2),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                      itemBuilder: (context, index) {
                        // 마지막 아이템은 ... 버튼
                        if (index == donations.length) {
                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const UserDonationPostsListScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              child: Center(
                                child: Text(
                                  '...',
                                  style: AppTheme.h3Style.copyWith(
                                    color: AppTheme.textTertiary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final donation = donations[index];

                        return InkWell(
                          onTap: () {
                            // 헌혈 모집 게시글 페이지로 이동하고 해당 게시글의 바텀 시트 표시
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => UserDonationPostsListScreen(
                                      initialPost: donation,
                                      autoShowBottomSheet: true,
                                    ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 왼쪽: 순서 (카드 중앙 높이)
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '${index + 1}',
                                    style: AppTheme.bodySmallStyle.copyWith(
                                      color: AppTheme.textTertiary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 중앙: 메인 콘텐츠
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 첫 번째 줄: 뱃지 + 제목
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  donation.isUrgent
                                                      ? AppTheme.error
                                                      : AppTheme.success,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              donation.isUrgent ? '긴급' : '정기',
                                              style: AppTheme.bodySmallStyle
                                                  .copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: MarqueeText(
                                              text: donation.title,
                                              style: AppTheme.bodyMediumStyle
                                                  .copyWith(
                                                    color:
                                                        donation.isUrgent
                                                            ? AppTheme.error
                                                            : AppTheme
                                                                .textPrimary,
                                                    fontWeight:
                                                        donation.isUrgent
                                                            ? FontWeight.w600
                                                            : FontWeight.w500,
                                                    fontSize: 14,
                                                  ),
                                              animationDuration: const Duration(
                                                milliseconds: 4000,
                                              ),
                                              pauseDuration: const Duration(
                                                milliseconds: 1000,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      // 두 번째 줄: 병원 주소
                                      Row(
                                        children: [
                                          // 병원 주소 (전체 표시)
                                          Expanded(
                                            child: Text(
                                              donation.location.isNotEmpty
                                                  ? donation.location
                                                  : '주소 정보 없음',
                                              style: AppTheme.bodySmallStyle
                                                  .copyWith(
                                                    color:
                                                        AppTheme.textSecondary,
                                                    fontSize: 12,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // 오른쪽: 날짜들 + 2줄 높이의 조회수 박스
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 날짜 컬럼 (등록/헌혈 날짜 세로 배치)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '작성: ${DateFormat('yy.MM.dd').format(donation.createdAt)}',
                                          style: AppTheme.bodySmallStyle
                                              .copyWith(
                                                color: AppTheme.textTertiary,
                                                fontSize: 11,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '헌혈: ${donation.donationDate != null ? DateFormat('yy.MM.dd').format(donation.donationDate!) : '미정'}',
                                          style: AppTheme.bodySmallStyle
                                              .copyWith(
                                                color: AppTheme.textTertiary,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    // 2줄 높이의 조회수 박스
                                    Container(
                                      height: 36, // 높이 늘림
                                      width: 40, // 너비 늘림
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.mediumGray.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppTheme.lightGray.withValues(
                                            alpha: 0.3,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.visibility_outlined,
                                            size: 10,
                                            color: AppTheme.textTertiary,
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            NumberFormatUtil.formatViewCount(
                                              donation.viewCount,
                                            ),
                                            style: AppTheme.bodySmallStyle
                                                .copyWith(
                                                  color: AppTheme.textTertiary,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  // 칼럼 게시판 위젯을 생성합니다.
  Widget _buildColumnBoard() {
    if (isLoadingColumns) {
      return const Center(child: CircularProgressIndicator());
    }

    if (columns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: AppTheme.mediumGray),
            const SizedBox(height: 16),
            Text('공개된 칼럼이 없습니다', style: AppTheme.h4Style),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 칼럼 목록
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: columns.length + 1, // ... 아이템 추가를 위해 +1
              separatorBuilder:
                  (context, index) => Container(
                    height: 1,
                    color: AppTheme.lightGray.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
              itemBuilder: (context, index) {
                // 마지막 아이템은 ... 버튼
                if (index == columns.length) {
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserColumnListScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: Center(
                        child: Text(
                          '...',
                          style: AppTheme.h3Style.copyWith(
                            color: AppTheme.textTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final column = columns[index];
                final isImportant =
                    column.title.contains('[중요]') ||
                    column.title.contains('[공지]');

                return InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('칼럼 ${column.columnIdx} 상세 페이지 (준비 중)'),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 왼쪽: 순서 번호 (1.5번째 줄 위치)
                        SizedBox(
                          width: 20,
                          height: 50, // 전체 높이에 맞춤
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: AppTheme.textTertiary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 중앙: 메인 콘텐츠
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 첫 번째 줄: 뱃지 + 제목
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isImportant) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '중요',
                                        style: AppTheme.bodySmallStyle.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: MarqueeText(
                                      text:
                                          TextPersonalizationUtil.personalizeTitle(
                                            title: column.title,
                                            userName: userName,
                                            userNickname: userNickname,
                                          ),
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        color:
                                            isImportant
                                                ? AppTheme.error
                                                : AppTheme.textPrimary,
                                        fontWeight:
                                            isImportant
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                      animationDuration: const Duration(
                                        milliseconds: 4000,
                                      ),
                                      pauseDuration: const Duration(
                                        milliseconds: 1000,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // 두 번째 줄: 작성자 이름
                              Text(
                                (column.authorNickname ?? column.hospitalName)
                                            .length >
                                        15
                                    ? '${(column.authorNickname ?? column.hospitalName).substring(0, 15)}..'
                                    : (column.authorNickname ??
                                        column.hospitalName),
                                style: AppTheme.bodySmallStyle.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 오른쪽: 날짜들 + 2줄 높이의 조회수 박스
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 날짜 컬럼 (작성/수정일 세로 배치)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '작성: ${DateFormat('yy.MM.dd').format(column.createdAt)}',
                                  style: AppTheme.bodySmallStyle.copyWith(
                                    color: AppTheme.textTertiary,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '수정: ${DateFormat('yy.MM.dd').format(column.updatedAt)}',
                                  style: AppTheme.bodySmallStyle.copyWith(
                                    color: AppTheme.textTertiary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            // 2줄 높이의 조회수 박스
                            Container(
                              height: 36,
                              width: 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.mediumGray.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.lightGray.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 10,
                                    color: AppTheme.textTertiary,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    NumberFormatUtil.formatViewCount(
                                      column.viewCount,
                                    ),
                                    style: AppTheme.bodySmallStyle.copyWith(
                                      color: AppTheme.textTertiary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 공지사항 게시판 위젯을 생성합니다.
  Widget _buildNoticeBoard() {
    if (isLoadingNotices) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.announcement_outlined,
              size: 64,
              color: AppTheme.mediumGray,
            ),
            const SizedBox(height: 16),
            Text('공지사항이 없습니다', style: AppTheme.h4Style),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 공지사항 목록
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: notices.length + 1, // ... 아이템 추가를 위해 +1
              separatorBuilder:
                  (context, index) => Container(
                    height: 1,
                    color: AppTheme.lightGray.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
              itemBuilder: (context, index) {
                // 마지막 아이템은 ... 버튼
                if (index == notices.length) {
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserNoticeListScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: Center(
                        child: Text(
                          '...',
                          style: AppTheme.h3Style.copyWith(
                            color: AppTheme.textTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final notice = notices[index];

                return InkWell(
                  onTap: () {
                    _showNoticeBottomSheet(context, notice);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 왼쪽: 순서 (2줄 높이 중앙 정렬)
                        SizedBox(
                          width: 28,
                          height: 40,
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: AppTheme.textTertiary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 중앙: 메인 콘텐츠
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 첫 번째 줄: 뱃지 + 제목
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // notice_important가 1이면 뱃지 표시
                                  if (notice.showBadge) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        notice.badgeText,
                                        style: AppTheme.bodySmallStyle.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: MarqueeText(
                                      text:
                                          TextPersonalizationUtil.personalizeTitle(
                                            title: notice.title,
                                            userName: userName,
                                            userNickname: userNickname,
                                          ),
                                      style: AppTheme.bodyMediumStyle.copyWith(
                                        color:
                                            notice.showBadge
                                                ? AppTheme.error
                                                : AppTheme.textPrimary,
                                        fontWeight:
                                            notice.showBadge
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                      animationDuration: const Duration(
                                        milliseconds: 4000,
                                      ),
                                      pauseDuration: const Duration(
                                        milliseconds: 1000,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // 두 번째 줄: 작성자 이름
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (notice.authorNickname ??
                                                      notice.authorName)
                                                  .length >
                                              15
                                          ? '${(notice.authorNickname ?? notice.authorName).substring(0, 15)}..'
                                          : (notice.authorNickname ??
                                              notice.authorName),
                                      style: AppTheme.bodySmallStyle.copyWith(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 오른쪽: 날짜들 + 2줄 높이의 조회수 박스
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 날짜 컬럼 (작성/수정일 세로 배치)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '작성: ${DateFormat('yy.MM.dd').format(notice.createdAt)}',
                                  style: AppTheme.bodySmallStyle.copyWith(
                                    color: AppTheme.textTertiary,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '수정: ${DateFormat('yy.MM.dd').format(notice.updatedAt)}',
                                  style: AppTheme.bodySmallStyle.copyWith(
                                    color: AppTheme.textTertiary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            // 2줄 높이의 조회수 박스
                            Container(
                              height: 36,
                              width: 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.mediumGray.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.lightGray.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 10,
                                    color: AppTheme.textTertiary,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    NumberFormatUtil.formatViewCount(
                                      notice.viewCount ?? 0,
                                    ),
                                    style: AppTheme.bodySmallStyle.copyWith(
                                      color: AppTheme.textTertiary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 가로 길게 생성하는 액션 카드 (관리자 스타일)
  Widget _buildLongActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radius16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.h4Style.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      subtitle,
                      style: AppTheme.bodyMediumStyle.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Icon(Icons.arrow_forward_ios, size: 16, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 퀵 액세스 카드를 생성하는 위젯

  // 공지사항 바텀시트 표시
  void _showNoticeBottomSheet(BuildContext context, Notice notice) async {
    // 상세 조회 API 호출 (조회수 자동 증가)
    final noticeDetail = await DashboardService.getNoticeDetail(
      notice.noticeIdx,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                  // 제목 영역
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        if (notice.showBadge) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.error,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              notice.badgeText,
                              style: AppTheme.bodySmallStyle.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            TextPersonalizationUtil.personalizeTitle(
                              title: noticeDetail?.title ?? notice.title,
                              userName: userName,
                              userNickname: userNickname,
                            ),
                            style: AppTheme.h3Style.copyWith(
                              color:
                                  notice.showBadge
                                      ? AppTheme.error
                                      : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
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
                    child: Row(
                      children: [
                        Text(
                          '${notice.authorNickname ?? notice.authorName} • ',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          DateFormat(
                            'yyyy년 MM월 dd일',
                          ).format(noticeDetail?.createdAt ?? notice.createdAt),
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          NumberFormatUtil.formatViewCount(
                            noticeDetail?.viewCount ?? notice.viewCount ?? 0,
                          ),
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 내용
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Text(
                        TextPersonalizationUtil.personalizeContent(
                          content:
                              noticeDetail?.contentPreview ?? notice.content,
                          userName: userName,
                          userNickname: userNickname,
                        ),
                        style: AppTheme.bodyMediumStyle.copyWith(height: 1.6),
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
}
