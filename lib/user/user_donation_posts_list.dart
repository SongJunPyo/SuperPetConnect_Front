import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../utils/config.dart';
import '../services/dashboard_service.dart';
import '../widgets/marquee_text.dart';
import '../utils/number_format_util.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/pet_model.dart';
import 'pet_register.dart';

class UserDonationPostsListScreen extends StatefulWidget {
  final DonationPost? initialPost; // 초기에 표시할 게시글
  final bool autoShowBottomSheet; // 자동으로 바텀 시트 표시 여부

  const UserDonationPostsListScreen({
    super.key,
    this.initialPost,
    this.autoShowBottomSheet = false,
  });

  @override
  State<UserDonationPostsListScreen> createState() =>
      _UserDonationPostsListScreenState();
}

class _UserDonationPostsListScreenState
    extends State<UserDonationPostsListScreen>
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

  @override
  void initState() {
    super.initState();

    // initialPost가 있으면 해당 탭으로 자동 이동
    if (widget.initialPost != null) {
      _currentTabIndex = widget.initialPost!.isUrgent ? 0 : 1; // 0=긴급, 1=정기
    }

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _currentTabIndex,
    );
    _tabController.addListener(_handleTabChange);

    _loadDonationPosts();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging ||
        _tabController.index != _currentTabIndex) {
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
      // 모든 헌혈 모집글을 가져옵니다 (limit을 크게 설정)
      final posts = await DashboardService.getPublicPosts(limit: 100);

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

    // 탭에 따른 필터링
    if (_currentTabIndex == 0) {
      // 긴급 탭: 긴급 게시글만 표시 (types == 0)
      filtered = filtered.where((post) => post.types == 0).toList();
    } else {
      // 정기 탭: 정기 게시글만 표시 (types == 1)
      filtered = filtered.where((post) => post.types == 1).toList();
    }

    // 검색어 필터링
    if (searchQuery.isNotEmpty) {
      final beforeSearch = filtered.length;
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
  void _showTimeSelectionDialog(
    BuildContext context,
    DonationPost post,
    String selectedDate,
  ) {
    // 새로운 availableDates 구조 사용
    final List<Map<String, dynamic>>? timeSlots =
        post.availableDates?[selectedDate];

    for (int i = 0; i < (timeSlots?.length ?? 0); i++) {
      final timeSlot = timeSlots![i];
    }

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
              Text('시간을 선택하세요:', style: AppTheme.bodyMediumStyle),
              const SizedBox(height: 12),
              // 실제 API에서 가져온 시간대 정보 표시
              ...timeSlots
                  .map(
                    (timeSlot) => Container(
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
                          final postTimesIdx = timeSlot['post_times_idx'] ?? 0;
                          final time = timeSlot['time'] ?? '';
                          final datetime = timeSlot['datetime'] ?? '';
                          _showDonationApplicationDialog(
                            context,
                            post,
                            selectedDate,
                            postTimesIdx,
                            time,
                            datetime,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _formatTime(timeSlot['time'] ?? ''),
                            style: AppTheme.bodyMediumStyle.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    '취소',
                    style: AppTheme.bodyMediumStyle.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 헌혈 신청 다이얼로그 표시 (시간대 선택 버전)
  void _showDonationApplicationDialog(
    BuildContext context,
    DonationPost post,
    String selectedDate,
    int postTimesIdx,
    String time,
    String datetime,
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
                      '$selectedDate ${_formatTime(time)}',
                      style: AppTheme.bodyLargeStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('신청을 진행하시겠습니까?', style: AppTheme.bodyMediumStyle),
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
                _submitDonationApplication(
                  post,
                  selectedDate,
                  postTimesIdx,
                  time,
                  datetime,
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
                            color: Colors.blue.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '다른 헌혈 요청을 찾아보세요',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade600,
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final petsResponse = await http.get(
      Uri.parse('${Config.serverUrl}/api/user/pets'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );

    if (petsResponse.statusCode == 200) {
      final petsData = jsonDecode(utf8.decode(petsResponse.bodyBytes));

      // 반려동물 정보 매핑 (DB 스키마 기준)
      return (petsData['data'] as List<dynamic>)
          .map<Map<String, dynamic>>(
            (pet) => {
              'pet_idx': pet['pet_idx'],
              'name': pet['name'] ?? '',
              'species': pet['species'] ?? '',
              'animal_type': pet['animal_type'], // 0=강아지, 1=고양이
              'breed': pet['breed'],
              'blood_type': pet['blood_type'],
              'age_number': pet['age_number'] ?? 0,
              'weight_kg': (pet['weight_kg'] ?? 0.0).toDouble(),
              'pregnant': pet['pregnant'] ?? false,
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
  Future<void> _submitGeneralDonationApplication(DonationPost post) async {
    try {
      // SharedPreferences에서 JWT 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('로그인이 필요합니다. 다시 로그인해주세요.');
      }

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

      final response = await http.post(
        Uri.parse('${Config.serverUrl}/api/donation/apply/general'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'post_idx': post.postIdx,
          'pet_idx': petIdx,
          'applicant_message': '우리 반려동물이 건강하게 헌혈에 참여하고 싶습니다.',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data['success'] == true) {
          // 성공 시 별도의 스낵바 메시지 표시하지 않음
        } else {
          throw Exception(data['message'] ?? '신청 처리 중 오류가 발생했습니다.');
        }
      } else {
        throw Exception('서버 연결 오류 (상태코드: ${response.statusCode})');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('신청 중 오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  // 시간대 별 헌혈 신청 제출 (실제 API 호출)
  Future<void> _submitDonationApplication(
    DonationPost post,
    String selectedDate,
    int postTimesIdx,
    String time,
    String datetime,
  ) async {
    try {
      // SharedPreferences에서 JWT 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('로그인이 필요합니다. 다시 로그인해주세요.');
      }

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

      final response = await http.post(
        Uri.parse('${Config.serverUrl}/api/donation/apply'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // 실제 JWT 토큰 사용
        },
        body: jsonEncode({
          'post_times_idx': postTimesIdx,
          'pet_idx': petIdx,
          'applicant_message': '우리 반려동물이 건강하게 헌혈에 참여하고 싶습니다.',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data['success'] == true) {
          // 성공 시 별도의 스낵바 메시지 표시하지 않음
        } else {
          throw Exception(data['message'] ?? '신청 처리 중 오류가 발생했습니다.');
        }
      } else {
        throw Exception('서버 연결 오류 (상태코드: ${response.statusCode})');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('신청 중 오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  // 일반 헌혈 신청 다이얼로그 (단일 날짜/시간 버전)
  void _showGeneralDonationApplicationDialog(
    BuildContext context,
    DonationPost post,
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
                  color: AppTheme.lightBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
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
                      if (post.donationTime != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '예정 시간: ${DateFormat('HH:mm').format(post.donationTime!)}',
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

  Future<void> _showPostDetail(DonationPost post) async {
    // 상세 정보 조회
    final detailPost = await DashboardService.getDonationPostDetail(
      post.postIdx,
    );

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
                            color:
                                displayPost.isUrgent
                                    ? Colors.red.withOpacity(0.15)
                                    : Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            displayPost.typeText,
                            style: AppTheme.bodySmallStyle.copyWith(
                              color:
                                  displayPost.isUrgent
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
                                displayPost.title,
                                style: AppTheme.h3Style.copyWith(
                                  color:
                                      displayPost.isUrgent
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

                  // 메타 정보 (닉네임, 주소, 설명글 순서)
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
                              displayPost.hospitalNickname ??
                                  displayPost.hospitalName ??
                                  '병원',
                              style: AppTheme.bodyMediumStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat(
                                'yy.MM.dd',
                              ).format(displayPost.createdAt),
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
                          if (displayPost.emergencyBloodType != null &&
                              displayPost.emergencyBloodType!.isNotEmpty) ...[
                            Text('필요 혈액형', style: AppTheme.h4Style),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    displayPost.isUrgent
                                        ? Colors.red.shade50
                                        : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      displayPost.isUrgent
                                          ? Colors.red.shade200
                                          : Colors.blue.shade200,
                                ),
                              ),
                              child: Text(
                                displayPost.displayBloodType,
                                style: AppTheme.h3Style.copyWith(
                                  color:
                                      displayPost.isUrgent
                                          ? Colors.red
                                          : Colors.blue,
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
                          if (displayPost.availableDates != null &&
                              displayPost.availableDates!.isNotEmpty) ...[
                            // 디버그: availableDates 구조 확인
                            Builder(
                              builder: (context) {
                                if (displayPost.availableDates != null) {
                                  for (final entry
                                      in displayPost.availableDates!.entries) {
                                    for (
                                      int i = 0;
                                      i < entry.value.length;
                                      i++
                                    ) {
                                      final timeSlot = entry.value[i];
                                    }
                                  }
                                } else {}

                                return Container(); // 빈 위젯
                              },
                            ),

                            // 새로운 드롭다운 형태의 날짜/시간 선택 UI
                            _buildDateTimeDropdown(displayPost),
                          ] else if (displayPost.donationDate != null) ...[
                            // 단일 날짜인 경우에도 클릭 가능하게 만들기
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    // 단일 날짜의 경우 바로 일반 신청 다이얼로그 표시
                                    _showGeneralDonationApplicationDialog(
                                      context,
                                      displayPost,
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
                                              if (displayPost.donationTime !=
                                                  null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  '예정 시간: ${DateFormat('HH:mm').format(displayPost.donationTime!)}',
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
                                            color: AppTheme.success.withOpacity(
                                              0.1,
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
      String emptyMessage =
          _currentTabIndex == 0 ? '긴급 헌혈 모집글이 없습니다.' : '정기 헌혈 모집글이 없습니다.';

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
                    '작성일',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 6.0,
                  vertical: 2.0,
                ),
                decoration: BoxDecoration(
                  color:
                      post.isUrgent
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
                    color:
                        post.isUrgent
                            ? Colors.red.shade700
                            : AppTheme.textPrimary,
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
                post.hospitalNickname ??
                    (post.hospitalName.isNotEmpty ? post.hospitalName : '병원'),
                style: AppTheme.bodySmallStyle.copyWith(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),

            // 작성날짜
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

  // 날짜별 그룹화된 확장 가능한 드롭다운 UI
  Widget _buildDateTimeDropdown(DonationPost post) {
    if (post.availableDates == null || post.availableDates!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children:
          post.availableDates!.entries.map((entry) {
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
                  trailing: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.black,
                    size: 24,
                  ),
                  children:
                      timeSlots.map<Widget>((timeSlot) {
                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                final displayText =
                                    '${_formatDateWithWeekday(dateStr)} ${_formatTime(timeSlot['time'] ?? '')}';
                                _showDonationApplicationPage(
                                  dateStr,
                                  timeSlot,
                                  displayText,
                                  post,
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.0,
                                  ),
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
                                        _formatTime(timeSlot['time'] ?? ''),
                                        style: AppTheme.bodyLargeStyle.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_right,
                                      color: Colors.black,
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

  // 새로운 헌혈 신청 페이지 모달 (전체 화면)
  void _showDonationApplicationPage(
    String dateStr,
    Map<String, dynamic> timeSlot,
    String displayText,
    DonationPost post,
  ) {
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
  }

  // 헌혈 신청 처리
  void _processDonationApplication(
    DonationPost post,
    Map<String, dynamic> timeSlot,
  ) {
    // TODO: 실제 API 호출 구현
    // 성공 시 별도의 스낵바 메시지 표시하지 않음
  }
}

// 새로운 헌혈 신청 페이지 위젯
class DonationApplicationPage extends StatefulWidget {
  final DonationPost post;
  final String selectedDate;
  final Map<String, dynamic> selectedTimeSlot;
  final String displayText;

  const DonationApplicationPage({
    super.key,
    required this.post,
    required this.selectedDate,
    required this.selectedTimeSlot,
    required this.displayText,
  });

  @override
  State<DonationApplicationPage> createState() =>
      _DonationApplicationPageState();
}

class _DonationApplicationPageState extends State<DonationApplicationPage> {
  Map<String, dynamic>? selectedPet;
  List<Map<String, dynamic>> userPets = [];
  Map<String, dynamic>? userInfo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndPets();
  }

  Future<void> _loadUserDataAndPets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 사용자 정보 API 호출
      final userResponse = await http.get(
        Uri.parse('${Config.serverUrl}/api/user/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      // 반려동물 목록 API 호출
      final petsResponse = await http.get(
        Uri.parse('${Config.serverUrl}/api/user/pets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(utf8.decode(userResponse.bodyBytes));
        final prefs = await SharedPreferences.getInstance();

        setState(() {
          // 사용자 정보 매핑 (DB 스키마 기준)
          userInfo = {
            'name': userData['data']['name'] ?? '',
            'nickname': prefs.getString('user_nickname') ?? '닉네임 없음',
            'phone': userData['data']['phone_number'] ?? '',
            'address': userData['data']['address'] ?? '',
            'email': userData['data']['email'] ?? '',
          };

          // 반려동물 정보는 API 성공 시에만 처리
          if (petsResponse.statusCode == 200) {
            final petsData = jsonDecode(utf8.decode(petsResponse.bodyBytes));

            print('🐕 반려동물 데이터 확인: $petsData'); // 디버깅용

            // 반려동물 정보 매핑 (DB 스키마 기준 - NOT NULL 필드들)
            userPets =
                (petsData['data'] as List<dynamic>)
                    .map(
                      (pet) => {
                        // NOT NULL 필드들 (DB 스키마 기준)
                        'pet_idx': pet['pet_idx'], // NOT NULL
                        'name': pet['name'], // NOT NULL
                        'species': pet['species'], // NOT NULL
                        'breed': pet['breed'], // NOT NULL
                        'age': pet['age_number'], // NOT NULL
                        'weight': '${pet['weight_kg']}kg', // NOT NULL (decimal)
                        'bloodType': pet['blood_type'], // NOT NULL
                        // NULLABLE 필드들 (기본값 처리)
                        'pregnant': pet['pregnant'] ?? false,
                        'vaccinated': pet['vaccinated'] ?? false,
                        'has_disease': pet['has_disease'] ?? false,
                        'has_birth_experience':
                            pet['has_birth_experience'] ?? false,
                        'prev_donation_date':
                            pet['prev_donation_date'], // nullable datetime
                      },
                    )
                    .toList();
          } else {
            // 반려동물 API 실패 시 빈 리스트
            userPets = [];
          }

          isLoading = false;
        });
      } else {
        String errorMessage =
            'API 호출 실패: User ${userResponse.statusCode}, Pets ${petsResponse.statusCode}';
        if (userResponse.statusCode != 200) {
          try {
            final userData = jsonDecode(utf8.decode(userResponse.bodyBytes));
            errorMessage = userData['detail'] ?? errorMessage;
          } catch (e) {}
        }
        if (petsResponse.statusCode != 200) {
          try {
            final petsData = jsonDecode(utf8.decode(petsResponse.bodyBytes));
            errorMessage = petsData['detail'] ?? errorMessage;
          } catch (e) {}
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      setState(() {
        // 오류 시 기본값 설정
        userInfo = {'name': '사용자', 'phone': '', 'address': '', 'email': ''};
        userPets = [];
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사용자 정보를 불러올 수 없습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
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
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 앱바
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '헌혈 신청',
                    style: AppTheme.h3Style.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 메인 콘텐츠
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 선택한 일정 정보
                          _buildSelectedScheduleInfo(),
                          const SizedBox(height: 24),

                          // 반려동물 선택
                          _buildPetSelection(),
                          const SizedBox(height: 24),

                          // 선택된 반려동물 정보 표시 (위로 이동)
                          if (selectedPet != null) _buildSelectedPetInfo(),
                          if (selectedPet != null) const SizedBox(height: 24),

                          // 신청자 정보 표시 (아래로 이동)
                          _buildUserInfo(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
          ),

          // 하단 버튼
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _canSubmitApplication() ? _showTermsBottomSheet : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '헌혈 신청하기',
                  style: AppTheme.h4Style.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 헌혈 신청 가능 여부 확인
  bool _canSubmitApplication() {
    if (selectedPet == null) return false;

    // 헌혈 가능한 반려동물 필터링 (동물 종류 매칭)
    final availablePets =
        userPets.where((pet) {
          // 동물 종류 매칭 (새로운 animal_type 필드 사용)
          bool animalTypeMatch = pet['animal_type'] == widget.post.animalType;

          // animal_type이 null인 경우 기존 species로 매칭 (하위 호환성)
          if (pet['animal_type'] == null) {
            if (widget.post.animalType == 0) {
              // 강아지
              animalTypeMatch =
                  pet['species'] == '강아지' || pet['species'] == '개';
            } else if (widget.post.animalType == 1) {
              // 고양이
              animalTypeMatch = pet['species'] == '고양이';
            }
          }

          return animalTypeMatch;
        }).toList();

    return availablePets.isNotEmpty;
  }

  Widget _buildSelectedScheduleInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '선택한 헌혈 일정',
            style: AppTheme.bodySmallStyle.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_month, color: Colors.black, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.displayText,
                  style: AppTheme.h4Style.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPetSelection() {
    // 헌혈 가능한 반려동물 필터링 (동물 종류 매칭)
    final availablePets =
        userPets.where((pet) {
          // 동물 종류 매칭 (새로운 animal_type 필드 사용)
          bool animalTypeMatch = pet['animal_type'] == widget.post.animalType;

          // animal_type이 null인 경우 기존 species로 매칭 (하위 호환성)
          if (pet['animal_type'] == null) {
            if (widget.post.animalType == 0) {
              // 강아지
              animalTypeMatch =
                  pet['species'] == '강아지' || pet['species'] == '개';
            } else if (widget.post.animalType == 1) {
              // 고양이
              animalTypeMatch = pet['species'] == '고양이';
            }
          }

          return animalTypeMatch;
        }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '반려동물 선택',
          style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // 헌혈 가능한 반려동물이 없을 때 안내 메시지
        if (availablePets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FaIcon(
                  widget.post.animalType == 0
                      ? FontAwesomeIcons.dog
                      : FontAwesomeIcons.cat,
                  size: 30,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '해당 헌혈 게시글에 참여할 수 있는 \n${widget.post.animalType == 0 ? "강아지" : "고양이"}가 없습니다',
                        style: AppTheme.bodyLargeStyle.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          // 헌혈 가능한 반려동물만 표시
          ...availablePets
              .map(
                (pet) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          selectedPet = pet;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                selectedPet?['pet_idx'] == pet['pet_idx']
                                    ? Colors.red
                                    : Colors.grey.shade400,
                            width:
                                selectedPet?['pet_idx'] == pet['pet_idx']
                                    ? 2
                                    : 1,
                          ),
                          color: Colors.grey.shade100,
                        ),
                        child: Row(
                          children: [
                            // 동물 종류별 아이콘
                            FaIcon(
                              (pet['animal_type'] == 0 ||
                                      (pet['animal_type'] == null &&
                                          (pet['species'] == "개" ||
                                              pet['species'] == "강아지")))
                                  ? FontAwesomeIcons.dog
                                  : FontAwesomeIcons.cat,
                              color:
                                  selectedPet?['pet_idx'] == pet['pet_idx']
                                      ? Colors.red
                                      : Colors.grey.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pet['name']?.toString() ?? '알 수 없음',
                                    style: AppTheme.bodyLargeStyle.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          selectedPet?['pet_idx'] ==
                                                  pet['pet_idx']
                                              ? Colors.red
                                              : AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${pet['age']?.toString() ?? '0'}세 • ${pet['weight']?.toString() ?? '0kg'} • ${pet['bloodType']?.toString() ?? ''}',
                                    style: AppTheme.bodyMediumStyle.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 수정 아이콘을 오른쪽 끝으로 이동
                            GestureDetector(
                              onTap: () {
                                _navigateToPetEditPage(pet);
                              },
                              child: Icon(
                                Icons.edit,
                                color: Colors.grey.shade600,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (selectedPet?['pet_idx'] == pet['pet_idx'])
                              Icon(Icons.check_circle, color: Colors.red),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
      ],
    );
  }

  Widget _buildUserInfo() {
    if (userInfo == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '신청자 정보',
              style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
              onPressed: _navigateToProfilePage,
              tooltip: '프로필 관리',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildInfoRow('이름', userInfo!['name']),
              _buildInfoRow('닉네임', userInfo!['nickname']),
              _buildInfoRow('연락처', userInfo!['phone']),
              _buildInfoRow('주소', userInfo!['address']),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPetInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '선택된 반려동물 정보',
              style: AppTheme.h4Style.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildInfoRow('이름', selectedPet!['name']?.toString() ?? '알 수 없음'),
              _buildInfoRow(
                '종',
                selectedPet!['species']?.toString() ?? '알 수 없음',
              ),
              _buildInfoRow(
                '품종',
                selectedPet!['breed']?.toString() ?? '알 수 없음',
              ),
              _buildInfoRow('나이', '${selectedPet!['age']?.toString() ?? '0'}세'),
              _buildInfoRow('체중', selectedPet!['weight']?.toString() ?? '0kg'),
              _buildInfoRow(
                '혈액형',
                selectedPet!['bloodType']?.toString() ?? '알 수 없음',
              ),
              _buildInfoRow(
                '예방접종',
                (selectedPet!['vaccinated'] == true) ? '완료' : '미완료',
              ),
              _buildInfoRow(
                '질병 유무',
                (selectedPet!['has_disease'] == true) ? '있음' : '없음',
              ),
              if (selectedPet!['prev_donation_date'] != null)
                _buildInfoRow(
                  '이전 헌혈일',
                  selectedPet!['prev_donation_date'].toString().split(' ')[0],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTheme.bodyMediumStyle.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMediumStyle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTermsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => TermsAgreementBottomSheet(onConfirm: _submitApplication),
    );
  }

  void _submitApplication() async {
    try {
      if (selectedPet == null) {
        throw Exception('반려동물을 선택해주세요.');
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final response = await http.post(
        Uri.parse('${Config.serverUrl}/api/donation/apply'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'post_times_idx': widget.selectedTimeSlot['post_times_idx'],
          'pet_idx': selectedPet!['pet_idx'],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        Navigator.pop(context); // 동의 바텀시트 닫기
        Navigator.pop(context); // 신청 페이지 닫기
        Navigator.pop(context); // 헌혈 게시글 바텀시트 닫기

        // 성공 시 별도의 스낵바 메시지 표시하지 않음
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          errorData['detail'] ?? errorData['message'] ?? '신청 처리 중 오류가 발생했습니다.',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('신청 실패: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// 주의사항 및 동의 바텀시트
class TermsAgreementBottomSheet extends StatefulWidget {
  final VoidCallback onConfirm;

  const TermsAgreementBottomSheet({super.key, required this.onConfirm});

  @override
  State<TermsAgreementBottomSheet> createState() =>
      _TermsAgreementBottomSheetState();
}

class _TermsAgreementBottomSheetState extends State<TermsAgreementBottomSheet> {
  bool isAgreed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
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
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Text(
                  '헌혈 주의사항 및 동의',
                  style: AppTheme.h3Style.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // 주의사항 내용
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '헌혈 전 주의사항',
                    style: AppTheme.h4Style.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNoticeItem('• 헌혈 전 8시간 이상 금식이 필요합니다.'),
                  _buildNoticeItem('• 건강한 상태의 반려동물만 헌혈 가능합니다.'),
                  _buildNoticeItem('• 헌혈 후 충분한 휴식이 필요합니다.'),
                  _buildNoticeItem('• 예방접종이 완료된 반려동물만 참여 가능합니다.'),
                  _buildNoticeItem('• 헌혈량은 체중에 따라 결정됩니다.'),

                  const SizedBox(height: 24),

                  Text(
                    '개인정보 처리 동의',
                    style: AppTheme.h4Style.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNoticeItem('• 헌혈 신청을 위한 개인정보 수집에 동의합니다.'),
                  _buildNoticeItem('• 수집된 정보는 헌혈 관련 목적으로만 사용됩니다.'),
                  _buildNoticeItem('• 개인정보는 안전하게 보관되며 목적 달성 후 파기됩니다.'),
                ],
              ),
            ),
          ),

          // 동의 체크박스 및 버튼
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: isAgreed,
                      onChanged: (value) {
                        setState(() {
                          isAgreed = value ?? false;
                        });
                      },
                      activeColor: AppTheme.primaryBlue,
                    ),
                    Expanded(
                      child: Text(
                        '위의 주의사항을 숙지 및 개인정보 처리에 동의합니다.',
                        style: AppTheme.bodyMediumStyle.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        child: Text(
                          '취소',
                          style: AppTheme.bodyLargeStyle.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            isAgreed
                                ? () {
                                  Navigator.pop(context);
                                  widget.onConfirm();
                                }
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          disabledBackgroundColor: Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          '확인',
                          style: AppTheme.bodyLargeStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: AppTheme.bodyMediumStyle.copyWith(height: 1.5)),
    );
  }
}

// DonationApplicationPage 클래스의 추가 메서드들
extension DonationApplicationPageMethods on _DonationApplicationPageState {
  // 사용자 정보 수정 다이얼로그
  void _showEditUserInfoDialog() {
    final nameController = TextEditingController(text: userInfo!['name']);
    final phoneController = TextEditingController(text: userInfo!['phone']);
    final addressController = TextEditingController(text: userInfo!['address']);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('사용자 정보 수정'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '이름',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: '연락처',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: '주소',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _updateUserInfo(
                    nameController.text,
                    phoneController.text,
                    addressController.text,
                  );
                  Navigator.pop(context);
                },
                child: const Text('저장'),
              ),
            ],
          ),
    );
  }

  // 반려동물 정보 수정 다이얼로그
  void _showEditPetInfoDialog(Map<String, dynamic> pet) {
    final nameController = TextEditingController(text: pet['name']);
    final breedController = TextEditingController(text: pet['breed']);
    final ageController = TextEditingController(text: pet['age'].toString());
    final weightController = TextEditingController(
      text: pet['weight'].toString().replaceAll('kg', ''),
    );
    final bloodTypeController = TextEditingController(text: pet['bloodType']);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('반려동물 정보 수정'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '이름',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: breedController,
                    decoration: const InputDecoration(
                      labelText: '품종',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: ageController,
                    decoration: const InputDecoration(
                      labelText: '나이 (세)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: weightController,
                    decoration: const InputDecoration(
                      labelText: '체중 (kg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: bloodTypeController,
                    decoration: const InputDecoration(
                      labelText: '혈액형',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _updatePetInfo(
                    pet['pet_idx'],
                    nameController.text,
                    breedController.text,
                    int.tryParse(ageController.text) ?? 0,
                    double.tryParse(weightController.text) ?? 0.0,
                    bloodTypeController.text,
                  );
                  Navigator.pop(context);
                },
                child: const Text('저장'),
              ),
            ],
          ),
    );
  }

  // 사용자 정보 업데이트 API
  Future<void> _updateUserInfo(
    String name,
    String phone,
    String address,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final response = await http.put(
        Uri.parse('${Config.serverUrl}/api/user/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'name': name,
          'phone_number': phone,
          'address': address,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          userInfo!['name'] = name;
          userInfo!['phone'] = phone;
          userInfo!['address'] = address;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사용자 정보가 수정되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(errorData['detail'] ?? '수정 실패: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('수정 실패: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 반려동물 정보 업데이트 API
  Future<void> _updatePetInfo(
    int petIdx,
    String name,
    String breed,
    int age,
    double weight,
    String bloodType,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        throw Exception('로그인이 필요합니다.');
      }

      final response = await http.put(
        Uri.parse('${Config.serverUrl}/api/user/pets/$petIdx'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'name': name,
          'breed': breed,
          'age_number': age,
          'weight_kg': weight,
          'blood_type': bloodType,
        }),
      );

      if (response.statusCode == 200) {
        // 로컬 데이터 업데이트
        for (int i = 0; i < userPets.length; i++) {
          if (userPets[i]['pet_idx'] == petIdx) {
            setState(() {
              userPets[i]['name'] = name;
              userPets[i]['breed'] = breed;
              userPets[i]['age'] = age;
              userPets[i]['weight'] = '${weight}kg';
              userPets[i]['bloodType'] = bloodType;

              // 선택된 반려동물이 수정된 경우 업데이트
              if (selectedPet != null && selectedPet!['pet_idx'] == petIdx) {
                selectedPet = userPets[i];
              }
            });
            break;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('반려동물 정보가 수정되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(errorData['detail'] ?? '수정 실패: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('수정 실패: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 반려동물 수정 페이지로 이동
  void _navigateToPetEditPage(Map<String, dynamic> petData) async {
    // Pet 모델로 변환
    final pet = Pet(
      petIdx: petData['pet_idx'],
      accountIdx: 0, // 현재 사용자의 account_idx
      ownerEmail: userInfo?['email'] ?? '', // 사용자 이메일 추가
      name: petData['name']?.toString() ?? '',
      species: petData['species']?.toString() ?? '',
      breed: petData['breed']?.toString() ?? '',
      ageNumber: petData['age'] ?? 0,
      bloodType: petData['bloodType']?.toString() ?? '',
      weightKg:
          double.tryParse(
            petData['weight']?.toString().replaceAll('kg', '') ?? '0',
          ) ??
          0.0,
      pregnant: petData['pregnant'] ?? false,
      vaccinated: petData['vaccinated'] ?? false,
      hasDisease: petData['has_disease'] ?? false,
      hasBirthExperience: petData['has_birth_experience'] ?? false,
      prevDonationDate:
          petData['prev_donation_date'] != null
              ? DateTime.tryParse(petData['prev_donation_date'].toString())
              : null,
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PetRegisterScreen(petToEdit: pet),
      ),
    );

    if (result == true) {
      // 수정 완료 후 다시 데이터 로드
      _loadUserDataAndPets();
    }
  }

  // 신청자 정보 수정 페이지로 이동
  void _navigateToProfilePage() {
    Navigator.pushNamed(context, '/profile_management').then((_) {
      // 수정 완료 후 다시 데이터 로드
      _loadUserDataAndPets();
    });
  }
}
