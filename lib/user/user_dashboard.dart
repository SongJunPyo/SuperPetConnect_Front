// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import '../models/unified_post_model.dart';
import '../models/column_post_model.dart';
import '../models/notice_post_model.dart';
import '../models/hospital_column_model.dart';
import '../models/notice_model.dart';
import '../utils/preferences_manager.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import '../utils/number_format_util.dart';
import '../utils/config.dart';
import '../widgets/marquee_text.dart';
import '../widgets/dashboard/dashboard_empty_state.dart';
import '../widgets/dashboard/dashboard_more_button.dart';
import '../widgets/dashboard/dashboard_list_item.dart';
import '../services/auth_http_client.dart';
import '../widgets/region_selection_sheet.dart';
import '../widgets/blinking_icon.dart';
import '../models/region_model.dart';
import '../utils/text_personalization_util.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/notification_provider.dart';
import '../widgets/rich_text_viewer.dart';
import '../services/applied_donation_service.dart';
import '../models/applied_donation_model.dart';
import '../utils/app_constants.dart';
import '../widgets/post_detail/post_detail_handle_bar.dart';
import '../widgets/post_detail/post_detail_header.dart';
import '../widgets/post_detail/post_detail_meta_section.dart';
import '../widgets/post_detail/post_detail_blood_type.dart';
import '../widgets/post_detail/post_detail_description.dart';

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
  List<UnifiedPostModel> donations = [];

  // 내가 신청한 시간대 정보 (postTimesIdx -> MyApplicationInfo)
  Map<int, MyApplicationInfo> myApplicationsMap = {};
  bool isLoadingColumns = false;
  bool isLoadingNotices = false;
  bool isLoadingDonations = false;
  bool isLoadingDashboard = false;

  // 사용자 위치 정보 (프로필 API에서 가져옴)
  String? userAddress;
  double? userLatitude;
  double? userLongitude;

  // 지역 선택 관련 변수들 - 시/도 단위 다중 선택
  List<Region> selectedLargeRegions = []; // 선택된 시/도 목록

  // 서버에 저장된 선호 지역 (프로필 API 응답)
  String? serverPreferredLocation;

  // 서버 프로필 전체 데이터 캐시 (PUT 시 전체 필드 전송 필요)
  Map<String, dynamic>? _cachedProfileData;

  String get selectedRegionText {
    if (selectedLargeRegions.isEmpty) return '전체 지역';

    if (selectedLargeRegions.length == 1) {
      return selectedLargeRegions.first.name;
    } else {
      return '${selectedLargeRegions.first.name} 외 ${selectedLargeRegions.length - 1}곳';
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
    _updateDateTime();
    _startTimer();
    _initializeDashboard();
    _loadMyApplications();

    // 알림 Provider 초기화 (페이지 새로고침 시에도 알림 수신 가능하도록)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NotificationProvider>();
      if (!provider.isInitialized) {
        provider.initialize();
      }
    });
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

  // 대시보드 초기화: 프로필 로드 → 선호 지역 설정 → 데이터 로드
  Future<void> _initializeDashboard() async {
    await _loadUserProfile();
    await _loadPreferredRegions();
    _loadDashboardData();
  }

  Future<void> _loadUserProfile() async {
    // 서버에서 프로필 정보 가져오기
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}/api/auth/profile'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final userRealName = data['name'] ?? '사용자';
        final userRealNickname = data['nickname'] ?? userRealName;

        // 프로필 전체 데이터 캐시 (PUT 시 전체 필드 전송에 사용)
        _cachedProfileData = Map<String, dynamic>.from(data);

        if (!mounted) return;
        setState(() {
          userName = userRealName;
          userNickname = userRealNickname;
          userAddress = data['address'];
          userLatitude = (data['latitude'] as num?)?.toDouble();
          userLongitude = (data['longitude'] as num?)?.toDouble();
          serverPreferredLocation = data['preferred_location'];
        });

        // 로컬 저장소에도 업데이트
        await PreferencesManager.setUserName(userRealName);
        await PreferencesManager.setUserNickname(userRealNickname);
        return;
      }
    } catch (e) {
      // 웹 환경에서는 CORS 문제로 인해 로컬 데이터 사용
    }

    // 서버 실패 시 로컬에 저장된 이름과 닉네임 사용
    final savedName = await PreferencesManager.getUserName();
    final savedNickname = await PreferencesManager.getUserNickname();
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
    await _loadUserProfile();
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
  Future<void> _refreshUnifiedPostModels() async {
    setState(() {
      isLoadingDonations = true;
    });

    try {
      List<UnifiedPostModel> allUnifiedPostModels = [];

      if (selectedLargeRegions.isEmpty) {
        // 전체 지역 선택인 경우
        final posts = await DashboardService.getPublicPosts(limit: 50);
        allUnifiedPostModels.addAll(posts);
      } else {
        // 선택된 시/도에서 데이터 가져오기
        for (final largeRegion in selectedLargeRegions) {
          final posts = await DashboardService.getPublicPosts(
            limit: 20,
            region: _getSimpleRegionName(largeRegion.name),
          );
          allUnifiedPostModels.addAll(posts);
        }
      }

      // 중복 제거 (postIdx 기준)
      final uniquePosts = <int, UnifiedPostModel>{};
      for (final post in allUnifiedPostModels) {
        uniquePosts[post.id] = post;
      }
      final donationPosts = uniquePosts.values.toList();

      // 헌혈 모집글 정렬 (긴급 우선, 그 다음 최신순)
      final sortedDonations = List<UnifiedPostModel>.from(donationPosts);
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

  // 내 신청 목록 로드
  Future<void> _loadMyApplications() async {
    try {
      final applications =
          await AppliedDonationService.getMyApplicationsFromServer();

      if (mounted) {
        setState(() {
          myApplicationsMap = {
            for (final app in applications)
              if (app.shouldShowAppliedBorder) app.postTimesIdx: app,
          };
        });
      }

    } catch (e) {
      // 내 신청 목록 로드 실패 시 무시
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
      List<UnifiedPostModel> allUnifiedPostModels = [];

      if (selectedLargeRegions.isEmpty) {
        // 전체 지역 선택인 경우
        final posts = await DashboardService.getPublicPosts(limit: 10);
        allUnifiedPostModels.addAll(posts);
      } else {
        // 선택된 시/도에서 데이터 가져오기 (초기 로딩이므로 제한적으로)
        for (final largeRegion in selectedLargeRegions.take(3)) {
          final posts = await DashboardService.getPublicPosts(
            limit: 5,
            region: _getSimpleRegionName(largeRegion.name),
          );
          allUnifiedPostModels.addAll(posts);
        }
      }

      // 중복 제거
      final uniquePosts = <int, UnifiedPostModel>{};
      for (final post in allUnifiedPostModels) {
        uniquePosts[post.id] = post;
      }
      final donationPosts = uniquePosts.values.take(10).toList();

      // 칼럼과 공지사항은 별도로 로딩
      final futures = await Future.wait([
        DashboardService.getPublicColumns(
          limit: DashboardService.dashboardColumnLimit,
        ),
        // 사용자는 인증된 API 사용 (targetAudience 0, 3 포함)
        DashboardService.getAuthenticatedNotices(
          limit: DashboardService.dashboardNoticeLimit,
        ),
      ]);

      final columnPosts = futures[0] as List<ColumnPost>;
      final noticePosts = futures[1] as List<NoticePost>;

      // 헌혈 모집글 정렬 (긴급 우선, 그 다음 최신순)
      final sortedDonations = List<UnifiedPostModel>.from(donationPosts);
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
              contentDelta: column.contentDelta,
              hospitalName: column.authorName, // 병원 실명
              hospitalIdx: 0,
              isPublished: true,
              viewCount: column.viewCount,
              createdAt: column.createdAt,
              updatedAt: column.updatedAt,
              authorNickname: column.authorNickname, // 병원 닉네임
              columnUrl: column.columnUrl,
            );
          }).toList();

      sortedColumns.sort((a, b) {
        final aImportant = a.title.contains('[중요]') || a.title.contains('[공지]');
        final bImportant = b.title.contains('[중요]') || b.title.contains('[공지]');
        if (aImportant && !bImportant) return -1;
        if (!aImportant && bImportant) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      final topColumns =
          sortedColumns.take(DashboardService.dashboardColumnLimit).toList();

      // 공지사항 필터링 및 정렬 (청중 타겟이 전체(0) 또는 사용자(3)만)
      // 서버가 이미 noticeActive=True만 반환하므로 추가 필터링 불필요
      final sortedNotices =
          noticePosts
              .where(
                (notice) =>
                    notice.targetAudience == AppConstants.noticeTargetAll ||
                    notice.targetAudience == AppConstants.noticeTargetUser,
              )
              .map((notice) {
                return Notice(
                  noticeIdx: notice.noticeIdx,
                  accountIdx: 0, // DashboardService에서 제공하지 않는 필드
                  title: notice.title,
                  content: notice.contentPreview,
                  noticeImportant: notice.noticeImportant, // 0=뱃지 표시, 1=뱃지 숨김
                  noticeActive: true,
                  createdAt: notice.createdAt,
                  updatedAt: notice.updatedAt,
                  authorEmail: notice.authorEmail,
                  authorName: notice.authorName,
                  authorNickname: notice.authorNickname, // 작성자 닉네임
                  viewCount: notice.viewCount,
                  targetAudience: notice.targetAudience,
                  noticeUrl: notice.noticeUrl,
                );
              })
              .toList();

      sortedNotices.sort((a, b) {
        if (a.showBadge && !b.showBadge) return -1;
        if (!a.showBadge && b.showBadge) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      final topNotices =
          sortedNotices.take(DashboardService.dashboardNoticeLimit).toList();

      if (!mounted) return;
      setState(() {
        donations = sortedDonations.take(10).toList();
        columns = topColumns;
        notices = topNotices;
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

  // 선호 지역을 SharedPreferences에 저장 + 서버 동기화
  Future<void> _savePreferredRegions() async {
    final largeRegionCodes = selectedLargeRegions.map((r) => r.code).toList();
    await PreferencesManager.setPreferredLargeRegions(largeRegionCodes);

    // 지역 설정 초기화 플래그 (한 번이라도 설정하면 자동 설정 안 함)
    await PreferencesManager.setRegionInitialized(true);

    // 서버에 preferred_location 동기화
    _syncPreferredLocationToServer();
  }

  // 서버에 선호 지역 동기화 (전체 프로필 필드와 함께 전송)
  // PUT /api/auth/profile은 전체 덮어쓰기 방식이므로 모든 필드를 포함해야 함
  Future<void> _syncPreferredLocationToServer() async {
    try {
      final regionNames = selectedLargeRegions
          .map((r) => _getSimpleRegionName(r.name))
          .join(',');

      // 캐시된 프로필 데이터가 없으면 서버에서 최신 데이터 가져오기
      if (_cachedProfileData == null) {
        final response = await AuthHttpClient.get(
          Uri.parse('${Config.serverUrl}/api/auth/profile'),
        );
        if (response.statusCode == 200) {
          _cachedProfileData = json.decode(utf8.decode(response.bodyBytes));
        } else {
          debugPrint('프로필 조회 실패, 선호 지역 동기화 중단');
          return;
        }
      }

      // 기존 프로필 데이터에 preferred_location만 업데이트하여 전송
      final profileData = {
        'name': _cachedProfileData!['name'],
        'nickname': _cachedProfileData!['nickname'],
        'phone_number': _cachedProfileData!['phone_number'],
        'address': _cachedProfileData!['address'],
        'latitude': _cachedProfileData!['latitude'],
        'longitude': _cachedProfileData!['longitude'],
        'preferred_location': regionNames.isEmpty ? null : regionNames,
      };

      await AuthHttpClient.put(
        Uri.parse('${Config.serverUrl}/api/auth/profile'),
        body: jsonEncode(profileData),
      );

      // 캐시도 업데이트
      _cachedProfileData!['preferred_location'] =
          regionNames.isEmpty ? null : regionNames;
    } catch (e) {
      debugPrint('선호 지역 서버 동기화 실패: $e');
    }
  }

  // SharedPreferences에서 선호 지역 불러오기
  Future<void> _loadPreferredRegions() async {
    final isRegionInitialized = await PreferencesManager.isRegionInitialized();

    // 시/도 코드 목록 불러오기
    final largeRegionCodes =
        await PreferencesManager.getPreferredLargeRegions();

    // 코드를 Region 객체로 변환
    final loadedLargeRegions = <Region>[];

    for (final code in largeRegionCodes) {
      final largeRegion =
          RegionData.regions.where((r) => r.code == code).firstOrNull;
      if (largeRegion != null) {
        loadedLargeRegions.add(largeRegion);
      }
    }

    // 서버에 지역이 있고 로컬이 비어있으면 → 서버 데이터로 로컬 초기화 (다른 기기 지원)
    if (loadedLargeRegions.isEmpty &&
        serverPreferredLocation != null &&
        serverPreferredLocation!.isNotEmpty) {
      final serverRegions = _parseServerPreferredLocation(serverPreferredLocation!);
      if (serverRegions.isNotEmpty) {
        loadedLargeRegions.addAll(serverRegions);
        final codes = serverRegions.map((r) => r.code).toList();
        await PreferencesManager.setPreferredLargeRegions(codes);
        await PreferencesManager.setRegionInitialized(true);
      }
    }

    if (mounted) {
      setState(() {
        selectedLargeRegions = loadedLargeRegions;
      });
    }

    // 마이그레이션: 로컬에는 있고 서버에는 없으면 서버에 동기화
    if (loadedLargeRegions.isNotEmpty &&
        (serverPreferredLocation == null || serverPreferredLocation!.isEmpty)) {
      _syncPreferredLocationToServer();
    }

    // 선호 지역을 한 번도 설정하지 않은 경우 → 주소 기반 기본 지역 자동 설정
    if (!isRegionInitialized &&
        loadedLargeRegions.isEmpty &&
        userAddress != null) {
      await _setDefaultRegionFromAddress(userAddress!);
    }
  }

  // 서버 preferred_location 문자열을 Region 객체 리스트로 변환
  // 예: "서울,경기,인천" → [Region(seoul), Region(gyeonggi), Region(incheon)]
  List<Region> _parseServerPreferredLocation(String preferredLocation) {
    // 간단명칭 → region code 매핑 (역방향)
    const simpleNameToCode = {
      '서울': 'seoul',
      '부산': 'busan',
      '대구': 'daegu',
      '인천': 'incheon',
      '광주': 'gwangju',
      '대전': 'daejeon',
      '울산': 'ulsan',
      '세종': 'sejong',
      '경기': 'gyeonggi',
      '강원': 'gangwon',
      '충북': 'chungbuk',
      '충남': 'chungnam',
      '전북': 'jeonbuk',
      '전남': 'jeonnam',
      '경북': 'gyeongbuk',
      '경남': 'gyeongnam',
      '제주': 'jeju',
    };

    final regions = <Region>[];
    final names = preferredLocation.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);

    for (final name in names) {
      final code = simpleNameToCode[name];
      if (code != null) {
        final region = RegionData.regions.where((r) => r.code == code).firstOrNull;
        if (region != null) {
          regions.add(region);
        }
      }
    }

    return regions;
  }

  // 주소에서 해당 시/도를 판별하여 기본 지역 1개 자동 설정
  Future<void> _setDefaultRegionFromAddress(String address) async {
    // 주소 시작 키워드 → RegionData의 region 코드 매핑
    const addressToRegionCode = {
      '서울': 'seoul',
      '부산': 'busan',
      '대구': 'daegu',
      '인천': 'incheon',
      '광주': 'gwangju',
      '대전': 'daejeon',
      '울산': 'ulsan',
      '세종': 'sejong',
      '경기': 'gyeonggi',
      '강원': 'gangwon',
      '충북': 'chungbuk',
      '충청북': 'chungbuk',
      '충남': 'chungnam',
      '충청남': 'chungnam',
      '전북': 'jeonbuk',
      '전라북': 'jeonbuk',
      '전남': 'jeonnam',
      '전라남': 'jeonnam',
      '경북': 'gyeongbuk',
      '경상북': 'gyeongbuk',
      '경남': 'gyeongnam',
      '경상남': 'gyeongnam',
      '제주': 'jeju',
    };

    // 주소에서 시/도 코드 판별
    String? regionCode;
    for (final entry in addressToRegionCode.entries) {
      if (address.startsWith(entry.key)) {
        regionCode = entry.value;
        break;
      }
    }

    if (regionCode == null) {
      return;
    }

    // RegionData에서 해당 Region 객체 조회
    final region =
        RegionData.regions.where((r) => r.code == regionCode).firstOrNull;

    if (region != null && mounted) {
      setState(() {
        selectedLargeRegions = [region];
      });

      // 기본 지역을 SharedPreferences에 저장
      await _savePreferredRegions();
    }
  }

  // 지역 선택 바텀 시트 표시
  void _showRegionSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => RegionSelectionSheet(
            initialSelectedRegions: List.from(selectedLargeRegions),
            onRegionSelected: (selectedRegions) {
              setState(() {
                selectedLargeRegions = selectedRegions;
              });
              // 선호 지역 저장
              _savePreferredRegions();
              // 지역이 변경되면 헌혈 모집 데이터만 새로고침
              _refreshUnifiedPostModels();
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
            _loadUserProfile();
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
    return Column(
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
                    Icon(Icons.announcement, size: 20),
                    SizedBox(width: 8),
                    Text('공지사항'),
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
            ],
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black87,
            dividerColor: Colors.transparent,
          ),
        ),
        // 탭 뷰 - 남은 공간을 모두 채움
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(
              left: AppTheme.spacing16,
              right: AppTheme.spacing16,
              bottom: AppTheme.spacing16,
            ),
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
                _buildNoticeBoard(), // 공지사항 게시판 내용
                _buildColumnBoard(), // 칼럼 게시판 내용
              ],
            ),
          ),
        ),
      ],
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
                          onTap: () => _showUnifiedPostModelBottomSheet(donation),
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
      return const DashboardEmptyState(
        icon: Icons.article_outlined,
        message: '공개된 칼럼이 없습니다',
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
                  return DashboardMoreButton(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserColumnListScreen(),
                        ),
                      );
                    },
                  );
                }

                final column = columns[index];

                return DashboardListItem<HospitalColumn>(
                  item: column,
                  index: index + 1,
                  onTap: () => _showColumnBottomSheet(column),
                  getTitle: (c) => c.title,
                  getAuthor: (c) => c.authorNickname ?? c.hospitalName,
                  getCreatedAt: (c) => c.createdAt,
                  getUpdatedAt: (c) => c.updatedAt,
                  getViewCount: (c) => c.viewCount,
                  shouldShowBadge: (c) => c.title.contains('[중요]') || c.title.contains('[공지]'),
                  getBadgeText: (c) => '중요',
                  enableTextPersonalization: true,
                  userName: userName,
                  userNickname: userNickname,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showColumnBottomSheet(HospitalColumn column) {
    final String? columnUrl = column.columnUrl;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          TextPersonalizationUtil.personalizeTitle(
                            title: column.title,
                            userName: userName,
                            userNickname: userNickname,
                          ),
                          style: AppTheme.h3Style.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black87),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              column.title.contains('[중요]') ||
                                      column.title.contains('[공지]')
                                  ? AppTheme.error
                                  : AppTheme.warning,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          column.title.contains('[중요]') ||
                                  column.title.contains('[공지]')
                              ? '중요'
                              : '칼럼',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          column.authorNickname ?? column.hospitalName,
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '작성: ${DateFormat('yyyy-MM-dd HH:mm').format(column.createdAt)}',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child:
                          column.contentDelta != null &&
                                  column.contentDelta!.isNotEmpty
                              ? RichTextViewer(
                                contentDelta: column.contentDelta,
                                plainText: column.content,
                                padding: EdgeInsets.zero,
                              )
                              : Text(
                                column.content,
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  height: 1.6,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (columnUrl != null && columnUrl.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(columnUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('링크를 열 수 없습니다.'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.open_in_new,
                          color: Colors.black,
                        ),
                        label: const Text('관련 링크 열기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '조회수 ${NumberFormatUtil.formatViewCount(column.viewCount)}회',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        if (!column.updatedAt.isAtSameMomentAs(
                          column.createdAt,
                        ))
                          Text(
                            '수정: ${DateFormat('yyyy-MM-dd HH:mm').format(column.updatedAt)}',
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
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

  // 공지사항 게시판 위젯을 생성합니다.
  Widget _buildNoticeBoard() {
    if (isLoadingNotices) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notices.isEmpty) {
      return const DashboardEmptyState(
        icon: Icons.announcement_outlined,
        message: '공지사항이 없습니다',
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
                  return DashboardMoreButton(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserNoticeListScreen(),
                        ),
                      );
                    },
                  );
                }

                final notice = notices[index];

                return DashboardListItem<Notice>(
                  item: notice,
                  index: index + 1,
                  onTap: () => _showNoticeBottomSheet(context, notice),
                  getTitle: (n) => n.title,
                  getAuthor: (n) => n.authorNickname ?? n.authorName,
                  getCreatedAt: (n) => n.createdAt,
                  getUpdatedAt: (n) => n.updatedAt,
                  getViewCount: (n) => n.viewCount ?? 0,
                  shouldShowBadge: (n) => n.showBadge,
                  getBadgeText: (n) => n.badgeText,
                  enableTextPersonalization: true,
                  userName: userName,
                  userNickname: userNickname,
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

    final bool isImportant =
        (noticeDetail?.noticeImportant ?? notice.noticeImportant) == 0;
    final DateTime createdAt = noticeDetail?.createdAt ?? notice.createdAt;
    final DateTime updatedAt = noticeDetail?.updatedAt ?? notice.updatedAt;
    final int viewCount = noticeDetail?.viewCount ?? notice.viewCount ?? 0;
    final String authorName =
        noticeDetail?.authorNickname ??
        notice.authorNickname ??
        notice.authorName;
    final String title = TextPersonalizationUtil.personalizeTitle(
      title: noticeDetail?.title ?? notice.title,
      userName: userName,
      userNickname: userNickname,
    );
    final String content = TextPersonalizationUtil.personalizeContent(
      content: noticeDetail?.contentPreview ?? notice.content,
      userName: userName,
      userNickname: userNickname,
    );
    final String? noticeUrl = noticeDetail?.noticeUrl ?? notice.noticeUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTheme.h3Style.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                isImportant
                                    ? AppTheme.error
                                    : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black87),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isImportant
                                  ? AppTheme.error
                                  : AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isImportant ? '공지' : '알림',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authorName,
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '작성: ${DateFormat('yyyy-MM-dd HH:mm').format(createdAt)}',
                        style: AppTheme.bodySmallStyle.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(
                        content,
                        style: AppTheme.bodyMediumStyle.copyWith(
                          height: 1.6,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (noticeUrl != null && noticeUrl.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(noticeUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('링크를 열 수 없습니다.'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.open_in_new,
                          color: Colors.black,
                        ),
                        label: const Text('링크 열기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '조회수 ${NumberFormatUtil.formatViewCount(viewCount)}회',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        if (!updatedAt.isAtSameMomentAs(createdAt))
                          Text(
                            '수정: ${DateFormat('yyyy-MM-dd HH:mm').format(updatedAt)}',
                            style: AppTheme.bodySmallStyle.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
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

  // 헌혈 모집 게시글 바텀시트 표시 (상세 페이지와 동일한 형식)
  Future<void> _showUnifiedPostModelBottomSheet(UnifiedPostModel donation) async {
    // 내 신청 목록 새로고침 (중복 신청 방지를 위해)
    await _loadMyApplications();

    // 상세 정보 조회
    final detailPost = await DashboardService.getDonationPostDetail(
      donation.id,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        final displayPost = detailPost ?? donation;

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
                  // 핸들바
                  const PostDetailHandleBar(),

                  // 헤더
                  PostDetailHeader(
                    title: displayPost.title,
                    isUrgent: displayPost.isUrgent,
                    typeText: displayPost.typeText,
                    onClose: () => Navigator.pop(context),
                  ),

                  const Divider(height: 1),

                  // 전체 콘텐츠 (스크롤 가능)
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 메타 정보 (병원명, 주소, 동물, 신청자수, 작성일)
                          PostDetailMetaSection(
                            hospitalName: displayPost.hospitalName,
                            hospitalNickname: displayPost.hospitalNickname,
                            location: displayPost.location,
                            animalType: displayPost.animalType,
                            applicantCount: displayPost.applicantCount,
                            createdAt: displayPost.createdAt,
                          ),

                          // 설명글
                          PostDetailDescription(
                            contentDelta: displayPost.contentDelta,
                            plainText: displayPost.description,
                          ),

                          // 혈액형
                          PostDetailBloodType(
                            bloodType: displayPost.bloodType,
                            isUrgent: displayPost.isUrgent,
                          ),

                          // 헌혈 날짜 정보
                          Text('헌혈 예정일', style: AppTheme.h4Style),
                          const SizedBox(height: 12),
                          if (displayPost.availableDates != null &&
                              displayPost.availableDates!.isNotEmpty) ...[
                            // 날짜/시간 선택 드롭다운
                            _buildDateTimeDropdownWidget(displayPost),
                          ] else if (displayPost.donationDate != null) ...[
                            // 단일 날짜인 경우
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _showDonationApplicationModal(
                                      displayPost,
                                      DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(displayPost.donationDate!),
                                      {
                                        'time':
                                            displayPost.donationDate != null
                                                ? DateFormat('HH:mm').format(
                                                  displayPost.donationDate!,
                                                )
                                                : '',
                                        'post_times_idx': 0,
                                      },
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 20,
                                          color: Colors.black,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                DateFormat(
                                                  'yyyy년 MM월 dd일 EEEE',
                                                  'ko',
                                                ).format(
                                                  displayPost.donationDate!,
                                                ),
                                                style: AppTheme.bodyLargeStyle
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              if (displayPost.donationDate !=
                                                  null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  '예정 시간: ${DateFormat('HH:mm').format(displayPost.donationDate!)}',
                                                  style: AppTheme
                                                      .bodyMediumStyle
                                                      .copyWith(
                                                        color:
                                                            AppTheme
                                                                .textSecondary,
                                                      ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.success.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '신청 가능',
                                            style: AppTheme.bodySmallStyle
                                                .copyWith(
                                                  color: AppTheme.success,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
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
                            ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
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

  // 시간 포맷팅 헬퍼 함수
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

  // 날짜를 "YYYY년 MM월 DD일 O요일" 형태로 포맷팅
  String _formatDateWithWeekday(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      final weekday = weekdays[date.weekday - 1];
      return '${date.year}년 ${date.month}월 ${date.day}일 $weekday요일';
    } catch (e) {
      return dateStr;
    }
  }

  // 날짜/시간 선택 드롭다운 위젯
  Widget _buildDateTimeDropdownWidget(UnifiedPostModel post) {
    if (post.availableDates == null || post.availableDates!.isEmpty) {
      return const SizedBox.shrink();
    }

    // 중복 제거를 위한 처리
    final Map<String, List<Map<String, dynamic>>> uniqueDates = {};
    final Set<String> seenTimeSlots = {};

    for (final entry in post.availableDates!.entries) {
      final dateStr = entry.key;
      final timeSlots = entry.value;

      uniqueDates[dateStr] = [];

      for (final timeSlot in timeSlots) {
        final time = timeSlot['time'] ?? '';
        final team = timeSlot['team'] ?? 0;

        final uniqueKey = '$dateStr-$time-$team';

        if (!seenTimeSlots.contains(uniqueKey)) {
          seenTimeSlots.add(uniqueKey);
          uniqueDates[dateStr]!.add(timeSlot);
        }
      }
    }

    return Column(
      children:
          uniqueDates.entries.map((entry) {
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
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
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
                  trailing: BlinkingIcon(
                    icon: Icons.keyboard_arrow_down,
                    color: Colors.black,
                    size: 24,
                    duration: Duration(milliseconds: 1500),
                  ),
                  children:
                      timeSlots.map<Widget>((timeSlot) {
                        // 내가 이미 신청한 시간대인지 확인
                        final postTimesIdx = timeSlot['post_times_idx'] ?? 0;
                        final myApplication = myApplicationsMap[postTimesIdx];
                        final isAlreadyApplied = myApplication != null;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (isAlreadyApplied) {
                                  // 이미 신청한 시간대 클릭 시 취소 바텀시트 표시
                                  _showCancelApplicationBottomSheet(
                                    myApplication,
                                  );
                                } else {
                                  // 신청하지 않은 시간대 클릭 시 신청 페이지 표시
                                  _showDonationApplicationModal(
                                    post,
                                    dateStr,
                                    timeSlot,
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isAlreadyApplied
                                          ? Colors.red.shade50
                                          : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        isAlreadyApplied
                                            ? Colors.red
                                            : Colors.black,
                                    width: isAlreadyApplied ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      color:
                                          isAlreadyApplied
                                              ? Colors.red
                                              : Colors.black,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatTime(timeSlot['time'] ?? ''),
                                            style: AppTheme.bodyLargeStyle
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      isAlreadyApplied
                                                          ? Colors.red
                                                          : Colors.black,
                                                ),
                                          ),
                                          if (isAlreadyApplied)
                                            Text(
                                              '신청완료 (${myApplication.status})',
                                              style: AppTheme.captionStyle
                                                  .copyWith(
                                                    color: Colors.red,
                                                    fontSize: 11,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isAlreadyApplied
                                          ? Icons.edit_outlined
                                          : Icons.keyboard_arrow_right,
                                      color:
                                          isAlreadyApplied
                                              ? Colors.red
                                              : Colors.black,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
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

  // 헌혈 신청 모달 표시
  void _showDonationApplicationModal(
    UnifiedPostModel post,
    String dateStr,
    Map<String, dynamic> timeSlot,
  ) {
    final displayText =
        '${_formatDateWithWeekday(dateStr)} ${_formatTime(timeSlot['time'] ?? '')}';

    Navigator.pop(context); // 현재 바텀시트 닫기

    // Navigator가 완전히 닫힌 후 다음 프레임에서 새 바텀시트 열기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (context) => DonationApplicationPage(
              post: post,
              selectedDate: dateStr,
              selectedTimeSlot: timeSlot,
              displayText: displayText,
            ),
      );
    });
  }

  // 신청 취소 바텀시트 표시
  void _showCancelApplicationBottomSheet(MyApplicationInfo application) {
    Navigator.pop(context); // 현재 바텀시트 닫기

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showModalBottomSheet<bool>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          final canCancel = application.canCancel;
          bool isCancelling = false;

          return StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 핸들바
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 제목
                    Row(
                      children: [
                        Icon(
                          canCancel
                              ? Icons.cancel_outlined
                              : Icons.info_outline,
                          color: canCancel ? Colors.red : Colors.orange,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          canCancel ? '신청 취소' : '신청 정보',
                          style: AppTheme.h3Style.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 신청 정보 카드
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCancelInfoRow('게시글', application.postTitle),
                          const SizedBox(height: 8),
                          _buildCancelInfoRow(
                            '반려동물',
                            '${application.petName} (${application.speciesText})',
                          ),
                          const SizedBox(height: 8),
                          _buildCancelInfoRow(
                            '헌혈 시간',
                            application.donationTime,
                          ),
                          const SizedBox(height: 8),
                          _buildCancelInfoRow(
                            '상태',
                            application.status,
                            statusColor: _getStatusColor(
                              application.statusCode,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 취소 불가 메시지
                    if (!canCancel) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                application.cancelBlockMessage,
                                style: AppTheme.bodyMediumStyle.copyWith(
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 버튼들
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('닫기'),
                          ),
                        ),
                        if (canCancel) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  isCancelling
                                      ? null
                                      : () async {
                                        setModalState(() {
                                          isCancelling = true;
                                        });
                                        try {
                                          await AppliedDonationService.cancelApplicationToServer(
                                            application.applicationId,
                                          );
                                          if (mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(
                                              this.context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('신청이 취소되었습니다.'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                            _loadMyApplications();
                                          }
                                        } catch (e) {
                                          setModalState(() {
                                            isCancelling = false;
                                          });
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              this.context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '취소 실패: ${e.toString()}',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child:
                                  isCancelling
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('신청 취소'),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
      );
    });
  }

  // 취소 바텀시트용 정보 행
  Widget _buildCancelInfoRow(String label, String value, {Color? statusColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: AppTheme.bodyMediumStyle.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTheme.bodyMediumStyle.copyWith(
              fontWeight: FontWeight.w500,
              color: statusColor ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // 상태 코드별 색상
  Color _getStatusColor(int statusCode) {
    return AppliedDonationStatus.getStatusColorValue(statusCode);
  }
}
