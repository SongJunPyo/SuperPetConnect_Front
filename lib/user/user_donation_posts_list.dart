import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/preferences_manager.dart';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../utils/app_constants.dart';
import '../services/dashboard_service.dart';
import '../models/unified_post_model.dart';
import '../services/applied_donation_service.dart';
import '../models/applied_donation_model.dart';
import '../services/auth_http_client.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/pagination_bar.dart';
import 'cancel_application_bottom_sheet.dart';
import 'donation_application_page.dart';
import 'post_detail_bottom_sheet.dart';
import 'package:intl/intl.dart';
import '../models/region_model.dart';
import '../widgets/region_selection_sheet.dart';
import '../utils/time_format_util.dart';
import '../widgets/post_list/post_list_header.dart';
import '../widgets/post_list/post_list_row.dart';

class UserDonationPostsListScreen extends StatefulWidget {
  /// 알림 탭 등 외부 진입 시 자동으로 상세 시트를 열 게시글 post_idx.
  /// initState에서 단건 fetch (`DashboardService.getDonationPostDetail`)
  /// 후 PostDetailBottomSheet 자동 오픈.
  final int? initialPostIdx;

  const UserDonationPostsListScreen({super.key, this.initialPostIdx});

  @override
  State<UserDonationPostsListScreen> createState() =>
      _UserDonationPostsListScreenState();
}

class _UserDonationPostsListScreenState
    extends State<UserDonationPostsListScreen> {
  List<UnifiedPostModel> filteredPosts = [];
  bool isLoading = true;
  String errorMessage = '';
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  // 지역 필터
  List<Region> selectedLargeRegions = [];

  // 페이징 관련
  final ScrollController _scrollController = ScrollController();
  final List<UnifiedPostModel> _allPosts = [];
  int _currentPage = 1;
  int _totalPages = 1;

  // 내가 신청한 시간대 정보 (postTimesIdx -> MyApplicationInfo)
  Map<int, MyApplicationInfo> myApplicationsMap = {};

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
    _loadMyApplications(); // 내 신청 목록 로드

    // 알림 탭 진입 시 자동으로 해당 게시글 상세 시트 오픈.
    // 리스트 fetch와 독립적으로 단건 detail API로 즉시 진행.
    if (widget.initialPostIdx != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _showPostDetailById(widget.initialPostIdx!);
      });
    }
  }

  /// post_idx만으로 상세 시트를 여는 진입점 (알림 탭 등 외부 진입용).
  /// 게시글이 폐기/비공개라 fetch 실패 시 스낵바로 사용자에게 안내.
  Future<void> _showPostDetailById(int postIdx) async {
    try {
      final detailPost = await DashboardService.getDonationPostDetail(postIdx);
      if (!mounted) return;
      if (detailPost == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('해당 게시글을 찾을 수 없거나 더 이상 공개되지 않습니다.'),
          ),
        );
        return;
      }
      _openDetailSheet(detailPost);
    } catch (e) {
      if (!mounted) return;
      debugPrint('[UserDonationPostsList] initialPostIdx=$postIdx fetch 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글 불러오기 실패. 새로고침해주세요.')),
      );
    }
  }

  /// 위 fetch 분기에서 정상 결과를 받은 경우 시트를 띄우는 헬퍼.
  void _openDetailSheet(UnifiedPostModel detailPost) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return PostDetailBottomSheet(
          displayPost: detailPost,
          myApplicationsMap: myApplicationsMap,
          onTimeSlotApply: _showDonationApplicationPage,
          onCancelApplication: _showCancelApplicationBottomSheet,
          onGeneralApply:
              (p) => _showGeneralDonationApplicationDialog(sheetContext, p),
        );
      },
    );
  }

  // 초기화: 저장된 지역 로드 → 게시글 로드
  Future<void> _initializeAndLoad() async {
    await _loadPreferredRegions();
    _loadDonationPosts();
  }

  // SharedPreferences에서 선호 지역 불러오기
  // 신규 사용자(처음 진입 + 로컬 지역 없음)인 경우 프로필 API에서
  // 서버 preferred_location 또는 가입 주소 기반 자동 설정 시도.
  Future<void> _loadPreferredRegions() async {
    var isRegionInitialized = await PreferencesManager.isRegionInitialized();

    final largeRegionCodes = await PreferencesManager.getPreferredLargeRegions();
    final loadedRegions = <Region>[];
    for (final code in largeRegionCodes) {
      final region = RegionData.regions.where((r) => r.code == code).firstOrNull;
      if (region != null) loadedRegions.add(region);
    }

    // 로컬 지역이 비어있고 한 번도 초기화 안 된 신규 사용자만 프로필 API 호출
    String? userAddress;
    if (loadedRegions.isEmpty && !isRegionInitialized) {
      final profile = await _fetchProfileForRegionInit();
      final serverPreferredLocation = profile?['preferred_location'] as String?;
      userAddress = profile?['address'] as String?;

      // 서버에 지역이 있으면 로컬 초기화 (다른 기기 지원)
      if (serverPreferredLocation != null &&
          serverPreferredLocation.isNotEmpty &&
          serverPreferredLocation != '전체') {
        final serverRegions =
            _parseServerPreferredLocation(serverPreferredLocation);
        if (serverRegions.isNotEmpty) {
          loadedRegions.addAll(serverRegions);
          final codes = serverRegions.map((r) => r.code).toList();
          await PreferencesManager.setPreferredLargeRegions(codes);
          await PreferencesManager.setRegionInitialized(true);
          isRegionInitialized = true;
        }
      }

      // "전체"인 경우에도 초기화 완료로 표시 (주소 기반 자동 설정 방지)
      if (serverPreferredLocation == '전체' && !isRegionInitialized) {
        await PreferencesManager.setRegionInitialized(true);
        isRegionInitialized = true;
      }
    }

    if (mounted) {
      setState(() {
        selectedLargeRegions = loadedRegions;
      });
    }

    // 선호 지역을 한 번도 설정하지 않은 경우 → 가입 주소 기반 기본 시/도 자동 설정
    if (!isRegionInitialized &&
        loadedRegions.isEmpty &&
        userAddress != null) {
      await _setDefaultRegionFromAddress(userAddress);
    }
  }

  // 프로필 API에서 address / preferred_location만 조회 (region 초기화 전용)
  Future<Map<String, dynamic>?> _fetchProfileForRegionInit() async {
    try {
      final response = await AuthHttpClient.get(
        Uri.parse('${Config.serverUrl}/api/auth/profile'),
      );
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[UserDonationPostsList] 프로필 조회 실패: $e');
    }
    return null;
  }

  // 서버 preferred_location 문자열을 Region 객체 리스트로 변환
  // 예: "서울,경기,인천" → [Region(seoul), Region(gyeonggi), Region(incheon)]
  List<Region> _parseServerPreferredLocation(String preferredLocation) {
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
    final names = preferredLocation
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);

    for (final name in names) {
      final code = simpleNameToCode[name];
      if (code != null) {
        final region =
            RegionData.regions.where((r) => r.code == code).firstOrNull;
        if (region != null) regions.add(region);
      }
    }
    return regions;
  }

  // 주소에서 해당 시/도를 판별하여 기본 지역 1개 자동 설정
  Future<void> _setDefaultRegionFromAddress(String address) async {
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

    String? regionCode;
    for (final entry in addressToRegionCode.entries) {
      if (address.startsWith(entry.key)) {
        regionCode = entry.value;
        break;
      }
    }
    if (regionCode == null) return;

    final region =
        RegionData.regions.where((r) => r.code == regionCode).firstOrNull;
    if (region == null || !mounted) return;

    setState(() {
      selectedLargeRegions = [region];
    });

    final codes = [region.code];
    await PreferencesManager.setPreferredLargeRegions(codes);
    await PreferencesManager.setRegionInitialized(true);
    _syncPreferredLocationToServer();
  }

  // 지역 선택 바텀시트
  void _showRegionSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RegionSelectionSheet(
        initialSelectedRegions: List.from(selectedLargeRegions),
        onRegionSelected: (selectedRegions) {
          setState(() {
            selectedLargeRegions = selectedRegions;
            _currentPage = 1;
          });
          // 선택한 지역 저장
          final codes = selectedRegions.map((r) => r.code).toList();
          PreferencesManager.setPreferredLargeRegions(codes);
          // 서버에 선호 지역 동기화
          _syncPreferredLocationToServer();
          // 지역 변경 시 게시글 다시 로드
          _loadDonationPosts();
        },
      ),
    );
  }

  /// 선호 지역을 서버에 동기화
  Future<void> _syncPreferredLocationToServer() async {
    try {
      final regionNames = selectedLargeRegions
          .map((r) => _getSimpleRegionName(r.name))
          .join(',');

      await AuthHttpClient.put(
        Uri.parse('${Config.serverUrl}/api/auth/profile'),
        body: jsonEncode({
          'preferred_location': regionNames.isEmpty ? '전체' : regionNames,
        }),
      );
    } catch (e) {
      debugPrint('선호 지역 서버 동기화 실패: $e');
    }
  }

  // 지역 전체명 → 간단명 변환
  String _getSimpleRegionName(String fullName) {
    const regionMapping = {
      '서울특별시': '서울', '부산광역시': '부산', '대구광역시': '대구',
      '인천광역시': '인천', '광주광역시': '광주', '대전광역시': '대전',
      '울산광역시': '울산', '세종특별자치시': '세종', '경기도': '경기',
      '강원도': '강원', '강원특별자치도': '강원', '충청북도': '충북',
      '충청남도': '충남', '전라북도': '전북', '전북특별자치도': '전북',
      '전라남도': '전남', '경상북도': '경북', '경상남도': '경남',
      '제주특별자치도': '제주',
    };
    return regionMapping[fullName] ?? fullName;
  }

  /// 내 신청 목록 로드
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

      debugPrint(
        '[UserDonationPostsList] 내 신청 목록 로드 완료: ${myApplicationsMap.length}개',
      );
      debugPrint(
        '[UserDonationPostsList] 신청한 시간대 IDs: ${myApplicationsMap.keys.toList()}',
      );
    } catch (e) {
      debugPrint('[UserDonationPostsList] 내 신청 목록 로드 실패: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  /// 페이지 변경 핸들러
  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _loadDonationPosts() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      _allPosts.clear();
      filteredPosts = [];
    });

    try {
      // 선택된 지역에 따라 게시글 로드
      if (selectedLargeRegions.isEmpty) {
        // 전체 지역
        int page = 1;
        bool hasMore = true;
        while (hasMore) {
          final response = await DashboardService.fetchPublicPostsPage(page: page);
          _allPosts.addAll(response.posts);
          hasMore = response.pagination.hasNext;
          page++;
        }
      } else {
        // 선택된 지역별로 로드
        for (final region in selectedLargeRegions) {
          final regionName = _getSimpleRegionName(region.name);
          int page = 1;
          bool hasMore = true;
          while (hasMore) {
            final response = await DashboardService.fetchPublicPostsPage(
              page: page,
              region: regionName,
            );
            _allPosts.addAll(response.posts);
            hasMore = response.pagination.hasNext;
            page++;
          }
        }
        // 중복 제거
        final uniquePosts = <int, UnifiedPostModel>{};
        for (final post in _allPosts) {
          uniquePosts[post.id] = post;
        }
        _allPosts.clear();
        _allPosts.addAll(uniquePosts.values);
      }

      if (!mounted) return;
      setState(() {
        _currentPage = 1;
        _filterPosts();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = '헌혈 모집글을 불러오는데 실패했습니다: $e';
        isLoading = false;
      });
    }
  }

  void _filterPosts() {
    List<UnifiedPostModel> filtered = _allPosts;

    // 검색어 필터링
    if (searchQuery.isNotEmpty) {
      filtered =
          filtered.where((post) {
            return post.title.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                post.hospitalName.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                post.location.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();
    }

    // 날짜 범위 필터링
    if (startDate != null && endDate != null) {
      filtered = filtered.where((post) {
        final dateOnly = DateTime(post.createdDate.year, post.createdDate.month, post.createdDate.day);
        final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
        final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
        return !dateOnly.isBefore(start) && !dateOnly.isAfter(end);
      }).toList();
    }

    // 최신순 정렬
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // 클라이언트 측 페이지네이션 계산
    const pageSize = AppConstants.detailListPageSize;
    _totalPages = (filtered.length / pageSize).ceil().clamp(1, 999);
    if (_currentPage > _totalPages) _currentPage = _totalPages;

    final startIndex = (_currentPage - 1) * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, filtered.length);

    setState(() {
      filteredPosts = filtered.sublist(startIndex, endIndex);
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
      _currentPage = 1;
    });
    _filterPosts();
  }

  // 날짜 범위 선택 함수
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange:
          startDate != null && endDate != null
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
        _currentPage = 1;
      });
      _filterPosts();
    }
  }

  // 종에 맞지 않는 반려동물 안내 바텀시트
  void _showIncompatiblePetBottomSheet(String requiredAnimalType) {
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
              children: [
                Icon(
                  Icons.info_outline,
                  size: 48,
                  color: Colors.orange.shade600,
                ),
                const SizedBox(height: 16),
                Text(
                  '헌혈 신청 불가',
                  style: AppTheme.h3Style.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '이 헌혈 요청은 $requiredAnimalType 전용입니다.\n등록하신 반려동물 중 참여 가능한 $requiredAnimalType가 없습니다.',
                  style: AppTheme.bodyLargeStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 20,
                            color: AppTheme.primaryBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '다른 헌혈 요청을 찾아보세요',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '메인 화면에서 귀하의 반려동물에게 맞는 다른 헌혈 요청을 확인해보세요.',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // 사용자 반려동물 목록 가져오기
  Future<List<Map<String, dynamic>>> _fetchUserPets() async {
    final petsResponse = await AuthHttpClient.get(
      Uri.parse('${Config.serverUrl}/api/pets'),
    );

    if (petsResponse.statusCode == 200) {
      final petsList = petsResponse.parseJsonList();

      // 반려동물 정보 매핑 (DB 스키마 기준)
      return petsList
          .map<Map<String, dynamic>>(
            (pet) => {
              'pet_idx': pet['pet_idx'],
              'name': pet['name'] ?? '',
              'species': pet['species'] ?? '',
              'animal_type': pet['animal_type'], // 0=강아지, 1=고양이
              'breed': pet['breed'],
              'blood_type': pet['blood_type'],
              'birth_date': pet['birth_date'],
              'weight_kg': (pet['weight_kg'] ?? 0.0).toDouble(),
              'sex': pet['sex'],
              'pregnancy_birth_status': pet['pregnancy_birth_status'] ?? 0,
              'last_pregnancy_end_date': pet['last_pregnancy_end_date'],
              'vaccinated': pet['vaccinated'] ?? false,
              'has_disease': pet['has_disease'] ?? false,
            },
          )
          .toList();
    } else {
      throw Exception('반려동물 목록을 불러올 수 없습니다.');
    }
  }

  // 일반 헌혈 신청 제출 (단일 날짜/시간 버전)
  Future<void> _submitGeneralDonationApplication(UnifiedPostModel post) async {
    try {
      // 사용자 반려동물 목록 가져오기
      final userPets = await _fetchUserPets();
      if (userPets.isEmpty) {
        throw Exception('등록된 반려동물이 없습니다. 먼저 반려동물을 등록해주세요.');
      }

      // 헌혈 가능한 반려동물 필터링 (동물 종류 매칭)
      final availablePets =
          userPets.where((pet) {
            // 동물 종류 매칭 (새로운 animal_type 필드 사용)
            bool animalTypeMatch = pet['animal_type'] == post.animalType;

            // animal_type이 null인 경우 기존 species로 매칭 (하위 호환성)
            if (pet['animal_type'] == null) {
              if (post.animalType == 0) {
                // 강아지
                animalTypeMatch = pet['species'] == '강아지';
              } else if (post.animalType == 1) {
                // 고양이
                animalTypeMatch = pet['species'] == '고양이';
              }
            }

            return animalTypeMatch;
          }).toList();

      if (availablePets.isEmpty) {
        final animalTypeStr = post.animalType == 0 ? '강아지' : '고양이';
        _showIncompatiblePetBottomSheet(animalTypeStr);
        return;
      }

      // 첫 번째 매칭되는 반려동물로 신청 (추후 선택 UI로 개선 가능)
      final petIdx = availablePets.first['pet_idx'];

      // post.availableDates에서 첫 번째 사용 가능한 post_times_idx 추출
      int? postTimesIdx;
      if (post.availableDates != null && post.availableDates!.isNotEmpty) {
        final sortedDates = post.availableDates!.keys.toList()..sort();
        final firstDateSlots = post.availableDates![sortedDates.first];
        if (firstDateSlots != null && firstDateSlots.isNotEmpty) {
          postTimesIdx = firstDateSlots.first['post_times_idx'];
        }
      }

      if (postTimesIdx == null || postTimesIdx == 0) {
        throw Exception('신청 가능한 시간대 정보를 찾을 수 없습니다.');
      }

      final response = await AuthHttpClient.post(
        Uri.parse('${Config.serverUrl}/api/donation/apply'),
        body: jsonEncode({
          'post_times_idx': postTimesIdx,
          'pet_idx': petIdx,
          'applicant_message': '우리 반려동물이 건강하게 헌혈에 참여하고 싶습니다.',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data['success'] == true) {
          // 성공 시 별도의 스낵바 메시지 표시하지 않음
        } else {
          throw Exception(data['message'] ?? '신청 처리 중 오류가 발생했습니다.');
        }
      } else {
        throw response.extractErrorMessage('신청 처리 중 오류가 발생했습니다.');
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.error),
                const SizedBox(width: 8),
                const Text('신청 실패'),
              ],
            ),
            content: Text(errorMsg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  // 일반 헌혈 신청 다이얼로그 (단일 날짜/시간 버전)
  void _showGeneralDonationApplicationDialog(
    BuildContext context,
    UnifiedPostModel post,
  ) {
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
                '헌혈 신청 확인',
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: Colors.black,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '헌혈 예정일시',
                          style: AppTheme.bodySmallStyle.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (post.donationDate != null) ...[
                      Text(
                        DateFormat(
                          'yyyy년 MM월 dd일 (EEEE)',
                          'ko',
                        ).format(post.donationDate!),
                        style: AppTheme.bodyMediumStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (post.donationDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '예정 시간: ${DateFormat('HH:mm').format(post.donationDate!)}',
                          style: AppTheme.bodyMediumStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ] else ...[
                      Text(
                        '헌혈 날짜가 아직 확정되지 않았습니다.',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '이 일정에 맞춰 헌혈 신청하시겠습니까?',
                style: AppTheme.bodyMediumStyle.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '신청 후 병원에서 상세 일정을 안내해드립니다.',
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
                _submitGeneralDonationApplication(post);
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

  Future<void> _showPostDetail(UnifiedPostModel post) async {
    // 상세 정보 조회
    final detailPost = await DashboardService.getDonationPostDetail(
      post.id,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return PostDetailBottomSheet(
          displayPost: detailPost ?? post,
          myApplicationsMap: myApplicationsMap,
          onTimeSlotApply: _showDonationApplicationPage,
          onCancelApplication: _showCancelApplicationBottomSheet,
          onGeneralApply:
              (p) => _showGeneralDonationApplicationDialog(sheetContext, p),
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
            // 지역 선택 토글 — 모양은 outlined로 고정, 상태는 색만으로 표시.
            icon: Icon(
              Icons.location_on_outlined,
              color: selectedLargeRegions.isEmpty
                  ? Colors.black87
                  : AppTheme.primaryBlue,
            ),
            tooltip: selectedLargeRegions.isEmpty
                ? '지역 선택'
                : selectedLargeRegions.length == 1
                    ? selectedLargeRegions.first.name
                    : '${selectedLargeRegions.first.name} 외 ${selectedLargeRegions.length - 1}곳',
            onPressed: _showRegionSelectionSheet,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, color: Colors.black87),
            tooltip: '날짜 범위 선택',
            onPressed: _selectDateRange,
          ),
          if (startDate != null && endDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.black87),
              tooltip: '날짜 필터 초기화',
              onPressed: () {
                setState(() {
                  startDate = null;
                  endDate = null;
                  _currentPage = 1;
                });
                _filterPosts();
              },
            ),
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
            child: AppSearchBar(
              controller: searchController,
              hintText: '게시글 제목, 병원명, 위치로 검색...',
              onChanged: _onSearchChanged,
              onClear: () {
                _onSearchChanged('');
              },
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
                style: AppTheme.bodyMediumStyle.copyWith(
                  color: Colors.grey[600],
                ),
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
      const String emptyMessage = '헌혈 모집글이 없습니다.';

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

    final int paginationBarCount = _totalPages > 1 ? 1 : 0;

    return RefreshIndicator(
      onRefresh: () => _loadDonationPosts(),
      child: ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: filteredPosts.length + 1 + paginationBarCount, // 헤더 + 아이템 + 페이지네이션
      itemBuilder: (context, index) {
        // 첫 번째 아이템은 헤더
        if (index == 0) {
          return const PostListHeader();
        }

        // 게시글 범위를 벗어나면 페이지네이션 바
        if (index > filteredPosts.length) {
          return PaginationBar(
            currentPage: _currentPage,
            totalPages: _totalPages,
            onPageChanged: _onPageChanged,
          );
        }

        // 나머지는 게시글 아이템
        final post = filteredPosts[index - 1];
        return _buildPostListItem(post);
      },
    ),
    );
  }

  Widget _buildPostListItem(UnifiedPostModel post) {
    return PostListRow(
      badgeType: post.isUrgent ? '긴급' : '정기',
      title: post.title,
      dateText: TimeFormatUtils.formatShortDate(post.createdAt),
      titleColor: post.isUrgent ? Colors.red.shade700 : null,
      hospitalProfileImage: post.hospitalProfileImage,
      onTap: () => _showPostDetail(post),
    );
  }

  // 새로운 헌혈 신청 페이지 모달 (전체 화면)
  void _showDonationApplicationPage(
    String dateStr,
    Map<String, dynamic> timeSlot,
    String displayText,
    UnifiedPostModel post,
  ) async {
    final result = await showModalBottomSheet<dynamic>(
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

    if (result is Map && mounted) {
      if (result['success'] == true) {
        // 신청 성공 → 내 신청 목록 새로고침 + 성공 알림
        _loadMyApplications();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600),
                const SizedBox(width: 8),
                const Text('신청 완료'),
              ],
            ),
            content: const Text('헌혈 신청이 완료되었습니다.\n관리자 승인 후 알림을 보내드립니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      } else if (result['error'] != null) {
        // 신청 실패 → 에러 알림
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.error),
                const SizedBox(width: 8),
                const Text('신청 실패'),
              ],
            ),
            content: Text(
              result['error'].toString(),
              style: AppTheme.bodyMediumStyle,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// 신청 취소 바텀시트 표시
  void _showCancelApplicationBottomSheet(MyApplicationInfo application) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return CancelApplicationBottomSheet(
          application: application,
          onCancelSuccess: () {
            // 바텀시트 닫으면서 true 반환
            Navigator.pop(context, true);
          },
        );
      },
    ).then((cancelled) {
      // 바텀시트가 닫힌 후 취소 성공 시 새로고침
      if (cancelled == true && mounted) {
        // 게시글 상세 바텀시트도 닫기 (UI 새로고침을 위해)
        Navigator.pop(context);

        _loadMyApplications();

        // 취소 성공 메시지 표시
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600),
                const SizedBox(width: 8),
                const Text('완료'),
              ],
            ),
            content: const Text('신청이 취소되었습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    });
  }
}
